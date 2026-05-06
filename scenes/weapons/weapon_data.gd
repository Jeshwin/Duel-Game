class_name WeaponData
extends Resource

enum WeaponType {
	ASSAULT_RIFLE,
	SNIPER,
	PISTOL,
	SHOTGUN,
	UZI,
	MACHINE_GUN,
	SWORD
}

@export var weapon_name: String = ""
@export var weapon_type: WeaponType = WeaponType.PISTOL
@export var damage: int = 10
@export var fire_rate: float = 0.15       # seconds between shots
@export var magazine_size: int = 30
@export var reload_time: float = 2.0
@export var range_max: float = 100.0
@export var spread: float = 0.02          # radians of bullet spread
@export var is_automatic: bool = false
@export var pellets: int = 1              # shotgun fires multiple
@export var ads_fov: float = 50.0         # camera FOV when aiming
@export var is_melee: bool = false
@export var melee_range: float = 2.0


static func make_assault_rifle() -> WeaponData:
	var d = WeaponData.new()
	d.weapon_name = "Assault Rifle"
	d.weapon_type = WeaponType.ASSAULT_RIFLE
	d.damage = 22
	d.fire_rate = 0.1
	d.magazine_size = 30
	d.reload_time = 2.2
	d.range_max = 80.0
	d.spread = 0.025
	d.is_automatic = true
	d.ads_fov = 55.0
	return d


static func make_sniper() -> WeaponData:
	var d = WeaponData.new()
	d.weapon_name = "Sniper"
	d.weapon_type = WeaponType.SNIPER
	d.damage = 90
	d.fire_rate = 1.2
	d.magazine_size = 5
	d.reload_time = 3.0
	d.range_max = 300.0
	d.spread = 0.001
	d.is_automatic = false
	d.ads_fov = 20.0
	return d


static func make_pistol() -> WeaponData:
	var d = WeaponData.new()
	d.weapon_name = "Pistol"
	d.weapon_type = WeaponType.PISTOL
	d.damage = 30
	d.fire_rate = 0.25
	d.magazine_size = 12
	d.reload_time = 1.5
	d.range_max = 60.0
	d.spread = 0.015
	d.is_automatic = false
	d.ads_fov = 50.0
	return d


static func make_shotgun() -> WeaponData:
	var d = WeaponData.new()
	d.weapon_name = "Shotgun"
	d.weapon_type = WeaponType.SHOTGUN
	d.damage = 18          # per pellet
	d.fire_rate = 0.9
	d.magazine_size = 6
	d.reload_time = 2.8
	d.range_max = 25.0
	d.spread = 0.12
	d.pellets = 8
	d.is_automatic = false
	d.ads_fov = 55.0
	return d


static func make_uzi() -> WeaponData:
	var d = WeaponData.new()
	d.weapon_name = "Uzi"
	d.weapon_type = WeaponType.UZI
	d.damage = 14
	d.fire_rate = 0.07
	d.magazine_size = 32
	d.reload_time = 1.8
	d.range_max = 40.0
	d.spread = 0.06
	d.is_automatic = true
	d.ads_fov = 55.0
	return d


static func make_machine_gun() -> WeaponData:
	var d = WeaponData.new()
	d.weapon_name = "Machine Gun"
	d.weapon_type = WeaponType.MACHINE_GUN
	d.damage = 18
	d.fire_rate = 0.08
	d.magazine_size = 100
	d.reload_time = 4.0
	d.range_max = 100.0
	d.spread = 0.04
	d.is_automatic = true
	d.ads_fov = 55.0
	return d


static func make_sword() -> WeaponData:
	var d = WeaponData.new()
	d.weapon_name = "Sword"
	d.weapon_type = WeaponType.SWORD
	d.damage = 55
	d.fire_rate = 0.5
	d.magazine_size = 0
	d.reload_time = 0.0
	d.range_max = 0.0
	d.spread = 0.0
	d.is_melee = true
	d.melee_range = 2.2
	return d


static func create(type: WeaponType) -> WeaponData:
	match type:
		WeaponType.ASSAULT_RIFLE: return make_assault_rifle()
		WeaponType.SNIPER:        return make_sniper()
		WeaponType.PISTOL:        return make_pistol()
		WeaponType.SHOTGUN:       return make_shotgun()
		WeaponType.UZI:           return make_uzi()
		WeaponType.MACHINE_GUN:   return make_machine_gun()
		WeaponType.SWORD:         return make_sword()
	return make_pistol()
