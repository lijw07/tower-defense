extends CanvasLayer

signal tower_selected(tower_data: TowerData)
signal upgrade_pressed

@export var tower_data_list: Array[TowerData] = []

var _panel: PanelContainer
var _button_container: HBoxContainer
var _gold_label: Label
var _upgrade_btn: Button
var _tower_buttons: Array[Button] = []

var _tooltip_panel: PanelContainer
var _tooltip_name: Label
var _tooltip_stats: Label
var _tooltip_desc: Label
var _tooltip_sell: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	_build_shop_bar()
	_build_tooltip()
	# Sort towers from cheapest to most expensive
	tower_data_list.sort_custom(func(a: TowerData, b: TowerData) -> bool: return a.cost < b.cost)
	# Only create buttons for towers that are already unlocked
	var upgrade_mgr: Node = get_node_or_null("/root/UpgradeManager")
	for data in tower_data_list:
		if upgrade_mgr and upgrade_mgr.is_unlocked(data.tower_name):
			_create_tower_button(data)
	# Listen for future unlocks
	if upgrade_mgr:
		upgrade_mgr.tower_unlocked.connect(_on_tower_unlocked)
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.towers_placed_changed.connect(_refresh_all_costs)
	_update_gold_display(GameManager.gold)
	# Position after one frame so sizes are calculated
	if is_inside_tree():
		await get_tree().process_frame
		_reposition_panel()

func _build_shop_bar() -> void:
	# The panel — only as wide as its contents, positioned at bottom-center
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.BG
	style.border_color = UITheme.BORDER
	style.set_border_width_all(2)
	style.border_width_bottom = 0
	style.set_corner_radius_all(0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.set_content_margin_all(8)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, -3)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(hbox)

	_button_container = HBoxContainer.new()
	_button_container.add_theme_constant_override("separation", 8)
	hbox.add_child(_button_container)

	# Vertical separator between towers and gold/upgrades
	var sep := VSeparator.new()
	var sep_style := StyleBoxLine.new()
	sep_style.color = UITheme.SEPARATOR
	sep_style.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	hbox.add_child(sep)

	# Gold + Shop column — vertically centered between tower buttons and panel edge
	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 4)
	right_col.alignment = BoxContainer.ALIGNMENT_CENTER
	right_col.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	hbox.add_child(right_col)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 16)
	_gold_label.add_theme_color_override("font_color", UITheme.GOLD)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_child(_gold_label)

	_upgrade_btn = Button.new()
	_upgrade_btn.text = "Shop"
	_upgrade_btn.custom_minimum_size = Vector2(72, 30)
	_upgrade_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_button(_upgrade_btn)
	_upgrade_btn.add_theme_font_size_override("font_size", 12)
	_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	right_col.add_child(_upgrade_btn)

func _reposition_panel() -> void:
	if not is_inside_tree():
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var panel_size: Vector2 = _panel.size
	_panel.position = Vector2(
		(vp_size.x - panel_size.x) / 2.0,
		vp_size.y - panel_size.y
	)

func _build_tooltip() -> void:
	_tooltip_panel = UITheme.make_panel(UITheme.BG_LIGHTER)
	_tooltip_panel.visible = false

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_tooltip_panel.add_child(vbox)

	_tooltip_name = UITheme.make_label("", 15, UITheme.GOLD)
	vbox.add_child(_tooltip_name)

	_tooltip_stats = UITheme.make_label("", 12, UITheme.TEXT)
	vbox.add_child(_tooltip_stats)

	vbox.add_child(UITheme.make_separator())

	_tooltip_desc = UITheme.make_label("", 11, UITheme.TEXT_GREEN)
	_tooltip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_desc.custom_minimum_size.x = 200
	vbox.add_child(_tooltip_desc)

	_tooltip_sell = UITheme.make_label("", 11, UITheme.TEXT_ORANGE)
	vbox.add_child(_tooltip_sell)

	add_child(_tooltip_panel)

