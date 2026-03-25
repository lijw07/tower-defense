class_name TowerData
extends Resource

@export var tower_name: String = ""
@export_multiline var description: String = ""
@export var scene: PackedScene
@export var projectile_scene: PackedScene
@export var cost: int = 50
@export var unlock_cost: int = 0        ## Gold to unlock in the Shop. 0 = free (available from start).
@export var damage: float = 10.0
@export var attack_speed: float = 1.0
@export var icon: Texture2D
