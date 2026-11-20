extends Node
## Persistent player settings (user://settings.cfg): volume, fullscreen and tutorial toggle.

const SETTINGS_PATH: String = "user://settings.cfg"

var master_volume: float = 0.8
var fullscreen: bool = false
var show_tutorial: bool = true


func _ready() -> void:
	load_settings()
	apply_audio()
	apply_video()


func load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	master_volume = clampf(float(cfg.get_value("audio", "master_volume", 0.8)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("video", "fullscreen", false))
	show_tutorial = bool(cfg.get_value("game", "show_tutorial", true))


func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("game", "show_tutorial", show_tutorial)
	cfg.save(SETTINGS_PATH)


func apply_audio() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, master_volume)))
	AudioServer.set_bus_mute(0, master_volume <= 0.001)


func apply_video() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	var is_fs: bool = mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen and not is_fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen and is_fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
