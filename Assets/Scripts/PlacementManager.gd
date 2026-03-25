extends Node

signal tower_clicked(tower: Node2D)

var _ground_layer: TileMapLayer
var _road_layer: TileMapLayer

var _pending_data: TowerData = null
var _ghost: Node2D = null
var _occupied_cells: Dictionary = {}   # Vector2i → Node2D (tower reference)
var _blocked_positions: Array[Vector2] = []
var _placed_towers: Array[Node2D] = []
var _grid_overlay: Node2D = null

const TOWER_CLICK_RADIUS := 12.0

func _ready() -> void:
	_ground_layer = get_node("../Ground")
	_road_layer = get_node("../Ground/Road")
	_collect_blocked_positions()
	_setup_grid_overlay()

func _collect_blocked_positions() -> void:
	for child in _ground_layer.get_children():
		if child is Sprite2D:
			_blocked_positions.append(child.global_position)

func _setup_grid_overlay() -> void:
	var overlay_script: GDScript = load("res://Assets/Scripts/GridOverlay.gd") as GDScript
	_grid_overlay = Node2D.new()
	_grid_overlay.set_script(overlay_script)
	_ground_layer.add_child(_grid_overlay)
	_grid_overlay.setup(_ground_layer, _road_layer, _occupied_cells, _blocked_positions)
	_grid_overlay.hide_grid()

func register_obstacle(world_pos: Vector2) -> void:
	_blocked_positions.append(world_pos)

func begin_placement(data: TowerData) -> void:
	cancel_placement()
	_pending_data = data
	_create_ghost(data)
	if _grid_overlay:
		_grid_overlay.show_grid()

func cancel_placement() -> void:
	_pending_data = null
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	if _grid_overlay:
		_grid_overlay.hide_grid()

func _create_ghost(data: TowerData) -> void:
	_ghost = data.scene.instantiate()
	var area = _ghost.get_node("Area2D")
	area.monitoring = false
	area.monitorable = false
	_ghost.modulate = Color(1.0, 1.0, 1.0, 0.5)
	get_tree().current_scene.add_child(_ghost)

func _process(_delta: float) -> void:
	if _pending_data == null or _ghost == null:
		return
	var mouse_world = _get_world_mouse_position()
	var snap_pos = _snap_to_tile(mouse_world)
	var offset = _get_sprite_y_offset(_ghost)

	# Check whether the snapped position is actually on the ground tilemap.
	var tile_coords: Vector2i = _ground_layer.local_to_map(_ground_layer.to_local(snap_pos))
	var on_ground: bool = _ground_layer.get_cell_source_id(tile_coords) != -1

	if on_ground:
		_ghost.global_position = snap_pos - Vector2(0, offset)
		_ghost.z_index = _y_to_z(snap_pos.y)
	else:
		# Outside the grid — follow the raw mouse so the ghost stays visible.
		_ghost.global_position = mouse_world - Vector2(0, offset)
		_ghost.z_index = _y_to_z(mouse_world.y)

	_ghost.visible = true
	var valid = on_ground and _is_placement_valid(snap_pos)
	_ghost.modulate = Color(0.2, 1.0, 0.2, 0.5) if valid else Color(1.0, 0.2, 0.2, 0.5)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _pending_data != null:
			# Placing a tower
			var mouse_world = _get_world_mouse_position()
			var snap_pos = _snap_to_tile(mouse_world)
			if _is_placement_valid(snap_pos):
				_place_tower(snap_pos)
			get_viewport().set_input_as_handled()
		else:
			# Check if clicking on an existing tower
			var clicked_tower = _get_tower_at_mouse()
			if clicked_tower != null:
				emit_signal("tower_clicked", clicked_tower)
				get_viewport().set_input_as_handled()

	if _pending_data != null:
		if event is InputEventMouseButton:
			if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
				cancel_placement()
				get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# Uses _input so ESC during placement runs before PauseMenuUI's _unhandled_input.
	if _pending_data != null:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			cancel_placement()
			get_viewport().set_input_as_handled()

