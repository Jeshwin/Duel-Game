class_name Player
extends CharacterBody3D

# --- Movement constants ---
const WALK_SPEED       := 6.5
const JUMP_VELOCITY    := 9.0
const DOUBLE_JUMP_VEL  := 7.5
const GRAVITY          := 20.0       # Also set in project physics, used here for fine control
const AIR_CONTROL      := 0.35       # 0–1 fraction of ground speed usable in air
const DIVE_SPEED       := 18.0
const DIVE_DURATION    := 0.28       # seconds the dive lasts
const ROLL_SPEED       := 13.0
const ROLL_DURATION    := 0.40
const CLIMB_DURATION   := 0.35
const STICK_DEAD_ZONE  := 0.15       # ignore right-stick input below this magnitude

# --- State machine ---
enum State {
	IDLE, RUNNING, JUMPING, DOUBLE_JUMPING,
	FALLING, DIVING, ROLLING, EDGE_GRABBING, CLIMBING, DEAD
}
var state: State = State.IDLE

# --- Runtime vars ---
var can_double_jump  := true
var dive_timer       := 0.0
var roll_timer       := 0.0
var climb_timer      := 0.0
var dive_dir         := Vector3.ZERO
var is_local_player  := true
var player_id        := 1

# --- Health ---
var max_health := 100
var health     := 100

# --- Weapons ---
var weapons: Array[WeaponBase] = []
var current_weapon_index := 0
var current_weapon: WeaponBase = null

# --- Nodes ---
@onready var head:           Node3D        = $Head
@onready var camera:         Camera3D      = $Head/Camera3D
@onready var weapon_holder:  Node3D        = $Head/Camera3D/WeaponHolder
@onready var edge_ray_front: RayCast3D     = $EdgeRayFront
@onready var edge_ray_top:   RayCast3D     = $EdgeRayTop

signal health_changed(new_health: int, max_hp: int)
signal died(id: int)


func _ready() -> void:
	add_to_group("players")
	if is_local_player:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		camera.current = true
		camera.add_to_group("player_camera")


func _unhandled_input(event: InputEvent) -> void:
	if not is_local_player or state == State.DEAD:
		return

	if event is InputEventMouseMotion:
		_rotate_camera(event.relative)

	elif event.is_action_pressed("jump"):
		_try_jump()

	elif event.is_action_pressed("dive_roll"):
		_try_dive_roll()

	elif event.is_action_pressed("fire"):
		if current_weapon:
			current_weapon.fire()

	elif event.is_action_pressed("aim"):
		if current_weapon:
			current_weapon.set_aiming(true)

	elif event.is_action_released("aim"):
		if current_weapon:
			current_weapon.set_aiming(false)

	elif event.is_action_pressed("reload"):
		if current_weapon:
			current_weapon.reload()

	elif event.is_action_pressed("switch_weapon"):
		_cycle_weapon()


func _physics_process(delta: float) -> void:
	if not is_local_player or state == State.DEAD:
		return

	match state:
		State.IDLE, State.RUNNING:
			_process_grounded(delta)
		State.JUMPING, State.DOUBLE_JUMPING, State.FALLING:
			_process_airborne(delta)
		State.DIVING:
			_process_diving(delta)
		State.ROLLING:
			_process_rolling(delta)
		State.EDGE_GRABBING:
			_process_edge_grab()
		State.CLIMBING:
			_process_climbing(delta)

	_process_stick_look(delta)
	move_and_slide()


# ── Movement processors ──────────────────────────────────────────────────────

func _process_grounded(delta: float) -> void:
	var dir = _flat_input_direction()
	var speed := WALK_SPEED

	if dir != Vector3.ZERO:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		state = State.RUNNING
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * 10.0 * delta)
		state = State.IDLE

	# Small downward nudge keeps us on slopes without floating
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
		state = State.FALLING
	else:
		velocity.y = -0.5   # constant tiny push into floor

	_check_edge_grab()


func _process_airborne(delta: float) -> void:
	velocity.y -= GRAVITY * delta

	var dir = _flat_input_direction()
	if dir != Vector3.ZERO:
		velocity.x = lerp(velocity.x, dir.x * WALK_SPEED, AIR_CONTROL * delta * 10.0)
		velocity.z = lerp(velocity.z, dir.z * WALK_SPEED, AIR_CONTROL * delta * 10.0)

	if is_on_floor():
		velocity.y = 0.0
		state = State.IDLE
		can_double_jump = true
		return

	if velocity.y < 0.0 and state == State.JUMPING:
		state = State.FALLING

	_check_edge_grab()


func _process_diving(delta: float) -> void:
	dive_timer -= delta
	velocity.x = dive_dir.x * DIVE_SPEED
	velocity.z = dive_dir.z * DIVE_SPEED
	velocity.y = -3.0    # slight downward arc so it reads as "dive"

	if dive_timer <= 0.0:
		state = State.FALLING
		velocity.x *= 0.5
		velocity.z *= 0.5

	if is_on_floor():
		state = State.IDLE
		dive_timer = 0.0


func _process_rolling(delta: float) -> void:
	roll_timer -= delta
	var fwd = -transform.basis.z
	velocity.x = fwd.x * ROLL_SPEED
	velocity.z = fwd.z * ROLL_SPEED
	velocity.y = 0.0

	if roll_timer <= 0.0 or not is_on_floor():
		state = State.IDLE if is_on_floor() else State.FALLING
		roll_timer = 0.0


