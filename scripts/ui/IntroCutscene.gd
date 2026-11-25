class_name IntroCutscene
extends Control
## Intro novela-visual: Trixie fracasa en la Gran Feria y decide seguir practicando.
## Las escenas cambian con fundido a negro; los diálogos admiten varios interlocutores
## por lado (ver PortraitStage). Todo el guion vive en intro_cutscene.json.
##
## Formato del JSON:
##   cast:        id -> {name, kind ("witch"|"customer"), side ("left"|"right"), color, tone}
##   backgrounds: id -> color sólido "#rrggbb" (si existe res://assets/backgrounds/intro/<id>.png|jpg, se usa esa imagen)
##   beats:       {"action":"scene","bg":id} | {"action":"enter","who":id,"emotion":e}
##                | {"action":"exit","who":id} | {"speaker":id,"emotion":e,"text":t,"shake":bool}

const SCRIPT_PATH: String = "res://data/dialogues/intro_cutscene.json"
const BACKGROUND_ART_DIR: String = "res://assets/backgrounds/intro"
const CHARS_PER_SEC: float = 52.0
const FADE_SECONDS: float = 0.45

@onready var _backdrop: ColorRect = $Backdrop
@onready var _background_art: TextureRect = $BackgroundArt
@onready var _stage: PortraitStage = $PortraitStage
@onready var _dialog_box: DialogBox = $DialogBox
@onready var _skip_btn: Button = $SkipButton
@onready var _flash_overlay: ColorRect = $FlashOverlay

var _cast: Dictionary = {}
var _backgrounds: Dictionary = {}
var _beats: Array = []
var _idx: int = -1
var _transitioning: bool = false
var _speaker_tone: int = 1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_skip_btn.pressed.connect(_finish_cutscene)
	_dialog_box.set_base_position(_dialog_box.position)
	_dialog_box.chars_per_sec = CHARS_PER_SEC
	_dialog_box.set_body_font_size(28)
	_dialog_box.set_continue_prompt("Clic / Espacio para continuar ▾")
	_dialog_box.hide_box()
	_dialog_box.typewriter_tick.connect(func(_ci: int) -> void:
		AudioJuiceManager.play_pentatonic(_speaker_tone, -12.0)
	)
	_load_script()
	_advance()


