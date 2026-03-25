extends Node2D

var tower_data: TowerData = null

var _area: Area2D
var _enemies_in_range: Array = []
var _attack_timer: Timer

func _ready() -> void:
	_area = $Area2D
	_area.area_entered.connect(_on_enemy_entered)
	_area.area_exited.connect(_on_enemy_exited)

	_attack_timer = Timer.new()
	_attack_timer.one_shot = false
	_attack_timer.timeout.connect(_on_attack_timeout)
	add_child(_attack_timer)

	if tower_data != null:
		_start_attacking()

func initialize(data: TowerData) -> void:
	tower_data = data
	if is_inside_tree():
		_start_attacking()

func _start_attacking() -> void:
	var upgrade_mgr: Node = get_node_or_null("/root/UpgradeManager")
	var speed_mult: float = 1.0
	if upgrade_mgr and tower_data:
		speed_mult = upgrade_mgr.get_speed_multiplier(tower_data.tower_name)
	# Higher multiplier = faster attacks = shorter wait time
	_attack_timer.wait_time = tower_data.attack_speed / speed_mult
	_attack_timer.start()

func _on_enemy_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		_enemies_in_range.append(area)

func _on_enemy_exited(area: Area2D) -> void:
	_enemies_in_range.erase(area)

func _on_attack_timeout() -> void:
	_clean_dead_enemies()
	var target = _pick_target()
	if target == null:
		return
	_fire_projectile(target)

func _clean_dead_enemies() -> void:
	var valid: Array = []
	for e in _enemies_in_range:
		if is_instance_valid(e):
			valid.append(e)
	_enemies_in_range = valid

func _pick_target() -> Node2D:
	var closest_dist := INF
	var closest: Node2D = null
	for e in _enemies_in_range:
		if not is_instance_valid(e):
			continue
		var dist = global_position.distance_to(e.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = e
	return closest

func _fire_projectile(target: Node2D) -> void:
	if tower_data == null or tower_data.projectile_scene == null:
		return
	var proj = tower_data.projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position
	var upgrade_mgr2: Node = get_node_or_null("/root/UpgradeManager")
	var dmg_mult: float = 1.0
	if upgrade_mgr2 and tower_data:
		dmg_mult = upgrade_mgr2.get_damage_multiplier(tower_data.tower_name)
	proj.initialize(target, tower_data.damage * dmg_mult)
