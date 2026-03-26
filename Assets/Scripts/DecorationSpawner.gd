# DecorationSpawner.gd
# Randomly places decorations (trees, rocks, mushrooms) on valid ground tiles
# at runtime. Decorations act as obstacles that block tower placement and can
# be clicked to open a removal UI.
extends Node

## How many decorations to spawn.
@export var decoration_count: int = 200

## Minimum distance between any two decorations (in pixels).
const MIN_SPACING: float = 10.0
## Minimum distance from the path curve (in pixels).
## Kept small so decorations can line the edges of roads.
const MIN_PATH_DISTANCE: float = 10.0
## Minimum distance from the castle and castle towers (in pixels).
const MIN_CASTLE_DISTANCE: float = 28.0

const CLICK_RADIUS: float = 10.0

# Decoration prefab paths grouped by type
# Trees are filtered per-biome at runtime via _active_tree_scenes
const ALL_TREE_SCENES: Dictionary = {
	"spring": [
		"res://Assets/Prefabs/Decorations/spr_tree_01_normal.tscn",
	],
	"autumn": [
		"res://Assets/Prefabs/Decorations/spr_tree_01_autumn.tscn",
		"res://Assets/Prefabs/Decorations/spr_tree_02_autumn.tscn",
	],
	"cherry_blossom": [
		"res://Assets/Prefabs/Decorations/spr_tree_01_cherry_blossom.tscn",
	],
	"spruce": [
		"res://Assets/Prefabs/Decorations/spr_tree_02_spruce.tscn",
	],
	"default": [
		"res://Assets/Prefabs/Decorations/spr_tree_01_normal.tscn",
		"res://Assets/Prefabs/Decorations/spr_tree_01_autumn.tscn",
		"res://Assets/Prefabs/Decorations/spr_tree_01_cherry_blossom.tscn",
		"res://Assets/Prefabs/Decorations/spr_tree_02_normal.tscn",
		"res://Assets/Prefabs/Decorations/spr_tree_02_autumn.tscn",
		"res://Assets/Prefabs/Decorations/spr_tree_02_spruce.tscn",
	],
}
const ROCK_SCENES: Array[String] = [
	"res://Assets/Prefabs/Decorations/spr_rock_01.tscn",
	"res://Assets/Prefabs/Decorations/spr_rock_02.tscn",
	"res://Assets/Prefabs/Decorations/spr_rock_03.tscn",
]
const MUSHROOM_SCENES: Array[String] = [
	"res://Assets/Prefabs/Decorations/spr_mushroom_01.tscn",
	"res://Assets/Prefabs/Decorations/spr_mushroom_02.tscn",
]

var _active_tree_scenes: Array[String] = []

# Removal cost per decoration type
const TREE_COST: int = 75
const ROCK_COST: int = 120
const MUSHROOM_COST: int = 40

var _ground_layer: TileMapLayer = null
var _road_layer: TileMapLayer = null
var _path_curve: Curve2D = null
var _castle_positions: Array[Vector2] = []
var _spawned: Array[Node2D] = []
var _loaded_scenes: Dictionary = {}

func setup(ground: TileMapLayer, road: TileMapLayer, path2d: Path2D, castle_positions: Array[Vector2], biome: String = "default") -> void:
	_ground_layer = ground
	_road_layer = road
	if path2d:
		_path_curve = path2d.curve
	_castle_positions = castle_positions
	# Pick tree variants based on biome
	if ALL_TREE_SCENES.has(biome):
		for s in ALL_TREE_SCENES[biome]:
			_active_tree_scenes.append(s)
	else:
		for s in ALL_TREE_SCENES["default"]:
			_active_tree_scenes.append(s)
	_spawn_decorations()

