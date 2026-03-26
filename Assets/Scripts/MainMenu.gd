extends Control

const GAME_SCENE_PATH = "res://Assets/Scene/scene.tscn"

var _howto_overlay: ColorRect

func _ready() -> void:
	_build_ui()
	# Start menu background music
	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play_music("menu")

func _build_ui() -> void:
	# Full-screen dark background
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Outer centering container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Main panel
	var panel := UITheme.make_panel(UITheme.BG)
	panel.custom_minimum_size = Vector2(340, 0)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# ── Decorative top line ──
	vbox.add_child(UITheme.make_separator())

	# ── Title ──
	var title := UITheme.make_label("Tower Defence", 20, UITheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# ── Subtitle ──
	var subtitle := UITheme.make_label("Defend your castle at all costs", 8, UITheme.TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 16
	vbox.add_child(spacer)

	# ── Start button ──
	var start_btn := UITheme.make_button("Start", Vector2(220, 42))
	start_btn.add_theme_font_size_override("font_size", 12)
	start_btn.pressed.connect(_on_start_pressed)
	var btn_row := CenterContainer.new()
	btn_row.add_child(start_btn)
	vbox.add_child(btn_row)

	# ── How to Play button ──
	var howto_btn := UITheme.make_button("How to Play", Vector2(220, 34))
	howto_btn.pressed.connect(_on_howto_pressed)
	var howto_row := CenterContainer.new()
	howto_row.add_child(howto_btn)
	vbox.add_child(howto_row)

	# Spacer
	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 6
	vbox.add_child(spacer2)

	# ── Bottom decorative line ──
	vbox.add_child(UITheme.make_separator())

	# ── How to Play overlay (hidden by default) ──
	_howto_overlay = ColorRect.new()
	_howto_overlay.color = Color(0, 0, 0, 0.6)
	_howto_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_howto_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_howto_overlay.visible = false
	add_child(_howto_overlay)

	var howto_center := CenterContainer.new()
	howto_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_howto_overlay.add_child(howto_center)

	var howto_panel := UITheme.make_panel(UITheme.BG)
	howto_panel.custom_minimum_size = Vector2(340, 0)
	howto_center.add_child(howto_panel)

	var hvbox := VBoxContainer.new()
	hvbox.add_theme_constant_override("separation", 6)
	hvbox.alignment = BoxContainer.ALIGNMENT_CENTER
	howto_panel.add_child(hvbox)

	var htitle := UITheme.make_title("How to Play", 16)
	htitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hvbox.add_child(htitle)

	hvbox.add_child(UITheme.make_separator())

	var tips: Array[String] = [
		"[color=#e8c654]Goal:[/color] Defend your castle from waves of enemies marching along the path.",
		"[color=#e8c654]Towers:[/color] Buy towers from the shop bar at the bottom and place them on the grass. They attack enemies automatically.",
		"[color=#e8c654]Gold:[/color] Earn gold by killing enemies. Spend it on new towers, upgrades, or removing obstacles.",
		"[color=#e8c654]Upgrades:[/color] Open the upgrade shop to improve your towers, castle health, and armor.",
		"[color=#e8c654]Selling:[/color] Click a placed tower to sell it for a partial refund.",
		"[color=#e8c654]Obstacles:[/color] Trees, rocks, and mushrooms block placement. Hover over them and click to remove for a cost.",
		"[color=#e8c654]Bosses:[/color] A red border flash and warning text signal a boss enemy. They have much more health!",
	]
	for tip_text in tips:
		var tip := RichTextLabel.new()
		tip.bbcode_enabled = true
		tip.fit_content = true
		tip.scroll_active = false
		tip.text = tip_text
		tip.add_theme_color_override("default_color", UITheme.TEXT)
		tip.add_theme_font_size_override("normal_font_size", 7)
		tip.add_theme_font_size_override("bold_font_size", 7)
		var pf: Font = UITheme.get_pixel_font()
		if pf:
			tip.add_theme_font_override("normal_font", pf)
			tip.add_theme_font_override("bold_font", pf)
		tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hvbox.add_child(tip)

	var hspacer := Control.new()
	hspacer.custom_minimum_size.y = 4
	hvbox.add_child(hspacer)

	var back_btn := UITheme.make_button("Back", Vector2(220, 34))
	back_btn.pressed.connect(_on_howto_back)
	var back_row := CenterContainer.new()
	back_row.add_child(back_btn)
	hvbox.add_child(back_row)

	hvbox.add_child(UITheme.make_separator())

func _on_start_pressed() -> void:
	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("button_click")
		sfx.stop_music()
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_howto_pressed() -> void:
	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("button_click")
	_howto_overlay.visible = true


func _on_howto_back() -> void:
	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("button_click")
	_howto_overlay.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _howto_overlay.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_on_howto_back()
			get_viewport().set_input_as_handled()
