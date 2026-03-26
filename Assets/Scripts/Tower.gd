extends Node2D

var tower_data: TowerData = null

var _area: Area2D
var _enemies_in_range: Array = []
var _attack_timer: Timer
var _can_attack: bool = true  # ready to fire immediately on first enemy

func _ready() -> void:
	_area = $Area2D
	_area.area_entered.connect(_on_enemy_entered)
	_area.area_exited.connect(_on_enemy_exited)

	_attack_timer = Timer.new()
	_attack_timer.one_shot = true
	_attack_timer.timeout.connect(_on_cooldown_finished)
	add_child(_attack_timer)

	if tower_data != null:
		_setup_timer()

func initialize(data: TowerData) -> void:
	tower_data = data
	if is_inside_tree():
		_setup_timer()
		# Attack immediately if enemies are already in range
		_try_attack()

func _setup_timer() -> void:
	var upgrade_mgr: Node = get_node_or_null("/root/UpgradeManager")
	var speed_mult: float = 1.0
	if upgrade_mgr and tower_data:
		speed_mult = upgrade_mgr.get_speed_multiplier(tower_data.tower_name)
	_attack_timer.wait_time = tower_data.attack_speed / speed_mult
	_can_attack = true

func _on_enemy_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		_enemies_in_range.append(area)
		# Defer the attack — Godot forbids adding physics nodes while flushing queries
		call_deferred("_try_attack")

func _on_enemy_exited(area: Area2D) -> void:
	_enemies_in_range.erase(area)

func _on_cooldown_finished() -> void:
	_can_attack = true
	_try_attack()

func _try_attack() -> void:
	if not _can_attack:
		return
	_clean_dead_enemies()
	var target = _pick_target()
	if target == null:
		return
	_can_attack = false
	_fire_projectile(target)
	# Start cooldown
	_attack_timer.start()

func _clean_dead_enemies() -> void:
	var valid: Array = []
	for e in _enemies_in_range:
		if is_instance_valid(e):
			valid.append(e)
	_enemies_in_range = valid

func _pick_target() -> Node2D:
	# Only target enemies visible on camera
	var cam: Camera2D = get_viewport().get_camera_2d()
	var cam_rect: Rect2 = Rect2()
	if cam:
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		var half_view: Vector2 = vp_size / (2.0 * cam.zoom)
		cam_rect = Rect2(cam.global_position - half_view, half_view * 2.0)
	var closest_dist := INF
	var closest: Node2D = null
	for e in _enemies_in_range:
		if not is_instance_valid(e):
			continue
		# Skip enemies outside the camera view
		if cam and not cam_rect.has_point(e.global_position):
			continue
		var dist = global_position.distance_to(e.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = e
	return closest

func _fire_projectile(target: Node2D) -> void:
	if tower_data == null or tower_data.projectile_scene == null:
		return
	# Play tower-type-specific shoot SFX
	var sfx := get_node_or_null("/root/SFXManager")
	if sfx:
		var tname: String = tower_data.tower_name.to_lower()
		if "cannon" in tname:
			sfx.play("cannon_shoot", -4.0)
		elif "ice" in tname or "lightning" in tname or "poison" in tname:
			sfx.play("magic_shoot", -4.0)
		else:
			sfx.play("arrow_shoot", -4.0)
	var proj = tower_data.projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position
	# Muzzle flash FX
	var dir: Vector2 = (target.global_position - global_position).normalized()
	var muzzle_color: Color = Color(1.0, 0.9, 0.4)
	var tname_lower: String = tower_data.tower_name.to_lower()
	if "ice" in tname_lower:
		muzzle_color = Color(0.5, 0.8, 1.0)
	elif "lightning" in tname_lower:
		muzzle_color = Color(0.7, 0.7, 1.0)
	elif "poison" in tname_lower:
		muzzle_color = Color(0.4, 1.0, 0.3)
	elif "cannon" in tname_lower:
		muzzle_color = Color(1.0, 0.6, 0.2)
	PixelFX.spawn_muzzle(get_tree(), global_position + dir * 8.0, dir, muzzle_color)
	var upgrade_mgr2: Node = get_node_or_null("/root/UpgradeManager")
	var dmg_mult: float = 1.0
	if upgrade_mgr2 and tower_data:
		dmg_mult = upgrade_mgr2.get_damage_multiplier(tower_data.tower_name)
	proj.initialize(target, tower_data.damage * dmg_mult)
