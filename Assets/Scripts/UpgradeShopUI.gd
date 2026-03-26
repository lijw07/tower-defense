extends CanvasLayer
## Shop UI — compact 3+ column grid. Tower cards + castle upgrades, no scrolling.

var _overlay: ColorRect
var _panel: PanelContainer
var _grid: GridContainer
var _tower_cards: Array[Dictionary] = []
var _upgrade_mgr: Node
var _tower_data_list: Array = []
var _scroll: ScrollContainer
var _dragging_scroll: bool = false
var _drag_prev_y: float = 0.0       # previous frame's mouse Y for incremental drag

# Castle upgrade UI references
var _castle_hp_level_lbl: Label
var _castle_hp_cost_lbl: Label
var _castle_hp_btn: Button
var _castle_armor_count_lbl: Label
var _castle_armor_cost_lbl: Label
var _castle_armor_btn: Button
var _castle_heal_cost_lbl: Label
var _castle_heal_btn: Button

const CARD_WIDTH: float = 140.0
const CARD_INNER: float = 120.0
const BTN_SIZE := Vector2(110, 24)
const SMALL_BTN := Vector2(52, 22)
const FONT_TITLE: int = 11
const FONT_SMALL: int = 9
const FONT_BTN: int = 9

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

	# Center container — fills the viewport
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)

	# Panel with styled background
	_panel = PanelContainer.new()
	var panel_style := UITheme.make_panel_style(UITheme.BG, 2, 6)
	panel_style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(_panel)

	# ScrollContainer wraps content — enables scroll wheel when content overflows
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	# Hide scrollbar for cleaner pixel-art look
	_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	# Drag-to-scroll input handling (no scroll wheel, no scrollbar — drag only)
	_scroll.gui_input.connect(_on_scroll_input)
	_panel.add_child(_scroll)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 8)
	outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(outer_vbox)

	# Title
	var title := UITheme.make_title("Shop", 16)
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
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
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
	castle_grid.add_theme_constant_override("h_separation", 8)
	castle_grid.add_theme_constant_override("v_separation", 8)
	outer_vbox.add_child(castle_grid)

	_build_castle_health_card(castle_grid)
	_build_castle_armor_card(castle_grid)
	_build_castle_heal_card(castle_grid)

	outer_vbox.add_child(UITheme.make_separator())

	# Close button
	var close_btn := UITheme.make_button("Close", Vector2(100, 24))
	close_btn.add_theme_font_size_override("font_size", FONT_BTN)
	close_btn.pressed.connect(toggle_shop)
	var close_row := CenterContainer.new()
	close_row.add_child(close_btn)
	outer_vbox.add_child(close_row)

	# Cap scroll height to 90% of viewport — content that exceeds this scrolls
	var vp_h: float = get_viewport().get_visible_rect().size.y
	var max_scroll_h: float = vp_h * 0.9
	var content_h: float = outer_vbox.get_combined_minimum_size().y
	_scroll.custom_minimum_size.y = min(content_h, max_scroll_h)

# ── Castle cards ──────────────────────────────────────────────────────────────

func _build_castle_health_card(parent: GridContainer) -> void:
	var card := _make_card_panel()
	parent.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	card.add_child(vbox)

	var hp_title := UITheme.make_label("Castle HP", FONT_TITLE, UITheme.TEXT)
	hp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hp_title)

	var desc := UITheme.make_label("+1 max HP per level", FONT_SMALL, UITheme.TEXT_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.custom_minimum_size = Vector2(CARD_INNER, 28)
	vbox.add_child(desc)

	_castle_hp_level_lbl = UITheme.make_label("Lv 0", FONT_SMALL, UITheme.TEXT_GREEN)
	_castle_hp_level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_castle_hp_level_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_castle_hp_level_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	vbox.add_child(_castle_hp_level_lbl)

	var hp_btn_row := CenterContainer.new()
	vbox.add_child(hp_btn_row)
	_castle_hp_btn = UITheme.make_button("Upgrade", BTN_SIZE)
	_castle_hp_btn.add_theme_font_size_override("font_size", FONT_BTN)
	_castle_hp_btn.pressed.connect(_on_buy_castle_health)
	hp_btn_row.add_child(_castle_hp_btn)

	_castle_hp_cost_lbl = UITheme.make_label("", FONT_SMALL, UITheme.GOLD)
	_castle_hp_cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_castle_hp_cost_lbl)

