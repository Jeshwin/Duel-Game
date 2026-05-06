extends Node

enum GameState { LOADOUT, COUNTDOWN, PLAYING, ROUND_END, MATCH_END }

const ROUNDS_TO_WIN   := 3
const RESPAWN_DELAY   := 3.0
const COUNTDOWN_TIME  := 3.0

var game_state: GameState = GameState.LOADOUT
var scores: Dictionary = { 1: 0, 2: 0 }
var round_number := 1

var _players: Dictionary = {}   # player_id -> Player node
var _arena: Node3D = null

signal score_updated(player_id: int, new_score: int)
signal round_started(round_num: int)
signal round_ended(winning_player_id: int)
signal match_ended(winning_player_id: int)
signal countdown_tick(seconds_left: int)


func register_player(player: Player) -> void:
	_players[player.player_id] = player


func register_arena(arena: Node3D) -> void:
	_arena = arena


func start_loadout_phase() -> void:
	game_state = GameState.LOADOUT


func start_match() -> void:
	scores = { 1: 0, 2: 0 }
	round_number = 1
	_start_round()


func _start_round() -> void:
	# Apply loadouts
	for id in _players:
		var p: Player = _players[id]
		var loadout = LoadoutManager.get_player_loadout(id)
		p.set_loadout(loadout)
		if _arena and _arena.has_method("get_spawn"):
			p.respawn(_arena.get_spawn(id))

	emit_signal("round_started", round_number)
	_begin_countdown()


func _begin_countdown() -> void:
	game_state = GameState.COUNTDOWN
	_set_players_frozen(true)

	for i in range(int(COUNTDOWN_TIME), 0, -1):
		await get_tree().create_timer(1.0).timeout
		emit_signal("countdown_tick", i)

	_set_players_frozen(false)
	game_state = GameState.PLAYING


func on_player_died(dead_player_id: int) -> void:
	if game_state != GameState.PLAYING:
		return

	var winner_id = 2 if dead_player_id == 1 else 1
	scores[winner_id] += 1
	emit_signal("score_updated", winner_id, scores[winner_id])
	emit_signal("round_ended", winner_id)

	if scores[winner_id] >= ROUNDS_TO_WIN:
		_end_match(winner_id)
	else:
		round_number += 1
		game_state = GameState.ROUND_END
		await get_tree().create_timer(RESPAWN_DELAY).timeout
		_start_round()


func _end_match(winner_id: int) -> void:
	game_state = GameState.MATCH_END
	_set_players_frozen(true)
	emit_signal("match_ended", winner_id)


func _set_players_frozen(frozen: bool) -> void:
	for p in _players.values():
		p.set_physics_process(not frozen)
		p.set_process_unhandled_input(not frozen)
