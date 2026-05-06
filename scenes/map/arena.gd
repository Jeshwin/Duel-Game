extends Node3D

# Spawn point paths — read by GameManager
@export var spawn_point_1: NodePath = "SpawnPoints/Spawn1"
@export var spawn_point_2: NodePath = "SpawnPoints/Spawn2"


func _ready() -> void:
	_build_arena()


func get_spawn(player_id: int) -> Vector3:
	var sp_name = "Spawn1" if player_id == 1 else "Spawn2"
	var sp = get_node_or_null("SpawnPoints/" + sp_name)
	return sp.global_position if sp else Vector3.ZERO


# ── Arena construction ────────────────────────────────────────────────────────
#
# Layout (side view, Y = up):
#
#           [TOP BRIDGE]          y=14
#       [HL]          [HR]        y=10
#     [ML]  [MC]  [MC]  [MR]     y=6
#  [===== GROUND FLOOR =====]     y=0
#
# Players spawn at opposite ends of the ground floor.
# Platforms are symmetrical for fair 1v1 play.

func _build_arena() -> void:
	_add_sky_and_light()

	# --- Ground ---
	_add_static_box(Vector3(0, -0.5, 0),   Vector3(40, 1, 40), Color(0.3, 0.35, 0.3))

	# --- Back walls (left/right boundary) ---
	_add_static_box(Vector3(-20.5, 8, 0),  Vector3(1, 20, 40), Color(0.2, 0.2, 0.25))
	_add_static_box(Vector3(20.5, 8, 0),   Vector3(1, 20, 40), Color(0.2, 0.2, 0.25))
	# --- Front/back boundary ---
	_add_static_box(Vector3(0, 8, -20.5),  Vector3(40, 20, 1), Color(0.2, 0.2, 0.25))
	_add_static_box(Vector3(0, 8, 20.5),   Vector3(40, 20, 1), Color(0.2, 0.2, 0.25))

	# --- Mid-level platforms (y=6) ---
	_add_static_box(Vector3(-12, 6, 0),    Vector3(10, 0.6, 8),  Color(0.45, 0.4, 0.35))
	_add_static_box(Vector3(12, 6, 0),     Vector3(10, 0.6, 8),  Color(0.45, 0.4, 0.35))

	# --- Centre bridge connecting mid platforms ---
	_add_static_box(Vector3(0, 6, 0),      Vector3(8, 0.6, 4),   Color(0.5, 0.45, 0.4))

	# --- High-level platforms (y=10) ---
	_add_static_box(Vector3(-14, 10, 0),   Vector3(7, 0.6, 6),   Color(0.4, 0.35, 0.5))
	_add_static_box(Vector3(14, 10, 0),    Vector3(7, 0.6, 6),   Color(0.4, 0.35, 0.5))

	# --- Top bridge (y=14) — sniper heaven ---
	_add_static_box(Vector3(0, 14, 0),     Vector3(12, 0.6, 3),  Color(0.35, 0.3, 0.45))

	# --- Ramps connecting ground to mid (walkable slopes) ---
	_add_ramp(Vector3(-15, 3, 5),   Vector3(4, 0.4, 7),  -20.0)
	_add_ramp(Vector3(-15, 3, -5),  Vector3(4, 0.4, 7),   20.0)
	_add_ramp(Vector3(15, 3, 5),    Vector3(4, 0.4, 7),  -20.0)
	_add_ramp(Vector3(15, 3, -5),   Vector3(4, 0.4, 7),   20.0)

	# --- Cover objects on ground ---
	_add_cover(Vector3(-6, 0, 6),    Vector3(2.5, 1.2, 0.5))
	_add_cover(Vector3(6, 0, 6),     Vector3(2.5, 1.2, 0.5))
	_add_cover(Vector3(-6, 0, -6),   Vector3(2.5, 1.2, 0.5))
	_add_cover(Vector3(6, 0, -6),    Vector3(2.5, 1.2, 0.5))
	_add_cover(Vector3(0, 0, 8),     Vector3(1.2, 1.8, 1.2))  # tall pillar
	_add_cover(Vector3(0, 0, -8),    Vector3(1.2, 1.8, 1.2))
	# Crates on mid platforms
	_add_cover(Vector3(-12, 6.6, 2), Vector3(1.0, 1.0, 1.0))
	_add_cover(Vector3(12, 6.6, -2), Vector3(1.0, 1.0, 1.0))
	# Low walls on high platforms
	_add_cover(Vector3(-14, 10.6, 2.2),  Vector3(4.0, 0.8, 0.4))
	_add_cover(Vector3(14, 10.6, -2.2),  Vector3(4.0, 0.8, 0.4))

	# --- Spawn points ---
	var spawn_root = Node3D.new()
	spawn_root.name = "SpawnPoints"
	add_child(spawn_root)

	var sp1 = Marker3D.new()
	sp1.name = "Spawn1"
	sp1.position = Vector3(-17, 1.0, 0)
	spawn_root.add_child(sp1)

	var sp2 = Marker3D.new()
	sp2.name = "Spawn2"
	sp2.position = Vector3(17, 1.0, 0)
	spawn_root.add_child(sp2)


# ── Builder helpers ───────────────────────────────────────────────────────────

func _add_static_box(pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0

	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.set_surface_override_material(0, mat)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape

	body.add_child(mi)
	body.add_child(col)
	add_child(body)
	return body


func _add_ramp(pos: Vector3, size: Vector3, angle_deg: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees.x = angle_deg
	body.collision_layer = 1

	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.38, 0.32)
	mi.set_surface_override_material(0, mat)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape

	body.add_child(mi)
	body.add_child(col)
	add_child(body)
	return body


func _add_cover(pos: Vector3, size: Vector3) -> StaticBody3D:
	return _add_static_box(pos + Vector3(0, size.y * 0.5, 0), size, Color(0.5, 0.42, 0.3))


func _add_sky_and_light() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.14, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.3, 0.4)
	env.ambient_light_energy = 0.6
	env_node.environment = env
	add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

	# Fill light from opposite direction
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, -150, 0)
	fill.light_energy = 0.4
	fill.shadow_enabled = false
	add_child(fill)
