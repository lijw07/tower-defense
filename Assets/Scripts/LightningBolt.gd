# LightningBolt.gd — Chain-lightning projectile for the Lightning tower.
# Hits the primary target, then arcs to up to MAX_CHAINS nearby enemies,
# each jump dealing CHAIN_FALLOFF × the previous hit's damage.
extends Node2D

const SPEED: float = 300.0
const MAX_CHAINS: int = 3
const CHAIN_RADIUS: float = 80.0
const CHAIN_FALLOFF: float = 0.6   # each chain jump does 60 % of the previous damage

var _target: Node2D = null
var _damage: float = 10.0

func initialize(target: Node2D, damage: float) -> void:
	_target = target
	_damage = damage

func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		queue_free()
		return

	var direction = (_target.global_position - global_position).normalized()
	global_position += direction * SPEED * delta
	rotation = direction.angle()

	if global_position.distance_to(_target.global_position) < 4.0:
		_chain_from(_target, _damage, [], MAX_CHAINS)
		queue_free()

# Recursively chain to nearby enemies that haven't been hit yet.
func _chain_from(source: Node2D, dmg: float, already_hit: Array, chains_left: int) -> void:
	if not is_instance_valid(source):
		return

	source.take_damage(dmg)
	already_hit.append(source)

	if chains_left <= 0:
		return

	# Find the closest unhit enemy within CHAIN_RADIUS.
	var best_enemy: Node2D = null
	var best_dist: float = CHAIN_RADIUS + 1.0

	for enemy in source.get_tree().get_nodes_in_group("enemies"):
		if enemy in already_hit:
			continue
		if not is_instance_valid(enemy):
			continue
		var dist: float = source.global_position.distance_to(enemy.global_position)
		if dist < best_dist:
			best_dist = dist
			best_enemy = enemy

	if best_enemy != null:
		_chain_from(best_enemy, dmg * CHAIN_FALLOFF, already_hit, chains_left - 1)
