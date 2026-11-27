class_name GalleryTab
extends Control
## Pestaña editable de Galería y Afinidad: selector de personajes, tarjeta de retrato
## y frases, regalos de elixir, tarjetas de escenas y visor lightbox.

signal back_to_map_requested()
signal sfx_requested(step_index: int, vol_db: float)
signal essence_changed()

const GALLERY_TITLES: Dictionary = {
	&"trixie": ["Chispas de Apertura", "Sobrecalentamiento Picante", "Maestra del Aquelarre"],
	&"sylvi": ["Brindis del Bosque", "Calor bajo las Hojas", "Fiesta Privada con Trixie"],
	&"velvet": ["Mirada Ejecutiva", "Prueba Directa del Cucharón", "Contrato Carmesí"],
	&"seraphina": ["Brisa de Verano", "Calidez Serena", "Tarde en el Jardín"],
	&"mona": ["Orgullo Élfico", "Sonrojo Tsundere", "Cita Privada en la Mansión"],
	&"roxy": ["Aullido de Luna Llena", "Cazadora Cautivada", "Frasco Reservado"],
}
const GameStateScript: GDScript = preload("res://scripts/autoloads/GameState.gd")

@onready var _btn_sylvi: Button = $CharacterSelectorRow/BtnSylvi
@onready var _btn_velvet: Button = $CharacterSelectorRow/BtnVelvet
@onready var _btn_seraphina: Button = $CharacterSelectorRow/BtnSeraphina
@onready var _btn_mona: Button = $CharacterSelectorRow/BtnMona
@onready var _btn_roxy: Button = $CharacterSelectorRow/BtnRoxy
@onready var _btn_trixie: Button = $CharacterSelectorRow/BtnTrixie

@onready var _portrait_canvas: Control = $LeftPortraitCard/Pad/VBox/PortraitCanvas
@onready var _title_lbl: Label = $LeftPortraitCard/Pad/VBox/TitleLabel
@onready var _aff_lbl: Label = $LeftPortraitCard/Pad/VBox/AffinityLabel
@onready var _lines_lbl: Label = $LeftPortraitCard/Pad/VBox/LinesLabel
@onready var _gift_btn: Button = $LeftPortraitCard/Pad/VBox/GiftButton

@onready var _cards_box: HBoxContainer = $RightScenesCard/Pad/VBox/CardsBox
@onready var _back_btn: Button = $RightScenesCard/Pad/VBox/BackButton

@onready var _lightbox_overlay: ColorRect = $LightboxLayer/LightboxOverlay
@onready var _lightbox_title_lbl: Label = $LightboxLayer/LightboxOverlay/Center/Panel/Pad/VBox/LightboxTitleLabel
@onready var _lightbox_canvas: Control = $LightboxLayer/LightboxOverlay/Center/Panel/Pad/VBox/LightboxCanvas
@onready var _lightbox_caption_lbl: Label = $LightboxLayer/LightboxOverlay/Center/Panel/Pad/VBox/LightboxCaptionLabel
@onready var _lightbox_close_btn: Button = $LightboxLayer/LightboxOverlay/Center/Panel/Pad/VBox/CloseCenter/CloseButton

var _state: Node = null
var _time: float = 0.0
var _selected_char_id: StringName = &"sylvi"
var _lightbox_scene_idx: int = 0
var _char_buttons: Dictionary = {}


func _ready() -> void:
	_char_buttons = {
		&"sylvi": _btn_sylvi,
		&"velvet": _btn_velvet,
		&"seraphina": _btn_seraphina,
		&"mona": _btn_mona,
		&"roxy": _btn_roxy,
		&"trixie": _btn_trixie,
	}
	for cid: StringName in _char_buttons.keys():
		var btn: Button = _char_buttons[cid] as Button
		if btn != null:
			btn.pressed.connect(func() -> void:
				_selected_char_id = cid
				refresh_gallery()
			)
	if _portrait_canvas != null:
		_portrait_canvas.draw.connect(_draw_gallery_portrait)
	if _gift_btn != null:
		_gift_btn.pressed.connect(_on_gift_pressed)
	if _back_btn != null:
		_back_btn.pressed.connect(func() -> void: back_to_map_requested.emit())
	if _lightbox_canvas != null:
		_lightbox_canvas.draw.connect(_draw_lightbox_scene)
	if _lightbox_close_btn != null:
		_lightbox_close_btn.pressed.connect(close_lightbox)


