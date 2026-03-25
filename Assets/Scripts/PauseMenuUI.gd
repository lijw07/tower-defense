# PauseMenuUI.gd
# Pressing ESC pauses the game and shows Resume / Exit buttons.
extends CanvasLayer

const MAIN_MENU_PATH = "res://Assets/Scene/main_menu.tscn"

var _is_paused: bool = false

var _overlay: ColorRect
var _panel: PanelContainer

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

	_panel = UITheme.make_panel()
	_panel.visible = false

	# Center on screen
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -120
	_panel.offset_right = 120
	_panel.offset_top = -85
	_panel.offset_bottom = 85

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(vbox)

	var title := UITheme.make_title("Paused", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(UITheme.make_separator())

	var resume_btn := UITheme.make_button("Resume")
	resume_btn.pressed.connect(_on_resume_pressed)
	vbox.add_child(resume_btn)

	var exit_btn := UITheme.make_button("Exit")
	exit_btn.pressed.connect(_on_exit_pressed)
	vbox.add_child(exit_btn)

	add_child(_panel)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _is_paused:
			_resume()
		elif not get_tree().paused:
			_pause()
		else:
			return
		get_viewport().set_input_as_handled()

func _pause() -> void:
	_is_paused = true
	_overlay.visible = true
	_panel.visible = true
	get_tree().paused = true

func _resume() -> void:
	_is_paused = false
	_overlay.visible = false
	_panel.visible = false
	get_tree().paused = false

func _on_resume_pressed() -> void:
	_resume()

func _on_exit_pressed() -> void:
	_is_paused = false
	_overlay.visible = false
	_panel.visible = false
	GameManager.reset()
	var upgrade_mgr: Node = get_node_or_null("/root/UpgradeManager")
	if upgrade_mgr:
		upgrade_mgr.reset()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
