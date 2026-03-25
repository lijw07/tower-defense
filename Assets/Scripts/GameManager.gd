extends Node

signal gold_changed(new_amount: int)

const STARTING_GOLD: int = 150

var gold: int = STARTING_GOLD

# ── Tower cost scaling ───────────────────────────────────────────────────────
const COST_SCALE_PER_TOWER: float = 1.5
var towers_placed: int = 0

signal towers_placed_changed

func get_scaled_cost(base_cost: int) -> int:
	if towers_placed == 0:
		return base_cost
	return int(base_cost * pow(COST_SCALE_PER_TOWER, towers_placed))

func record_tower_placed() -> void:
	towers_placed += 1
	emit_signal("towers_placed_changed")

func record_tower_sold() -> void:
	if towers_placed > 0:
		towers_placed -= 1
		emit_signal("towers_placed_changed")

# ── Session stats ────────────────────────────────────────────────────────────
var total_damage_dealt: float = 0.0
var gold_earned: int = 0
var gold_spent: int = 0
var waves_completed: int = 0
var _start_time_msec: int = 0

func _ready() -> void:
	_start_time_msec = Time.get_ticks_msec()

# ── Gold API ─────────────────────────────────────────────────────────────────

func add_gold(amount: int) -> void:
	gold += amount
	gold_earned += amount
	emit_signal("gold_changed", gold)

# Refund gold without counting it as "earned" (used for tower sells).
func refund_gold(amount: int) -> void:
	gold += amount
	emit_signal("gold_changed", gold)

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_spent += amount
	emit_signal("gold_changed", gold)
	return true

# ── Stats API ────────────────────────────────────────────────────────────────

func record_damage(amount: float) -> void:
	total_damage_dealt += amount

func record_wave_completed() -> void:
	waves_completed += 1

func get_time_played_seconds() -> float:
	return float(Time.get_ticks_msec() - _start_time_msec) / 1000.0

func get_time_played_string() -> String:
	var total_sec := int(get_time_played_seconds())
	@warning_ignore("integer_division")
	var minutes := total_sec / 60
	var seconds := total_sec % 60
	return "%d:%02d" % [minutes, seconds]

# ── Reset ────────────────────────────────────────────────────────────────────

func reset() -> void:
	gold = STARTING_GOLD
	towers_placed = 0
	total_damage_dealt = 0.0
	gold_earned = 0
	gold_spent = 0
	waves_completed = 0
	_start_time_msec = Time.get_ticks_msec()
	emit_signal("gold_changed", gold)
