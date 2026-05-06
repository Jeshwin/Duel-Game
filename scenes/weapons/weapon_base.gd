class_name WeaponBase
extends Node3D

var data: WeaponData
var current_ammo: int = 0
var is_reloading: bool = false
var fire_cooldown: float = 0.0
var is_aiming: bool = false

var _camera_ref: Camera3D = null
var _owner_body: Node3D = null    # The CharacterBody3D that holds this weapon

signal ammo_changed(current: int, maximum: int)
signal reload_started
signal reload_finished
signal fired


func _ready() -> void:
	if data:
		current_ammo = data.magazine_size
		_build_placeholder_mesh()


func _process(delta: float) -> void:
	if fire_cooldown > 0.0:
		fire_cooldown -= delta

	if data and data.is_automatic and not data.is_melee:
		if Input.is_action_pressed("fire") and fire_cooldown <= 0.0 and not is_reloading:
			_execute_fire()


func setup(weapon_data: WeaponData, camera: Camera3D, owner_body: Node3D) -> void:
	data = weapon_data
	_camera_ref = camera
	_owner_body = owner_body
	current_ammo = data.magazine_size if not data.is_melee else 0
	_build_placeholder_mesh()


func fire() -> void:
	if is_reloading or fire_cooldown > 0.0:
		return
	if data.is_melee:
		_execute_melee()
		return
	if current_ammo <= 0:
		reload()
		return
	_execute_fire()


func _execute_fire() -> void:
	current_ammo -= 1
	fire_cooldown = data.fire_rate
	emit_signal("fired")
	emit_signal("ammo_changed", current_ammo, data.magazine_size)

	if not _camera_ref:
		return

	for _i in range(data.pellets):
		var spread_vec = Vector3(
			randf_range(-data.spread, data.spread),
			randf_range(-data.spread, data.spread),
			0.0
		)
		var ray_origin = _camera_ref.global_position
		var ray_dir = (_camera_ref.global_transform.basis * (Vector3.FORWARD + spread_vec)).normalized()
		_cast_bullet(ray_origin, ray_dir)


func _execute_melee() -> void:
	fire_cooldown = data.fire_rate
	emit_signal("fired")

	if not _camera_ref:
		return

	var space_state = get_world_3d().direct_space_state
	var params = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 1.2
	params.shape = sphere
	params.transform = Transform3D(
		Basis(),
		_camera_ref.global_position + (-_camera_ref.global_transform.basis.z * data.melee_range)
	)
	if _owner_body:
		params.exclude = [_owner_body.get_rid()]

	var results = space_state.intersect_shape(params)
	for result in results:
		var collider = result.get("collider")
		if collider and collider.has_method("take_damage"):
			collider.take_damage(data.damage)


func _cast_bullet(ray_origin: Vector3, ray_dir: Vector3) -> void:
	var space_state = get_world_3d().direct_space_state
	var ray_end = ray_origin + ray_dir * data.range_max
	var params = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	if _owner_body:
		params.exclude = [_owner_body.get_rid()]

	var result = space_state.intersect_ray(params)
	if result:
		var collider = result.get("collider")
		if collider and collider.has_method("take_damage"):
			collider.take_damage(data.damage)
		_spawn_hit_marker(result.get("position", Vector3.ZERO))


func _spawn_hit_marker(pos: Vector3) -> void:
	# Placeholder: simple MeshInstance3D flash that auto-removes
	var marker = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.05
	sphere_mesh.height = 0.1
	marker.mesh = sphere_mesh
	marker.global_position = pos
	get_tree().root.add_child(marker)
	await get_tree().create_timer(0.15).timeout
	marker.queue_free()


func reload() -> void:
	if is_reloading or data.is_melee:
		return
	if current_ammo == data.magazine_size:
		return
	is_reloading = true
	emit_signal("reload_started")
	await get_tree().create_timer(data.reload_time).timeout
	current_ammo = data.magazine_size
	is_reloading = false
	emit_signal("reload_finished")
	emit_signal("ammo_changed", current_ammo, data.magazine_size)


func set_aiming(aiming: bool) -> void:
	is_aiming = aiming
	if not _camera_ref:
		return
	var tween = create_tween()
	var target_fov = 70.0 if not aiming else data.ads_fov
	tween.tween_property(_camera_ref, "fov", target_fov, 0.12)


func _build_placeholder_mesh() -> void:
	for child in get_children():
		if child is MeshInstance3D:
			child.queue_free()

	var mi = MeshInstance3D.new()
	var box = BoxMesh.new()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.25, 0.3)

	match data.weapon_type:
		WeaponData.WeaponType.ASSAULT_RIFLE:
			box.size = Vector3(0.05, 0.07, 0.55)
		WeaponData.WeaponType.SNIPER:
			box.size = Vector3(0.04, 0.05, 0.80)
			mat.albedo_color = Color(0.15, 0.15, 0.2)
		WeaponData.WeaponType.PISTOL:
			box.size = Vector3(0.04, 0.12, 0.20)
		WeaponData.WeaponType.SHOTGUN:
			box.size = Vector3(0.06, 0.08, 0.60)
			mat.albedo_color = Color(0.35, 0.2, 0.1)
		WeaponData.WeaponType.UZI:
			box.size = Vector3(0.05, 0.14, 0.26)
		WeaponData.WeaponType.MACHINE_GUN:
			box.size = Vector3(0.07, 0.08, 0.65)
			mat.albedo_color = Color(0.2, 0.2, 0.15)
		WeaponData.WeaponType.SWORD:
			box.size = Vector3(0.03, 0.50, 0.015)
			mat.albedo_color = Color(0.7, 0.7, 0.8)

	mi.mesh = box
	mi.set_surface_override_material(0, mat)
	# Offset so weapon sits in bottom-right view like a typical FPS
	mi.position = Vector3(0.18, -0.15, -0.35)
	add_child(mi)