func _spawn_decorations() -> void:
	# Preload all scenes
	var all_scenes: Array[String] = []
	all_scenes.append_array(_active_tree_scenes)
	all_scenes.append_array(ROCK_SCENES)
	all_scenes.append_array(MUSHROOM_SCENES)
	for path in all_scenes:
		if not _loaded_scenes.has(path):
			_loaded_scenes[path] = load(path)

	# Collect valid positions using shared helper
	var valid_positions: Array[Vector2] = _collect_valid_positions()
	valid_positions.shuffle()
	var chosen: Array[Vector2] = []
	for pos in valid_positions:
		if chosen.size() >= decoration_count:
			break
		var too_close: bool = false
		for existing in chosen:
			if pos.distance_to(existing) < MIN_SPACING:
				too_close = true
				break
		if not too_close:
			chosen.append(pos)

	# Spawn decorations at chosen positions
	for pos in chosen:
		var scene_path: String = _pick_random_scene()
		var scene: PackedScene = _loaded_scenes[scene_path]
		var instance: Node2D = scene.instantiate()
		instance.global_position = pos
		# Determine y-based z_index so decorations layer correctly
		instance.z_index = 1000 + int(pos.y)
		# Tag with metadata for the removal UI
		instance.set_meta("decoration_type", _get_type_from_path(scene_path))
		instance.set_meta("removal_cost", _get_cost_from_path(scene_path))
		instance.set_meta("decoration_name", _get_name_from_path(scene_path))
		_ground_layer.add_child(instance)
		_spawned.append(instance)

func _is_near_path(world_pos: Vector2) -> bool:
	if _path_curve == null or _path_curve.point_count < 2:
		return false
	# Sample along the curve and check distance
	var length: float = _path_curve.get_baked_length()
	var steps: int = int(length / 8.0)
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		# get_baked_points gives local coords relative to Path2D
		var curve_pos: Vector2 = _path_curve.sample_baked(t * length)
		# Path2D is at origin in scene.tscn, so curve_pos is already world
		if world_pos.distance_to(curve_pos) < MIN_PATH_DISTANCE:
			return true
	return false

func _pick_random_scene() -> String:
	# Weighted random: 45% trees, 30% rocks, 25% mushrooms
	var roll: float = randf()
	if roll < 0.45:
		return _active_tree_scenes[randi() % _active_tree_scenes.size()]
	elif roll < 0.75:
		return ROCK_SCENES[randi() % ROCK_SCENES.size()]
	else:
		return MUSHROOM_SCENES[randi() % MUSHROOM_SCENES.size()]

func _get_type_from_path(path: String) -> String:
	if "tree" in path:
		return "tree"
	elif "rock" in path:
		return "rock"
	else:
		return "mushroom"

func _get_name_from_path(path: String) -> String:
	if "tree" in path:
		return "Tree"
	elif "rock" in path:
		return "Rock"
	else:
		return "Mushroom"

func _get_cost_from_path(path: String) -> int:
	if "tree" in path:
		return TREE_COST
	elif "rock" in path:
		return ROCK_COST
	else:
		return MUSHROOM_COST

# ── Click detection ──────────────────────────────────────────────────────────

