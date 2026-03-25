extends CanvasLayer
## Shop UI — compact 3+ column grid. Tower cards + castle upgrades, no scrolling.

var _overlay: ColorRect
var _panel: PanelContainer
var _grid: GridContainer
var _tower_cards: Array[Dictionary] = []
var _upgrade_mgr: Node
var _tower_data_list: Array = []

# Castle upgrade UI references
var _castle_hp_level_lbl: Label
var _castle_hp_cost_lbl: Label
var _castle_hp_btn: Button
var _castle_armor_count_lbl: Label
var _castle_armor_cost_lbl: Label
var _castle_armor_btn: Button

const CARD_WIDTH: float = 150.0
const CARD_INNER: float = 130.0
const BTN_SIZE := Vector2(130, 22)
const SMALL_BTN := Vector2(60, 20)
const FONT_TITLE: int = 11
const FONT_SMALL: int = 8
const FONT_BTN: int = 8

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 8
	_upgrade_mgr = get_node("/root/UpgradeManager")
	_upgrade_mgr.upgrades_changed.connect(_refresh_all)
	_upgrade_mgr.castle_stats_changed.connect(_refresh_castle_section)
	GameManager.gold_changed.connect(_on_gold_changed)

func setup(tower_list: Array) -> void:
	_tower_data_list = tower_list.duplicate()
	_tower_data_list.sort_custom(func(a: TowerData, b: TowerData) -> bool: return a.cost < b.cost)
	_build_shop_panel()

# ── Shop panel ───────────────────────────────────────────────────────────────

func _build_shop_panel() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.5)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	_overlay.gui_input.connect(_on_overlay_input)

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)

	# Use a compact panel style with smaller margins
	_panel = PanelContainer.new()
	var panel_style := UITheme.make_panel_style(UITheme.BG, 2, 6)
	panel_style.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(_panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 5)
	_panel.add_child(outer_vbox)

	# Title
	var title := UITheme.make_label("Shop", 16, UITheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(title)

	outer_vbox.add_child(UITheme.make_separator())

	# ── Tower section header ──
	var tower_header := UITheme.make_label("Towers", 12, UITheme.TEXT_DIM)
	tower_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(tower_header)

	# 3-column grid for towers
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 5)
	_grid.add_theme_constant_override("v_separation", 5)
	outer_vbox.add_child(_grid)

	for data in _tower_data_list:
		_build_tower_card(data)

	outer_vbox.add_child(UITheme.make_separator())

	# ── Castle section header ──
	var castle_header := UITheme.make_label("Castle", 12, UITheme.TEXT_DIM)
	castle_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(castle_header)

	var castle_grid := GridContainer.new()
	castle_grid.columns = 3
	castle_grid.add_theme_constant_override("h_separation", 5)
	castle_grid.add_theme_constant_override("v_separation", 5)
	outer_vbox.add_child(castle_grid)

	_build_castle_health_card(castle_grid)
	_build_castle_armor_card(castle_grid)

	outer_vbox.add_child(UITheme.make_separator())

	# Close button
	var close_btn := UITheme.make_button("Close", Vector2(90, 24))
	close_btn.add_theme_font_size_override("font_size", 10)
	close_btn.pressed.connect(toggle_shop)
	var close_row := CenterContainer.new()
	close_row.add_child(close_btn)
	outer_vbox.add_child(close_row)

# ── Castle cards ──────────────────────────────────────────────────────────────

func _build_castle_health_card(parent: GridContainer) -> void:
	var card := _make_card_panel()
	parent.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	vbox.add_child(UITheme.make_label("Castle HP", FONT_TITLE, UITheme.TEXT))

	var desc := UITheme.make_label("+1 max HP per level", FONT_SMALL, UITheme.TEXT_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = CARD_INNER
	vbox.add_child(desc)

	_castle_hp_level_lbl = UITheme.make_label("Lv 0", FONT_SMALL, UITheme.TEXT_GREEN)
	_castle_hp_level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_castle_hp_level_lbl)

	_castle_hp_btn = UITheme.make_button("Upgrade", BTN_SIZE)
	_castle_hp_btn.add_theme_font_size_override("font_size", FONT_BTN)
	_castle_hp_btn.pressed.connect(_on_buy_castle_health)
	vbox.add_child(_castle_hp_btn)

	_castle_hp_cost_lbl = UITheme.make_label("", FONT_SMALL, UITheme.GOLD)
	_castle_hp_cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_castle_hp_cost_lbl)

func _build_castle_armor_card(parent: GridContainer) -> void:
	var card := _make_card_panel()
	parent.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	vbox.add_child(UITheme.make_label("Armor", FONT_TITLE, UITheme.TEXT))

	var desc := UITheme.make_label("Blocks 1 full hit. Max 10.", FONT_SMALL, UITheme.TEXT_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = CARD_INNER
	vbox.add_child(desc)

	_castle_armor_count_lbl = UITheme.make_label("0 / 10", FONT_SMALL, UITheme.TEXT_GREEN)
	_castle_armor_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_castle_armor_count_lbl)

	_castle_armor_btn = UITheme.make_button("Buy", BTN_SIZE)
	_castle_armor_btn.add_theme_font_size_override("font_size", FONT_BTN)
	_castle_armor_btn.pressed.connect(_on_buy_castle_armor)
	vbox.add_child(_castle_armor_btn)

	_castle_armor_cost_lbl = UITheme.make_label("", FONT_SMALL, UITheme.GOLD)
	_castle_armor_cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_castle_armor_cost_lbl)

