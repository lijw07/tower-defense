# UITheme.gd — shared pixel-art colour palette and helpers for all in-game UI panels.
# Usage:  var panel = UITheme.make_panel()
#         var btn   = UITheme.make_button("Play")
class_name UITheme
extends RefCounted

# ── Pixel font ────────────────────────────────────────────────────────────────
# Silkscreen is much more readable than PressStart2P at small sizes while
# keeping a crisp pixel-art aesthetic.
static var _pixel_font: Font = null
static var _pixel_font_bold: Font = null

static func get_pixel_font() -> Font:
	if _pixel_font == null:
		_pixel_font = load("res://Assets/Fonts/Silkscreen-Regular.ttf")
	return _pixel_font

static func get_pixel_font_bold() -> Font:
	if _pixel_font_bold == null:
		_pixel_font_bold = load("res://Assets/Fonts/Silkscreen-Bold.ttf")
	return _pixel_font_bold

# ── Palette ──────────────────────────────────────────────────────────────────
const BG           := Color(0.08, 0.08, 0.11, 0.94)
const BG_LIGHTER   := Color(0.12, 0.12, 0.16, 0.94)
const BORDER       := Color(0.38, 0.33, 0.20, 1.0)
const BORDER_LIGHT := Color(0.55, 0.48, 0.28, 0.6)
const GOLD         := Color(1.0, 0.85, 0.30)
const TEXT          := Color(0.92, 0.92, 0.92)
const TEXT_DIM      := Color(0.62, 0.62, 0.62)
const TEXT_GREEN    := Color(0.55, 0.82, 0.55)
const TEXT_ORANGE   := Color(0.92, 0.68, 0.30)
const TEXT_RED      := Color(0.90, 0.35, 0.35)
const BTN_NORMAL   := Color(0.16, 0.16, 0.22, 1.0)
const BTN_HOVER    := Color(0.22, 0.22, 0.30, 1.0)
const BTN_PRESSED  := Color(0.12, 0.12, 0.16, 1.0)
const SEPARATOR    := Color(0.35, 0.30, 0.20, 0.5)

# ── Panel helpers ────────────────────────────────────────────────────────────

static func make_panel_style(bg: Color = BG, border_width: int = 2, corner: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = BORDER
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(corner)  # 0 for pixel-sharp corners
	s.set_content_margin_all(14)
	# Hard pixel shadow (no blur)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 3
	s.shadow_offset = Vector2(2, 2)
	return s

static func make_panel(bg: Color = BG) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", make_panel_style(bg))
	return p

# ── Button helpers ───────────────────────────────────────────────────────────

static func make_button_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = BORDER_LIGHT
	s.set_border_width_all(2)
	s.set_corner_radius_all(0)  # Pixel-sharp corners
	s.set_content_margin_all(6)
	s.content_margin_left = 14
	s.content_margin_right = 14
	return s

static func style_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", make_button_style(BTN_NORMAL))
	btn.add_theme_stylebox_override("hover", make_button_style(BTN_HOVER))
	btn.add_theme_stylebox_override("pressed", make_button_style(BTN_PRESSED))
	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_color_override("font_hover_color", GOLD)
	btn.add_theme_color_override("font_pressed_color", TEXT_DIM)
	btn.add_theme_font_size_override("font_size", 10)
	var pf: Font = get_pixel_font()
	if pf:
		btn.add_theme_font_override("font", pf)

static func make_button(label_text: String, min_size := Vector2(160, 34)) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = min_size
	style_button(btn)
	return btn

# ── Label helpers ────────────────────────────────────────────────────────────

static func make_label(text: String, size: int = 10, color: Color = TEXT) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	var pf: Font = get_pixel_font()
	if pf:
		lbl.add_theme_font_override("font", pf)
	return lbl

static func make_title(text: String, size: int = 16) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", GOLD)
	var pf: Font = get_pixel_font_bold()
	if pf:
		lbl.add_theme_font_override("font", pf)
	return lbl

static func make_separator() -> HSeparator:
	var sep := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = SEPARATOR
	line.thickness = 2
	sep.add_theme_stylebox_override("separator", line)
	return sep

# ── Slider helpers (for settings) ────────────────────────────────────────────

static func make_slider_style_grabber() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = GOLD
	s.set_corner_radius_all(0)
	s.set_content_margin_all(0)
	return s

static func _make_grabber_icon(color: Color, w: int = 8, h: int = 16) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

static func make_hslider(min_val: float = 0.0, max_val: float = 1.0, initial: float = 1.0) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = initial
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(120, 20)

	# Track background
	var track_style := StyleBoxFlat.new()
	track_style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	track_style.border_color = BORDER_LIGHT
	track_style.set_border_width_all(2)
	track_style.set_corner_radius_all(0)
	track_style.content_margin_top = 4
	track_style.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", track_style)

	# Filled area (left of grabber)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.55, 0.48, 0.2, 1.0)
	fill_style.set_corner_radius_all(0)
	fill_style.content_margin_top = 4
	fill_style.content_margin_bottom = 4
	slider.add_theme_stylebox_override("grabber_area", fill_style)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_style)

	# Grabber handle (pixel block)
	var grabber_tex := _make_grabber_icon(GOLD, 8, 18)
	var grabber_hover_tex := _make_grabber_icon(Color(1.0, 0.95, 0.5), 8, 18)
	slider.add_theme_icon_override("grabber", grabber_tex)
	slider.add_theme_icon_override("grabber_highlight", grabber_hover_tex)
	slider.add_theme_icon_override("grabber_disabled", _make_grabber_icon(TEXT_DIM, 8, 18))

	return slider
