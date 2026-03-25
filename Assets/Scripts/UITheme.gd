# UITheme.gd — shared colour palette and helpers for all in-game UI panels.
# Usage:  var panel = UITheme.make_panel()
#         var btn   = UITheme.make_button("Play")
class_name UITheme
extends RefCounted

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

static func make_panel_style(bg: Color = BG, border_width: int = 2, corner: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = BORDER
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(corner)
	s.set_content_margin_all(14)
	# Subtle inner shadow
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 2)
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
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
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
	btn.add_theme_font_size_override("font_size", 13)

static func make_button(label_text: String, min_size := Vector2(160, 34)) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = min_size
	style_button(btn)
	return btn

# ── Label helpers ────────────────────────────────────────────────────────────

static func make_label(text: String, size: int = 13, color: Color = TEXT) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

static func make_title(text: String, size: int = 20) -> Label:
	return make_label(text, size, GOLD)

static func make_separator() -> HSeparator:
	var sep := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = SEPARATOR
	line.thickness = 1
	sep.add_theme_stylebox_override("separator", line)
	return sep
