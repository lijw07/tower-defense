extends Node2D
## Draws a tile-aligned grid over the ground when tower placement is active.
## Added as a child of the Ground TileMapLayer by PlacementManager.

var _ground_layer: TileMapLayer
var _road_layer: TileMapLayer
var _occupied_cells: Dictionary   # reference to PlacementManager's dict
var _blocked_positions: Array[Vector2]

const GRID_COLOR      := Color(1.0, 1.0, 1.0, 0.12)
const VALID_COLOR     := Color(0.2, 0.9, 0.3, 0.08)
const INVALID_COLOR   := Color(0.9, 0.2, 0.2, 0.06)
const LINE_WIDTH      := 1.0

var _active := false

func setup(ground: TileMapLayer, road: TileMapLayer, occupied: Dictionary, blocked: Array[Vector2]) -> void:
	_ground_layer = ground
	_road_layer = road
	_occupied_cells = occupied
	_blocked_positions = blocked

func show_grid() -> void:
	_active = true
	visible = true
	queue_redraw()

func hide_grid() -> void:
	_active = false
	visible = false

func _process(_delta: float) -> void:
	if _active:
		queue_redraw()

func _draw() -> void:
	if not _active or _ground_layer == null:
		return

	var tile_set: TileSet = _ground_layer.tile_set
	if tile_set == null:
		return
	var tile_size: Vector2i = tile_set.tile_size  # 16×16
	var ts := Vector2(tile_size)

	# Get all ground cells
	var ground_cells: Array[Vector2i] = _ground_layer.get_used_cells()

	for cell in ground_cells:
		# Convert tile coordinate to local position (top-left corner of tile)
		var local_center: Vector2 = _ground_layer.map_to_local(cell)
		var rect_origin: Vector2 = local_center - ts / 2.0
		var rect := Rect2(rect_origin, ts)

		# Determine if this cell is valid for placement
		var is_valid := _is_cell_valid(cell, local_center)

		# Draw tinted fill
		if is_valid:
			draw_rect(rect, VALID_COLOR, true)
		else:
			draw_rect(rect, INVALID_COLOR, true)

		# Draw grid lines (outline)
		draw_rect(rect, GRID_COLOR, false, LINE_WIDTH)

func _is_cell_valid(cell: Vector2i, local_center: Vector2) -> bool:
	# On road?
	if _road_layer.get_cell_source_id(cell) != -1:
		return false
	# Already occupied?
	if _occupied_cells.has(cell):
		return false
	# On a blocked obstacle?
	var world_pos: Vector2 = _ground_layer.to_global(local_center)
	for blocked_pos in _blocked_positions:
		if world_pos.distance_to(blocked_pos) < 10.0:
			return false
	return true