func _load_script() -> void:
	var f: FileAccess = FileAccess.open(SCRIPT_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		var data: Dictionary = parsed as Dictionary
		_cast = data.get("cast", {}) as Dictionary
		_backgrounds = data.get("backgrounds", {}) as Dictionary
		_beats = data.get("beats", []) as Array


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_handle_advance_input()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var kev: InputEventKey = event as InputEventKey
		if kev.pressed and not kev.echo:
			if kev.keycode == KEY_SPACE or kev.keycode == KEY_ENTER:
				_handle_advance_input()
			elif kev.keycode == KEY_ESCAPE:
				_finish_cutscene()


func _handle_advance_input() -> void:
	if _transitioning or SceneFader.is_busy():
		return
	if _dialog_box.is_typing():
		_dialog_box.complete_typing()
		return
	_advance()


func _advance() -> void:
	_idx += 1
	if _idx >= _beats.size():
		_finish_cutscene()
		return

	var beat: Dictionary = _beats[_idx] as Dictionary
	match String(beat.get("action", "")):
		"scene":
			_change_scene(String(beat.get("bg", "")), String(beat.get("transition", "fade")))
		"enter":
			var who: StringName = StringName(String(beat.get("who", "")))
			var entry: Dictionary = _cast.get(String(who), {}) as Dictionary
			var lane: String = String(beat.get("side", entry.get("side", "left")))
			_stage.add_member(who, String(entry.get("kind", "witch")), lane, String(beat.get("emotion", "normal")))
			_advance()
		"exit":
			_stage.remove_member(StringName(String(beat.get("who", ""))))
			_advance()
		_:
			_show_dialogue(beat)


func _show_dialogue(beat: Dictionary) -> void:
	var speaker: StringName = StringName(String(beat.get("speaker", "")))
	var entry: Dictionary = _cast.get(String(speaker), {}) as Dictionary
	_speaker_tone = int(entry.get("tone", 1))
	_stage.set_speaker(speaker, String(beat.get("emotion", "")))
	var was_hidden: bool = not _dialog_box.visible
	_dialog_box.show_line(
		String(entry.get("name", "")),
		Color.html(String(entry.get("color", "#2d1a12"))),
		String(beat.get("text", "")),
		was_hidden
	)
	if bool(beat.get("shake", false)):
		_stage.shake_member(speaker)
		AudioJuiceManager.play_pentatonic(0, 0.0)


func _change_scene(bg_id: String, transition: String = "fade") -> void:
	_transitioning = true
	var is_first_scene: bool = _idx == 0
	if transition == "flash":
		_dialog_box.hide_box()
		AudioJuiceManager.play_explosion(2.5, 0.86)
		_shake_stage(18.0, 0.45)
		var flash_in: Tween = create_tween()
		flash_in.tween_property(_flash_overlay, "color:a", 1.0, 0.07).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		await flash_in.finished
		_stage.clear_members()
		_apply_background(bg_id)
		_spawn_consecutive_enters()
		await get_tree().create_timer(0.10).timeout
		var flash_out: Tween = create_tween()
		flash_out.tween_property(_flash_overlay, "color:a", 0.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await flash_out.finished
		_transitioning = false
		_advance()
		return

	if not is_first_scene:
		await SceneFader.fade_out(FADE_SECONDS)
	_dialog_box.hide_box()
	_stage.clear_members()
	_apply_background(bg_id)
	if not is_first_scene:
		await SceneFader.fade_in(FADE_SECONDS)
	_transitioning = false
	_advance()


func _spawn_consecutive_enters() -> void:
	while _idx + 1 < _beats.size():
		var next_beat: Dictionary = _beats[_idx + 1] as Dictionary
		if String(next_beat.get("action", "")) != "enter":
			break
		_idx += 1
		var who: StringName = StringName(String(next_beat.get("who", "")))
		var entry: Dictionary = _cast.get(String(who), {}) as Dictionary
		var lane: String = String(next_beat.get("side", entry.get("side", "left")))
		_stage.add_member(who, String(entry.get("kind", "witch")), lane, String(next_beat.get("emotion", "normal")))


func _shake_stage(intensity: float, duration: float) -> void:
	var tw: Tween = create_tween()
	var steps: int = maxi(6, int(duration / 0.035))
	var step_dur: float = duration / float(steps)
	for i: int in range(steps):
		var decay: float = 1.0 - float(i) / float(steps)
		var off: Vector2 = Vector2(
			randf_range(-intensity, intensity) * decay,
			randf_range(-intensity, intensity) * decay
		)
		tw.tween_property(_background_art, "position", off, step_dur)
		tw.parallel().tween_property(_stage, "position", off, step_dur)
	tw.tween_property(_background_art, "position", Vector2.ZERO, 0.04)
	tw.parallel().tween_property(_stage, "position", Vector2.ZERO, 0.04)


func _apply_background(bg_id: String) -> void:
	var art: Texture2D = null
	for ext: String in ["png", "jpg"]:
		var path: String = "%s/%s.%s" % [BACKGROUND_ART_DIR, bg_id, ext]
		if ResourceLoader.exists(path):
			art = load(path) as Texture2D
			break
	_background_art.texture = art
	_background_art.visible = art != null
	_backdrop.color = Color.html(String(_backgrounds.get(bg_id, "#000000")))


func _finish_cutscene() -> void:
	if _transitioning or SceneFader.is_busy():
		return
	_transitioning = true
	SceneFader.fade_to_scene("res://scenes/main/Main.tscn", 0.55, 0.55)