func _build_castle_armor_card(parent: GridContainer) -> void:
	var card := _make_card_panel()
	parent.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	card.add_child(vbox)

	var armor_title := UITheme.make_label("Armor", FONT_TITLE, UITheme.TEXT)
	armor_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(armor_title)

	var desc := UITheme.make_label("Blocks 1 full hit. Max 10.", FONT_SMALL, UITheme.TEXT_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.custom_minimum_size = Vector2(CARD_INNER, 28)
	vbox.add_child(desc)

	_castle_armor_count_lbl = UITheme.make_label("0 / 10", FONT_SMALL, UITheme.TEXT_GREEN)
	_castle_armor_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_castle_armor_count_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_castle_armor_count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	vbox.add_child(_castle_armor_count_lbl)

	var armor_btn_row := CenterContainer.new()
	vbox.add_child(armor_btn_row)
	_castle_armor_btn = UITheme.make_button("Buy", BTN_SIZE)
	_castle_armor_btn.add_theme_font_size_override("font_size", FONT_BTN)
	_castle_armor_btn.pressed.connect(_on_buy_castle_armor)
	armor_btn_row.add_child(_castle_armor_btn)

	_castle_armor_cost_lbl = UITheme.make_label("", FONT_SMALL, UITheme.GOLD)
	_castle_armor_cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_castle_armor_cost_lbl)

func _build_castle_heal_card(parent: GridContainer) -> void:
	var card := _make_card_panel()
	parent.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	card.add_child(vbox)

	var heal_title := UITheme.make_label("Heal", FONT_TITLE, UITheme.TEXT)
	heal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(heal_title)

	var desc := UITheme.make_label("Restore +1 HP to castle.", FONT_SMALL, UITheme.TEXT_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.custom_minimum_size = Vector2(CARD_INNER, 28)
	vbox.add_child(desc)

	# Expand-fill spacer pushes button to bottom, aligned with HP/Armor cards
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var heal_btn_row := CenterContainer.new()
	vbox.add_child(heal_btn_row)
	_castle_heal_btn = UITheme.make_button("Heal", BTN_SIZE)
	_castle_heal_btn.add_theme_font_size_override("font_size", FONT_BTN)
	_castle_heal_btn.pressed.connect(_on_buy_castle_heal)
	heal_btn_row.add_child(_castle_heal_btn)

	_castle_heal_cost_lbl = UITheme.make_label("", FONT_SMALL, UITheme.GOLD)
	_castle_heal_cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_castle_heal_cost_lbl)

# ── Tower card builder ────────────────────────────────────────────────────────

func _make_card_panel() -> PanelContainer:
	var card := PanelContainer.new()
	var s := UITheme.make_panel_style(UITheme.BG_LIGHTER, 1, 0)
	s.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", s)
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	return card

func _build_tower_card(data: TowerData) -> void:
	var card_panel := _make_card_panel()
	_grid.add_child(card_panel)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 5)
	card_panel.add_child(card_vbox)

	# Header: icon + name
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	card_vbox.add_child(header)

	if data.icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = data.icon
		icon_rect.custom_minimum_size = Vector2(20, 20)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		header.add_child(icon_rect)

	var name_lbl := UITheme.make_label(data.tower_name, FONT_TITLE, UITheme.TEXT)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_lbl)

	# Stats on its own line below the header, with natural card_vbox spacing
	var stats_lbl := UITheme.make_label("", FONT_SMALL, UITheme.TEXT_DIM)
	card_vbox.add_child(stats_lbl)

	# Description — always visible, even after unlock
	var desc_lbl := UITheme.make_label(data.description, FONT_SMALL, UITheme.TEXT_DIM)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(CARD_INNER, 28)
	card_vbox.add_child(desc_lbl)

	# State wrapper — expand to fill remaining space so buttons align across cards
	var state_wrapper := Control.new()
	state_wrapper.custom_minimum_size.y = 50
	state_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_vbox.add_child(state_wrapper)

	# Locked content — same 3-row structure as unlocked (label/btn/cost) for alignment
	var locked_box := VBoxContainer.new()
	locked_box.add_theme_constant_override("separation", 4)
	locked_box.alignment = BoxContainer.ALIGNMENT_CENTER
	locked_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	locked_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	state_wrapper.add_child(locked_box)

	# Top spacer — matches the level label row in unlocked columns
	var lock_spacer_top := UITheme.make_label("", FONT_SMALL, UITheme.TEXT_DIM)
	lock_spacer_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	locked_box.add_child(lock_spacer_top)

	var unlock_btn := UITheme.make_button("Unlock", BTN_SIZE)
	unlock_btn.add_theme_font_size_override("font_size", FONT_BTN)
	unlock_btn.pressed.connect(_on_unlock_pressed.bind(data))
	locked_box.add_child(unlock_btn)

	# Bottom cost label — matches the cost label row in unlocked columns
	var unlock_cost_lbl := UITheme.make_label("", FONT_SMALL, UITheme.GOLD)
	unlock_cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	locked_box.add_child(unlock_cost_lbl)

	# Unlocked content: DMG + SPD side by side — anchored to bottom for alignment
	var unlocked_box := HBoxContainer.new()
	unlocked_box.add_theme_constant_override("separation", 8)
	unlocked_box.alignment = BoxContainer.ALIGNMENT_CENTER
	unlocked_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	unlocked_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	state_wrapper.add_child(unlocked_box)

	# DMG column
	var dmg_col := VBoxContainer.new()
	dmg_col.add_theme_constant_override("separation", 4)
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
	spd_col.add_theme_constant_override("separation", 4)
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
		"unlock_cost_lbl": unlock_cost_lbl,
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
		cd.unlock_btn.text = "Unlock"
		cd.unlock_cost_lbl.text = "%dG" % data.unlock_cost
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

	var max_lvl: int = _upgrade_mgr.MAX_UPGRADE_LEVEL
	cd.dmg_level_lbl.text = "Lv %d" % dmg_lvl
	if dmg_lvl >= max_lvl:
		cd.dmg_cost_lbl.text = "MAX"
		cd.dmg_btn.disabled = true
		cd.dmg_btn.modulate = Color(0.4, 0.4, 0.4, 0.7)
	else:
		var dmg_cost: int = _upgrade_mgr.get_damage_upgrade_cost(tname)
		cd.dmg_cost_lbl.text = "%dG" % dmg_cost
		var can_dmg := GameManager.gold >= dmg_cost
		cd.dmg_btn.disabled = not can_dmg
		cd.dmg_btn.modulate = Color.WHITE if can_dmg else Color(0.4, 0.4, 0.4, 0.7)

	cd.spd_level_lbl.text = "Lv %d" % spd_lvl
	if spd_lvl >= max_lvl:
		cd.spd_cost_lbl.text = "MAX"
		cd.spd_btn.disabled = true
		cd.spd_btn.modulate = Color(0.4, 0.4, 0.4, 0.7)
	else:
		var spd_cost: int = _upgrade_mgr.get_speed_upgrade_cost(tname)
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

	# Heal card
	if _castle_heal_btn != null:
		if _upgrade_mgr.is_castle_full_health():
			_castle_heal_cost_lbl.text = "FULL"
			_castle_heal_btn.disabled = true
			_castle_heal_btn.modulate = Color(0.4, 0.4, 0.4, 0.7)
		else:
			var heal_cost: int = _upgrade_mgr.get_castle_heal_cost()
			_castle_heal_cost_lbl.text = "%dG" % heal_cost
			var can_heal := GameManager.gold >= heal_cost
			_castle_heal_btn.disabled = not can_heal
			_castle_heal_btn.modulate = Color.WHITE if can_heal else Color(0.4, 0.4, 0.4, 0.7)