# ── Tower card builder ────────────────────────────────────────────────────────

func _make_card_panel() -> PanelContainer:
	var card := PanelContainer.new()
	var s := UITheme.make_panel_style(UITheme.BG_LIGHTER, 1, 4)
	s.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", s)
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	return card

func _build_tower_card(data: TowerData) -> void:
	var card_panel := _make_card_panel()
	_grid.add_child(card_panel)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 2)
	card_panel.add_child(card_vbox)

	# Header: icon + name
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	card_vbox.add_child(header)

	if data.icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = data.icon
		icon_rect.custom_minimum_size = Vector2(20, 20)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		header.add_child(icon_rect)

	var name_col := VBoxContainer.new()
	name_col.add_theme_constant_override("separation", 0)
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_col)

	name_col.add_child(UITheme.make_label(data.tower_name, FONT_TITLE, UITheme.TEXT))

	var stats_lbl := UITheme.make_label("", FONT_SMALL, UITheme.TEXT_DIM)
	name_col.add_child(stats_lbl)

	# Locked content
	var locked_box := VBoxContainer.new()
	locked_box.add_theme_constant_override("separation", 2)
	card_vbox.add_child(locked_box)

	var desc_lbl := UITheme.make_label(data.description, FONT_SMALL, UITheme.TEXT_DIM)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size.x = CARD_INNER
	locked_box.add_child(desc_lbl)

	var unlock_btn := UITheme.make_button("Unlock", BTN_SIZE)
	unlock_btn.add_theme_font_size_override("font_size", FONT_BTN)
	unlock_btn.pressed.connect(_on_unlock_pressed.bind(data))
	locked_box.add_child(unlock_btn)

	# Unlocked content: DMG + SPD side by side
	var unlocked_box := HBoxContainer.new()
	unlocked_box.add_theme_constant_override("separation", 3)
	unlocked_box.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_child(unlocked_box)

	# DMG column
	var dmg_col := VBoxContainer.new()
	dmg_col.add_theme_constant_override("separation", 1)
	dmg_col.alignment = BoxContainer.ALIGNMENT_CENTER
	dmg_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unlocked_box.add_child(dmg_col)

	var dmg_level_lbl := UITheme.make_label("", FONT_SMALL, UITheme.TEXT_GREEN)
	dmg_level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dmg_col.add_child(dmg_level_lbl)

	var dmg_btn := UITheme.make_button("DMG", SMALL_BTN)
	dmg_btn.add_theme_font_size_override("font_size", FONT_BTN)
	dmg_btn.pressed.connect(_on_buy_damage.bind(data.tower_name))
	dmg_col.add_child(dmg_btn)

	var dmg_cost_lbl := UITheme.make_label("", FONT_SMALL, UITheme.GOLD)
	dmg_cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dmg_col.add_child(dmg_cost_lbl)

	# SPD column
	var spd_col := VBoxContainer.new()
	spd_col.add_theme_constant_override("separation", 1)
	spd_col.alignment = BoxContainer.ALIGNMENT_CENTER
	spd_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unlocked_box.add_child(spd_col)

	var spd_level_lbl := UITheme.make_label("", FONT_SMALL, UITheme.TEXT_GREEN)
	spd_level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spd_col.add_child(spd_level_lbl)

	var spd_btn := UITheme.make_button("SPD", SMALL_BTN)
	spd_btn.add_theme_font_size_override("font_size", FONT_BTN)
	spd_btn.pressed.connect(_on_buy_speed.bind(data.tower_name))
	spd_col.add_child(spd_btn)

	var spd_cost_lbl := UITheme.make_label("", FONT_SMALL, UITheme.GOLD)
	spd_cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spd_col.add_child(spd_cost_lbl)

	var card_data := {
		"tower_name": data.tower_name,
		"tower_data": data,
		"base_damage": data.damage,
		"base_speed": data.attack_speed,
		"stats_lbl": stats_lbl,
		"locked_box": locked_box,
		"unlock_btn": unlock_btn,
		"unlocked_box": unlocked_box,
		"dmg_btn": dmg_btn,
		"dmg_cost_lbl": dmg_cost_lbl,
		"dmg_level_lbl": dmg_level_lbl,
		"spd_btn": spd_btn,
		"spd_cost_lbl": spd_cost_lbl,
		"spd_level_lbl": spd_level_lbl,
	}
	_tower_cards.append(card_data)
	_refresh_card(card_data)

# ── Refresh ──────────────────────────────────────────────────────────────────