func _process_edge_grab() -> void:
	velocity = Vector3.ZERO


func _process_climbing(delta: float) -> void:
	climb_timer -= delta
	# Boost up and slightly forward onto the ledge
	velocity = Vector3(0.0, 7.0, 0.0) + (-transform.basis.z * 3.0)
	if climb_timer <= 0.0:
		state = State.IDLE
		climb_timer = 0.0


# ── Action handlers ──────────────────────────────────────────────────────────

func _try_jump() -> void:
	match state:
		State.IDLE, State.RUNNING:
			velocity.y = JUMP_VELOCITY
			state = State.JUMPING
			can_double_jump = true

		State.JUMPING, State.FALLING, State.DOUBLE_JUMPING:
			if can_double_jump:
				velocity.y = DOUBLE_JUMP_VEL
				state = State.DOUBLE_JUMPING
				can_double_jump = false

		State.EDGE_GRABBING:
			# Wall-jump off the ledge
			state = State.CLIMBING
			climb_timer = CLIMB_DURATION


func _try_dive_roll() -> void:
	if state in [State.JUMPING, State.FALLING, State.DOUBLE_JUMPING]:
		# Air dive
		var dir = _flat_input_direction()
		dive_dir = dir if dir != Vector3.ZERO else -transform.basis.z
		dive_timer = DIVE_DURATION
		state = State.DIVING

	elif state in [State.IDLE, State.RUNNING] and is_on_floor():
		# Ground roll
		state = State.ROLLING
		roll_timer = ROLL_DURATION


func _check_edge_grab() -> void:
	if state in [State.EDGE_GRABBING, State.CLIMBING, State.ROLLING, State.DIVING]:
		return
	if velocity.y >= 0.0:
		return  # Only grab on the way down

	# edge_ray_front: at shoulder height, points forward — detects the wall face
	# edge_ray_top:   just above the ledge, points forward — clears if ledge top is open
	if edge_ray_front.is_colliding() and not edge_ray_top.is_colliding():
		var normal = edge_ray_front.get_collision_normal()
		if abs(normal.y) < 0.15:   # roughly vertical surface
			state = State.EDGE_GRABBING
			velocity = Vector3.ZERO
			can_double_jump = true   # reset double-jump on grab


# ── Helpers ──────────────────────────────────────────────────────────────────

func _flat_input_direction() -> Vector3:
	var raw = Vector2(
		Input.get_axis("move_left",    "move_right"),
		Input.get_axis("move_forward", "move_backward")
	)
	if raw == Vector2.ZERO:
		return Vector3.ZERO
	return (transform.basis * Vector3(raw.x, 0.0, raw.y)).normalized()


func _rotate_camera(mouse_delta: Vector2) -> void:
	var sens := SettingsManager.mouse_sensitivity
	rotate_y(-mouse_delta.x * sens)
	head.rotate_x(-mouse_delta.y * sens)
	head.rotation.x = clamp(head.rotation.x, -deg_to_rad(85.0), deg_to_rad(85.0))


func _process_stick_look(delta: float) -> void:
	# Don't rotate when settings menu is open (mouse is visible)
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var rx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var ry := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if abs(rx) < STICK_DEAD_ZONE: rx = 0.0
	if abs(ry) < STICK_DEAD_ZONE: ry = 0.0
	if rx == 0.0 and ry == 0.0:
		return
	var sens := SettingsManager.controller_look_sens
	rotate_y(-rx * sens * delta)
	head.rotate_x(-ry * sens * delta)
	head.rotation.x = clamp(head.rotation.x, -deg_to_rad(85.0), deg_to_rad(85.0))


# ── Weapon management ────────────────────────────────────────────────────────

func set_loadout(weapon_types: Array) -> void:
	for w in weapons:
		w.queue_free()
	weapons.clear()
	current_weapon = null
	current_weapon_index = 0

	for wtype in weapon_types:
		var wb := WeaponBase.new()
		var wd := WeaponData.create(wtype)
		weapon_holder.add_child(wb)
		wb.setup(wd, camera, self)
		wb.visible = false
		weapons.append(wb)

	if weapons.size() > 0:
		_equip(0)


func _equip(index: int) -> void:
	if current_weapon:
		current_weapon.visible = false
		if current_weapon.is_aiming:
			current_weapon.set_aiming(false)
	current_weapon_index = index
	current_weapon = weapons[index]
	current_weapon.visible = true


func _cycle_weapon() -> void:
	if weapons.size() < 2:
		return
	_equip((current_weapon_index + 1) % weapons.size())


# ── Health ───────────────────────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return
	health = max(0, health - amount)
	emit_signal("health_changed", health, max_health)
	if health == 0:
		_die()


func _die() -> void:
	state = State.DEAD
	velocity = Vector3.ZERO
	emit_signal("died", player_id)
	GameManager.on_player_died(player_id)


func respawn(spawn_pos: Vector3) -> void:
	health = max_health
	state = State.IDLE
	global_position = spawn_pos
	velocity = Vector3.ZERO
	emit_signal("health_changed", health, max_health)
