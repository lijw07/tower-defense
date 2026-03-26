extends Node2D

@onready var _castle: Area2D = $SpringBiomeMap/CastleBlue
@onready var _castle_tower: Node2D = $SpringBiomeMap/CastleTowerBlue
@onready var _castle_tower2: Node2D = $SpringBiomeMap/CastleTowerBlue2
@onready var _game_over_ui: CanvasLayer = $GameOverUI
@onready var _tower_shop: CanvasLayer = $TowerShopUI
@onready var _placement_manager: Node = $PlacementManager
@onready var _wave_clear_ui: CanvasLayer = $WaveClearUI
@onready var _wave_manager: Node = $Path2D/WaveManager
@onready var _tower_sell_ui: CanvasLayer = $TowerSellUI
@onready var _health_bar_ui: CanvasLayer = $HealthBarUI
@onready var _upgrade_shop_ui: CanvasLayer = $UpgradeShopUI
var _last_heal_count: int = 0
var _decoration_spawner: Node = null
var _obstacle_removal_ui: CanvasLayer = null
var _castle_tier: int = 0  # 0 = blue, 1 = green, 2 = red

# Castle sprite paths per tier: [blue, green, red]
const CASTLE_SPRITES: Array[String] = [
	"res://Assets/Towers/Castle/spr_castle_blue.png",
	"res://Assets/Towers/Castle/spr_castle_green.png",
	"res://Assets/Towers/Castle/spr_castle_red.png",
]
const TOWER_SPRITES: Array[String] = [
	"res://Assets/Towers/Non-Combat Towers/spr_normal_tower_01_blue.png",
	"res://Assets/Towers/Non-Combat Towers/spr_normal_tower_01_green.png",
	"res://Assets/Towers/Non-Combat Towers/spr_normal_tower_01_red.png",
]
const CASTLE_FRAME_SIZE := Vector2(52, 38)
const TOWER_FRAME_SIZE := Vector2(22, 28)
# Tier thresholds based on total castle max HP (base 5 + upgrade levels)
const CASTLE_HP_GREEN: int = 10   # base 5 + 5 levels
const CASTLE_HP_RED: int = 20     # base 5 + 15 levels

func _ready() -> void:
	_castle.game_over.connect(_on_game_over)
	_tower_shop.tower_selected.connect(_placement_manager.begin_placement)
	# Register a block of tiles around each castle element so towers can't overlap
	var ground: TileMapLayer = $SpringBiomeMap
	_register_castle_block(ground, _castle.global_position)
	_register_castle_block(ground, _castle_tower.global_position)
	if is_instance_valid(_castle_tower2):
		_register_castle_block(ground, _castle_tower2.global_position)
	_wave_manager.wave_completed.connect(_wave_clear_ui.show_wave_complete)
	_wave_manager.wave_completed.connect(_on_wave_completed)
	_wave_manager.wave_started.connect(_tower_shop.update_wave_display)
	_wave_manager.enemy_count_changed.connect(_tower_shop.update_enemy_count)
	_wave_manager.boss_spawned.connect(_show_boss_warning)
	_wave_clear_ui.next_wave_requested.connect(_wave_manager.proceed_to_next_wave)

	# Tower sell: click a placed tower → show sell UI; sell confirmed → remove tower
	_placement_manager.tower_clicked.connect(_tower_sell_ui.select_tower)
	_tower_sell_ui.tower_sold.connect(_placement_manager.sell_tower)
	# Unlock shop tooltip when placement ends (placed or cancelled)
	_placement_manager.placement_ended.connect(_tower_shop.on_placement_ended)

	# Health bar — health + armor
	_castle.lives_changed.connect(_health_bar_ui.update_health)
	_castle.lives_changed.connect(_on_castle_lives_changed)
	# Refresh shop heal/armor buttons whenever castle HP changes (e.g. taking damage while shop open)
	_castle.lives_changed.connect(func(_c: int, _m: int) -> void: _upgrade_shop_ui._refresh_castle_section())
	_castle.armor_changed.connect(_health_bar_ui.update_armor)
	# Castle world-space damage FX
	_castle.health_damaged.connect(_on_castle_health_damaged)
	_castle.armor_blocked.connect(_on_castle_armor_blocked)

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
		# Listen for castle health upgrades so we can apply them to the castle
		upgrade_mgr.castle_stats_changed.connect(_on_castle_stats_changed)

	# Decoration spawner — random trees, rocks, mushrooms
	var spawner_script: GDScript = load("res://Assets/Scripts/DecorationSpawner.gd") as GDScript
	_decoration_spawner = Node.new()
	_decoration_spawner.set_script(spawner_script)
	_decoration_spawner.name = "DecorationSpawner"
	add_child(_decoration_spawner)
	var castle_positions: Array[Vector2] = [_castle.global_position, _castle_tower.global_position]
	if is_instance_valid(_castle_tower2):
		castle_positions.append(_castle_tower2.global_position)
	var ground_layer: TileMapLayer = $SpringBiomeMap
	var road_layer: TileMapLayer = $SpringBiomeMap/Road
	var path2d: Path2D = $Path2D
	_decoration_spawner.setup(ground_layer, road_layer, path2d, castle_positions, "spring")
	# Register spawned decorations as obstacles for tower placement
	for pos in _decoration_spawner.get_spawned_positions():
		_placement_manager.register_obstacle(pos)
	_placement_manager.set_decoration_spawner(_decoration_spawner)

	# Obstacle removal UI — created at runtime (same pattern as DecorationSpawner)
	var removal_script: GDScript = load("res://Assets/Scripts/ObstacleRemovalUI.gd") as GDScript
	_obstacle_removal_ui = CanvasLayer.new()
	_obstacle_removal_ui.set_script(removal_script)
	_obstacle_removal_ui.name = "ObstacleRemovalUI"
	add_child(_obstacle_removal_ui)
	_placement_manager.decoration_clicked.connect(_obstacle_removal_ui.select_decoration)
	_obstacle_removal_ui.obstacle_removed.connect(_on_obstacle_removed)

	# Show wave 1 countdown instead of starting immediately
	_wave_clear_ui.show_wave_starting(1)

	# Start gameplay background music
	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play_music("gameplay")