func _create_tower_button(data: TowerData) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(72, 72)
	btn.tooltip_text = ""
	if data.icon != null:
		btn.icon = data.icon
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var scaled: int = GameManager.get_scaled_cost(data.cost, data.tower_name)
	btn.text = "%d g" % scaled
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_button(btn)
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_constant_override("icon_max_width", 40)
	btn.pressed.connect(_on_tower_button_pressed.bind(data))
	btn.mouse_entered.connect(_on_button_hover.bind(btn, data))
	btn.mouse_exited.connect(_on_button_hover_end)
	btn.set_meta("tower_data", data)
	_button_container.add_child(btn)
	_tower_buttons.append(btn)
	_update_button_affordability(btn, scaled)

func _on_button_hover(btn: Button, data: TowerData) -> void:
	var scaled: int = GameManager.get_scaled_cost(data.cost, data.tower_name)
	var sell_val: int = GameManager.get_sell_value(data.tower_name)
	# Show effective stats with upgrade multipliers
	var upgrade_mgr: Node = get_node_or_null("/root/UpgradeManager")
	var eff_dmg: float = data.damage
	var eff_spd: float = data.attack_speed
	if upgrade_mgr:
		eff_dmg = data.damage * upgrade_mgr.get_damage_multiplier(data.tower_name)
		eff_spd = data.attack_speed / upgrade_mgr.get_speed_multiplier(data.tower_name)
	_tooltip_name.text = data.tower_name
	_tooltip_stats.text = "Cost: %d  |  Damage: %d  |  Speed: %.1fs" % [scaled, int(eff_dmg), eff_spd]
	_tooltip_desc.text = data.description if data.description != "" else "No description."
	_tooltip_sell.text = "Sell value: %d gold" % sell_val

	_tooltip_panel.visible = true
	# Wait one frame so the panel calculates its size before positioning.
	await get_tree().process_frame
	# Guard: if mouse left the button during the await, abort positioning.
	if not _tooltip_panel.visible or not is_instance_valid(btn):
		return
	var btn_rect: Rect2 = btn.get_global_rect()
	_tooltip_panel.global_position = Vector2(
		btn_rect.position.x,
		btn_rect.position.y - _tooltip_panel.size.y - 8
	)

func _on_button_hover_end() -> void:
	_tooltip_panel.visible = false

func _on_tower_button_pressed(data: TowerData) -> void:
	if GameManager.gold >= GameManager.get_scaled_cost(data.cost, data.tower_name):
		emit_signal("tower_selected", data)

func _on_gold_changed(new_amount: int) -> void:
	_update_gold_display(new_amount)
	_refresh_all_affordability()

func _update_gold_display(amount: int) -> void:
	_gold_label.text = "%dG" % amount

func _on_tower_unlocked(tower_name: String) -> void:
	# Avoid duplicates — check if a button for this tower already exists
	for btn in _tower_buttons:
		if is_instance_valid(btn) and btn.has_meta("tower_data"):
			var existing: TowerData = btn.get_meta("tower_data")
			if existing.tower_name == tower_name:
				return
	# Find the matching TowerData and add a button for it
	for data in tower_data_list:
		if data.tower_name == tower_name:
			_create_tower_button(data)
			break
	_refresh_all_affordability()
	# Reposition panel after the new button is added
	if is_inside_tree():
		await get_tree().process_frame
		_reposition_panel()

func _on_upgrade_pressed() -> void:
	emit_signal("upgrade_pressed")

func _refresh_all_affordability() -> void:
	for btn in _tower_buttons:
		if is_instance_valid(btn) and btn.has_meta("tower_data"):
			var data: TowerData = btn.get_meta("tower_data")
			var scaled: int = GameManager.get_scaled_cost(data.cost, data.tower_name)
			_update_button_affordability(btn, scaled)

func _refresh_all_costs() -> void:
	for btn in _tower_buttons:
		if is_instance_valid(btn) and btn.has_meta("tower_data"):
			var data: TowerData = btn.get_meta("tower_data")
			var scaled: int = GameManager.get_scaled_cost(data.cost, data.tower_name)
			btn.text = "%d g" % scaled
			_update_button_affordability(btn, scaled)

func _update_button_affordability(btn: Button, cost: int) -> void:
	var can_afford := GameManager.gold >= cost
	btn.disabled = not can_afford
	if can_afford:
		btn.modulate = Color.WHITE
		btn.add_theme_color_override("font_color", UITheme.TEXT)
	else:
		btn.modulate = Color(0.4, 0.4, 0.4, 0.7)
		btn.add_theme_color_override("font_color", UITheme.TEXT_DIM)