func _refresh_card(cd: Dictionary) -> void:
	var tname: String = cd.tower_name
	var data: TowerData = cd.tower_data
	var unlocked: bool = _upgrade_mgr.is_unlocked(tname)

	cd.locked_box.visible = not unlocked
	cd.unlocked_box.visible = unlocked

	if not unlocked:
		cd.stats_lbl.text = "DMG: %.0f | SPD: %.2fs" % [data.damage, data.attack_speed]
		cd.unlock_btn.text = "Unlock %dG" % data.unlock_cost
		var can_buy := GameManager.gold >= data.unlock_cost
		cd.unlock_btn.disabled = not can_buy
		cd.unlock_btn.modulate = Color.WHITE if can_buy else Color(0.4, 0.4, 0.4, 0.7)
		return

	var dmg_lvl: int = _upgrade_mgr.get_damage_level(tname)
	var spd_lvl: int = _upgrade_mgr.get_speed_level(tname)
	var dmg_mult: float = _upgrade_mgr.get_damage_multiplier(tname)
	var spd_mult: float = _upgrade_mgr.get_speed_multiplier(tname)

	var eff_dmg: float = cd.base_damage * dmg_mult
	var eff_spd: float = cd.base_speed / spd_mult
	cd.stats_lbl.text = "DMG: %.0f | SPD: %.2fs" % [eff_dmg, eff_spd]

	var dmg_cost: int = _upgrade_mgr.get_damage_upgrade_cost(tname)
	cd.dmg_level_lbl.text = "Lv %d" % dmg_lvl
	cd.dmg_cost_lbl.text = "%dG" % dmg_cost
	var can_dmg := GameManager.gold >= dmg_cost
	cd.dmg_btn.disabled = not can_dmg
	cd.dmg_btn.modulate = Color.WHITE if can_dmg else Color(0.4, 0.4, 0.4, 0.7)

	var spd_cost: int = _upgrade_mgr.get_speed_upgrade_cost(tname)
	cd.spd_level_lbl.text = "Lv %d" % spd_lvl
	cd.spd_cost_lbl.text = "%dG" % spd_cost
	var can_spd := GameManager.gold >= spd_cost
	cd.spd_btn.disabled = not can_spd
	cd.spd_btn.modulate = Color.WHITE if can_spd else Color(0.4, 0.4, 0.4, 0.7)

func _refresh_castle_section() -> void:
	if _castle_hp_btn == null:
		return
	var hp_lvl: int = _upgrade_mgr.get_castle_health_level()
	var hp_cost: int = _upgrade_mgr.get_castle_health_upgrade_cost()
	_castle_hp_level_lbl.text = "Lv %d" % hp_lvl
	_castle_hp_cost_lbl.text = "%dG" % hp_cost
	var can_hp := GameManager.gold >= hp_cost
	_castle_hp_btn.disabled = not can_hp
	_castle_hp_btn.modulate = Color.WHITE if can_hp else Color(0.4, 0.4, 0.4, 0.7)

	var armor: int = _upgrade_mgr.get_castle_armor()
	var max_armor: int = _upgrade_mgr.CASTLE_ARMOR_MAX
	_castle_armor_count_lbl.text = "%d / %d" % [armor, max_armor]
	if _upgrade_mgr.can_buy_armor():
		var armor_cost: int = _upgrade_mgr.get_castle_armor_cost()
		_castle_armor_cost_lbl.text = "%dG" % armor_cost
		var can_armor := GameManager.gold >= armor_cost
		_castle_armor_btn.disabled = not can_armor
		_castle_armor_btn.modulate = Color.WHITE if can_armor else Color(0.4, 0.4, 0.4, 0.7)
	else:
		_castle_armor_cost_lbl.text = "MAX"
		_castle_armor_btn.disabled = true
		_castle_armor_btn.modulate = Color(0.4, 0.4, 0.4, 0.7)

func _refresh_all() -> void:
	for cd in _tower_cards:
		_refresh_card(cd)
	_refresh_castle_section()

# ── Interactions ─────────────────────────────────────────────────────────────

func toggle_shop() -> void:
	_overlay.visible = not _overlay.visible
	if _overlay.visible:
		_refresh_all()

func _on_unlock_pressed(data: TowerData) -> void:
	_upgrade_mgr.unlock_tower(data.tower_name, data.unlock_cost)

func _on_buy_damage(tower_name: String) -> void:
	_upgrade_mgr.buy_damage_upgrade(tower_name)

func _on_buy_speed(tower_name: String) -> void:
	_upgrade_mgr.buy_speed_upgrade(tower_name)

func _on_buy_castle_health() -> void:
	_upgrade_mgr.buy_castle_health_upgrade()

func _on_buy_castle_armor() -> void:
	_upgrade_mgr.buy_castle_armor()

func _on_gold_changed(_amount: int) -> void:
	if _overlay.visible:
		_refresh_all()

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _panel.get_global_rect().has_point(event.global_position):
			toggle_shop()

func _unhandled_input(event: InputEvent) -> void:
	if _overlay.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			toggle_shop()
			get_viewport().set_input_as_handled()
