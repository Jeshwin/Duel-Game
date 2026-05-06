extends CanvasLayer

# Action currently being re-bound; "" means we're not listening
var _listening_action:    String  = ""
var _listening_button:    Button  = null
var _listening_ctrl_only: bool    = false

# --- Node refs (unique names match settings_menu.tscn) ---
@onready var keybind_list:   VBoxContainer = %KeybindList
@onready var mouse_sens_sl:  HSlider       = %MouseSensSlider
@onready var mouse_sens_val: Label         = %MouseSensValue
@onready var ctrl_sens_sl:   HSlider       = %CtrlSensSlider
@onready var ctrl_sens_val:  Label         = %CtrlSensValue
@onready var master_sl:      HSlider       = %MasterSlider
@onready var master_pct:     Label         = %MasterPct
@onready var music_sl:       HSlider       = %MusicSlider
@onready var music_pct:      Label         = %MusicPct
@onready var sfx_sl:         HSlider       = %SFXSlider
@onready var sfx_pct:        Label         = %SFXPct
@onready var display_opt:    OptionButton  = %DisplayOption
@onready var res_opt:        OptionButton  = %ResOption
@onready var fov_sl:         HSlider       = %FOVSlider
@onready var fov_val:        Label         = %FOVValue
@onready var vsync_check:    CheckButton   = %VSyncCheck
@onready var listen_overlay: Panel         = %ListenOverlay

signal closed


func _ready() -> void:
	visible = false
	listen_overlay.visible = false
	_build_keybind_rows()
	_populate_options()
	_connect_signals()


func open() -> void:
	_refresh_all()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	_cancel_listen()
	visible = false
	emit_signal("closed")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _listening_action != "":
		_capture_rebind(event)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# ── Initialisation ────────────────────────────────────────────────────────────

func _connect_signals() -> void:
	master_sl.value_changed.connect(_on_master_changed)
	music_sl.value_changed.connect(_on_music_changed)
	sfx_sl.value_changed.connect(_on_sfx_changed)
	fov_sl.value_changed.connect(_on_fov_changed)
	vsync_check.toggled.connect(_on_vsync_toggled)
	display_opt.item_selected.connect(_on_display_changed)
	res_opt.item_selected.connect(_on_res_changed)
	mouse_sens_sl.value_changed.connect(_on_mouse_sens_changed)
	ctrl_sens_sl.value_changed.connect(_on_ctrl_sens_changed)
	%ApplyButton.pressed.connect(_on_apply_pressed)
	%DefaultsButton.pressed.connect(_on_defaults_pressed)
	%CancelButton.pressed.connect(close)


func _populate_options() -> void:
	display_opt.clear()
	display_opt.add_item("Windowed")
	display_opt.add_item("Fullscreen")
	display_opt.add_item("Borderless Window")

	res_opt.clear()
	for res in SettingsManager.RESOLUTIONS:
		res_opt.add_item("%d × %d" % [res.x, res.y])


func _build_keybind_rows() -> void:
	for action in SettingsManager.ACTION_LABELS.keys():
		keybind_list.add_child(_make_row(action))


