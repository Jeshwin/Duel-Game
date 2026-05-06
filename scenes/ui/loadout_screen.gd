extends CanvasLayer

# Loadout screen: each player picks up to 2 weapons before the match starts.
# Player 1 confirms with Enter, Player 2 confirms with Numpad Enter (or same Enter
# for single-player testing). When both confirm, the match begins.

const WEAPON_NAMES := {
	WeaponData.WeaponType.ASSAULT_RIFLE: "Assault Rifle",
	WeaponData.WeaponType.SNIPER:        "Sniper Rifle",
	WeaponData.WeaponType.PISTOL:        "Pistol",
	WeaponData.WeaponType.SHOTGUN:       "Shotgun",
	WeaponData.WeaponType.UZI:           "Uzi",
	WeaponData.WeaponType.MACHINE_GUN:   "Machine Gun",
	WeaponData.WeaponType.SWORD:         "Sword",
}

var _selections: Dictionary = { 1: [], 2: [] }
var _confirmed: Dictionary = { 1: false, 2: false }
var _active_player := 1    # which player's column the UI focuses

@onready var p1_list:    ItemList = $PanelContainer/HBoxContainer/P1Column/WeaponList
@onready var p2_list:    ItemList = $PanelContainer/HBoxContainer/P2Column/WeaponList
@onready var p1_confirm: Button   = $PanelContainer/HBoxContainer/P1Column/ConfirmButton
@onready var p2_confirm: Button   = $PanelContainer/HBoxContainer/P2Column/ConfirmButton
@onready var start_btn:  Button   = $StartButton

signal loadout_confirmed


func _ready() -> void:
	_populate_list(p1_list)
	_populate_list(p2_list)

	p1_list.multi_selected.connect(_on_p1_selected)
	p2_list.multi_selected.connect(_on_p2_selected)
	p1_confirm.pressed.connect(_confirm_player.bind(1))
	p2_confirm.pressed.connect(_confirm_player.bind(2))
	start_btn.pressed.connect(_on_start_pressed)
	start_btn.disabled = true


func _populate_list(list: ItemList) -> void:
	list.clear()
	for wtype in WeaponData.WeaponType.values():
		list.add_item(WEAPON_NAMES[wtype])
	list.max_columns = 1
	list.select_mode = ItemList.SELECT_MULTI


func _on_p1_selected(index: int, _selected: bool) -> void:
	_update_selection(1, p1_list)


func _on_p2_selected(index: int, _selected: bool) -> void:
	_update_selection(2, p2_list)


func _update_selection(player_id: int, list: ItemList) -> void:
	if _confirmed[player_id]:
		return
	var selected: Array = []
	for i in range(list.item_count):
		if list.is_selected(i):
			selected.append(WeaponData.WeaponType.values()[i])
			if selected.size() >= 2:
				break
	_selections[player_id] = selected


func _confirm_player(player_id: int) -> void:
	if _selections[player_id].is_empty():
		# Default loadout if nothing picked
		_selections[player_id] = [WeaponData.WeaponType.ASSAULT_RIFLE]
	_confirmed[player_id] = true
	LoadoutManager.set_player_loadout(player_id, _selections[player_id])

	var btn = p1_confirm if player_id == 1 else p2_confirm
	btn.text = "LOCKED IN"
	btn.disabled = true

	if _confirmed[1] and _confirmed[2]:
		start_btn.disabled = false


func _on_start_pressed() -> void:
	emit_signal("loadout_confirmed")
	visible = false
	GameManager.start_match()
