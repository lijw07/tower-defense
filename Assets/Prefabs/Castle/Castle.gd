extends Area2D

signal game_over
signal lives_changed(current: int, maximum: int)

@export var max_lives: int = 3
var lives: int

func _ready():
	lives = max_lives
	area_entered.connect(_on_area_entered)
	# Emit initial state so the health bar can pick it up
	call_deferred("_emit_lives")

func _emit_lives() -> void:
	emit_signal("lives_changed", lives, max_lives)

func _on_area_entered(area):
	if area.is_in_group("enemies"):
		var dmg = area.get("damage")
		if dmg != null:
			lives -= dmg
			var parent = area.get_parent()
			if parent is PathFollow2D:
				parent.queue_free()
			else:
				area.queue_free()
			print("Lives remaining: ", lives)
			emit_signal("lives_changed", lives, max_lives)
			if lives <= 0:
				emit_signal("game_over")
