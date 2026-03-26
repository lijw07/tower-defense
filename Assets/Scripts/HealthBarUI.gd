extends CanvasLayer

var _bar_bg: Panel
var _bar_fill: Panel
var _bar_fill_style: StyleBoxFlat
var _label: Label
var _container: PanelContainer
var _vbox: VBoxContainer

var _armor_bar_bg: Panel
var _armor_bar_fill: Panel
var _armor_bar_fill_style: StyleBoxFlat
var _armor_label: Label
var _armor_row: HBoxContainer

# Damage flash overlay — sits on top of the health bar fill
var _damage_flash: Panel

var _max_lives: int = 1
var _current_lives: int = 1
var _current_armor: int = 0
var _prev_lives: int = -1  # track previous HP so we can detect damage
var _shake_tween: Tween = null

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
	style.set_content_margin_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 4
	style.shadow_offset = Vector2(2, 2)
	_container.add_theme_stylebox_override("panel", style)
	_container.position = Vector2(0, 0)
	add_child(_container)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 4)
	_container.add_child(_vbox)

	# ── Armor row (on top) ──
	_armor_row = HBoxContainer.new()
	_armor_row.add_theme_constant_override("separation", 6)
	_vbox.add_child(_armor_row)

	var _pf: Font = UITheme.get_pixel_font()

	var armor_icon := Label.new()
	armor_icon.text = "AR"
	armor_icon.add_theme_font_size_override("font_size", 8)
	if _pf:
		armor_icon.add_theme_font_override("font", _pf)
	armor_icon.add_theme_color_override("font_color", Color(0.45, 0.65, 0.90))
	_armor_row.add_child(armor_icon)

	_armor_label = Label.new()
	_armor_label.add_theme_font_size_override("font_size", 8)
	if _pf:
		_armor_label.add_theme_font_override("font", _pf)
	_armor_label.add_theme_color_override("font_color", UITheme.TEXT)
	_armor_row.add_child(_armor_label)

	# Armor bar background
	_armor_bar_bg = Panel.new()
	_armor_bar_bg.custom_minimum_size = Vector2(140, 14)
	var armor_bg_style := StyleBoxFlat.new()
	armor_bg_style.bg_color = Color(0.15, 0.15, 0.15, 1.0)
	armor_bg_style.border_color = UITheme.BORDER_LIGHT
	armor_bg_style.set_border_width_all(1)
	armor_bg_style.set_corner_radius_all(0)
	_armor_bar_bg.add_theme_stylebox_override("panel", armor_bg_style)
	_vbox.add_child(_armor_bar_bg)

	# Armor bar fill
	_armor_bar_fill = Panel.new()
	_armor_bar_fill.position = Vector2(2, 2)
	_armor_bar_fill.size = Vector2(0, 10)
	_armor_bar_fill_style = StyleBoxFlat.new()
	_armor_bar_fill_style.bg_color = Color(0.35, 0.55, 0.85, 1.0)
	_armor_bar_fill_style.set_corner_radius_all(0)
	_armor_bar_fill.add_theme_stylebox_override("panel", _armor_bar_fill_style)
	_armor_bar_bg.add_child(_armor_bar_fill)

	# ── Health row (below armor) ──
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	_vbox.add_child(hbox)

	var heart_label := Label.new()
	heart_label.text = "HP"
	heart_label.add_theme_font_size_override("font_size", 8)
	if _pf:
		heart_label.add_theme_font_override("font", _pf)
	heart_label.add_theme_color_override("font_color", UITheme.TEXT_RED)
	hbox.add_child(heart_label)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 8)
	if _pf:
		_label.add_theme_font_override("font", _pf)
	_label.add_theme_color_override("font_color", UITheme.TEXT)
	hbox.add_child(_label)

	# Health bar background
	_bar_bg = Panel.new()
	_bar_bg.custom_minimum_size = Vector2(140, 14)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.15, 1.0)
	bg_style.border_color = UITheme.BORDER_LIGHT
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(0)
	_bar_bg.add_theme_stylebox_override("panel", bg_style)
	_vbox.add_child(_bar_bg)

	# Health bar fill
	_bar_fill = Panel.new()
	_bar_fill.position = Vector2(2, 2)
	_bar_fill.size = Vector2(136, 10)
	_bar_fill_style = StyleBoxFlat.new()
	_bar_fill_style.bg_color = Color(0.2, 0.75, 0.3, 1.0)
	_bar_fill_style.set_corner_radius_all(0)
	_bar_fill.add_theme_stylebox_override("panel", _bar_fill_style)
	_bar_bg.add_child(_bar_fill)

	# Damage flash overlay — white panel on top of fill, initially invisible
	_damage_flash = Panel.new()
	_damage_flash.position = Vector2(2, 2)
	_damage_flash.size = Vector2(136, 10)
	var flash_style := StyleBoxFlat.new()
	flash_style.bg_color = Color(1.0, 0.2, 0.2, 0.0)
	flash_style.set_corner_radius_all(0)
	_damage_flash.add_theme_stylebox_override("panel", flash_style)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_bg.add_child(_damage_flash)

	# Initially hide armor if 0
	_update_armor_visibility()

func update_health(current: int, maximum: int) -> void:
	var took_damage: bool = _prev_lives > 0 and current < _prev_lives
	_prev_lives = current
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

	# Trigger damage animation when HP goes down
	if took_damage:
		_play_damage_animation()

func _play_damage_animation() -> void:
	# Kill any running shake tween so animations don't stack
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()

	# 1) Red flash on the health bar
	var flash_style: StyleBoxFlat = _damage_flash.get_theme_stylebox("panel") as StyleBoxFlat
	flash_style.bg_color = Color(1.0, 0.15, 0.15, 0.8)
	var flash_tween: Tween = create_tween()
	flash_tween.tween_method(func(alpha: float) -> void:
		flash_style.bg_color.a = alpha
	, 0.8, 0.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# 2) Shake the whole container
	var origin: Vector2 = Vector2(0, 0)
	_shake_tween = create_tween()
	_shake_tween.tween_property(_container, "position", origin + Vector2(6, 0), 0.03)
	_shake_tween.tween_property(_container, "position", origin + Vector2(-5, 0), 0.03)
	_shake_tween.tween_property(_container, "position", origin + Vector2(4, 2), 0.03)
	_shake_tween.tween_property(_container, "position", origin + Vector2(-3, -1), 0.03)
	_shake_tween.tween_property(_container, "position", origin + Vector2(2, 0), 0.03)
	_shake_tween.tween_property(_container, "position", origin, 0.04)

	# 3) Brief modulate flash on the entire container (red tint)
	_container.modulate = Color(1.5, 0.5, 0.5, 1.0)
	var color_tween: Tween = create_tween()
	color_tween.tween_property(_container, "modulate", Color.WHITE, 0.35).set_ease(Tween.EASE_OUT)

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