func get_decoration_at(world_pos: Vector2) -> Node2D:
	var closest: Node2D = null
	var closest_dist: float = CLICK_RADIUS
	for deco in _spawned:
		if not is_instance_valid(deco):
			continue
		var dist: float = world_pos.distance_to(deco.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = deco
	return closest

func remove_decoration(deco: Node2D) -> void:
	if deco == null or not is_instance_valid(deco):
		return
	_spawned.erase(deco)
	# Don't queue_free here — SceneRoot plays an animation first, then frees it

func get_all_decorations() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for deco in _spawned:
		if is_instance_valid(deco):
			result.append(deco)
	return result

func get_spawned_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for deco in _spawned:
		if is_instance_valid(deco):
			positions.append(deco.global_position)
	return positions

# ── Wave regrowth ───────────────────────────────────────────────────────────
## Maximum decorations the map can support. Regrowth stops when this is reached.
const MAX_DECORATIONS: int = 300
## Base number of new decorations per wave (before density scaling).
const WAVE_GROWTH_BASE: int = 15

## Called at the end of each wave. Spawns new decorations scaled by how empty
## the map is — lots of room means more growth, a packed map means almost none.
## Returns the positions of newly spawned decorations (so SceneRoot can register
## them as obstacles).
func spawn_wave_growth() -> Array[Vector2]:
	# Purge any freed references
	_spawned = _spawned.filter(func(d: Node2D) -> bool: return is_instance_valid(d))

	var current: int = _spawned.size()
	if current >= MAX_DECORATIONS:
		return []

	# Density ratio: 1.0 when empty, 0.0 when at capacity
	var room: float = 1.0 - clampf(float(current) / float(MAX_DECORATIONS), 0.0, 1.0)
	# Scale the base growth by how much room is left (minimum 2 if any room)
	var target: int = max(2, int(WAVE_GROWTH_BASE * room))
	# Never exceed the cap
	target = mini(target, MAX_DECORATIONS - current)

	# Collect valid positions (same rules as initial spawn)
	var valid_positions: Array[Vector2] = _collect_valid_positions()
	valid_positions.shuffle()

	# Gather existing positions for spacing checks
	var existing_positions: Array[Vector2] = []
	for deco in _spawned:
		existing_positions.append(deco.global_position)

	var new_positions: Array[Vector2] = []
	for pos in valid_positions:
		if new_positions.size() >= target:
			break
		# Check spacing against all existing + newly chosen positions
		var too_close: bool = false
		for ep in existing_positions:
			if pos.distance_to(ep) < MIN_SPACING:
				too_close = true
				break
		if too_close:
			continue
		for np in new_positions:
			if pos.distance_to(np) < MIN_SPACING:
				too_close = true
				break
		if too_close:
			continue
		new_positions.append(pos)
		# Also add to existing so subsequent checks see it
		existing_positions.append(pos)

	# Bail out if the scene tree is being torn down (e.g. returning to main menu)
	if not is_inside_tree() or not _ground_layer.is_inside_tree():
		return []

	# Play a single growth sound for the batch
	if new_positions.size() > 0:
		var sfx: Node = get_tree().root.get_node_or_null("SFXManager")
		if sfx:
			sfx.play("nature_grow")

	# Spawn at each chosen position with staggered grow-in animation
	for i in range(new_positions.size()):
		var pos: Vector2 = new_positions[i]
		var scene_path: String = _pick_random_scene()
		var scene: PackedScene = _loaded_scenes[scene_path]
		var instance: Node2D = scene.instantiate()
		instance.global_position = pos
		instance.z_index = 1000 + int(pos.y)
		instance.set_meta("decoration_type", _get_type_from_path(scene_path))
		instance.set_meta("removal_cost", _get_cost_from_path(scene_path))
		instance.set_meta("decoration_name", _get_name_from_path(scene_path))
		# Start invisible and tiny
		instance.modulate.a = 0.0
		instance.scale = Vector2(0.0, 0.0)
		_ground_layer.add_child(instance)
		_spawned.append(instance)
		# Stagger the grow-in so they don't all pop at once
		var delay: float = float(i) * 0.08
		var tween: Tween = instance.create_tween()
		tween.set_parallel(true)
		# Fade in
		tween.tween_property(instance, "modulate:a", 1.0, 0.4).set_delay(delay)
		# Scale up with a slight overshoot bounce
		tween.tween_property(instance, "scale", Vector2(1.1, 1.1), 0.3).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.chain().tween_property(instance, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_IN_OUT)
		# Spawn particle FX at each position
		if instance.is_inside_tree():
			PixelFX.spawn_nature_grow(instance.get_tree(), pos)

	return new_positions

## Collects all valid ground positions (not road, not near castle, not on path).
## Shared logic between initial spawn and wave regrowth.
func _collect_valid_positions() -> Array[Vector2]:
	var valid: Array[Vector2] = []
	var used_cells: Array[Vector2i] = _ground_layer.get_used_cells()
	for cell in used_cells:
		if _road_layer.get_cell_source_id(cell) != -1:
			continue
		var world_pos: Vector2 = _ground_layer.to_global(_ground_layer.map_to_local(cell))
		var near_castle: bool = false
		for castle_pos in _castle_positions:
			if world_pos.distance_to(castle_pos) < MIN_CASTLE_DISTANCE:
				near_castle = true
				break
		if near_castle:
			continue
		if _is_near_path(world_pos):
			continue
		valid.append(world_pos)
	return valid