# ── Shader-based partial-occlusion transparency ───────────────────────────
# Only the overlapping pixels between an enemy/decoration and a tower/tree
# become transparent — not the whole sprite.

const OCCLUDE_NEAR := 28.0      # how close (world px) an enemy must be to count
const OCCLUDE_Y_RANGE := 28.0   # max vertical "behind" distance
const HOVER_RADIUS := 22.0      # mouse proximity for hover-fade
const OCC_SHADER_RADIUS := 22.0 # shader fade radius sent to shader uniform

var _occlusion_shader: Shader = null
# Track which visuals currently have our shader so we can restore originals.
# Key = visual's instance id → { "visual": CanvasItem, "original_mat": Material or null }
var _occluded_visuals: Dictionary = {}

func _process(_delta: float) -> void:
	_update_occlusion()

## Lazily load the occlusion shader the first time it's needed.
func _ensure_shader() -> void:
	if _occlusion_shader == null:
		_occlusion_shader = load("res://Assets/Scripts/occlusion_fade.gdshader") as Shader

## Find the main visual child (Sprite2D / AnimatedSprite2D) for a node.
## For decorations (which ARE Sprite2D), returns the node itself.
func _find_visual(node: Node2D) -> CanvasItem:
	if node is Sprite2D or node is AnimatedSprite2D:
		return node
	for child in node.get_children():
		if child is AnimatedSprite2D:
			return child
		if child is Sprite2D:
			return child
	# One more level deep (e.g. tower → subnode → sprite)
	for child in node.get_children():
		for grandchild in child.get_children():
			if grandchild is AnimatedSprite2D or grandchild is Sprite2D:
				return grandchild
	return null

## Apply our occlusion ShaderMaterial to a visual, saving the original material.
## `owner_node` is the tower/deco that owns this visual (used for meta flags).
## Returns the ShaderMaterial (or null if shader failed to load).
func _apply_shader(visual: CanvasItem, owner_node: Node2D) -> ShaderMaterial:
	_ensure_shader()
	if _occlusion_shader == null:
		return null
	var vid: int = visual.get_instance_id()
	# Already has our shader?
	if vid in _occluded_visuals:
		if visual.material is ShaderMaterial:
			var mat: ShaderMaterial = visual.material as ShaderMaterial
			if mat.shader == _occlusion_shader:
				return mat
	# Save original material and apply ours
	var original_mat: Material = visual.material
	var mat := ShaderMaterial.new()
	mat.shader = _occlusion_shader
	visual.material = mat
	_occluded_visuals[vid] = { "visual": visual, "original_mat": original_mat, "owner": owner_node }
	return mat

## Remove our occlusion shader from a visual and restore its original material.
func _remove_shader(visual: CanvasItem) -> void:
	var vid: int = visual.get_instance_id()
	if vid in _occluded_visuals:
		var entry: Dictionary = _occluded_visuals[vid]
		visual.material = entry["original_mat"]
		_occluded_visuals.erase(vid)
	elif visual.material is ShaderMaterial:
		var mat: ShaderMaterial = visual.material as ShaderMaterial
		if mat.shader == _occlusion_shader:
			visual.material = null