func _refresh_all() -> void:
	for cd in _tower_cards:
		_refresh_card(cd)
	_refresh_castle_section()

# ── Interactions ─────────────────────────────────────────────────────────────

func toggle_shop() -> void:
	_overlay.visible = not _overlay.visible
	var sfx: Node = get_node_or_null("/root/SFXManager")
	if _overlay.visible:
		if sfx:
			sfx.play("shop_open")
		_refresh_all()
	else:
		if sfx:
			sfx.play("shop_close")

func _play_buy_sfx() -> void:
	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("upgrade_buy")

func _on_unlock_pressed(data: TowerData) -> void:
	if _upgrade_mgr.unlock_tower(data.tower_name, data.unlock_cost):
		_play_buy_sfx()

func _on_buy_damage(tower_name: String) -> void:
	if _upgrade_mgr.buy_damage_upgrade(tower_name):
		_play_buy_sfx()

func _on_buy_speed(tower_name: String) -> void:
	if _upgrade_mgr.buy_speed_upgrade(tower_name):
		_play_buy_sfx()

func _on_buy_castle_health() -> void:
	if _upgrade_mgr.buy_castle_health_upgrade():
		_play_buy_sfx()

func _on_buy_castle_armor() -> void:
	if _upgrade_mgr.buy_castle_armor():
		_play_buy_sfx()

func _on_buy_castle_heal() -> void:
	if _upgrade_mgr.buy_castle_heal():
		_play_buy_sfx()

func _on_gold_changed(_amount: int) -> void:
	if _overlay.visible:
		_refresh_all()

func _on_scroll_input(event: InputEvent) -> void:
	# Block scroll wheel entirely — only allow click-drag scrolling
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll.get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging_scroll = true
				_drag_prev_y = event.global_position.y
			else:
				_dragging_scroll = false
	if event is InputEventMouseMotion and _dragging_scroll:
		# Incremental drag: move scroll by a fraction of the mouse delta each frame
		var delta_y: float = _drag_prev_y - event.global_position.y
		_drag_prev_y = event.global_position.y
		_scroll.scroll_vertical = maxi(_scroll.scroll_vertical + int(delta_y * 0.12), 0)
		_scroll.get_viewport().set_input_as_handled()

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _panel.get_global_rect().has_point(event.global_position):
			toggle_shop()

func _unhandled_input(event: InputEvent) -> void:
	if _overlay.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			toggle_shop()
			get_viewport().set_input_as_handled()