func _make_row(action: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Row_" + action

	var lbl := Label.new()
	lbl.text = SettingsManager.ACTION_LABELS[action]
	lbl.custom_minimum_size.x = 150
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var btn_kb := Button.new()
	btn_kb.name = "KB"
	btn_kb.custom_minimum_size.x = 130
	btn_kb.pressed.connect(_start_listen.bind(action, btn_kb, false))
	row.add_child(btn_kb)

	var btn_pad := Button.new()
	btn_pad.name = "Pad"
	btn_pad.custom_minimum_size.x = 130
	btn_pad.pressed.connect(_start_listen.bind(action, btn_pad, true))
	row.add_child(btn_pad)

	var btn_clear := Button.new()
	btn_clear.text = "✕"
	btn_clear.custom_minimum_size = Vector2(32, 0)
	btn_clear.pressed.connect(_clear_action.bind(action, btn_kb, btn_pad))
	row.add_child(btn_clear)

	_update_row(action, btn_kb, btn_pad)
	return row


# ── Keybind rebinding ─────────────────────────────────────────────────────────

func _start_listen(action: String, btn: Button, ctrl_only: bool) -> void:
	_listening_action    = action
	_listening_button    = btn
	_listening_ctrl_only = ctrl_only
	btn.text = "[ press key… ]"
	listen_overlay.visible = true


func _capture_rebind(event: InputEvent) -> void:
	var is_ctrl := event is InputEventJoypadButton or event is InputEventJoypadMotion
	var is_kb   := event is InputEventKey or event is InputEventMouseButton

	if not is_ctrl and not is_kb:
		return

	# Escape cancels without rebinding
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		_cancel_listen()
		return

	# Filter to the right device category
	if _listening_ctrl_only and not is_ctrl:
		return
	if not _listening_ctrl_only and not is_kb:
		return

	# Replace only the matching category of events for this action
	var existing := InputMap.action_get_events(_listening_action)
	for ev in existing:
		var ev_is_ctrl := ev is InputEventJoypadButton or ev is InputEventJoypadMotion
		if ev_is_ctrl == is_ctrl:
			InputMap.action_erase_event(_listening_action, ev)

	InputMap.action_add_event(_listening_action, event)

	var saved_action := _listening_action
	_cancel_listen()
	_refresh_row(saved_action)


func _cancel_listen() -> void:
	if _listening_action != "":
		_refresh_row(_listening_action)
	_listening_action  = ""
	_listening_button  = null
	listen_overlay.visible = false


func _clear_action(action: String, btn_kb: Button, btn_pad: Button) -> void:
	InputMap.action_erase_events(action)
	_update_row(action, btn_kb, btn_pad)


func _refresh_row(action: String) -> void:
	var row := keybind_list.get_node_or_null("Row_" + action)
	if row:
		_update_row(action, row.get_node("KB"), row.get_node("Pad"))


func _update_row(action: String, btn_kb: Button, btn_pad: Button) -> void:
	var kb_text  := "—"
	var pad_text := "—"
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey or ev is InputEventMouseButton:
			kb_text = SettingsManager.event_display_name(ev)
		elif ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			pad_text = SettingsManager.event_display_name(ev)
	btn_kb.text  = kb_text
	btn_pad.text = pad_text


# ── Audio tab ─────────────────────────────────────────────────────────────────

func _on_master_changed(v: float) -> void:
	SettingsManager.master_volume = v
	SettingsManager.apply_audio()
	master_pct.text = "%d%%" % int(v * 100)


func _on_music_changed(v: float) -> void:
	SettingsManager.music_volume = v
	SettingsManager.apply_audio()
	music_pct.text = "%d%%" % int(v * 100)


func _on_sfx_changed(v: float) -> void:
	SettingsManager.sfx_volume = v
	SettingsManager.apply_audio()
	sfx_pct.text = "%d%%" % int(v * 100)


# ── Video tab ─────────────────────────────────────────────────────────────────

func _on_display_changed(idx: int) -> void:
	SettingsManager.fullscreen = idx == 1
	res_opt.disabled = SettingsManager.fullscreen


func _on_res_changed(idx: int) -> void:
	SettingsManager.resolution_index = idx


func _on_fov_changed(v: float) -> void:
	SettingsManager.fov = v
	fov_val.text = "%d°" % int(v)


func _on_vsync_toggled(on: bool) -> void:
	SettingsManager.vsync = on


# ── Controls sensitivity ──────────────────────────────────────────────────────

func _on_mouse_sens_changed(v: float) -> void:
	SettingsManager.mouse_sensitivity = v
	mouse_sens_val.text = "%.4f" % v


func _on_ctrl_sens_changed(v: float) -> void:
	SettingsManager.controller_look_sens = v
	ctrl_sens_val.text = "%.1f" % v


# ── Bottom buttons ────────────────────────────────────────────────────────────

func _on_apply_pressed() -> void:
	SettingsManager.apply_all()
	SettingsManager.save_settings()
	close()


func _on_defaults_pressed() -> void:
	SettingsManager.reset_to_defaults()
	SettingsManager.apply_all()
	_refresh_all()


# ── Full UI refresh ───────────────────────────────────────────────────────────

func _refresh_all() -> void:
	# Audio
	master_sl.set_value_no_signal(SettingsManager.master_volume)
	music_sl.set_value_no_signal(SettingsManager.music_volume)
	sfx_sl.set_value_no_signal(SettingsManager.sfx_volume)
	master_pct.text = "%d%%" % int(SettingsManager.master_volume * 100)
	music_pct.text  = "%d%%" % int(SettingsManager.music_volume  * 100)
	sfx_pct.text    = "%d%%" % int(SettingsManager.sfx_volume    * 100)

	# Video
	display_opt.selected = 1 if SettingsManager.fullscreen else 0
	res_opt.selected = SettingsManager.resolution_index
	res_opt.disabled = SettingsManager.fullscreen
	fov_sl.set_value_no_signal(SettingsManager.fov)
	fov_val.text = "%d°" % int(SettingsManager.fov)
	vsync_check.set_pressed_no_signal(SettingsManager.vsync)

	# Controls
	mouse_sens_sl.set_value_no_signal(SettingsManager.mouse_sensitivity)
	mouse_sens_val.text = "%.4f" % SettingsManager.mouse_sensitivity
	ctrl_sens_sl.set_value_no_signal(SettingsManager.controller_look_sens)
	ctrl_sens_val.text = "%.1f" % SettingsManager.controller_look_sens

	# Keybinds
	for row in keybind_list.get_children():
		var action: String = row.name.replace("Row_", "")
		if SettingsManager.ACTION_LABELS.has(action):
			_update_row(action, row.get_node("KB"), row.get_node("Pad"))