## Set occluder positions on a ShaderMaterial (world-space vec2 uniforms).
func _apply_occluders(mat: ShaderMaterial, positions: Array[Vector2]) -> void:
	var count: int = mini(positions.size(), 8)
	mat.set_shader_parameter("occ_count", count)
	mat.set_shader_parameter("occ_radius", OCC_SHADER_RADIUS)
	var far := Vector2(99999.0, 99999.0)
	for i in range(8):
		var key: String = "occ_%d" % i
		mat.set_shader_parameter(key, positions[i] if i < count else far)

func _update_occlusion() -> void:
	# ── Gather live enemies ──
	var enemies: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Node2D and is_instance_valid(node):
			enemies.append(node as Node2D)

	# ── Gather structures that can be see-through ──
	var towers: Array[Node2D] = []
	if _placement_manager and "_placed_towers" in _placement_manager:
		for tower in _placement_manager._placed_towers:
			if is_instance_valid(tower):
				towers.append(tower)
	var decos: Array[Node2D] = []
	if _decoration_spawner and _decoration_spawner.has_method("get_all_decorations"):
		decos = _decoration_spawner.get_all_decorations()

	# ── Mouse world position for hover-fade ──
	var mouse_world := Vector2.ZERO
	var vp := get_viewport()
	if vp:
		mouse_world = vp.get_canvas_transform().affine_inverse() * vp.get_mouse_position()

	# Track which visuals are actively occluded this frame
	var active_vids: Dictionary = {}

	# We only process TOWERS as occluders (things that become transparent).
	# Decorations (trees, rocks, mushrooms) are too small and don't need
	# automatic enemy-based transparency — they only fade on mouse hover
	# when they block something the player wants to interact with.
	for occ in towers:
		if not is_instance_valid(occ):
			continue
		var visual: CanvasItem = _find_visual(occ)
		if visual == null:
			continue

		var occ_pos: Vector2 = occ.global_position
		var occ_positions: Array[Vector2] = []

		# 1) Enemies behind this tower — always transparent so player can see them
		for enemy in enemies:
			if occ_positions.size() >= 8:
				break
			var e_pos: Vector2 = enemy.global_position
			var dx: float = absf(e_pos.x - occ_pos.x)
			var dy: float = occ_pos.y - e_pos.y  # positive = enemy behind
			if dx < OCCLUDE_NEAR and dy > 0.0 and dy < OCCLUDE_Y_RANGE:
				occ_positions.append(e_pos)

		# 2) Other towers behind this tower — only if mouse hovers over the behind tower
		if occ_positions.size() < 8:
			for other_tower in towers:
				if other_tower == occ or not is_instance_valid(other_tower):
					continue
				var t_pos: Vector2 = other_tower.global_position
				if mouse_world.distance_to(t_pos) > HOVER_RADIUS:
					continue
				var tdx: float = absf(t_pos.x - occ_pos.x)
				var tdy: float = occ_pos.y - t_pos.y  # positive = other tower behind
				if tdx < OCCLUDE_NEAR and tdy > 0.0 and tdy < OCCLUDE_Y_RANGE:
					occ_positions.append(t_pos)
					if occ_positions.size() >= 8:
						break

		# 3) Decorations behind this tower — only if mouse hovers over the decoration
		if occ_positions.size() < 8:
			for deco in decos:
				if not is_instance_valid(deco):
					continue
				var d_pos: Vector2 = deco.global_position
				if mouse_world.distance_to(d_pos) > HOVER_RADIUS:
					continue
				# Is this tower in front of (higher Y) the decoration?
				var block_dx: float = absf(d_pos.x - occ_pos.x)
				var block_dy: float = occ_pos.y - d_pos.y
				if block_dx < OCCLUDE_NEAR and block_dy > 0.0 and block_dy < OCCLUDE_Y_RANGE:
					occ_positions.append(d_pos)
					if occ_positions.size() >= 8:
						break

		# Apply or remove shader
		var vid: int = visual.get_instance_id()
		if occ_positions.size() > 0:
			var mat: ShaderMaterial = _apply_shader(visual, occ)
			if mat != null:
				_apply_occluders(mat, occ_positions)
				active_vids[vid] = true
				# Mark the owner node so click logic can detect occlusion
				occ.set_meta("_occ_active", true)
		else:
			# No occlusion this frame — clear meta immediately
			if occ.has_meta("_occ_active"):
				occ.remove_meta("_occ_active")

	# ── Clean up: remove shader from visuals that no longer need it ──
	var stale_vids: Array = []
	for vid in _occluded_visuals:
		if vid not in active_vids:
			stale_vids.append(vid)
	for vid in stale_vids:
		var entry: Dictionary = _occluded_visuals[vid]
		var visual: CanvasItem = entry["visual"]
		if is_instance_valid(visual):
			visual.material = entry["original_mat"]
		# Clear the occlusion meta flag on the owner node (tower / deco)
		var owner_node: Node2D = entry.get("owner") as Node2D
		if owner_node != null and is_instance_valid(owner_node) and owner_node.has_meta("_occ_active"):
			owner_node.remove_meta("_occ_active")
		_occluded_visuals.erase(vid)

