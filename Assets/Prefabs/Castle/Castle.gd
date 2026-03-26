extends Area2D

signal game_over
signal lives_changed(current: int, maximum: int)
signal armor_changed(current: int)
signal health_damaged          # emitted only on actual HP loss from an enemy hit
signal armor_blocked           # emitted only when armor absorbs a hit

@export var max_lives: int = 3
var lives: int

func _ready():
	lives = max_lives
	area_entered.connect(_on_area_entered)
	# Emit initial state so the health bar can pick it up
	call_deferred("_emit_lives")

## Called by SceneRoot after UpgradeManager is reset + health upgrades applied.
func apply_health_bonus(bonus: int) -> void:
	max_lives = max_lives + bonus
	lives = max_lives
	_emit_lives()

func _emit_lives() -> void:
	emit_signal("lives_changed", lives, max_lives)
	var upgrade_mgr: Node = get_node_or_null("/root/UpgradeManager")
	if upgrade_mgr:
		emit_signal("armor_changed", upgrade_mgr.get_castle_armor())

func _on_area_entered(area):
	if area.is_in_group("enemies"):
		# Remove the enemy first
		var parent = area.get_parent()
		if parent is PathFollow2D:
			parent.queue_free()
		else:
			area.queue_free()

		# Check armor — each armor point absorbs one full enemy hit
		var upgrade_mgr: Node = get_node_or_null("/root/UpgradeManager")
		var sfx: Node = get_node_or_null("/root/SFXManager")
		if upgrade_mgr and upgrade_mgr.consume_armor():
			if sfx:
				sfx.play("armor_block")
			emit_signal("armor_changed", upgrade_mgr.get_castle_armor())
			emit_signal("armor_blocked")
			return

		# No armor — take health damage
		if sfx:
			sfx.play("castle_hit")
		var dmg = area.get("damage")
		if dmg != null:
			lives -= dmg
		else:
			lives -= 1
		emit_signal("lives_changed", lives, max_lives)
		emit_signal("health_damaged")
		if lives <= 0:
			emit_signal("game_over")
