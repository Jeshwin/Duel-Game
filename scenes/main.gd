extends Node3D

@onready var arena:          Node3D      = $Arena
@onready var players_root:   Node3D      = $Players
@onready var hud:            CanvasLayer = $HUD
@onready var loadout_screen: CanvasLayer = $LoadoutScreen

var player_scene := preload("res://scenes/player/player.tscn")


func _ready() -> void:
	_spawn_players()
	_wire_game_manager()
	_wire_hud()
	loadout_screen.loadout_confirmed.connect(_on_loadout_confirmed)
	GameManager.start_loadout_phase()


func _spawn_players() -> void:
	# Player 1 — local, full FPS control
	var p1: Player = player_scene.instantiate()
	p1.name          = "Player1"
	p1.player_id     = 1
	p1.is_local_player = true
	p1.global_position = arena.get_spawn(1)
	players_root.add_child(p1)

	# Player 2 — second local player or AI placeholder
	# Set is_local_player = false so they don't capture mouse / respond to input
	var p2: Player = player_scene.instantiate()
	p2.name          = "Player2"
	p2.player_id     = 2
	p2.is_local_player = false
	p2.global_position = arena.get_spawn(2)
	# Tint P2 blue so players are visually distinct
	var body_mesh := p2.get_node("Body") as MeshInstance3D
	if body_mesh:
		var mat := body_mesh.get_surface_override_material(0).duplicate() as StandardMaterial3D
		mat.albedo_color = Color(0.2, 0.2, 0.8)
		body_mesh.set_surface_override_material(0, mat)
	players_root.add_child(p2)


func _wire_game_manager() -> void:
	for child in players_root.get_children():
		if child is Player:
			GameManager.register_player(child)
	GameManager.register_arena(arena)
	GameManager.score_updated.connect(_on_score_updated)
	GameManager.round_started.connect(_on_round_started)
	GameManager.round_ended.connect(_on_round_ended)
	GameManager.match_ended.connect(_on_match_ended)
	GameManager.countdown_tick.connect(_on_countdown)


func _wire_hud() -> void:
	var p1 = players_root.get_node("Player1") as Player
	if p1:
		hud.bind_player(p1)
		p1.connect("_equip", hud.bind_weapon)


func _on_loadout_confirmed() -> void:
	pass  # GameManager.start_match() is called from LoadoutScreen directly


func _on_score_updated(player_id: int, _new_score: int) -> void:
	var p1s = GameManager.scores.get(1, 0)
	var p2s = GameManager.scores.get(2, 0)
	hud.update_score(p1s, p2s)


func _on_round_started(round_num: int) -> void:
	hud.set_round(round_num)


func _on_round_ended(winner_id: int) -> void:
	hud.show_announcement("Player %d wins the round!" % winner_id, 2.5)


func _on_match_ended(winner_id: int) -> void:
	hud.show_announcement("PLAYER %d WINS THE MATCH!" % winner_id, 5.0)


func _on_countdown(seconds_left: int) -> void:
	var text = "GO!" if seconds_left == 0 else str(seconds_left)
	hud.show_announcement(text, 0.9)