func configure(state: Node) -> void:
	_state = state


func step_visuals(time_sec: float, is_active: bool) -> void:
	_time = time_sec
	if is_active and _portrait_canvas != null:
		_portrait_canvas.queue_redraw()
		if is_lightbox_open() and _lightbox_canvas != null:
			_lightbox_canvas.queue_redraw()


func is_lightbox_open() -> bool:
	return _lightbox_overlay != null and _lightbox_overlay.visible


func close_lightbox() -> void:
	if _lightbox_overlay != null:
		_lightbox_overlay.visible = false


func refresh_gallery() -> void:
	if _title_lbl == null or _state == null:
		return
	for cid: StringName in _char_buttons.keys():
		var btn: Button = _char_buttons[cid] as Button
		if btn != null:
			btn.modulate = Color(1.0, 0.92, 0.55) if cid == _selected_char_id else Color(0.82, 0.78, 0.90)

	var pts: int = _state.get_affinity_points(_selected_char_id)
	var lvl: int = _state.get_affinity_level(_selected_char_id)
	var next_req: int = GameStateScript.AFFINITY_THRESHOLDS[mini(lvl, GameStateScript.AFFINITY_THRESHOLDS.size() - 1)]

	var char_name: String = "Trixie"
	var role_txt: String = "Bruja del Caldero"
	var quotes: PackedStringArray = DialogueBank.get_trixie_gallery_quotes()
	if _selected_char_id != &"trixie":
		for c: CustomerArchetypeData in _state.customers_catalog:
			if c.customer_id == _selected_char_id:
				char_name = c.display_name
				role_txt = c.species_archetype
				var all_q: Array[String] = []
				for s: String in DialogueBank.get_customer_lines(c.customer_id, "greeting"):
					all_q.append("• " + DialogueBank.strip_tags(s))
				if lvl >= 1:
					for s: String in DialogueBank.get_customer_lines(c.customer_id, "satisfied"):
						all_q.append("★ " + DialogueBank.strip_tags(s))
				if lvl >= 2:
					for s: String in DialogueBank.get_customer_lines(c.customer_id, "spicy"):
						all_q.append("💋 " + DialogueBank.strip_tags(s))
				else:
					all_q.append("🔒 Frases picantes bloqueadas (Requiere Afinidad Nv.2)")
				quotes = PackedStringArray(all_q)
				break

	_title_lbl.text = "%s — %s" % [char_name, role_txt]
	_aff_lbl.text = "❤ Afinidad Nv.%d / 3  (%d / %d pts)" % [lvl, pts, next_req]
	_lines_lbl.text = "\n".join(quotes)

	var gift_cost: int = 40 * (lvl + 1)
	_gift_btn.text = "🎁 REGALAR ELIXIR (%d✦ -> +2❤)" % gift_cost
	_gift_btn.disabled = (int(_state.essence_gold) < gift_cost) or (lvl >= 3)

	for child: Node in _cards_box.get_children():
		child.queue_free()

	var titles: Array = GALLERY_TITLES.get(_selected_char_id, ["Escena I", "Escena II", "Escena III"]) as Array
	for idx: int in range(3):
		var req_lvl: int = idx + 1
		var unlocked: bool = lvl >= req_lvl
		var card_panel: PanelContainer = _make_card_panel(
			Color(0.18, 0.10, 0.24) if unlocked else Color(0.09, 0.07, 0.13),
			Color(1.0, 0.80, 0.42) if unlocked else Color(0.32, 0.28, 0.42)
		)
		card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_cards_box.add_child(card_panel)

		var cv: VBoxContainer = VBoxContainer.new()
		cv.add_theme_constant_override("separation", 12)
		card_panel.get_child(0).add_child(cv)
		var c_hdr: Label = _make_label("Escena %d · Nv.%d" % [req_lvl, req_lvl], 20, Color(1.0, 0.68, 0.86) if unlocked else Color(0.55, 0.52, 0.65))
		c_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(c_hdr)

		var preview: Control = Control.new()
		preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var cap_cid: StringName = _selected_char_id
		var cap_idx: int = idx
		var cap_unl: bool = unlocked
		preview.draw.connect(func() -> void: _draw_gallery_card_preview(preview, cap_cid, cap_idx, cap_unl))
		cv.add_child(preview)

		var c_title: Label = _make_label(String(titles[idx]) if unlocked else "🔒 Afinidad Nv.%d" % req_lvl, 19, Color(1.0, 0.90, 0.48) if unlocked else Color(0.60, 0.56, 0.70))
		c_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(c_title)

		var open_btn: Button = _make_pill_button("🔍 VER ESCENA" if unlocked else "BLOQUEADA",
			Color(0.58, 0.18, 0.38) if unlocked else Color(0.20, 0.18, 0.25),
			Color(1.0, 0.84, 0.38) if unlocked else Color(0.40, 0.36, 0.48)
		)
		open_btn.custom_minimum_size = Vector2(0, 48)
		open_btn.disabled = not unlocked
		open_btn.pressed.connect(func() -> void: _open_lightbox(cap_cid, cap_idx, String(titles[cap_idx])))
		cv.add_child(open_btn)

	if _portrait_canvas != null:
		_portrait_canvas.queue_redraw()


