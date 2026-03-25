# GameOverUI.gd — Game-over screen showing session stats and action buttons.
extends CanvasLayer

const GAME_SCENE_PATH = "res://Assets/Scene/scene.tscn"
const MAIN_MENU_PATH  = "res://Assets/Scene/main_menu.tscn"

var _overlay: ColorRect
var _panel: PanelContainer
var _waves_label: Label
var _damage_label: Label
var _earned_label: Label
var _spent_label: Label
var _time_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func _build_ui() -> void:
	# Dark semi-transparent full-screen overlay
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.55)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	_panel = UITheme.make_panel()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -155
	_panel.offset_right = 155
	_panel.offset_top = -160
	_panel.offset_bottom = 160
	_panel.visible = false
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(vbox)

	# Title
	var title := UITheme.make_title("Game Over", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UITheme.TEXT_RED)
	vbox.add_child(title)

	vbox.add_child(UITheme.make_separator())

	# ── Stats section ────────────────────────────────────────────────────────
	var stats_box := VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 5)
	vbox.add_child(stats_box)

	_waves_label  = _stat_row(stats_box, "Waves Survived")
	_damage_label = _stat_row(stats_box, "Damage Dealt")
	_earned_label = _stat_row(stats_box, "Gold Earned")
	_spent_label  = _stat_row(stats_box, "Gold Spent")
	_time_label   = _stat_row(stats_box, "Time Played")

	vbox.add_child(UITheme.make_separator())

	# ── Buttons ──────────────────────────────────────────────────────────────
	var retry_btn := UITheme.make_button("Retry")
	retry_btn.pressed.connect(_on_restart_pressed)
	vbox.add_child(retry_btn)

	var menu_btn := UITheme.make_button("Main Menu")
	menu_btn.pressed.connect(_on_main_menu_pressed)
	vbox.add_child(menu_btn)

func _stat_row(parent: VBoxContainer, label_text: String) -> Label:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var name_lbl := UITheme.make_label(label_text, 12, UITheme.TEXT_DIM)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var val_lbl := UITheme.make_label("—", 12, UITheme.TEXT)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(val_lbl)

	return val_lbl

func show_game_over() -> void:
	# Populate stats
	_waves_label.text  = "%d" % GameManager.waves_completed
	_damage_label.text = "%d" % int(GameManager.total_damage_dealt)
	_earned_label.text = "%d" % GameManager.gold_earned
	_spent_label.text  = "%d" % GameManager.gold_spent
	_time_label.text   = GameManager.get_time_played_string()

	_overlay.visible = true
	_panel.visible = true
	get_tree().paused = true

func _on_restart_pressed() -> void:
	_reset_autoloads()
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_main_menu_pressed() -> void:
	_reset_autoloads()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_PATH)

func _reset_autoloads() -> void:
	GameManager.reset()
	var upgrade_mgr: Node = get_node_or_null("/root/UpgradeManager")
	if upgrade_mgr:
		upgrade_mgr.reset()
