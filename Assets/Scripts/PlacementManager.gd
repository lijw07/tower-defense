extends Node

signal tower_clicked(tower: Node2D)
signal decoration_clicked(decoration: Node2D)
signal placement_ended

var _ground_layer: TileMapLayer
var _road_layer: TileMapLayer

var _pending_data: TowerData = null
var _ghost: Node2D = null
var _occupied_cells: Dictionary = {}   # Vector2i → Node2D (tower reference)
var _blocked_positions: Array[Vector2] = []
var _placed_towers: Array[Node2D] = []
var _grid_overlay: Node2D = null
var _range_indicator: Node2D = null
var _decoration_spawner: Node = null

const TOWER_CLICK_RADIUS := 12.0

func _ready() -> void:
	_ground_layer = get_node("../SpringBiomeMap")
	_road_layer = get_node("../SpringBiomeMap/Road")
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

func remove_obstacle(world_pos: Vector2) -> void:
	for i in range(_blocked_positions.size() - 1, -1, -1):
		if _blocked_positions[i].distance_to(world_pos) < 10.0:
			_blocked_positions.remove_at(i)
			break

func begin_placement(data: TowerData) -> void:
	cancel_placement()
	_pending_data = data
	_create_ghost(data)
	if _grid_overlay:
		_grid_overlay.show_grid()

func cancel_placement() -> void:
	var was_placing: bool = _pending_data != null
	_pending_data = null
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	if _range_indicator != null:
		_range_indicator.queue_free()
		_range_indicator = null
	if _grid_overlay:
		_grid_overlay.hide_grid()
	if was_placing:
		emit_signal("placement_ended")

func _create_ghost(data: TowerData) -> void:
	_ghost = data.scene.instantiate()
	var area = _ghost.get_node("Area2D")
	area.monitoring = false
	area.monitorable = false
	_ghost.modulate = Color(1.0, 1.0, 1.0, 0.5)
	get_tree().current_scene.add_child(_ghost)

	# Create range indicator circle
	var radius: float = get_tower_range_cached(data)
	if radius > 0.0:
		var ri_script: GDScript = load("res://Assets/Scripts/RangeIndicator.gd") as GDScript
		_range_indicator = Node2D.new()
		_range_indicator.set_script(ri_script)
		_range_indicator.z_index = 999
		get_tree().current_scene.add_child(_range_indicator)
		_range_indicator.set_radius(radius)
		_range_indicator.set_color(
			Color(0.3, 0.9, 1.0, 0.4),
			Color(0.3, 0.9, 1.0, 0.07)
		)

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

	# Move range indicator to match ghost (tower origin = Area2D center)
	if _range_indicator != null:
		_range_indicator.global_position = _ghost.global_position
		if valid:
			_range_indicator.set_color(Color(0.3, 0.9, 1.0, 0.4), Color(0.3, 0.9, 1.0, 0.07))
		else:
			_range_indicator.set_color(Color(1.0, 0.3, 0.3, 0.35), Color(1.0, 0.3, 0.3, 0.05))

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
			var clicked_deco = _get_decoration_at_mouse()
			if clicked_tower != null:
				# If the tower is currently transparent (occlusion shader active)
				# AND there's a decoration behind it, let the click pass through
				# to the decoration instead.
				if clicked_deco != null and clicked_tower.has_meta("_occ_active"):
					emit_signal("decoration_clicked", clicked_deco)
					get_viewport().set_input_as_handled()
				else:
					emit_signal("tower_clicked", clicked_tower)
					get_viewport().set_input_as_handled()
			elif clicked_deco != null:
				emit_signal("decoration_clicked", clicked_deco)
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

func set_decoration_spawner(spawner: Node) -> void:
	_decoration_spawner = spawner

