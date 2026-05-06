extends CanvasLayer

@onready var health_bar:     ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var health_label:   Label       = $MarginContainer/VBoxContainer/HealthLabel
@onready var ammo_label:     Label       = $AmmoContainer/AmmoLabel
@onready var reload_label:   Label       = $AmmoContainer/ReloadLabel
@onready var score_label:    Label       = $ScoreContainer/ScoreLabel
@onready var crosshair:      Control     = $Crosshair
@onready var round_label:    Label       = $RoundLabel
@onready var announcement:   Label       = $AnnouncementLabel


func _ready() -> void:
	reload_label.visible = false
	announcement.visible = false


func bind_player(player: Player) -> void:
	player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health, player.max_health)

	if player.current_weapon:
		_bind_weapon(player.current_weapon)


func bind_weapon(weapon: WeaponBase) -> void:
	if weapon.ammo_changed.is_connected(_on_ammo_changed):
		weapon.ammo_changed.disconnect(_on_ammo_changed)
	if weapon.reload_started.is_connected(_on_reload_started):
		weapon.reload_started.disconnect(_on_reload_started)
	if weapon.reload_finished.is_connected(_on_reload_finished):
		weapon.reload_finished.disconnect(_on_reload_finished)

	weapon.ammo_changed.connect(_on_ammo_changed)
	weapon.reload_started.connect(_on_reload_started)
	weapon.reload_finished.connect(_on_reload_finished)

	if weapon.data.is_melee:
		ammo_label.text = "MELEE"
	else:
		ammo_label.text = "%d / %d" % [weapon.current_ammo, weapon.data.magazine_size]


func update_score(p1_score: int, p2_score: int) -> void:
	score_label.text = "%d  —  %d" % [p1_score, p2_score]


func show_announcement(text: String, duration: float = 2.0) -> void:
	announcement.text = text
	announcement.visible = true
	await get_tree().create_timer(duration).timeout
	announcement.visible = false


func set_round(round_num: int) -> void:
	round_label.text = "Round %d" % round_num


# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_health_changed(new_hp: int, max_hp: int) -> void:
	health_bar.max_value = max_hp
	health_bar.value = new_hp
	health_label.text = "%d HP" % new_hp


func _on_ammo_changed(current: int, maximum: int) -> void:
	ammo_label.text = "%d / %d" % [current, maximum]


func _on_reload_started() -> void:
	reload_label.visible = true
	ammo_label.visible = false


func _on_reload_finished() -> void:
	reload_label.visible = false
	ammo_label.visible = true
