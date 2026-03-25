# enemy.gd
extends Area2D

@export var speed: float = 60.0
@export var health: float = 40.0
@export var damage: int = 1
@export var reward: int = 10

var _path_follow: PathFollow2D = null

# ── Status-effect state ───────────────────────────────────────────────────────
# Slow:   _base_speed = -1 means not currently slowed (sentinel value).
#         When a slow is applied we cache the original speed and reduce it.
var _base_speed: float = -1.0
var _slow_timer: float = 0.0

# Poison: damage-per-second applied each frame while _poison_timer > 0.
var _poison_dps: float = 0.0
var _poison_timer: float = 0.0

func _ready():
	add_to_group("enemies")

# Called by WaveManager right after instantiation.
func initialize(data: EnemyData) -> void:
	speed = data.speed
	health = data.health
	damage = data.damage
	reward = data.reward

func _process(delta: float) -> void:
	# ── Tick slow ────────────────────────────────────────────────────────────
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			# Restore original speed when the slow expires.
			if _base_speed >= 0.0:
				speed = _base_speed
			_base_speed = -1.0

	# ── Tick poison ──────────────────────────────────────────────────────────
	if _poison_timer > 0.0:
		_poison_timer -= delta
		var poison_dmg := _poison_dps * delta
		var actual_poison: float = min(poison_dmg, health)
		GameManager.record_damage(actual_poison)
		health -= poison_dmg
		if health <= 0:
			die()
			return

	# ── Path movement ────────────────────────────────────────────────────────
	if _path_follow == null:
		_path_follow = get_parent() as PathFollow2D
		return
	_path_follow.progress += speed * delta
	if _path_follow.progress_ratio >= 1.0:
		reach_end()

func take_damage(amount: float) -> void:
	var actual: float = min(amount, health)
	GameManager.record_damage(actual)
	health -= amount
	if health <= 0:
		die()

# ── Status effects ────────────────────────────────────────────────────────────

# Slow the enemy to `factor` × its current base speed for `duration` seconds.
# Re-applying a slow refreshes the timer but never stacks below the slowest
# factor (we always use the most recent call's factor to keep logic simple).
func apply_slow(factor: float, duration: float) -> void:
	if _base_speed < 0.0:
		# First slow — cache the current (un-slowed) speed.
		_base_speed = speed
	else:
		# Already slowed — restore to base before re-applying so we don't
		# compound multiple slow factors together.
		speed = _base_speed
	speed = _base_speed * factor
	_slow_timer = duration

# Poison the enemy for `dps` damage per second over `duration` seconds.
# Multiple poison applications take the highest DPS and longest duration.
func apply_poison(dps: float, duration: float) -> void:
	_poison_dps   = max(_poison_dps, dps)
	_poison_timer = max(_poison_timer, duration)

# ── Death / end-of-path ───────────────────────────────────────────────────────

func die() -> void:
	GameManager.add_gold(reward)
	var parent = get_parent()
	if parent is PathFollow2D:
		parent.queue_free()
	else:
		queue_free()

func reach_end() -> void:
	_path_follow.queue_free()
