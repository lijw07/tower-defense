# TowerSellUI.gd
# Shows a small popup next to a placed tower with its info and a Sell button.
# Clicking Sell refunds half the tower's cost and removes it from the map.
# Click anywhere outside the panel (or press ESC / right-click) to dismiss.
extends CanvasLayer

signal tower_sold(tower: Node2D)

var _selected_tower: Node2D = null

var _panel: PanelContainer
var _name_label: Label
var _stats_label: Label
var _desc_label: Label
var _sell_btn: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func _build_ui() -> void:
	_panel = UITheme.make_panel(UITheme.BG_LIGHTER)
	_panel.visible = false
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	_panel.add_child(vbox)

	_name_label = UITheme.make_label("", 14, UITheme.GOLD)
	vbox.add_child(_name_label)

	_stats_label = UITheme.make_label("", 11, UITheme.TEXT)
	vbox.add_child(_stats_label)

	vbox.add_child(UITheme.make_separator())

	_desc_label = UITheme.make_label("", 10, UITheme.TEXT_GREEN)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.custom_minimum_size.x = 180
	vbox.add_child(_desc_label)

	_sell_btn = UITheme.make_button("Sell", Vector2(180, 30))
	_sell_btn.pressed.connect(_on_sell_pressed)
	vbox.add_child(_sell_btn)

func select_tower(tower: Node2D) -> void:
	if tower == null or tower.tower_data == null:
		return
	_selected_tower = tower
	var data: TowerData = tower.tower_data
	var paid: int = tower.get_meta("paid_cost") if tower.has_meta("paid_cost") else data.cost
	var sell_value: int = int(paid / 2.0)
	_name_label.text = data.tower_name
	_stats_label.text = "Damage: %d  |  Speed: %.1fs" % [int(data.damage), data.attack_speed]
	_desc_label.text = data.description if data.description != "" else "No description."
	_sell_btn.text = "Sell (%d gold)" % sell_value

	_panel.visible = true
	# Position near the tower in screen space.
	# Wait one frame so the panel calculates its size before positioning.
	await get_tree().process_frame
	# Guard: tower or selection may have changed during the await.
	if not is_instance_valid(tower) or _selected_tower != tower or not _panel.visible:
		return
	var cam := get_viewport().get_camera_2d()
	var screen_pos: Vector2
	if cam:
		screen_pos = (tower.global_position - cam.global_position) * cam.zoom + get_viewport().get_visible_rect().size * 0.5
	else:
		screen_pos = tower.global_position
	_panel.global_position = Vector2(screen_pos.x + 20, screen_pos.y - _panel.size.y * 0.5)

func deselect() -> void:
	_selected_tower = null
	_panel.visible = false

func _on_sell_pressed() -> void:
	if _selected_tower == null or not is_instance_valid(_selected_tower):
		deselect()
		return
	var data: TowerData = _selected_tower.tower_data
	var paid: int = _selected_tower.get_meta("paid_cost") if _selected_tower.has_meta("paid_cost") else data.cost
	var sell_value: int = int(paid / 2.0)
	GameManager.refund_gold(sell_value)
	GameManager.record_tower_sold()
	var tower_ref := _selected_tower
	deselect()
	emit_signal("tower_sold", tower_ref)

func _input(event: InputEvent) -> void:
	# Uses _input so it runs before PauseMenuUI's _unhandled_input and
	# consumes ESC / clicks when the sell panel is open.
	if not _panel.visible:
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		deselect()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			deselect()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			# Dismiss if the click is outside the panel (synchronous check)
			var panel_rect := Rect2(_panel.global_position, _panel.size)
			if not panel_rect.has_point(event.position):
				deselect()
