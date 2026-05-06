extends Node

const SAVE_PATH := "user://settings.cfg"

# Keybind display labels shown in the settings UI
const ACTION_LABELS: Dictionary = {
	"move_forward":  "Move Forward",
	"move_backward": "Move Backward",
	"move_left":     "Move Left",
	"move_right":    "Move Right",
	"jump":          "Jump",
	"dive_roll":     "Dive / Roll",
	"fire":          "Fire",
	"aim":           "Aim (ADS)",
	"reload":        "Reload",
	"switch_weapon": "Switch Weapon",
	"melee":         "Melee",
}

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

# --- Audio ---
var master_volume: float     = 1.0
var music_volume: float      = 0.8
var sfx_volume: float        = 1.0

# --- Video ---
var fullscreen: bool         = false
var resolution_index: int    = 2      # index into RESOLUTIONS
var fov: float               = 70.0
var vsync: bool              = true

# --- Controls ---
var mouse_sensitivity: float       = 0.0025
var controller_look_sens: float    = 2.5   # degrees per frame per full-deflection

signal settings_applied


func _ready() -> void:
	_ensure_audio_buses()
	load_settings()
	apply_all()


func _ensure_audio_buses() -> void:
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")


# ── Apply ─────────────────────────────────────────────────────────────────────

func apply_all() -> void:
	apply_audio()
	apply_video()
	emit_signal("settings_applied")


func apply_audio() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	var music_idx  := AudioServer.get_bus_index("Music")
	var sfx_idx    := AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(master_idx, linear_to_db(max(master_volume, 0.001)))
	AudioServer.set_bus_volume_db(music_idx,  linear_to_db(max(music_volume,  0.001)))
	AudioServer.set_bus_volume_db(sfx_idx,    linear_to_db(max(sfx_volume,    0.001)))
	AudioServer.set_bus_mute(master_idx, master_volume == 0.0)
	AudioServer.set_bus_mute(music_idx,  music_volume  == 0.0)
	AudioServer.set_bus_mute(sfx_idx,    sfx_volume    == 0.0)


func apply_video() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(RESOLUTIONS[resolution_index])

	var vsync_mode := DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)

	# Push FOV to every active player camera
	for cam in get_tree().get_nodes_in_group("player_camera"):
		(cam as Camera3D).fov = fov


# ── Persistence ───────────────────────────────────────────────────────────────

func save_settings() -> void:
	var config := ConfigFile.new()

	config.set_value("audio", "master",  master_volume)
	config.set_value("audio", "music",   music_volume)
	config.set_value("audio", "sfx",     sfx_volume)

	config.set_value("video", "fullscreen",       fullscreen)
	config.set_value("video", "resolution_index", resolution_index)
	config.set_value("video", "fov",              fov)
	config.set_value("video", "vsync",            vsync)

	config.set_value("controls", "mouse_sensitivity",    mouse_sensitivity)
	config.set_value("controls", "controller_look_sens", controller_look_sens)

	for action in ACTION_LABELS.keys():
		var events := InputMap.action_get_events(action)
		var serialized: Array = []
		for ev in events:
			var d := _serialize_event(ev)
			if not d.is_empty():
				serialized.append(d)
		config.set_value("keybinds", action, serialized)

	config.save(SAVE_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return

	master_volume       = config.get_value("audio", "master",  1.0)
	music_volume        = config.get_value("audio", "music",   0.8)
	sfx_volume          = config.get_value("audio", "sfx",     1.0)

	fullscreen          = config.get_value("video", "fullscreen",       false)
	resolution_index    = config.get_value("video", "resolution_index", 2)
	fov                 = config.get_value("video", "fov",              70.0)
	vsync               = config.get_value("video", "vsync",            true)

	mouse_sensitivity      = config.get_value("controls", "mouse_sensitivity",    0.0025)
	controller_look_sens   = config.get_value("controls", "controller_look_sens", 2.5)

	for action in ACTION_LABELS.keys():
		var serialized = config.get_value("keybinds", action, null)
		if serialized == null:
			continue
		InputMap.action_erase_events(action)
		for data in serialized:
			var ev := _deserialize_event(data)
			if ev:
				InputMap.action_add_event(action, ev)


func reset_to_defaults() -> void:
	InputMap.load_from_project_settings()
	master_volume          = 1.0
	music_volume           = 0.8
	sfx_volume             = 1.0
	fullscreen             = false
	resolution_index       = 2
	fov                    = 70.0
	vsync                  = true
	mouse_sensitivity      = 0.0025
	controller_look_sens   = 2.5


# ── Event serialisation ───────────────────────────────────────────────────────

func _serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"type": "key", "keycode": event.keycode, "physical": event.physical_keycode}
	if event is InputEventMouseButton:
		return {"type": "mouse", "button": event.button_index}
	if event is InputEventJoypadButton:
		return {"type": "joy_btn", "button": event.button_index}
	if event is InputEventJoypadMotion:
		return {"type": "joy_axis", "axis": event.axis, "value": event.axis_value}
	return {}


func _deserialize_event(d: Dictionary) -> InputEvent:
	match d.get("type", ""):
		"key":
			var e := InputEventKey.new()
			e.keycode          = d.get("keycode", 0)
			e.physical_keycode = d.get("physical", 0)
			return e
		"mouse":
			var e := InputEventMouseButton.new()
			e.button_index = d.get("button", 1)
			return e
		"joy_btn":
			var e := InputEventJoypadButton.new()
			e.button_index = d.get("button", 0)
			return e
		"joy_axis":
			var e := InputEventJoypadMotion.new()
			e.axis       = d.get("axis", 0)
			e.axis_value = d.get("value", 0.0)
			return e
	return null


# ── Display helpers ───────────────────────────────────────────────────────────

func event_display_name(event: InputEvent) -> String:
	if event is InputEventKey:
		return event.as_text().replace(" (Physical)", "")
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:   return "LMB"
			MOUSE_BUTTON_RIGHT:  return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
			_: return "Mouse %d" % event.button_index
	if event is InputEventJoypadButton:
		match event.button_index:
			JOY_BUTTON_A:              return "A / Cross"
			JOY_BUTTON_B:              return "B / Circle"
			JOY_BUTTON_X:              return "X / Square"
			JOY_BUTTON_Y:              return "Y / Triangle"
			JOY_BUTTON_LEFT_SHOULDER:  return "L1 / LB"
			JOY_BUTTON_RIGHT_SHOULDER: return "R1 / RB"
			JOY_BUTTON_START:          return "Start"
			JOY_BUTTON_BACK:           return "Select / Back"
			JOY_BUTTON_DPAD_UP:        return "D-Pad Up"
			JOY_BUTTON_DPAD_DOWN:      return "D-Pad Down"
			JOY_BUTTON_DPAD_LEFT:      return "D-Pad Left"
			JOY_BUTTON_DPAD_RIGHT:     return "D-Pad Right"
			_: return "Btn %d" % event.button_index
	if event is InputEventJoypadMotion:
		var sign_str := "+" if event.axis_value > 0 else "−"
		match event.axis:
			JOY_AXIS_LEFT_X:        return "L-Stick X" + sign_str
			JOY_AXIS_LEFT_Y:        return "L-Stick Y" + sign_str
			JOY_AXIS_RIGHT_X:       return "R-Stick X" + sign_str
			JOY_AXIS_RIGHT_Y:       return "R-Stick Y" + sign_str
			JOY_AXIS_TRIGGER_LEFT:  return "L2 / LT"
			JOY_AXIS_TRIGGER_RIGHT: return "R2 / RT"
			_: return "Axis %d%s" % [event.axis, sign_str]
	return "—"
