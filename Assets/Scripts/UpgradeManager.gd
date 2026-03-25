extends Node
## Per-tower upgrade state — tracks damage and speed upgrade levels for each tower type.
## Registered as an autoload singleton.

signal upgrades_changed
signal tower_unlocked(tower_name: String)

# tower_name → { "damage_level": int, "speed_level": int }
var _tower_upgrades: Dictionary = {}
var _unlocked_towers: Dictionary = {}   # tower_name → true

const DAMAGE_BASE_COST: int = 100
const SPEED_BASE_COST: int = 120
const COST_SCALE: float = 1.5
const DAMAGE_PER_LEVEL: float = 0.20   # +20% per level
const SPEED_PER_LEVEL: float = 0.15    # +15% per level

# ── Castle upgrades ──────────────────────────────────────────────────────────
signal castle_stats_changed

const CASTLE_HEALTH_BASE_COST: int = 150
const CASTLE_HEALTH_COST_SCALE: float = 1.5
const CASTLE_ARMOR_BASE_COST: int = 75
const CASTLE_ARMOR_COST_SCALE: float = 1.1
const CASTLE_ARMOR_MAX: int = 10

var _castle_health_level: int = 0       # permanent +1 max HP per level
var _castle_armor: int = 0              # current armor points (consumable)
var _castle_armor_total_purchased: int = 0  # lifetime purchases for cost scaling

# ── Ensure a tower entry exists ──────────────────────────────────────────────

func _ensure_tower(tower_name: String) -> void:
	if not _tower_upgrades.has(tower_name):
		_tower_upgrades[tower_name] = { "damage_level": 0, "speed_level": 0 }

# ── Cost calculation ─────────────────────────────────────────────────────────

func get_damage_upgrade_cost(tower_name: String) -> int:
	_ensure_tower(tower_name)
	var lvl: int = _tower_upgrades[tower_name].damage_level
	return int(DAMAGE_BASE_COST * pow(COST_SCALE, lvl))

func get_speed_upgrade_cost(tower_name: String) -> int:
	_ensure_tower(tower_name)
	var lvl: int = _tower_upgrades[tower_name].speed_level
	return int(SPEED_BASE_COST * pow(COST_SCALE, lvl))

# ── Purchase ─────────────────────────────────────────────────────────────────

func buy_damage_upgrade(tower_name: String) -> bool:
	var cost := get_damage_upgrade_cost(tower_name)
	if not GameManager.spend_gold(cost):
		return false
	_tower_upgrades[tower_name].damage_level += 1
	emit_signal("upgrades_changed")
	return true

func buy_speed_upgrade(tower_name: String) -> bool:
	var cost := get_speed_upgrade_cost(tower_name)
	if not GameManager.spend_gold(cost):
		return false
	_tower_upgrades[tower_name].speed_level += 1
	emit_signal("upgrades_changed")
	return true

# ── Buff queries (used by Tower.gd) ─────────────────────────────────────────

func get_damage_multiplier(tower_name: String) -> float:
	_ensure_tower(tower_name)
	var lvl: int = _tower_upgrades[tower_name].damage_level
	return 1.0 + lvl * DAMAGE_PER_LEVEL

func get_speed_multiplier(tower_name: String) -> float:
	_ensure_tower(tower_name)
	var lvl: int = _tower_upgrades[tower_name].speed_level
	return 1.0 + lvl * SPEED_PER_LEVEL

func get_damage_level(tower_name: String) -> int:
	_ensure_tower(tower_name)
	return _tower_upgrades[tower_name].damage_level

func get_speed_level(tower_name: String) -> int:
	_ensure_tower(tower_name)
	return _tower_upgrades[tower_name].speed_level

# ── Unlock system ────────────────────────────────────────────────────────────

func is_unlocked(tower_name: String) -> bool:
	return _unlocked_towers.has(tower_name)

func unlock_tower(tower_name: String, cost: int) -> bool:
	if is_unlocked(tower_name):
		return false
	if not GameManager.spend_gold(cost):
		return false
	_unlocked_towers[tower_name] = true
	emit_signal("tower_unlocked", tower_name)
	emit_signal("upgrades_changed")
	return true

## Call once at game start to mark free towers (unlock_cost == 0) as available.
func init_unlocks(tower_list: Array) -> void:
	for data in tower_list:
		if data is TowerData and data.unlock_cost == 0:
			_unlocked_towers[data.tower_name] = true
			emit_signal("tower_unlocked", data.tower_name)

# ── Castle health upgrade ─────────────────────────────────────────────────────

func get_castle_health_level() -> int:
	return _castle_health_level

func get_castle_health_upgrade_cost() -> int:
	return int(CASTLE_HEALTH_BASE_COST * pow(CASTLE_HEALTH_COST_SCALE, _castle_health_level))

func buy_castle_health_upgrade() -> bool:
	var cost := get_castle_health_upgrade_cost()
	if not GameManager.spend_gold(cost):
		return false
	_castle_health_level += 1
	emit_signal("castle_stats_changed")
	emit_signal("upgrades_changed")
	return true

# ── Castle armor ──────────────────────────────────────────────────────────────

func get_castle_armor() -> int:
	return _castle_armor

func get_castle_armor_cost() -> int:
	return int(CASTLE_ARMOR_BASE_COST * pow(CASTLE_ARMOR_COST_SCALE, _castle_armor_total_purchased))

func can_buy_armor() -> bool:
	return _castle_armor < CASTLE_ARMOR_MAX

func buy_castle_armor() -> bool:
	if _castle_armor >= CASTLE_ARMOR_MAX:
		return false
	var cost := get_castle_armor_cost()
	if not GameManager.spend_gold(cost):
		return false
	_castle_armor += 1
	_castle_armor_total_purchased += 1
	emit_signal("castle_stats_changed")
	emit_signal("upgrades_changed")
	return true

## Called by Castle when armor absorbs a hit. Returns true if armor was available.
func consume_armor() -> bool:
	if _castle_armor <= 0:
		return false
	_castle_armor -= 1
	emit_signal("castle_stats_changed")
	return true

# ── Reset ────────────────────────────────────────────────────────────────────

func reset() -> void:
	_tower_upgrades.clear()
	_unlocked_towers.clear()
	_castle_health_level = 0
	_castle_armor = 0
	_castle_armor_total_purchased = 0
	emit_signal("upgrades_changed")
	emit_signal("castle_stats_changed")
