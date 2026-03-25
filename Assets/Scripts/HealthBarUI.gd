extends CanvasLayer

var _bar_bg: Panel
var _bar_fill: Panel
var _bar_fill_style: StyleBoxFlat
var _label: Label
var _container: PanelContainer

var _armor_bar_bg: Panel
var _armor_bar_fill: Panel
var _armor_bar_fill_style: StyleBoxFlat
var _armor_label: Label
var _armor_row: HBoxContainer

var _max_lives: int = 1
var _current_lives: int = 1
var _current_armor: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	_build_ui()

func _build_ui() -> void:
	# Outer container — top-left corner
	_container = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.BG
	style.border_color = UITheme.BORDER
	style.set_border_width_all(2)
	style.border_width_top = 0
	style.border_width_left = 0
	style.set_corner_radius_all(0)
	style.corner_radius_bottom_right = 8
	style.set_content_margin_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 4
	style.shadow_offset = Vector2(2, 2)
	_container.add_theme_stylebox_override("panel", style)
	_container.position = Vector2(0, 0)
	add_child(_container)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_container.add_child(vbox)

	# ── Health row ──
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(hbox)

	var heart_label := Label.new()
	heart_label.text = "HP"
	heart_label.add_theme_font_size_override("font_size", 13)
	heart_label.add_theme_color_override("font_color", UITheme.TEXT_RED)
	hbox.add_child(heart_label)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", UITheme.TEXT)
	hbox.add_child(_label)

	# Health bar background
	_bar_bg = Panel.new()
	_bar_bg.custom_minimum_size = Vector2(140, 14)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.15, 1.0)
	bg_style.border_color = UITheme.BORDER_LIGHT
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(3)
	_bar_bg.add_theme_stylebox_override("panel", bg_style)
	vbox.add_child(_bar_bg)

	# Health bar fill
	_bar_fill = Panel.new()
	_bar_fill.position = Vector2(2, 2)
	_bar_fill.size = Vector2(136, 10)
	_bar_fill_style = StyleBoxFlat.new()
	_bar_fill_style.bg_color = Color(0.2, 0.75, 0.3, 1.0)
	_bar_fill_style.set_corner_radius_all(2)
	_bar_fill.add_theme_stylebox_override("panel", _bar_fill_style)
	_bar_bg.add_child(_bar_fill)

	# ── Armor row ──
	_armor_row = HBoxContainer.new()
	_armor_row.add_theme_constant_override("separation", 6)
	vbox.add_child(_armor_row)

	var armor_icon := Label.new()
	armor_icon.text = "AR"
	armor_icon.add_theme_font_size_override("font_size", 13)
	armor_icon.add_theme_color_override("font_color", Color(0.45, 0.65, 0.90))
	_armor_row.add_child(armor_icon)

	_armor_label = Label.new()
	_armor_label.add_theme_font_size_override("font_size", 13)
	_armor_label.add_theme_color_override("font_color", UITheme.TEXT)
	_armor_row.add_child(_armor_label)

	# Armor bar background
	_armor_bar_bg = Panel.new()
	_armor_bar_bg.custom_minimum_size = Vector2(140, 14)
	var armor_bg_style := StyleBoxFlat.new()
	armor_bg_style.bg_color = Color(0.15, 0.15, 0.15, 1.0)
	armor_bg_style.border_color = UITheme.BORDER_LIGHT
	armor_bg_style.set_border_width_all(1)
	armor_bg_style.set_corner_radius_all(3)
	_armor_bar_bg.add_theme_stylebox_override("panel", armor_bg_style)
	vbox.add_child(_armor_bar_bg)

	# Armor bar fill
	_armor_bar_fill = Panel.new()
	_armor_bar_fill.position = Vector2(2, 2)
	_armor_bar_fill.size = Vector2(0, 10)
	_armor_bar_fill_style = StyleBoxFlat.new()
	_armor_bar_fill_style.bg_color = Color(0.35, 0.55, 0.85, 1.0)
	_armor_bar_fill_style.set_corner_radius_all(2)
	_armor_bar_fill.add_theme_stylebox_override("panel", _armor_bar_fill_style)
	_armor_bar_bg.add_child(_armor_bar_fill)

	# Initially hide armor if 0
	_update_armor_visibility()

func update_health(current: int, maximum: int) -> void:
	_current_lives = current
	_max_lives = maximum
	_label.text = "%d / %d" % [clampi(current, 0, maximum), maximum]

	# Update fill bar width
	var ratio: float = clampf(float(current) / float(maximum), 0.0, 1.0)
	var max_width: float = _bar_bg.custom_minimum_size.x - 4.0
	_bar_fill.size.x = max_width * ratio

	# Color: green → yellow → red
	if _bar_fill_style:
		if ratio > 0.6:
			_bar_fill_style.bg_color = Color(0.2, 0.75, 0.3, 1.0)
		elif ratio > 0.3:
			_bar_fill_style.bg_color = Color(0.85, 0.75, 0.15, 1.0)
		else:
			_bar_fill_style.bg_color = Color(0.85, 0.2, 0.2, 1.0)

func update_armor(current: int) -> void:
	_current_armor = current
	_armor_label.text = "%d / 10" % clampi(current, 0, 10)

	var ratio: float = clampf(float(current) / 10.0, 0.0, 1.0)
	var max_width: float = _armor_bar_bg.custom_minimum_size.x - 4.0
	_armor_bar_fill.size.x = max_width * ratio

	_update_armor_visibility()

func _update_armor_visibility() -> void:
	# Show armor section only when armor has been purchased at least once
	var has_armor: bool = _current_armor > 0
	var upgrade_mgr: Node = get_node_or_null("/root/UpgradeManager")
	if upgrade_mgr:
		has_armor = has_armor or upgrade_mgr.get_castle_armor() > 0 or upgrade_mgr._castle_armor_total_purchased > 0
	_armor_row.visible = has_armor
	_armor_bar_bg.visible = has_armor
