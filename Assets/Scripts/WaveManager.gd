# WaveManager.gd
extends Node

signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)

# ── Enemy data for procedural generation ─────────────────────────────────────
const SLIME      := preload("res://Resource/Enemy/Slime.tres")
const BAT        := preload("res://Resource/Enemy/Bat.tres")
const SKELETON   := preload("res://Resource/Enemy/Skeleton.tres")
const ZOMBIE     := preload("res://Resource/Enemy/Zombie.tres")
const GOBLIN     := preload("res://Resource/Enemy/Goblin.tres")
const BIG_SLIME  := preload("res://Resource/Enemy/BigSlime.tres")
const GHOST      := preload("res://Resource/Enemy/Ghost.tres")
const DEMON      := preload("res://Resource/Enemy/Demon.tres")
const KING_SLIME := preload("res://Resource/Enemy/KingSlime.tres")

# Hand-crafted waves set in the Inspector (waves 1–7).
# Any wave beyond this array is generated procedurally.
@export var waves: Array[WaveData] = []

var _path: Path2D
var _current_wave_number: int = 0   # 1-based; 0 means not started yet
var _enemies_alive: int = 0
var _is_spawning: bool = false

func _ready() -> void:
	_path = get_parent() as Path2D
	# Wave 1 is now triggered by SceneRoot after the opening countdown.

# ── Public API ────────────────────────────────────────────────────────────────

func start_next_wave() -> void:
	_current_wave_number += 1
	var wave: WaveData = _get_wave(_current_wave_number)
	print("Starting wave ", _current_wave_number)
	emit_signal("wave_started", _current_wave_number)
	_is_spawning = true
	await _run_wave(wave)
	_is_spawning = false
	_check_wave_complete()

# Called by WaveClearUI after the player presses "Next Wave".
func proceed_to_next_wave() -> void:
	start_next_wave()

# ── Wave retrieval / generation ───────────────────────────────────────────────

func _get_wave(n: int) -> WaveData:
	if n >= 1 and n <= waves.size():
		return waves[n - 1]
	return _generate_wave(n)

func _generate_wave(n: int) -> WaveData:
	var wave := WaveData.new()
	wave.wave_number = n

	# Each procedural wave past the last static wave is one step harder.
	var excess: int = max(0, n - waves.size())

	# Shrink the pause between batches as waves increase (min 0.5 s).
	wave.time_between_batches = max(0.5, 2.0 - excess * 0.1)

	# ── Scaling ──────────────────────────────────────────────────────────────
	# Health grows linearly — no cap, enemies always get tougher.
	#   Wave  8 → ×1.10  |  Wave 15 → ×1.80  |  Wave 25 → ×2.80
	wave.health_scale = 1.0 + excess * 0.10

	# Movement speed grows 4 % per wave, hard-capped at 2× base speed.
	# (Prevents Ghost / Demon from becoming physically impossible to hit.)
	#   Wave  8 → ×1.04  |  Wave 20 → ×1.52  |  Wave 33+ → ×2.00 (cap)
	wave.speed_scale = min(2.0, 1.0 + excess * 0.04)

	wave.entries = _build_entries(n, excess)
	return wave

func _build_entries(n: int, excess: int) -> Array[WaveEntry]:
	var entries: Array[WaveEntry] = []

	# Full regular-enemy pool — all non-boss types available in procedural waves.
	var pool: Array = [SLIME, BAT, SKELETON, ZOMBIE, GOBLIN, BIG_SLIME, GHOST, DEMON]
	pool.shuffle()

	# Alternate 2 and 3 enemy types to keep waves varied without being purely random.
	var num_types: int = min(pool.size(), 2 + (excess % 2))

	# Spawn count and interval scale with wave number.
	var count: int    = min(30, 8 + int(excess * 1.5))
	var interval: float = max(0.4, 1.5 - excess * 0.04)

	for i in range(num_types):
		var entry := WaveEntry.new()
		entry.enemy_data = pool[i]
		entry.count = count
		entry.spawn_interval = interval
		entries.append(entry)

	# Boss wave: every 5th wave number (10, 15, 20, …).
	# Boss count grows by 1 for every 10 additional waves.
	if n % 5 == 0:
		var boss := WaveEntry.new()
		boss.enemy_data = KING_SLIME
		boss.count = 1 + int(float(excess) / 10.0)
		boss.spawn_interval = 5.0
		entries.append(boss)

	return entries

# ── Spawning ──────────────────────────────────────────────────────────────────

func _run_wave(wave: WaveData) -> void:
	for i in range(wave.entries.size()):
		await _spawn_batch(wave.entries[i], wave.health_scale, wave.speed_scale)
		if i < wave.entries.size() - 1:
			await get_tree().create_timer(wave.time_between_batches).timeout

func _spawn_batch(entry: WaveEntry, health_scale: float = 1.0, speed_scale: float = 1.0) -> void:
	for i in range(entry.count):
		_spawn_enemy(entry.enemy_data, health_scale, speed_scale)
		await get_tree().create_timer(entry.spawn_interval).timeout

func _spawn_enemy(data: EnemyData, health_scale: float = 1.0, speed_scale: float = 1.0) -> void:
	if data == null or data.scene == null:
		push_error("WaveManager: EnemyData or its scene is null!")
		return
	var path_follow := PathFollow2D.new()
	path_follow.loop = false
	path_follow.rotates = false
	_path.add_child(path_follow)
	var enemy = data.scene.instantiate()
	path_follow.add_child(enemy)
	enemy.initialize(data)
	# Apply per-wave scaling on top of the base stats from EnemyData.
	# speed_scale is already capped at 2.0 in _generate_wave().
	enemy.health *= health_scale
	enemy.speed  *= speed_scale
	_enemies_alive += 1
	enemy.tree_exited.connect(_on_enemy_removed)

# ── Wave completion ───────────────────────────────────────────────────────────

func _on_enemy_removed() -> void:
	_enemies_alive -= 1
	_check_wave_complete()

func _check_wave_complete() -> void:
	if _is_spawning or _enemies_alive > 0:
		return
	print("Wave ", _current_wave_number, " complete!")
	GameManager.record_wave_completed()
	emit_signal("wave_completed", _current_wave_number)
	# The game never ends — WaveClearUI calls proceed_to_next_wave() when ready.
