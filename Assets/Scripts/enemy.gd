# enemy.gd
extends Area2D

@export var speed: float = 60.0
@export var health: float = 40.0
@export var damage: int = 1
@export var reward: int = 10

var _path_follow: PathFollow2D = null
var _max_health: float = 40.0

# ── Health bar ────────────────────────────────────────────────────────────────
var _health_bar_bg: ColorRect = null
var _health_bar_fill: ColorRect = null
const HEALTH_BAR_WIDTH: float = 14.0
const HEALTH_BAR_HEIGHT: float = 2.0
const HEALTH_BAR_OFFSET_Y: float = -8.0

# ── Status-effect state ───────────────────────────────────────────────────────
# Slow:   _base_speed = -1 means not currently slowed (sentinel value).
#         When a slow is applied we cache the original speed and reduce it.
var _base_speed: float = -1.0
var _slow_timer: float = 0.0

# Poison: damage-per-second applied each frame while _poison_timer > 0.
var _poison_dps: float = 0.0
var _poison_timer: float = 0.0

# Persistent status aura FX (children of this enemy)
var _poison_aura: StatusAura = null
var _ice_aura: StatusAura = null

func _ready():
	add_to_group("enemies")
	_create_health_bar()

# Called by WaveManager right after instantiation.
func initialize(data: EnemyData) -> void:
	speed = data.speed
	health = data.health
	_max_health = data.health
	damage = data.damage
	reward = data.reward

func _create_health_bar() -> void:
	_health_bar_bg = ColorRect.new()
	_health_bar_bg.color = Color(0.15, 0.15, 0.15, 0.8)
	_health_bar_bg.size = Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
	_health_bar_bg.position = Vector2(-HEALTH_BAR_WIDTH / 2.0, HEALTH_BAR_OFFSET_Y)
	_health_bar_bg.z_index = 1
	add_child(_health_bar_bg)

	_health_bar_fill = ColorRect.new()
	_health_bar_fill.color = Color(0.2, 0.9, 0.2, 0.9)
	_health_bar_fill.size = Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
	_health_bar_fill.position = Vector2(-HEALTH_BAR_WIDTH / 2.0, HEALTH_BAR_OFFSET_Y)
	_health_bar_fill.z_index = 2
	add_child(_health_bar_fill)

func _update_health_bar() -> void:
	if _health_bar_fill == null:
		return
	var ratio: float = clamp(health / _max_health, 0.0, 1.0)
	_health_bar_fill.size.x = HEALTH_BAR_WIDTH * ratio
	# Color: green → yellow → red
	if ratio > 0.5:
		_health_bar_fill.color = Color(0.2, 0.9, 0.2, 0.9)
	elif ratio > 0.25:
		_health_bar_fill.color = Color(0.9, 0.9, 0.2, 0.9)
	else:
		_health_bar_fill.color = Color(0.9, 0.2, 0.2, 0.9)

func _process(delta: float) -> void:
	# ── Tick slow ────────────────────────────────────────────────────────────
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			# Restore original speed when the slow expires.
			if _base_speed >= 0.0:
				speed = _base_speed
			_base_speed = -1.0
			# Remove ice aura
			if _ice_aura != null:
				_ice_aura.queue_free()
				_ice_aura = null

	# ── Tick poison ──────────────────────────────────────────────────────────
	if _poison_timer > 0.0:
		_poison_timer -= delta
		var poison_dmg := _poison_dps * delta
		var actual_poison: float = min(poison_dmg, health)
		GameManager.record_damage(actual_poison)
		health -= poison_dmg
		_update_health_bar()
		if health <= 0:
			var sfx2 := get_node_or_null("/root/SFXManager")
			if sfx2:
				sfx2.play("enemy_death", -3.0)
			PixelFX.spawn_death(get_tree(), global_position)
			die()
			return
		if _poison_timer <= 0.0:
			# Remove poison aura
			_poison_dps = 0.0
			if _poison_aura != null:
				_poison_aura.queue_free()
				_poison_aura = null

	# ── Y-based depth sorting (matches decoration z_index formula) ───────────
	z_index = 1000 + int(global_position.y)

	# ── Path movement ────────────────────────────────────────────────────────
	if _path_follow == null:
		_path_follow = get_parent() as PathFollow2D
		return
	_path_follow.progress += speed * delta
	if _path_follow.progress_ratio >= 1.0:
		reach_end()

func take_damage(amount: float) -> void:
	if health <= 0:
		return  # already dead, avoid double-death/gold
	var actual: float = min(amount, health)
	GameManager.record_damage(actual)
	health -= amount
	_update_health_bar()
	# Flash red/white on hit
	_flash_hit()
	var sfx := get_node_or_null("/root/SFXManager")
	if health <= 0:
		if sfx:
			sfx.play("enemy_death", -3.0)
		PixelFX.spawn_death(get_tree(), global_position)
		die()
	else:
		if sfx:
			sfx.play("enemy_hit", -6.0)

# ── Hit flash ────────────────────────────────────────────────────────────────
var _flash_tween: Tween = null

func _flash_hit() -> void:
	# Kill any previous flash so they don't stack
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	# Flash white then red then back to normal
	modulate = Color(3.0, 3.0, 3.0, 1.0)  # bright white flash
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color(2.0, 0.4, 0.4, 1.0), 0.05)
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.1)

# ── Status effects ────────────────────────────────────────────────────────────

# Slow the enemy to `factor` × its current base speed for `duration` seconds.
# Re-applying a slow refreshes the timer but never stacks below the slowest
# factor (we always use the most recent call's factor to keep logic simple).
func apply_slow(factor: float, duration: float) -> void:
	if _base_speed < 0.0:
		_base_speed = speed
	else:
		speed = _base_speed
	speed = _base_speed * factor
	_slow_timer = duration
	# Create ice aura if not already present
	if _ice_aura == null:
		_ice_aura = StatusAura.create_ice(self)

# Poison the enemy for `dps` damage per second over `duration` seconds.
# Multiple poison applications take the highest DPS and longest duration.
func apply_poison(dps: float, duration: float) -> void:
	_poison_dps   = max(_poison_dps, dps)
	_poison_timer = max(_poison_timer, duration)
	_flash_hit()
	# Create poison aura if not already present
	if _poison_aura == null:
		_poison_aura = StatusAura.create_poison(self)

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
