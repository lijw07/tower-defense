# WaveClearUI.gd
# Shows a countdown banner at the top of the screen between waves.
# After 10 seconds the next wave starts automatically.
extends CanvasLayer

signal next_wave_requested

const COUNTDOWN_DURATION: int = 10

var _seconds_left: int = 0
var _countdown_timer: Timer

var _panel: PanelContainer
var _wave_label: Label
var _countdown_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_countdown_timer = Timer.new()
	_countdown_timer.wait_time = 1.0
	_countdown_timer.one_shot = false
	# Timer should pause when the game is paused (e.g. ESC pause menu).
	_countdown_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	_countdown_timer.timeout.connect(_on_tick)
	add_child(_countdown_timer)

func _build_ui() -> void:
	_panel = UITheme.make_panel(UITheme.BG)
	_panel.visible = false

	# Anchor to top-center
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = -150
	_panel.offset_right = 150
	_panel.offset_top = 10
	_panel.offset_bottom = 78

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(vbox)

	_wave_label = UITheme.make_title("", 17)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_wave_label)

	_countdown_label = UITheme.make_label("", 13, UITheme.TEXT)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_countdown_label)

	add_child(_panel)

func show_wave_complete(wave_number: int) -> void:
	if not is_inside_tree():
		return
	_wave_label.text = "Wave %d Complete!" % wave_number
	_seconds_left = COUNTDOWN_DURATION
	_update_countdown_text()
	_panel.visible = true
	_countdown_timer.start()

func _on_tick() -> void:
	_seconds_left -= 1
	if _seconds_left <= 0:
		_start_next()
	else:
		_update_countdown_text()

func _update_countdown_text() -> void:
	_countdown_label.text = "Next wave in %d..." % _seconds_left

func _start_next() -> void:
	_countdown_timer.stop()
	_panel.visible = false
	emit_signal("next_wave_requested")

func force_hide() -> void:
	_countdown_timer.stop()
	_panel.visible = false
