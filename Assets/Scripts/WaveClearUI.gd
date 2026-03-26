# WaveClearUI.gd
# Shows a countdown banner at the top of the screen between waves.
# After 10 seconds the next wave starts automatically.
# At 5 seconds the panel slides off-screen to the right and fades out.
# When a new wave banner appears it slides in from the right.
extends CanvasLayer

signal next_wave_requested

const COUNTDOWN_DURATION: int = 10
const SLIDE_THRESHOLD: int = 5

# Panel rest offsets (anchored top-right)
const REST_LEFT: float = -200.0
const REST_RIGHT: float = -8.0
const REST_TOP: float = 8.0
const REST_BOTTOM: float = 62.0

# Off-screen offsets (slid fully to the right)
const OFF_LEFT: float = 8.0
const OFF_RIGHT: float = 200.0

var _seconds_left: int = 0
var _countdown_timer: Timer
var _slide_tween: Tween = null

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

	# Anchor to top-right
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = REST_LEFT
	_panel.offset_right = REST_RIGHT
	_panel.offset_top = REST_TOP
	_panel.offset_bottom = REST_BOTTOM

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(vbox)

	_wave_label = UITheme.make_title("", 11)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_wave_label)

	_countdown_label = UITheme.make_label("", 9, UITheme.TEXT)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_countdown_label)

	add_child(_panel)

func _kill_slide_tween() -> void:
	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()
	_slide_tween = null

func _set_panel_rest() -> void:
	_panel.offset_left = REST_LEFT
	_panel.offset_right = REST_RIGHT
	_panel.modulate.a = 1.0

func _set_panel_offscreen() -> void:
	_panel.offset_left = OFF_LEFT
	_panel.offset_right = OFF_RIGHT
	_panel.modulate.a = 0.0

## Animate the panel sliding in from the right.
func _slide_in() -> void:
	_kill_slide_tween()
	_set_panel_offscreen()
	_panel.visible = true
	_slide_tween = create_tween()
	_slide_tween.set_parallel(true)
	_slide_tween.tween_property(_panel, "offset_left", REST_LEFT, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_slide_tween.tween_property(_panel, "offset_right", REST_RIGHT, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_slide_tween.tween_property(_panel, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)

## Animate the panel sliding out to the right and fading.
func _slide_out() -> void:
	_kill_slide_tween()
	_slide_tween = create_tween()
	_slide_tween.set_parallel(true)
	_slide_tween.tween_property(_panel, "offset_left", OFF_LEFT, 1.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_slide_tween.tween_property(_panel, "offset_right", OFF_RIGHT, 1.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_slide_tween.tween_property(_panel, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN)

func show_wave_starting(wave_number: int) -> void:
	if not is_inside_tree():
		return
	_wave_label.text = "Wave %d Starting" % wave_number
	_seconds_left = COUNTDOWN_DURATION
	_update_countdown_text()
	_slide_in()
	_countdown_timer.start()

func show_wave_complete(wave_number: int) -> void:
	if not is_inside_tree():
		return
	_wave_label.text = "Wave %d Complete!" % wave_number
	_seconds_left = COUNTDOWN_DURATION
	_update_countdown_text()
	_slide_in()
	_countdown_timer.start()

func _on_tick() -> void:
	_seconds_left -= 1
	if _seconds_left <= 0:
		_start_next()
	else:
		_update_countdown_text()
		if _seconds_left == SLIDE_THRESHOLD:
			_slide_out()

func _update_countdown_text() -> void:
	_countdown_label.text = "Next wave in %d..." % _seconds_left

func _start_next() -> void:
	_countdown_timer.stop()
	_kill_slide_tween()
	_panel.visible = false
	_set_panel_rest()
	emit_signal("next_wave_requested")

func force_hide() -> void:
	_countdown_timer.stop()
	_kill_slide_tween()
	_panel.visible = false
	_set_panel_rest()