func _get_decoration_at_mouse() -> Node2D:
	if _decoration_spawner == null:
		return null
	var mouse_world = _get_world_mouse_position()
	return _decoration_spawner.get_decoration_at(mouse_world)

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
	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("tower_destroy")
	# ── Destruction FX: debris particles + crumble animation ──
	var destroy_pos: Vector2 = tower.global_position
	PixelFX.spawn_tower_destroy(get_tree(), destroy_pos)
	# Disable the tower's Area2D so it stops attacking during animation
	var area: Area2D = tower.get_node_or_null("Area2D")
	if area:
		area.monitoring = false
		area.monitorable = false
	# Animated destruction: shake → crumble down → fade out
	var origin: Vector2 = tower.position
	var shake_tw: Tween = tower.create_tween()
	# Quick violent shake
	shake_tw.tween_property(tower, "position", origin + Vector2(3, -1), 0.03)
	shake_tw.tween_property(tower, "position", origin + Vector2(-4, 2), 0.03)
	shake_tw.tween_property(tower, "position", origin + Vector2(2, -2), 0.03)
	shake_tw.tween_property(tower, "position", origin + Vector2(-1, 1), 0.03)
	shake_tw.tween_property(tower, "position", origin, 0.02)
	# Then crumble — squash vertically and sink into ground
	shake_tw.tween_callback(func() -> void:
		if not is_instance_valid(tower):
			return
		var crumble: Tween = tower.create_tween()
		crumble.set_parallel(true)
		crumble.tween_property(tower, "scale", Vector2(1.4, 0.0), 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		crumble.tween_property(tower, "position", origin + Vector2(0, 10), 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		crumble.tween_property(tower, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
		crumble.chain().tween_callback(tower.queue_free)
	)

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

	# Must be within the camera's visible area
	var cam := get_viewport().get_camera_2d()
	if cam:
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		var half_view: Vector2 = vp_size / (2.0 * cam.zoom)
		var cam_rect := Rect2(cam.global_position - half_view, half_view * 2.0)
		if not cam_rect.has_point(snapped_world_pos):
			return false

	return true

func _place_tower(snapped_world_pos: Vector2) -> void:
	var tower_name: String = _pending_data.tower_name
	var scaled_cost: int = GameManager.get_scaled_cost(_pending_data.cost, tower_name)
	if not GameManager.spend_gold(scaled_cost):
		cancel_placement()
		return

	GameManager.record_tower_placed(tower_name, scaled_cost)
	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx:
		# Play tower-specific placement sound; fall back to generic if not found
		var place_key: String = "place_" + tower_name.to_lower().replace(" ", "_")
		if sfx._sounds.has(place_key):
			sfx.play(place_key)
		else:
			sfx.play("tower_place")

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

	# ── Placement FX: smoke + slam animation + camera vibration ──
	PixelFX.spawn_tower_place(get_tree(), snapped_world_pos)
	# Slam-down animation — tower drops in from above and bounces
	tower.scale = Vector2(1.3, 0.6)
	var slam_tw: Tween = tower.create_tween()
	slam_tw.tween_property(tower, "scale", Vector2(0.85, 1.2), 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	slam_tw.tween_property(tower, "scale", Vector2(1.05, 0.92), 0.08).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	slam_tw.tween_property(tower, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
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

## Extract the attack range (Area2D circle radius) from a tower's scene.
func _get_tower_range(data: TowerData) -> float:
	if data.scene == null:
		return 0.0
	var tmp: Node2D = data.scene.instantiate()
	var area: Area2D = tmp.get_node_or_null("Area2D")
	if area == null:
		tmp.queue_free()
		return 0.0
	for child in area.get_children():
		if child is CollisionShape2D and child.shape is CircleShape2D:
			var r: float = child.shape.radius
			tmp.queue_free()
			return r
	tmp.queue_free()
	return 0.0

## Cache of tower_name → range radius so we only instantiate once per type.
var _range_cache: Dictionary = {}

func get_tower_range_cached(data: TowerData) -> float:
	if _range_cache.has(data.tower_name):
		return _range_cache[data.tower_name]
	var r: float = _get_tower_range(data)
	_range_cache[data.tower_name] = r
	return r
