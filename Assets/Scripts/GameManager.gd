extends Node

signal gold_changed(new_amount: int)

const STARTING_GOLD: int = 1000000

var gold: int = STARTING_GOLD

# ── Per-tower-type cost scaling ──────────────────────────────────────────────
const COST_SCALE_PER_TOWER: float = 1.25

signal towers_placed_changed

# tower_name → number of that type currently on the map
var _tower_type_counts: Dictionary = {}
# tower_name → Array[int] of paid costs, kept sorted ascending
var _tower_paid_costs: Dictionary = {}

func get_scaled_cost(base_cost: int, tower_name: String) -> int:
	var count: int = _tower_type_counts.get(tower_name, 0)
	if count == 0:
		return base_cost
	return int(base_cost * pow(COST_SCALE_PER_TOWER, count))

func record_tower_placed(tower_name: String, paid_cost: int) -> void:
	_tower_type_counts[tower_name] = _tower_type_counts.get(tower_name, 0) + 1
	if not _tower_paid_costs.has(tower_name):
		_tower_paid_costs[tower_name] = []
	_tower_paid_costs[tower_name].append(paid_cost)
	_tower_paid_costs[tower_name].sort()
	emit_signal("towers_placed_changed")

## Sell value = half of the highest-cost placed tower of that type.
func get_sell_value(tower_name: String) -> int:
	if not _tower_paid_costs.has(tower_name) or _tower_paid_costs[tower_name].size() == 0:
		return 0
	var costs: Array = _tower_paid_costs[tower_name]
	var highest: int = costs[costs.size() - 1]
	return int(highest / 2.0)

func record_tower_sold(tower_name: String) -> void:
	if _tower_paid_costs.has(tower_name) and _tower_paid_costs[tower_name].size() > 0:
		# Remove the highest-cost entry (last element, array is sorted ascending)
		_tower_paid_costs[tower_name].pop_back()
	_tower_type_counts[tower_name] = max(0, _tower_type_counts.get(tower_name, 0) - 1)
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
	_tower_type_counts.clear()
	_tower_paid_costs.clear()
	total_damage_dealt = 0.0
	gold_earned = 0
	gold_spent = 0
	waves_completed = 0
	_start_time_msec = Time.get_ticks_msec()
	emit_signal("gold_changed", gold)
