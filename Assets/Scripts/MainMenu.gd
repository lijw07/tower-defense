extends Control

const GAME_SCENE_PATH = "res://Assets/Scene/scene.tscn"

func _ready() -> void:
	_build_ui()

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
	var title := UITheme.make_label("Tower Defence", 28, UITheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# ── Subtitle ──
	var subtitle := UITheme.make_label("Defend your castle at all costs", 12, UITheme.TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 16
	vbox.add_child(spacer)

	# ── Start button ──
	var start_btn := UITheme.make_button("Start", Vector2(220, 42))
	start_btn.add_theme_font_size_override("font_size", 16)
	start_btn.pressed.connect(_on_start_pressed)
	var btn_row := CenterContainer.new()
	btn_row.add_child(start_btn)
	vbox.add_child(btn_row)

	# Spacer
	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 6
	vbox.add_child(spacer2)

	# ── Bottom decorative line ──
	vbox.add_child(UITheme.make_separator())

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)
