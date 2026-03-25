extends Node2D

@onready var _castle: Area2D = $CastleBlue
@onready var _castle_tower: Node2D = $CastleTowerBlue
@onready var _game_over_ui: CanvasLayer = $GameOverUI
@onready var _tower_shop: CanvasLayer = $TowerShopUI
@onready var _placement_manager: Node = $PlacementManager
@onready var _wave_clear_ui: CanvasLayer = $WaveClearUI
@onready var _wave_manager: Node = $Path2D/WaveManager
@onready var _tower_sell_ui: CanvasLayer = $TowerSellUI
@onready var _health_bar_ui: CanvasLayer = $HealthBarUI
@onready var _upgrade_shop_ui: CanvasLayer = $UpgradeShopUI

func _ready() -> void:
	_castle.game_over.connect(_on_game_over)
	_tower_shop.tower_selected.connect(_placement_manager.begin_placement)
	_placement_manager.register_obstacle(_castle.global_position)
	_placement_manager.register_obstacle(_castle_tower.global_position)
	_wave_manager.wave_completed.connect(_wave_clear_ui.show_wave_complete)
	_wave_clear_ui.next_wave_requested.connect(_wave_manager.proceed_to_next_wave)

	# Tower sell: click a placed tower → show sell UI; sell confirmed → remove tower
	_placement_manager.tower_clicked.connect(_tower_sell_ui.select_tower)
	_tower_sell_ui.tower_sold.connect(_placement_manager.sell_tower)

	# Health bar
	_castle.lives_changed.connect(_health_bar_ui.update_health)

	# Upgrade shop — button lives in TowerShopUI, panel lives in UpgradeShopUI
	_tower_shop.upgrade_pressed.connect(_upgrade_shop_ui.toggle_shop)
	# Pass tower data so the shop knows which towers exist
	_upgrade_shop_ui.setup(Array(_tower_shop.tower_data_list))

	GameManager.reset()
	var upgrade_mgr: Node = get_node_or_null("/root/UpgradeManager")
	if upgrade_mgr:
		upgrade_mgr.reset()
		# Mark free towers (unlock_cost == 0) as available before the shop builds buttons
		upgrade_mgr.init_unlocks(Array(_tower_shop.tower_data_list))

func _on_game_over() -> void:
	_wave_clear_ui.force_hide()
	_game_over_ui.show_game_over()