func _get_tower_at_mouse() -> Node2D:
	var mouse_world = _get_world_mouse_position()
	var closest_tower: Node2D = null
	var closest_dist := TOWER_CLICK_RADIUS
	for tower in _placed_towers:
		if not is_instance_valid(tower):
			continue
		var dist = mouse_world.distance_to(tower.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_tower = tower
	return closest_tower

func sell_tower(tower: Node2D) -> void:
	if tower == null or not is_instance_valid(tower):
		return
	# Use stored tile coords (tower position is offset from tile center).
	var tile_coords: Vector2i
	if tower.has_meta("tile_coords"):
		tile_coords = tower.get_meta("tile_coords")
	else:
		tile_coords = _ground_layer.local_to_map(
			_ground_layer.to_local(tower.global_position)
		)
	_occupied_cells.erase(tile_coords)
	_placed_towers.erase(tower)
	tower.queue_free()

func _get_world_mouse_position() -> Vector2:
	var viewport = get_viewport()
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_mouse_position()

func _snap_to_tile(world_pos: Vector2) -> Vector2:
	var tile_coords: Vector2i = _ground_layer.local_to_map(_ground_layer.to_local(world_pos))
	return _ground_layer.to_global(_ground_layer.map_to_local(tile_coords))

func _is_placement_valid(snapped_world_pos: Vector2) -> bool:
	var tile_coords: Vector2i = _ground_layer.local_to_map(
		_ground_layer.to_local(snapped_world_pos)
	)

	# Must be on ground
	if _ground_layer.get_cell_source_id(tile_coords) == -1:
		return false

	# Must not be on road
	if _road_layer.get_cell_source_id(tile_coords) != -1:
		return false

	# Must not overlap another tower
	if _occupied_cells.has(tile_coords):
		return false

	# Must not be on obstacles
	for blocked_pos in _blocked_positions:
		if snapped_world_pos.distance_to(blocked_pos) < 10.0:
			return false

	return true

func _place_tower(snapped_world_pos: Vector2) -> void:
	var tower_name: String = _pending_data.tower_name
	var scaled_cost: int = GameManager.get_scaled_cost(_pending_data.cost, tower_name)
	if not GameManager.spend_gold(scaled_cost):
		cancel_placement()
		return

	GameManager.record_tower_placed(tower_name, scaled_cost)

	var tile_coords: Vector2i = _ground_layer.local_to_map(
		_ground_layer.to_local(snapped_world_pos)
	)

	var tower = _pending_data.scene.instantiate()
	get_tree().current_scene.add_child(tower)
	var offset = _get_sprite_y_offset(tower)
	tower.global_position = snapped_world_pos - Vector2(0, offset)
	# Towers lower on screen (higher Y) draw on top of towers above them.
	tower.z_index = _y_to_z(snapped_world_pos.y)
	tower.initialize(_pending_data)

	# Store tile coords and actual paid cost for sell refunds.
	tower.set_meta("tile_coords", tile_coords)
	tower.set_meta("paid_cost", scaled_cost)
	_occupied_cells[tile_coords] = tower
	_placed_towers.append(tower)

	cancel_placement()

# ── Sprite-bottom alignment helpers ──────────────────────────────────────────

# Returns the upward shift so the sprite's bottom edge aligns with the
# bottom edge of the tile cell (snap_to_tile returns the tile centre).
func _get_sprite_y_offset(tower_instance: Node2D) -> float:
	var sprite: Sprite2D = _find_sprite(tower_instance)
	if sprite and sprite.texture:
		var half_sprite: float = sprite.texture.get_height() / 2.0
		var half_tile: float = _ground_layer.tile_set.tile_size.y / 2.0
		return half_sprite - half_tile
	return 0.0

func _find_sprite(node: Node) -> Sprite2D:
	for child in node.get_children():
		if child is Sprite2D:
			return child
		var found: Sprite2D = _find_sprite(child)
		if found:
			return found
	return null

## Convert a world-Y position to a z_index that is always above the
## ground tilemap (z_index 0) while preserving relative ordering.
func _y_to_z(y: float) -> int:
	return 1000 + int(y)
