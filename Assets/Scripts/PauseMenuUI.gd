# PauseMenuUI.gd
# Pressing ESC pauses the game and shows Resume / Settings / Exit buttons.
extends CanvasLayer

const MAIN_MENU_PATH = "res://Assets/Scene/main_menu.tscn"

var _is_paused: bool = false
var _showing_settings: bool = false
var _showing_howto: bool = false

var _overlay: ColorRect
var _panel: PanelContainer
var _main_vbox: VBoxContainer
var _settings_vbox: VBoxContainer
var _howto_vbox: VBoxContainer

var _music_slider: HSlider
var _sfx_slider: HSlider
var _music_value_label: Label
var _sfx_value_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func _build_ui() -> void:
	# Full-screen dim overlay
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.45)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = UITheme.make_panel()
	_panel.visible = false
	_panel.custom_minimum_size = Vector2(260, 0)
	center.add_child(_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 0)
	_panel.add_child(root_vbox)

	# ── Main menu (Resume / Settings / Exit) ──
	_main_vbox = VBoxContainer.new()
	_main_vbox.add_theme_constant_override("separation", 10)
	_main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(_main_vbox)

	var title := UITheme.make_title("Paused", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_vbox.add_child(title)

	_main_vbox.add_child(UITheme.make_separator())

	var resume_btn := UITheme.make_button("Resume")
	resume_btn.pressed.connect(_on_resume_pressed)
	_main_vbox.add_child(resume_btn)

	var howto_btn := UITheme.make_button("How to Play")
	howto_btn.pressed.connect(func() -> void: _show_howto())
	_main_vbox.add_child(howto_btn)

	var settings_btn := UITheme.make_button("Settings")
	settings_btn.pressed.connect(_show_settings)
	_main_vbox.add_child(settings_btn)

	var exit_btn := UITheme.make_button("Exit")
	exit_btn.pressed.connect(_on_exit_pressed)
	_main_vbox.add_child(exit_btn)

	# ── Settings panel (volume sliders) ──
	_settings_vbox = VBoxContainer.new()
	_settings_vbox.add_theme_constant_override("separation", 8)
	_settings_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_settings_vbox.visible = false
	root_vbox.add_child(_settings_vbox)

	var stitle := UITheme.make_title("Settings", 14)
	stitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_vbox.add_child(stitle)

	_settings_vbox.add_child(UITheme.make_separator())

	# Music volume
	var music_row := HBoxContainer.new()
	music_row.add_theme_constant_override("separation", 8)
	var music_lbl := UITheme.make_label("Music", 8, UITheme.TEXT)
	music_lbl.custom_minimum_size.x = 50
	music_row.add_child(music_lbl)

	var sfx_node: Node = get_node_or_null("/root/SFXManager")
	var music_init: float = 1.0
	if sfx_node:
		music_init = sfx_node.get_music_volume_linear()
	_music_slider = UITheme.make_hslider(0.0, 1.0, music_init)
	_music_slider.value_changed.connect(_on_music_volume_changed)
	music_row.add_child(_music_slider)
	_music_value_label = UITheme.make_label(_pct(music_init), 8, UITheme.TEXT_DIM)
	_music_value_label.custom_minimum_size.x = 35
	_music_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	music_row.add_child(_music_value_label)
	_settings_vbox.add_child(music_row)

	# SFX volume
	var sfx_row := HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 8)
	var sfx_lbl := UITheme.make_label("SFX", 8, UITheme.TEXT)
	sfx_lbl.custom_minimum_size.x = 50
	sfx_row.add_child(sfx_lbl)

	var sfx_init: float = 1.0
	if sfx_node:
		sfx_init = sfx_node.get_sfx_volume_linear()
	_sfx_slider = UITheme.make_hslider(0.0, 1.0, sfx_init)
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	sfx_row.add_child(_sfx_slider)
	_sfx_value_label = UITheme.make_label(_pct(sfx_init), 8, UITheme.TEXT_DIM)
	_sfx_value_label.custom_minimum_size.x = 35
	_sfx_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sfx_row.add_child(_sfx_value_label)
	_settings_vbox.add_child(sfx_row)

	# Back button
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4
	_settings_vbox.add_child(spacer)

	var back_btn := UITheme.make_button("Back")
	back_btn.pressed.connect(_hide_settings)
	_settings_vbox.add_child(back_btn)

	# ── How to Play panel ──
	_howto_vbox = VBoxContainer.new()
	_howto_vbox.add_theme_constant_override("separation", 6)
	_howto_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_howto_vbox.visible = false
	root_vbox.add_child(_howto_vbox)

	var htitle := UITheme.make_title("How to Play", 14)
	htitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_howto_vbox.add_child(htitle)

	_howto_vbox.add_child(UITheme.make_separator())

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
		tip.custom_minimum_size = Vector2(240, 0)
		tip.add_theme_color_override("default_color", UITheme.TEXT)
		tip.add_theme_font_size_override("normal_font_size", 7)
		tip.add_theme_font_size_override("bold_font_size", 7)
		var pf: Font = UITheme.get_pixel_font()
		if pf:
			tip.add_theme_font_override("normal_font", pf)
			tip.add_theme_font_override("bold_font", pf)
		tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_howto_vbox.add_child(tip)

	var hback_btn := UITheme.make_button("Back")
	hback_btn.pressed.connect(func() -> void: _hide_howto())
	_howto_vbox.add_child(hback_btn)