# ── Boss warning ───────────────────────────────────────────────────────────

func _show_boss_warning() -> void:
	if not is_inside_tree():
		return
	# Play a deep warning sound
	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("boss_warning")
	# Create a CanvasLayer so the warning sits on top of everything
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	# Warning label — big red text, centered on screen
	var label := Label.new()
	label.text = "BOSS INCOMING!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.1))
	label.add_theme_color_override("font_outline_color", Color(0.2, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", 4)
	var pf: Font = UITheme.get_pixel_font()
	if pf:
		label.add_theme_font_override("font", pf)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate.a = 0.0
	layer.add_child(label)

	# ── Flashing red border vignette ──
	var border := ColorRect.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Shader draws a red glow at screen edges; "intensity" uniform controls brightness
	var border_shader := Shader.new()
	border_shader.code = "shader_type canvas_item;\nuniform float intensity : hint_range(0.0, 1.0) = 0.0;\nvoid fragment() {\n\tfloat edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));\n\tfloat glow = smoothstep(0.09, 0.0, edge);\n\tCOLOR = vec4(1.0, 0.05, 0.02, glow * 0.75 * intensity);\n}\n"
	var border_mat := ShaderMaterial.new()
	border_mat.shader = border_shader
	border_mat.set_shader_parameter("intensity", 0.0)
	border.material = border_mat
	layer.add_child(border)

	# ── Single tween chain: fade in → flash + shake → fade out → cleanup ──
	# Border uses the shader "intensity" uniform so it doesn't conflict with modulate.
	var tw: Tween = create_tween()

	# Phase 1: Fade in (0.25s)
	tw.tween_property(label, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(border_mat, "shader_parameter/intensity", 1.0, 0.25).set_ease(Tween.EASE_OUT)

	# Phase 2: Flashing border pulses (4 pulses × 0.7s = 2.8s)
	for pulse in range(4):
		tw.tween_property(border_mat, "shader_parameter/intensity", 0.2, 0.35)
		tw.tween_property(border_mat, "shader_parameter/intensity", 1.0, 0.35)

	# Phase 3: Fade out (0.5s)
	tw.tween_property(label, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(border_mat, "shader_parameter/intensity", 0.0, 0.5).set_ease(Tween.EASE_IN)

	# Cleanup
	tw.tween_callback(layer.queue_free)

	# ── Text shaking runs on a separate tween (only animates position, no conflict) ──
	var shake_tw: Tween = create_tween()
	shake_tw.tween_interval(0.25)  # wait for fade-in
	for i in range(25):
		var ox: float = randf_range(-4.0, 4.0)
		var oy: float = randf_range(-3.0, 3.0)
		shake_tw.tween_property(label, "position", Vector2(ox, oy), 0.07)
	shake_tw.tween_property(label, "position", Vector2.ZERO, 0.05)

# ── Callbacks ───────────────────────────────────────────────────────────────

func _on_game_over() -> void:
	_wave_clear_ui.force_hide()
	# Stop gameplay music and play game over sound
	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.stop_music()
		sfx.play("game_over")
	_game_over_ui.show_game_over()

func _on_castle_lives_changed(current: int, maximum: int) -> void:
	var upgrade_mgr: Node = get_node_or_null("/root/UpgradeManager")
	if upgrade_mgr:
		upgrade_mgr.update_castle_lives(current, maximum)

## Castle took real HP damage — red flash, shake, debris particles + impact SFX.
func _on_castle_health_damaged() -> void:
	if not is_inside_tree():
		return
	# Layered impact SFX (heavy crunch + rumble, complements castle_hit from Castle.gd)
	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("castle_damage_impact", -3.0)
	# Particle FX — red impact burst + falling debris
	PixelFX.spawn_castle_hit(get_tree(), _castle.global_position)
	# Red flash + heavy shake on castle sprite
	_castle.modulate = Color(2.5, 0.3, 0.3, 1.0)
	var tw: Tween = create_tween()
	tw.tween_property(_castle, "modulate", Color.WHITE, 0.35).set_ease(Tween.EASE_OUT)
	# Shake: quick violent horizontal + vertical jitter
	var origin: Vector2 = _castle.position
	var shake_tw: Tween = create_tween()
	shake_tw.tween_property(_castle, "position", origin + Vector2(4, -2), 0.025)
	shake_tw.tween_property(_castle, "position", origin + Vector2(-5, 3), 0.025)
	shake_tw.tween_property(_castle, "position", origin + Vector2(3, -1), 0.025)
	shake_tw.tween_property(_castle, "position", origin + Vector2(-2, 2), 0.025)
	shake_tw.tween_property(_castle, "position", origin + Vector2(1, 0), 0.025)
	shake_tw.tween_property(_castle, "position", origin, 0.03)
	# Brief squash on impact
	_castle.scale = Vector2(1.1, 0.85)
	var squash_tw: Tween = create_tween()
	squash_tw.tween_property(_castle, "scale", Vector2(1.0, 1.0), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

## Castle armor absorbed a hit — blue flash, shield sparks, subtle bounce + deflect SFX.
func _on_castle_armor_blocked() -> void:
	if not is_inside_tree():
		return
	# Layered deflect SFX (metallic clang + ring, complements armor_block from Castle.gd)
	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("armor_deflect", -2.0)
	# Particle FX — blue metallic sparks + shield shimmer
	PixelFX.spawn_armor_block(get_tree(), _castle.global_position)
	# Blue-white flash (lighter than health damage)
	_castle.modulate = Color(0.6, 0.8, 2.0, 1.0)
	var tw: Tween = create_tween()
	tw.tween_property(_castle, "modulate", Color.WHITE, 0.3).set_ease(Tween.EASE_OUT)
	# Subtle bounce — castle absorbs impact, briefly compresses then springs back
	_castle.scale = Vector2(0.95, 1.05)
	var bounce_tw: Tween = create_tween()
	bounce_tw.tween_property(_castle, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

## Castle was healed — green flash, rising sparkles, warm chime.
func _on_castle_healed() -> void:
	if not is_inside_tree():
		return
	# Heal SFX — ascending chime
	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("castle_heal")
	# Particle FX — green rising sparkles
	PixelFX.spawn_castle_heal(get_tree(), _castle.global_position)
	# Soft green flash
	_castle.modulate = Color(0.5, 2.0, 0.5, 1.0)
	var tw: Tween = create_tween()
	tw.tween_property(_castle, "modulate", Color.WHITE, 0.4).set_ease(Tween.EASE_OUT)
	# Gentle upward bounce
	_castle.scale = Vector2(1.05, 1.08)
	var bounce_tw: Tween = create_tween()
	bounce_tw.tween_property(_castle, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _on_castle_stats_changed() -> void:
	var upgrade_mgr: Node = get_node_or_null("/root/UpgradeManager")
	if upgrade_mgr:
		# Re-apply max HP from health upgrades
		var bonus: int = upgrade_mgr.get_castle_health_level()
		var base_max: int = 5  # matches CastleBlue's exported max_lives
		var new_max: int = base_max + bonus
		var damage_taken: int = _castle.max_lives - _castle.lives
		_castle.max_lives = new_max
		_castle.lives = max(1, new_max - damage_taken)

		# Check if a heal was purchased (heal total went up)
		var heal_total: int = upgrade_mgr._castle_heal_total_purchased
		if heal_total > _last_heal_count:
			var heals: int = heal_total - _last_heal_count
			_castle.lives = mini(_castle.lives + heals, _castle.max_lives)
			_last_heal_count = heal_total
			_on_castle_healed()
		_castle._emit_lives()
		upgrade_mgr.update_castle_lives(_castle.lives, _castle.max_lives)
		# Also update armor display
		_health_bar_ui.update_armor(upgrade_mgr.get_castle_armor())
		# Check if castle appearance should upgrade
		_check_castle_tier()

## Build a SpriteFrames resource from a sprite-sheet texture and frame size.
func _make_sprite_frames(texture: Texture2D, frame_size: Vector2) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("default")
	frames.set_animation_speed("default", 10.0)
	frames.set_animation_loop("default", true)
	var cols: int = int(texture.get_width() / frame_size.x)
	for i in range(cols):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * frame_size.x, 0, frame_size.x, frame_size.y)
		frames.add_frame("default", atlas)
	return frames

## Remove and replace the AnimatedSprite2D on a node with a fresh one.
## Hides + renames the old sprite immediately to prevent any overlap artifacts,
## then creates a clean replacement.
func _replace_sprite(parent: Node, tex: Texture2D, frame_size: Vector2) -> void:
	# Kill every existing AnimatedSprite2D child to be safe (handles stragglers)
	for child in parent.get_children():
		if child is AnimatedSprite2D:
			child.visible = false
			child.name = "_dead_%d" % child.get_instance_id()
			parent.remove_child(child)
			child.queue_free()
	var new_sprite := AnimatedSprite2D.new()
	new_sprite.name = "AnimatedSprite2D"
	new_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	new_sprite.sprite_frames = _make_sprite_frames(tex, frame_size)
	parent.add_child(new_sprite)
	new_sprite.play("default")

## Swap castle and castle-tower sprites to match the given tier index.
## Plays SFX + particle FX on tier change.
func _apply_castle_tier(tier: int) -> void:
	if tier == _castle_tier:
		return
	_castle_tier = tier
	# Castle main building — remove old sprite, add new one
	var castle_tex: Texture2D = load(CASTLE_SPRITES[tier])
	_replace_sprite(_castle, castle_tex, CASTLE_FRAME_SIZE)
	# Castle towers
	var tower_tex: Texture2D = load(TOWER_SPRITES[tier])
	for tower_node in [_castle_tower, _castle_tower2]:
		if is_instance_valid(tower_node):
			_replace_sprite(tower_node, tower_tex, TOWER_FRAME_SIZE)
	# SFX
	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("castle_evolve")
	# Particle FX on castle + each tower
	if is_inside_tree():
		PixelFX.spawn_castle_evolve(get_tree(), _castle.global_position, tier)
		for tower_node in [_castle_tower, _castle_tower2]:
			if is_instance_valid(tower_node):
				PixelFX.spawn_castle_evolve(get_tree(), tower_node.global_position, tier)
	# Flash animation — brief white flash then settle
	_flash_node(_castle)
	for tower_node in [_castle_tower, _castle_tower2]:
		if is_instance_valid(tower_node):
			_flash_node(tower_node)

## Quick white flash + scale bounce on a node when it evolves.
func _flash_node(node: Node2D) -> void:
	node.modulate = Color(3.0, 3.0, 3.0, 1.0)
	node.scale = Vector2(1.3, 1.3)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "modulate", Color.WHITE, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(node, "scale", Vector2(1.0, 1.0), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

## Check total castle max HP and upgrade the castle appearance tier if needed.
func _check_castle_tier() -> void:
	var total_hp: int = _castle.max_lives
	var new_tier: int = 0
	if total_hp >= CASTLE_HP_RED:
		new_tier = 2
	elif total_hp >= CASTLE_HP_GREEN:
		new_tier = 1
	_apply_castle_tier(new_tier)

## Register a 3×3 block of tiles around a castle element as placement obstacles.
func _register_castle_block(ground: TileMapLayer, center_pos: Vector2) -> void:
	var center_tile: Vector2i = ground.local_to_map(ground.to_local(center_pos))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var tile: Vector2i = center_tile + Vector2i(dx, dy)
			var world_pos: Vector2 = ground.to_global(ground.map_to_local(tile))
			_placement_manager.register_obstacle(world_pos)

func _on_wave_completed(wave_number: int) -> void:
	# Regrow decorations at the end of each wave (density-aware)
	if _decoration_spawner and is_inside_tree():
		var new_positions: Array[Vector2] = _decoration_spawner.spawn_wave_growth()
		for pos in new_positions:
			_placement_manager.register_obstacle(pos)
	# Every 10 waves — fireworks celebration on castle, castle towers, and attack towers
	if wave_number > 0 and wave_number % 10 == 0 and is_inside_tree():
		_play_fireworks_celebration()

## Fireworks celebration — staggered bursts over ~3 seconds with camera shake,
## tower/castle bounce animations, and golden sparkle FX.
func _play_fireworks_celebration() -> void:
	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("fireworks")
	# Gather all structure nodes and positions
	var all_nodes: Array[Node2D] = []
	var positions: Array[Vector2] = []
	# Castle + castle towers
	all_nodes.append(_castle)
	positions.append(_castle.global_position)
	for tower_node in [_castle_tower, _castle_tower2]:
		if is_instance_valid(tower_node):
			all_nodes.append(tower_node)
			positions.append(tower_node.global_position)
	# Placed attack towers
	if _placement_manager and "_placed_towers" in _placement_manager:
		for tower in _placement_manager._placed_towers:
			if is_instance_valid(tower):
				all_nodes.append(tower)
				positions.append(tower.global_position)

	# ── Immediate: golden flash on all structures ──
	for node in all_nodes:
		if is_instance_valid(node):
			node.modulate = Color(1.8, 1.6, 0.6, 1.0)
			var flash_tw: Tween = create_tween()
			flash_tw.tween_property(node, "modulate", Color.WHITE, 0.5).set_ease(Tween.EASE_OUT)

	# ── Staggered firework bursts + structure animations over ~3 seconds ──
	var burst_delays: Array[float] = [0.0, 0.3, 0.55, 0.85, 1.15, 1.5, 1.9, 2.35]
	var celebration_tw: Tween = create_tween()
	for wave_idx in range(burst_delays.size()):
		var delay: float = burst_delays[wave_idx]
		var delta: float = delay if wave_idx == 0 else delay - burst_delays[wave_idx - 1]
		celebration_tw.tween_callback(func() -> void:
			if not is_inside_tree():
				return
			# Firework particles on random subset of positions
			var fw_count: int = mini(positions.size(), 3)
			var shuffled := positions.duplicate()
			shuffled.shuffle()
			for j in range(fw_count):
				PixelFX.spawn_firework_single(get_tree(), shuffled[j])
			# Golden sparkle FX on a few structures
			var sparkle_shuffled := all_nodes.duplicate()
			sparkle_shuffled.shuffle()
			var sp_count: int = mini(sparkle_shuffled.size(), 2)
			for j in range(sp_count):
				var nd: Node2D = sparkle_shuffled[j]
				if is_instance_valid(nd):
					PixelFX.spawn_celebration_sparkle(get_tree(), nd.global_position)
		).set_delay(delta)

	# ── Repeating bounce animation on all structures (4 bounces over ~3s) ──
	var bounce_delays: Array[float] = [0.1, 0.8, 1.5, 2.2]
	for b_idx in range(bounce_delays.size()):
		var bd: float = bounce_delays[b_idx]
		var _b_delta: float = bd if b_idx == 0 else bd - bounce_delays[b_idx - 1]
		var bounce_tw: Tween = create_tween()
		bounce_tw.tween_callback(func() -> void:
			if not is_inside_tree():
				return
			for node in all_nodes:
				if not is_instance_valid(node):
					continue
				_celebration_bounce(node)
		).set_delay(bd)

	# Camera shake — rumbling jitter over the celebration duration
	var cam: Camera2D = get_node_or_null("SpringBiomeMap/Camera2D")
	if not cam:
		cam = get_viewport().get_camera_2d()
	if cam:
		_fireworks_camera_shake(cam, 3.0)

## Joyful bounce on a single structure — squash-stretch with a golden flash.
func _celebration_bounce(node: Node2D) -> void:
	# Quick golden tint
	node.modulate = Color(1.5, 1.4, 0.5, 1.0)
	var flash_tw: Tween = create_tween()
	flash_tw.tween_property(node, "modulate", Color.WHITE, 0.35).set_ease(Tween.EASE_OUT)
	# Squash down then spring up
	node.scale = Vector2(1.15, 0.85)
	var sq_tw: Tween = create_tween()
	sq_tw.tween_property(node, "scale", Vector2(0.9, 1.15), 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	sq_tw.tween_property(node, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	# Small upward hop
	var origin: Vector2 = node.position
	var hop_tw: Tween = create_tween()
	hop_tw.tween_property(node, "position", origin + Vector2(0, -3), 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	hop_tw.tween_property(node, "position", origin, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)

## Gentle camera shake over a duration — celebratory rumble, not violent.
func _fireworks_camera_shake(cam: Camera2D, duration: float) -> void:
	var shake_tw: Tween = create_tween()
	var steps: int = int(duration / 0.06)  # ~17 fps jitter
	for i in range(steps):
		var intensity: float = 2.5 * (1.0 - float(i) / float(steps))  # fade out
		var offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		shake_tw.tween_property(cam, "offset", offset, 0.06)
	# Settle back to zero
	shake_tw.tween_property(cam, "offset", Vector2.ZERO, 0.1)

func _on_obstacle_removed(deco: Node2D) -> void:
	if deco == null or not is_instance_valid(deco):
		return
	var pos: Vector2 = deco.global_position
	var deco_type: String = deco.get_meta("decoration_type", "tree")
	# Immediately unblock the position and remove from spawner tracking
	_placement_manager.remove_obstacle(pos)
	_decoration_spawner.remove_decoration(deco)
	# Play type-specific sound, particle FX, and animated removal
	var sfx: Node = get_node_or_null("/root/SFXManager")
	match deco_type:
		"tree":
			if sfx: sfx.play("tree_chop")
			PixelFX.spawn_tree_chop(get_tree(), pos)
			_animate_tree_fall(deco)
		"rock":
			if sfx: sfx.play("rock_break")
			PixelFX.spawn_rock_break(get_tree(), pos)
			_animate_rock_crumble(deco)
		"mushroom":
			if sfx: sfx.play("mushroom_pick")
			PixelFX.spawn_mushroom_pick(get_tree(), pos)
			_animate_mushroom_fling(deco)

func _animate_tree_fall(deco: Node2D) -> void:
	# Tree chops and falls sideways (random left or right)
	var direction: float = -1.0 if randf() < 0.5 else 1.0
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	# Rotate to fall sideways (90 degrees)
	tween.tween_property(deco, "rotation", direction * PI / 2.0, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	# Slide in the fall direction
	tween.tween_property(deco, "position", deco.position + Vector2(direction * 12.0, 4.0), 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	# Fade out during the fall
	tween.tween_property(deco, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(deco.queue_free)

func _animate_rock_crumble(deco: Node2D) -> void:
	# Rock crumbles downward into the earth
	var start_pos: Vector2 = deco.position
	# Quick shake first
	var shake_tween: Tween = create_tween()
	shake_tween.tween_property(deco, "position", start_pos + Vector2(2.0, 0), 0.04)
	shake_tween.tween_property(deco, "position", start_pos + Vector2(-2.0, 0), 0.04)
	shake_tween.tween_property(deco, "position", start_pos + Vector2(1.0, 0), 0.03)
	shake_tween.tween_property(deco, "position", start_pos, 0.03)
	# Then crumble down
	shake_tween.tween_callback(func():
		var crumble: Tween = create_tween()
		crumble.set_parallel(true)
		crumble.tween_property(deco, "scale", Vector2(1.3, 0.0), 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		crumble.tween_property(deco, "position", start_pos + Vector2(0, 8.0), 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		crumble.tween_property(deco, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		crumble.chain().tween_callback(deco.queue_free)
	)

func _animate_mushroom_fling(deco: Node2D) -> void:
	# Mushroom flies in a parabolic arc, lands, bounces a few times, then fades
	var direction: float = -1.0 if randf() < 0.5 else 1.0
	var start_pos: Vector2 = deco.position
	var ground_y: float = start_pos.y + 6.0  # ground level for bounces
	# Use a method callback so we can simulate a real parabola + bounces
	var phase_data: Dictionary = {
		"dir": direction,
		"start": start_pos,
		"ground_y": ground_y,
		# Arc phase: launch upward and sideways
		"launch_vx": direction * 80.0,
		"launch_vy": -180.0,
		"gravity": 500.0,
		"spin_speed": direction * TAU * 1.5,
		"x": start_pos.x,
		"y": start_pos.y,
		"vx": direction * 80.0,
		"vy": -180.0,
		"bounce_count": 0,
		"max_bounces": 3,
		"damping": 0.45,  # each bounce loses this much energy
		"done": false,
	}
	deco.set_meta("fling_data", phase_data)
	deco.set_meta("fling_time", 0.0)
	deco.set_meta("fling_fade_started", false)
	# Use a tween with a method to drive physics each frame
	var tween: Tween = create_tween()
	tween.tween_method(func(t: float) -> void:
		if not is_instance_valid(deco):
			return
		var d: Dictionary = deco.get_meta("fling_data")
		if d.done:
			return
		var dt: float = t - deco.get_meta("fling_time")
		deco.set_meta("fling_time", t)
		if dt <= 0.0:
			return
		# Apply gravity
		d.vy += d.gravity * dt
		d.x += d.vx * dt
		d.y += d.vy * dt
		# Spin
		deco.rotation += d.spin_speed * dt
		# Check ground collision
		if d.y >= d.ground_y and d.vy > 0.0:
			d.y = d.ground_y
			d.bounce_count += 1
			if d.bounce_count > d.max_bounces:
				d.done = true
				return
			# Bounce: reverse and dampen vertical velocity
			d.vy = -d.vy * d.damping
			d.vx *= 0.7
			d.spin_speed *= 0.5
			# Squash on impact
			deco.scale = Vector2(1.3, 0.6)
		else:
			# Gradually restore scale
			deco.scale = deco.scale.lerp(Vector2(1.0, 1.0), dt * 8.0)
		deco.position = Vector2(d.x, d.y)
		# Start a smooth tween fade after the first bounce
		if d.bounce_count >= 1 and not deco.get_meta("fling_fade_started"):
			deco.set_meta("fling_fade_started", true)
			var fade_tween: Tween = deco.create_tween()
			fade_tween.tween_property(deco, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	, 0.0, 1.8, 1.8)
	tween.tween_callback(deco.queue_free)
