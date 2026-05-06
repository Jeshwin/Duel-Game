extends Node3D

@onready var arena:          Node3D      = $Arena
@onready var players_root:   Node3D      = $Players
@onready var hud:            CanvasLayer = $HUD
@onready var loadout_screen: CanvasLayer = $LoadoutScreen
@onready var settings_menu:  CanvasLayer = $SettingsMenu

var player_scene := preload("res://scenes/player/player.tscn")


func _ready() -> void:
	_spawn_players()
	_wire_game_manager()
	_wire_hud()
	loadout_screen.loadout_confirmed.connect(_on_loadout_confirmed)
	settings_menu.closed.connect(_on_settings_closed)
	GameManager.start_loadout_phase()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not settings_menu.visible:
		_open_settings()
		get_viewport().set_input_as_handled()


func _open_settings() -> void:
	_set_player1_input(false)
	settings_menu.open()


func _on_settings_closed() -> void:
	# Only re-capture mouse and re-enable input during active play
	if GameManager.game_state == GameManager.GameState.PLAYING:
		_set_player1_input(true)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _set_player1_input(enabled: bool) -> void:
	var p1 := players_root.get_node_or_null("Player1") as Player
	if p1:
		p1.set_process_unhandled_input(enabled)


func _spawn_players() -> void:
	var p1: Player = player_scene.instantiate()
	p1.name           = "Player1"
	p1.player_id      = 1
	p1.is_local_player = true
	p1.global_position = arena.get_spawn(1)
	players_root.add_child(p1)

	var p2: Player = player_scene.instantiate()
	p2.name           = "Player2"
	p2.player_id      = 2
	p2.is_local_player = false
	p2.global_position = arena.get_spawn(2)
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
	var p1 := players_root.get_node("Player1") as Player
	if p1:
		hud.bind_player(p1)
	hud.settings_requested.connect(_open_settings)


func _on_loadout_confirmed() -> void:
	pass  # GameManager.start_match() called directly from LoadoutScreen


func _on_score_updated(_player_id: int, _new_score: int) -> void:
	hud.update_score(GameManager.scores.get(1, 0), GameManager.scores.get(2, 0))


func _on_round_started(round_num: int) -> void:
	hud.set_round(round_num)


func _on_round_ended(winner_id: int) -> void:
	hud.show_announcement("Player %d wins the round!" % winner_id, 2.5)


func _on_match_ended(winner_id: int) -> void:
	hud.show_announcement("PLAYER %d WINS THE MATCH!" % winner_id, 5.0)


func _on_countdown(seconds_left: int) -> void:
	hud.show_announcement("GO!" if seconds_left == 0 else str(seconds_left), 0.9)
