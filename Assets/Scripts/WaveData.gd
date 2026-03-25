# WaveData.gd
class_name WaveData
extends Resource

@export var wave_number: int = 1
@export var entries: Array[WaveEntry] = []
@export var time_between_batches: float = 2.0
# Multipliers applied to every enemy spawned in this wave.
# Defaults to 1.0 so hand-crafted waves 1–7 are unaffected.
@export var health_scale: float = 1.0
@export var speed_scale: float = 1.0
