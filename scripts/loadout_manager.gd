extends Node

# All available weapon types for selection
const ALL_WEAPONS := [
	WeaponData.WeaponType.ASSAULT_RIFLE,
	WeaponData.WeaponType.SNIPER,
	WeaponData.WeaponType.PISTOL,
	WeaponData.WeaponType.SHOTGUN,
	WeaponData.WeaponType.UZI,
	WeaponData.WeaponType.MACHINE_GUN,
	WeaponData.WeaponType.SWORD,
]

# Each player picks 2 weapons
var player_loadouts: Dictionary = {
	1: [WeaponData.WeaponType.ASSAULT_RIFLE, WeaponData.WeaponType.PISTOL],
	2: [WeaponData.WeaponType.ASSAULT_RIFLE, WeaponData.WeaponType.PISTOL],
}

signal loadouts_confirmed


func set_player_loadout(player_id: int, weapon_types: Array) -> void:
	assert(weapon_types.size() <= 2, "Max 2 weapons per loadout")
	player_loadouts[player_id] = weapon_types.duplicate()


func get_player_loadout(player_id: int) -> Array:
	return player_loadouts.get(player_id, [WeaponData.WeaponType.ASSAULT_RIFLE])


func confirm_loadouts() -> void:
	emit_signal("loadouts_confirmed")


func weapon_display_name(wtype: WeaponData.WeaponType) -> String:
	return WeaponData.create(wtype).weapon_name