func _on_gift_pressed() -> void:
	if _state == null:
		return
	var lvl: int = _state.get_affinity_level(_selected_char_id)
	var cost: int = 40 * (lvl + 1)
	if lvl >= 3 or not _state.spend_essence(cost):
		return
	var leveled: bool = _state.add_affinity(_selected_char_id, 2)
	sfx_requested.emit(6 if leveled else 4, -1.0)
	essence_changed.emit()
	refresh_gallery()


func _open_lightbox(cid: StringName, scene_idx: int, title_txt: String) -> void:
	_selected_char_id = cid
	_lightbox_scene_idx = scene_idx
	_lightbox_title_lbl.text = "💋 %s — %s" % [String(cid).capitalize(), title_txt]
	var captions: Array[String] = [
		"Un momento íntimo junto al caldero ambulante tras cerrar la jornada.",
		"El aroma dulce del elixir llena la posada y sube el rubor de la noche.",
		"Escena especial de afinidad máxima. ¡Lista para reemplazar con tu ilustración final de Krita!",
	]
	_lightbox_caption_lbl.text = captions[clampi(scene_idx, 0, captions.size() - 1)]
	_lightbox_overlay.visible = true
	if _lightbox_canvas != null:
		_lightbox_canvas.queue_redraw()


func _draw_gallery_portrait() -> void:
	if _portrait_canvas == null or _state == null:
		return
	var r: Rect2 = Rect2(Vector2.ZERO, _portrait_canvas.size)
	_portrait_canvas.draw_rect(r, Color(0.14, 0.09, 0.22))
	_portrait_canvas.draw_rect(r, Color(0.94, 0.64, 0.82, 0.6), false, 2.0)
	if _selected_char_id == &"trixie":
		CharacterArt.draw_trixie_full(_portrait_canvas, Vector2(r.size.x * 0.5, r.size.y - 22.0), 1.02, "sonrojada", _time, 1.0)
	elif CharacterArt.has_customer_halfbody(_selected_char_id):
		CharacterArt.draw_customer_halfbody(_portrait_canvas, r.grow(-8), _selected_char_id, "sonrojada" if _state.get_affinity_level(_selected_char_id) >= 1 else "normal", _time, 1.0)
	else:
		CharacterArt.draw_expressive_waifu_bust(_portrait_canvas, r.grow(-12), _selected_char_id, _state.get_affinity_level(_selected_char_id) >= 2, _time)