func _pct(val: float) -> String:
	return "%d%%" % int(val * 100.0)


func _on_music_volume_changed(value: float) -> void:
	var sfx_node: Node = get_node_or_null("/root/SFXManager")
	if sfx_node:
		sfx_node.set_music_volume(value)
	_music_value_label.text = _pct(value)


func _on_sfx_volume_changed(value: float) -> void:
	var sfx_node: Node = get_node_or_null("/root/SFXManager")
	if sfx_node:
		sfx_node.set_sfx_volume(value)
		sfx_node.play("button_click")  # Preview the SFX volume
	_sfx_value_label.text = _pct(value)


func _show_settings() -> void:
	_play_sfx("button_click")
	_showing_settings = true
	_main_vbox.visible = false
	_settings_vbox.visible = true


func _hide_settings() -> void:
	_play_sfx("button_click")
	_showing_settings = false
	_settings_vbox.visible = false
	_main_vbox.visible = true


func _show_howto() -> void:
	_play_sfx("button_click")
	_showing_howto = true
	_main_vbox.visible = false
	_howto_vbox.visible = true


func _hide_howto() -> void:
	_play_sfx("button_click")
	_showing_howto = false
	_howto_vbox.visible = false
	_main_vbox.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _showing_howto:
			_hide_howto()
		elif _showing_settings:
			_hide_settings()
		elif _is_paused:
			_resume()
		elif not get_tree().paused:
			_pause()
		else:
			return
		get_viewport().set_input_as_handled()


func _play_sfx(sound_name: String) -> void:
	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play(sound_name)

func _pause() -> void:
	_is_paused = true
	_overlay.visible = true
	_panel.visible = true
	_play_sfx("shop_open")
	get_tree().paused = true


func _resume() -> void:
	_is_paused = false
	_showing_settings = false
	_showing_howto = false
	_overlay.visible = false
	_panel.visible = false
	_settings_vbox.visible = false
	_howto_vbox.visible = false
	_main_vbox.visible = true
	_play_sfx("shop_close")
	get_tree().paused = false


func _on_resume_pressed() -> void:
	_play_sfx("button_click")
	_resume()


func _on_exit_pressed() -> void:
	_play_sfx("button_click")
	_is_paused = false
	_showing_settings = false
	_overlay.visible = false
	_panel.visible = false
	GameManager.reset()
	var upgrade_mgr: Node = get_node_or_null("/root/UpgradeManager")
	if upgrade_mgr:
		upgrade_mgr.reset()
	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.stop_music()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