func _draw_gallery_card_preview(ci: CanvasItem, cid: StringName, scene_idx: int, unlocked: bool) -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, ci.size)
	ci.draw_rect(r, Color(0.18, 0.10, 0.24) if unlocked else Color(0.08, 0.06, 0.12))
	if not unlocked:
		ci.draw_circle(r.size * 0.5, 42.0, Color(0.22, 0.16, 0.30))
		ci.draw_string(ThemeDB.fallback_font, r.size * 0.5 + Vector2(-14, 10), "🔒", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.75, 0.70, 0.85))
		return
	var glow_col: Color = Color(1.0, 0.48, 0.72, 0.24) if scene_idx == 2 else (Color(0.98, 0.72, 0.36, 0.20) if scene_idx == 1 else Color(0.45, 0.80, 1.0, 0.16))
	ci.draw_circle(r.size * 0.5, minf(r.size.x, r.size.y) * 0.42, glow_col)
	if cid == &"trixie":
		CharacterArt.draw_trixie_bust(ci, r.grow(-8), "sonrojada" if scene_idx == 2 else ("confiada" if scene_idx == 1 else "normal"), _time, 1.0, "dialogue")
	elif CharacterArt.has_customer_halfbody(cid):
		CharacterArt.draw_customer_halfbody(ci, r.grow(-6), cid, "sonrojada" if scene_idx == 2 else ("impaciente" if scene_idx == 1 else "normal"), _time, 1.0)
	else:
		CharacterArt.draw_expressive_waifu_bust(ci, r.grow(-10), cid, scene_idx >= 1, _time)


func _draw_lightbox_scene() -> void:
	if _lightbox_canvas == null:
		return
	var r: Rect2 = Rect2(Vector2.ZERO, _lightbox_canvas.size)
	_lightbox_canvas.draw_rect(r, Color(0.14, 0.07, 0.20))
	_lightbox_canvas.draw_circle(r.size * 0.5, 250.0, Color(1.0, 0.42, 0.74, 0.20))
	if _selected_char_id == &"trixie":
		CharacterArt.draw_trixie_bust(_lightbox_canvas, Rect2(r.size.x * 0.5 - 295.0, r.size.y - 520.0, 590.0, 510.0), "sonrojada" if _lightbox_scene_idx == 2 else ("confiada" if _lightbox_scene_idx == 1 else "normal"), _time, 1.0, "cutscene")
	elif CharacterArt.has_customer_halfbody(_selected_char_id):
		CharacterArt.draw_customer_halfbody(_lightbox_canvas, Rect2(r.size.x * 0.5 - 260.0, 12.0, 520.0, r.size.y - 20.0), _selected_char_id, "sonrojada" if _lightbox_scene_idx == 2 else ("impaciente" if _lightbox_scene_idx == 1 else "normal"), _time, 1.0)
	else:
		CharacterArt.draw_expressive_waifu_bust(_lightbox_canvas, Rect2(r.size.x * 0.5 - 240.0, 20.0, 480.0, r.size.y - 30.0), _selected_char_id, _lightbox_scene_idx >= 1, _time)


static func _make_label(txt: String, fsize: int, col: Color) -> Label:
	var lbl: Label = Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", fsize)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.09))
	lbl.add_theme_constant_override("outline_size", 3)
	return lbl


static func _make_pill_button(txt: String, bg: Color, border: Color) -> Button:
	var btn: Button = Button.new()
	btn.text = txt
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", Color(1.0, 0.96, 0.92))
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = border
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.16)
	hover.border_color = border.lightened(0.20)
	var disabled: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.16, 0.14, 0.22)
	disabled.border_color = Color(0.35, 0.32, 0.45)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("disabled", disabled)
	return btn


static func _make_card_panel(bg: Color, border: Color) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 560)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	var pad: MarginContainer = MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 16)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 12)
	pad.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(pad)
	return panel
