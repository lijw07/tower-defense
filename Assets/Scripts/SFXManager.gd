extends Node
## SFXManager — autoload singleton for 8-bit sound effects and music.
## All audio is generated programmatically.
## Usage:  SFXManager.play("arrow_shoot")
##         SFXManager.play_music("menu")
##         SFXManager.stop_music()

const RATE: int = 44100

# Map of short names → AudioStreamWAV
var _sounds: Dictionary = {}

# Pool of AudioStreamPlayer nodes for concurrent SFX playback
var _players: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 8

# Dedicated music player (separate from SFX pool)
var _music_player: AudioStreamPlayer = null
var _current_music: String = ""

# Volume offsets (0.0 = full, applied on top of per-sound volume_db)
const MUSIC_MAX_DB: float = -18.0    # music cap — 100% slider = this dB level
var _music_volume_db: float = -18.0   # music plays quieter so SFX stay audible
var _sfx_volume_db: float = 0.0


func _ready() -> void:
	# Ensure audio keeps playing even when the scene tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Generate all SFX
	_sounds["arrow_shoot"] = _gen_arrow_shoot()
	_sounds["cannon_shoot"] = _gen_cannon_shoot()
	_sounds["magic_shoot"] = _gen_magic_shoot()
	_sounds["enemy_hit"] = _gen_enemy_hit()
	_sounds["enemy_death"] = _gen_enemy_death()
	_sounds["tower_place"] = _gen_tower_place()
	_sounds["tower_sell"] = _gen_tower_sell()
	_sounds["castle_hit"] = _gen_castle_hit()
	_sounds["armor_block"] = _gen_armor_block()
	_sounds["wave_start"] = _gen_wave_start()
	_sounds["game_over"] = _gen_game_over()
	_sounds["upgrade_buy"] = _gen_upgrade_buy()
	_sounds["button_click"] = _gen_button_click()
	_sounds["shop_open"] = _gen_shop_open()
	_sounds["shop_close"] = _gen_shop_close()
	_sounds["tree_chop"] = _gen_tree_chop()
	_sounds["rock_break"] = _gen_rock_break()
	_sounds["mushroom_pick"] = _gen_mushroom_pick()
	_sounds["nature_grow"] = _gen_nature_grow()
	_sounds["tower_destroy"] = _gen_tower_destroy()
	_sounds["boss_warning"] = _gen_boss_warning()
	_sounds["castle_evolve"] = _gen_castle_evolve()
	_sounds["castle_damage_impact"] = _gen_castle_damage_impact()
	_sounds["armor_deflect"] = _gen_armor_deflect()
	_sounds["castle_heal"] = _gen_castle_heal()
	_sounds["fireworks"] = _gen_fireworks()
	# Per-tower placement sounds
	_sounds["place_archer"] = _gen_place_archer()
	_sounds["place_crossbow"] = _gen_place_crossbow()
	_sounds["place_cannon"] = _gen_place_cannon()
	_sounds["place_poison"] = _gen_place_poison()
	_sounds["place_ice_wizard"] = _gen_place_ice_wizard()
	_sounds["place_lightning"] = _gen_place_lightning()

	# Generate music tracks
	_sounds["music_menu"] = _gen_music_menu()
	_sounds["music_gameplay"] = _gen_music_gameplay()

	# Create SFX player pool
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = &"Master"
		add_child(player)
		_players.append(player)

	# Create dedicated music player
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = &"Master"
	add_child(_music_player)


## Play a one-shot sound effect by name.
func play(sound_name: String, volume_db: float = 0.0) -> void:
	if not _sounds.has(sound_name):
		return
	var player := _get_free_player()
	if player == null:
		return
	player.stream = _sounds[sound_name]
	player.volume_db = volume_db + _sfx_volume_db
	player.play()


## Set SFX volume. linear 0.0–1.0 → dB scale.
func set_sfx_volume(linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	_sfx_volume_db = linear_to_db(linear) if linear > 0.0 else -80.0


## Set music volume. linear 0.0–1.0 maps to silence → MUSIC_MAX_DB.
func set_music_volume(linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	if linear <= 0.0:
		_music_volume_db = -80.0
	else:
		# Map 0→-80, 1→MUSIC_MAX_DB  (slider 100% = capped volume)
		_music_volume_db = linear_to_db(linear) + MUSIC_MAX_DB
	if _music_player and _music_player.playing:
		_music_player.volume_db = _music_volume_db


## Get current SFX volume as linear 0.0–1.0.
func get_sfx_volume_linear() -> float:
	return db_to_linear(_sfx_volume_db)


## Get current music volume as linear 0.0–1.0 (relative to MUSIC_MAX_DB cap).
func get_music_volume_linear() -> float:
	if _music_volume_db <= -80.0:
		return 0.0
	return db_to_linear(_music_volume_db - MUSIC_MAX_DB)


## Start looping background music. Pass "menu" or "gameplay".
func play_music(track_name: String, volume_db: float = 0.0) -> void:
	var key: String = "music_" + track_name
	if not _sounds.has(key):
		return
	if _current_music == track_name and _music_player.playing:
		return  # already playing this track
	_music_player.stream = _sounds[key]
	_music_player.volume_db = _music_volume_db
	_music_player.play()
	_current_music = track_name
	# Loop when finished
	if not _music_player.finished.is_connected(_on_music_finished):
		_music_player.finished.connect(_on_music_finished)


## Stop background music.
func stop_music() -> void:
	_music_player.stop()
	_current_music = ""


func _on_music_finished() -> void:
	if _current_music != "":
		_music_player.play()


func _get_free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return null


# ─── Helper functions ───

func _make_music_stream(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		var s: float = clampf(samples[i], -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream


func _make_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		var s: float = clampf(samples[i], -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream


func _env(t: float, attack: float, decay: float, sustain_lvl: float, sustain_dur: float, release: float) -> float:
	if t < attack:
		return t / attack if attack > 0.0 else 1.0
	t -= attack
	if t < decay:
		return 1.0 - (1.0 - sustain_lvl) * (t / decay) if decay > 0.0 else sustain_lvl
	t -= decay
	if t < sustain_dur:
		return sustain_lvl
	t -= sustain_dur
	if t < release:
		return sustain_lvl * (1.0 - t / release) if release > 0.0 else 0.0
	return 0.0


func _square(t: float, freq: float) -> float:
	return 1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0


func _triangle(t: float, freq: float) -> float:
	return 4.0 * absf(fmod(t * freq, 1.0) - 0.5) - 1.0


func _noise() -> float:
	return randf_range(-1.0, 1.0)


# Helper: convert MIDI note number to frequency
func _mtof(note: int) -> float:
	return 440.0 * pow(2.0, float(note - 69) / 12.0)


# ─── SFX generators ───

func _gen_arrow_shoot() -> AudioStreamWAV:
	var dur: float = 0.15
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var freq: float = 800.0 + 1200.0 * (1.0 - t / dur)
		var e: float = _env(t, 0.005, 0.05, 0.4, 0.0, 0.1)
		var s: float = _square(t, freq) * 0.3 + _noise() * 0.15
		samples[i] = s * e * 0.8
	return _make_stream(samples)


func _gen_cannon_shoot() -> AudioStreamWAV:
	var dur: float = 0.3
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var freq: float = 120.0 - 80.0 * (t / dur)
		var e: float = _env(t, 0.002, 0.08, 0.3, 0.05, 0.15)
		var s: float = _square(t, freq) * 0.4 + _noise() * 0.4
		samples[i] = s * e * 0.9
	return _make_stream(samples)


func _gen_magic_shoot() -> AudioStreamWAV:
	var dur: float = 0.25
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var freq: float = 400.0 + 600.0 * sin(t * 30.0)
		var e: float = _env(t, 0.01, 0.05, 0.5, 0.05, 0.1)
		var s: float = sin(2.0 * PI * freq * t) * 0.5 + _triangle(t, freq * 1.5) * 0.3
		samples[i] = s * e * 0.7
	return _make_stream(samples)


func _gen_enemy_hit() -> AudioStreamWAV:
	var dur: float = 0.12
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var freq: float = 300.0 - 200.0 * (t / dur)
		var e: float = _env(t, 0.001, 0.03, 0.3, 0.0, 0.09)
		var s: float = _square(t, freq) * 0.5 + _noise() * 0.2
		samples[i] = s * e * 0.8
	return _make_stream(samples)


func _gen_enemy_death() -> AudioStreamWAV:
	var dur: float = 0.35
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var freq: float = 500.0 - 400.0 * (t / dur)
		var e: float = _env(t, 0.002, 0.05, 0.4, 0.1, 0.2)
		var s: float = _square(t, freq) * 0.3 + _noise() * 0.3
		samples[i] = s * e * 0.8
	return _make_stream(samples)


func _gen_tower_place() -> AudioStreamWAV:
	var dur: float = 0.2
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var freq: float = 300.0 + 400.0 * (t / dur)
		var e: float = _env(t, 0.005, 0.05, 0.5, 0.05, 0.1)
		var s: float = _triangle(t, freq) * 0.6 + _square(t, freq * 2.0) * 0.2
		samples[i] = s * e * 0.7
	return _make_stream(samples)


func _gen_tower_sell() -> AudioStreamWAV:
	var dur: float = 0.2
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var freq: float = 600.0 - 300.0 * (t / dur)
		var e: float = _env(t, 0.005, 0.05, 0.5, 0.05, 0.1)
		var s: float = _triangle(t, freq) * 0.5 + sin(2.0 * PI * freq * 0.5 * t) * 0.3
		samples[i] = s * e * 0.7
	return _make_stream(samples)


func _gen_tower_destroy() -> AudioStreamWAV:
	# Heavy crumbling/destruction sound — low rumble + crunch + debris scatter
	var dur: float = 0.6
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		# Low rumble that drops in pitch
		var rumble_freq: float = 100.0 - 50.0 * (t / dur)
		var rumble: float = _square(t, rumble_freq) * 0.3
		# Crunchy noise burst at the start
		var crunch_env: float = _env(t, 0.002, 0.08, 0.4, 0.1, 0.15)
		var crunch: float = _noise() * crunch_env * 0.5
		# Mid-frequency cracking sounds
		var crack_freq: float = 200.0 + 150.0 * sin(t * 25.0)
		var crack_env: float = _env(t, 0.01, 0.1, 0.3, 0.15, 0.25)
		var crack: float = _triangle(t, crack_freq) * crack_env * 0.3
		# Overall envelope
		var main_env: float = _env(t, 0.005, 0.1, 0.5, 0.15, 0.25)
		samples[i] = (rumble + crunch + crack) * main_env * 0.8
	return _make_stream(samples)


func _gen_boss_warning() -> AudioStreamWAV:
	# Deep war-horn alarm — two descending blasts with rumble
	var dur: float = 1.2
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		# Two horn blasts: 0.0–0.45s and 0.55–1.0s
		var horn: float = 0.0
		var blast1_t: float = t
		var blast2_t: float = t - 0.55
		if blast1_t >= 0.0 and blast1_t < 0.45:
			var freq: float = 120.0 - 30.0 * (blast1_t / 0.45)
			var e: float = _env(blast1_t, 0.02, 0.05, 0.7, 0.2, 0.18)
			horn += (_square(blast1_t, freq) * 0.4 + _triangle(blast1_t, freq * 2.0) * 0.2) * e
		if blast2_t >= 0.0 and blast2_t < 0.45:
			var freq: float = 100.0 - 25.0 * (blast2_t / 0.45)
			var e: float = _env(blast2_t, 0.02, 0.05, 0.75, 0.2, 0.18)
			horn += (_square(blast2_t, freq) * 0.45 + _triangle(blast2_t, freq * 2.0) * 0.2) * e
		# Underlying rumble throughout
		var rumble_env: float = _env(t, 0.05, 0.1, 0.4, 0.7, 0.35)
		var rumble: float = _square(t, 55.0 + 10.0 * sin(t * 6.0)) * 0.15 * rumble_env
		samples[i] = (horn + rumble) * 0.8
	return _make_stream(samples)


func _gen_castle_hit() -> AudioStreamWAV:
	var dur: float = 0.4
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var freq: float = 80.0 + 40.0 * sin(t * 15.0)
		var e: float = _env(t, 0.002, 0.1, 0.4, 0.1, 0.2)
		var s: float = _square(t, freq) * 0.5 + _noise() * 0.3
		samples[i] = s * e * 0.9
	return _make_stream(samples)


func _gen_armor_block() -> AudioStreamWAV:
	var dur: float = 0.2
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var freq: float = 1000.0 + 500.0 * (t / dur)
		var e: float = _env(t, 0.001, 0.03, 0.5, 0.05, 0.1)
		var s: float = _triangle(t, freq) * 0.5 + _square(t, freq * 0.5) * 0.3
		samples[i] = s * e * 0.8
	return _make_stream(samples)


func _gen_wave_start() -> AudioStreamWAV:
	var dur: float = 0.5
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var freq: float = 523.25 if t < 0.25 else 659.25
		var e: float = _env(t, 0.01, 0.05, 0.6, 0.2, 0.2)
		var s: float = _square(t, freq) * 0.4 + _triangle(t, freq) * 0.3
		samples[i] = s * e * 0.7
	return _make_stream(samples)


func _gen_game_over() -> AudioStreamWAV:
	var dur: float = 0.8
	var notes: Array[float] = [400.0, 350.0, 300.0, 200.0]
	var note_dur: float = dur / float(notes.size())
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var note_idx: int = mini(int(t / note_dur), notes.size() - 1)
		var freq: float = notes[note_idx]
		var local_t: float = t - float(note_idx) * note_dur
		var e: float = _env(local_t, 0.005, 0.03, 0.5, note_dur * 0.5, note_dur * 0.3)
		var s: float = _square(t, freq) * 0.4 + _triangle(t, freq * 0.5) * 0.3
		samples[i] = s * e * 0.8
	return _make_stream(samples)


func _gen_upgrade_buy() -> AudioStreamWAV:
	var dur: float = 0.25
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var freq: float
		if t < 0.08:
			freq = 523.0
		elif t < 0.16:
			freq = 659.0
		else:
			freq = 784.0
		var e: float = _env(t, 0.005, 0.03, 0.6, 0.1, 0.1)
		var s: float = _triangle(t, freq) * 0.5 + _square(t, freq) * 0.2
		samples[i] = s * e * 0.7
	return _make_stream(samples)


func _gen_button_click() -> AudioStreamWAV:
	var dur: float = 0.06
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var freq: float = 1200.0
		var e: float = _env(t, 0.001, 0.02, 0.3, 0.0, 0.04)
		var s: float = _square(t, freq) * 0.4
		samples[i] = s * e * 0.7
	return _make_stream(samples)


func _gen_shop_open() -> AudioStreamWAV:
	# Rising sparkle / page-flip sound
	var dur: float = 0.2
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var freq: float = 400.0 + 800.0 * (t / dur)
		var e: float = _env(t, 0.005, 0.03, 0.5, 0.08, 0.08)
		var s: float = _triangle(t, freq) * 0.4 + _square(t, freq * 2.0) * 0.15
		samples[i] = s * e * 0.6
	return _make_stream(samples)


func _gen_shop_close() -> AudioStreamWAV:
	# Falling tone
	var dur: float = 0.15
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var freq: float = 800.0 - 500.0 * (t / dur)
		var e: float = _env(t, 0.003, 0.03, 0.4, 0.04, 0.08)
		var s: float = _triangle(t, freq) * 0.4 + _square(t, freq * 0.5) * 0.15
		samples[i] = s * e * 0.5
	return _make_stream(samples)


func _gen_tree_chop() -> AudioStreamWAV:
	# Two-hit axe chop: percussive wood crack with a leafy rustle tail
	var dur: float = 0.35
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var s: float = 0.0
		# First chop hit at t=0
		if t < 0.12:
			var freq: float = 250.0 - 150.0 * (t / 0.12)
			var e: float = _env(t, 0.002, 0.02, 0.4, 0.02, 0.07)
			s += (_square(t, freq) * 0.3 + _noise() * 0.35) * e
		# Second chop hit at t=0.12
		var t2: float = t - 0.12
		if t2 > 0.0 and t2 < 0.1:
			var freq2: float = 200.0 - 120.0 * (t2 / 0.1)
			var e2: float = _env(t2, 0.002, 0.02, 0.5, 0.02, 0.06)
			s += (_square(t, freq2) * 0.35 + _noise() * 0.3) * e2
		# Leafy rustle tail (filtered noise, fading)
		var t3: float = t - 0.15
		if t3 > 0.0:
			var rustle_e: float = _env(t3, 0.01, 0.05, 0.3, 0.05, 0.1)
			s += _noise() * rustle_e * 0.2
		samples[i] = s * 0.85
	return _make_stream(samples)


func _gen_rock_break() -> AudioStreamWAV:
	# Heavy stone crumble: low thud followed by cracking debris
	var dur: float = 0.4
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var s: float = 0.0
		# Deep impact thud
		if t < 0.15:
			var freq: float = 80.0 + 60.0 * (1.0 - t / 0.15)
			var e: float = _env(t, 0.001, 0.04, 0.5, 0.03, 0.08)
			s += (_square(t, freq) * 0.5 + _noise() * 0.3) * e
		# Cracking debris (multiple short bursts)
		for hit in range(4):
			var offset: float = 0.06 + float(hit) * 0.06
			var th: float = t - offset
			if th > 0.0 and th < 0.08:
				var crack_freq: float = 350.0 + float(hit) * 80.0
				var ce: float = _env(th, 0.001, 0.01, 0.3, 0.01, 0.05)
				s += (_square(t, crack_freq) * 0.2 + _noise() * 0.25) * ce
		# Rumble tail
		var t4: float = t - 0.2
		if t4 > 0.0:
			var rumble_e: float = _env(t4, 0.01, 0.05, 0.25, 0.05, 0.1)
			s += (_square(t, 50.0) * 0.2 + _noise() * 0.15) * rumble_e
		samples[i] = s * 0.9
	return _make_stream(samples)


func _gen_mushroom_pick() -> AudioStreamWAV:
	# Soft pluck with a gentle pop — light and quick
	var dur: float = 0.18
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var s: float = 0.0
		# Soft pop
		var pop_freq: float = 600.0 + 400.0 * (1.0 - t / dur)
		var pop_e: float = _env(t, 0.003, 0.02, 0.4, 0.03, 0.12)
		s += _triangle(t, pop_freq) * pop_e * 0.5
		# Tiny sparkle overtone
		if t < 0.1:
			var spark_e: float = _env(t, 0.002, 0.015, 0.3, 0.02, 0.06)
			s += _triangle(t, 1200.0 + 300.0 * sin(t * 40.0)) * spark_e * 0.2
		samples[i] = s * 0.7
	return _make_stream(samples)


func _gen_nature_grow() -> AudioStreamWAV:
	# Gentle ascending sparkle — nature sprouting / growing
	var dur: float = 0.45
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var s: float = 0.0
		# Rising shimmer — triangle wave ascending from 300 to 900 Hz
		var rise_freq: float = 300.0 + 600.0 * (t / dur)
		var rise_e: float = _env(t, 0.02, 0.1, 0.6, 0.15, 0.3)
		s += _triangle(t, rise_freq) * rise_e * 0.35
		# Soft chime layer — two quick ascending notes
		if t < 0.2:
			var chime_e: float = _env(t, 0.005, 0.03, 0.5, 0.05, 0.15)
			s += _triangle(t, 800.0 + 400.0 * (t / 0.2)) * chime_e * 0.25
		# Leafy rustle tail — filtered noise
		if t > 0.15:
			var rustle_t: float = t - 0.15
			var rustle_e: float = _env(rustle_t, 0.02, 0.05, 0.3, 0.08, 0.2)
			s += _noise() * rustle_e * 0.1
		samples[i] = s * 0.6
	return _make_stream(samples)

func _gen_castle_evolve() -> AudioStreamWAV:
	# Majestic ascending fanfare — castle upgrades to a new tier
	var dur: float = 0.7
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	# Notes: C5 → E5 → G5 → C6 (triumphant major arpeggio)
	var notes: Array[float] = [523.25, 659.25, 783.99, 1046.50]
	var note_dur: float = 0.15
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var s: float = 0.0
		# Staggered note hits
		for n in range(notes.size()):
			var offset: float = float(n) * note_dur
			var nt: float = t - offset
			if nt >= 0.0 and nt < 0.35:
				var e: float = _env(nt, 0.008, 0.04, 0.55, 0.12, 0.2)
				s += _triangle(t, notes[n]) * e * 0.25
				s += _square(t, notes[n] * 2.0) * e * 0.08
		# Shimmer overtone on top
		if t > 0.3:
			var shimmer_t: float = t - 0.3
			var shimmer_e: float = _env(shimmer_t, 0.02, 0.05, 0.3, 0.15, 0.2)
			s += _triangle(t, 1200.0 + 400.0 * sin(t * 20.0)) * shimmer_e * 0.12
		# Rumble base for weight
		if t < 0.5:
			var rumble_e: float = _env(t, 0.01, 0.1, 0.3, 0.2, 0.2)
			s += _square(t, 130.0) * rumble_e * 0.1
		samples[i] = s * 0.8
	return _make_stream(samples)


func _gen_castle_heal() -> AudioStreamWAV:
	# Warm ascending chime — gentle healing sparkle with harmonic shimmer
	var dur: float = 0.6
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	# Ascending notes: C5 → E5 → G5 (major triad, soft and warm)
	var notes: Array[float] = [523.25, 659.25, 783.99]
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var s: float = 0.0
		# Three overlapping chime notes with staggered onsets
		for n in range(notes.size()):
			var onset: float = float(n) * 0.1
			var nt: float = t - onset
			if nt < 0.0:
				continue
			var note_dur: float = 0.4 - float(n) * 0.05
			if nt > note_dur:
				continue
			var env: float = _env(nt, 0.008, 0.04, 0.5, 0.1, note_dur - 0.15)
			# Soft sine + gentle triangle overtone for warmth
			s += sin(2.0 * PI * notes[n] * nt) * env * 0.3
			s += _triangle(nt, notes[n] * 2.0) * env * 0.08
		# Sparkle layer — high-frequency shimmer throughout
		if t > 0.05 and t < 0.5:
			var sparkle_t: float = t - 0.05
			var sparkle_e: float = _env(sparkle_t, 0.02, 0.06, 0.2, 0.15, 0.28)
			s += _triangle(t, 1760.0 + 300.0 * sin(t * 18.0)) * sparkle_e * 0.06
		samples[i] = s * 0.8
	return _make_stream(samples)


func _gen_fireworks() -> AudioStreamWAV:
	# Grand celebratory fireworks — 3-second show with staggered booms, crackle,
	# sparkle shimmer, and a triumphant fanfare undertone.
	var dur: float = 3.2
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	# 8 staggered firework bursts spread across the full duration
	var burst_times: Array[float] = [0.0, 0.3, 0.55, 0.85, 1.15, 1.5, 1.9, 2.35]
	var burst_freqs: Array[float] = [300.0, 370.0, 260.0, 340.0, 310.0, 380.0, 290.0, 350.0]
	# Ascending fanfare notes (C5 E5 G5 C6) for triumphant feel
	var fanfare_notes: Array[float] = [523.25, 659.25, 783.99, 1046.5]
	var fanfare_times: Array[float] = [0.1, 0.6, 1.2, 1.9]
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var s: float = 0.0
		# Each firework burst — pop + crackle + long sparkle tail
		for b in range(burst_times.size()):
			var bt: float = t - burst_times[b]
			if bt < 0.0 or bt > 0.7:
				continue
			# Big initial boom — loud noise pop
			if bt < 0.06:
				var pop_e: float = _env(bt, 0.001, 0.01, 0.75, 0.015, 0.03)
				s += _noise() * pop_e * 0.35
				s += _square(bt, 90.0) * pop_e * 0.15  # sub-bass thump
			# Extended crackle — staccato noise bursts
			if bt > 0.03 and bt < 0.4:
				var crackle_t: float = bt - 0.03
				var crackle_e: float = _env(crackle_t, 0.005, 0.04, 0.3, 0.12, 0.25)
				s += _noise() * crackle_e * 0.18 * (0.5 + 0.5 * sin(bt * burst_freqs[b] * 3.0))
			# Long sparkle shimmer tail — high frequencies decaying slowly
			if bt > 0.05 and bt < 0.65:
				var sparkle_t: float = bt - 0.05
				var sparkle_e: float = _env(sparkle_t, 0.02, 0.06, 0.2, 0.2, 0.4)
				var freq: float = burst_freqs[b] * 4.0 + 300.0 * sin(bt * 15.0)
				s += _triangle(t, freq) * sparkle_e * 0.07
				# Secondary shimmer at a different frequency
				s += sin(2.0 * PI * (freq * 1.5) * t) * sparkle_e * 0.03
		# Fanfare — gentle ascending chime notes for triumphant feel
		for n in range(fanfare_notes.size()):
			var ft: float = t - fanfare_times[n]
			if ft < 0.0 or ft > 0.6:
				continue
			var fan_e: float = _env(ft, 0.01, 0.05, 0.15, 0.15, 0.35)
			s += sin(2.0 * PI * fanfare_notes[n] * ft) * fan_e * 0.12
			s += _triangle(ft, fanfare_notes[n] * 2.0) * fan_e * 0.03
		# Low celebratory rumble throughout
		if t > 0.05 and t < 2.8:
			var rumble_e: float = _env(t - 0.05, 0.08, 0.3, 0.1, 0.8, 1.5)
			s += _square(t, 50.0 + 10.0 * sin(t * 4.0)) * rumble_e * 0.06
		# Final shimmer fadeout
		if t > 2.4 and t < 3.2:
			var tail_t: float = t - 2.4
			var tail_e: float = _env(tail_t, 0.05, 0.1, 0.1, 0.3, 0.5)
			s += _triangle(t, 1400.0 + 500.0 * sin(t * 10.0)) * tail_e * 0.04
		samples[i] = s * 0.8
	return _make_stream(samples)


func _gen_castle_damage_impact() -> AudioStreamWAV:
	# Heavy impact layered on top of castle_hit — deep crunch + rumble + debris scatter
	var dur: float = 0.5
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var s: float = 0.0
		# Deep impact thud — sub-bass punch
		if t < 0.2:
			var thud_freq: float = 55.0 + 30.0 * (1.0 - t / 0.2)
			var thud_e: float = _env(t, 0.001, 0.03, 0.6, 0.05, 0.12)
			s += _square(t, thud_freq) * thud_e * 0.45
		# Stone crunch — noisy mid-frequency burst
		if t < 0.15:
			var crunch_freq: float = 180.0 - 100.0 * (t / 0.15)
			var crunch_e: float = _env(t, 0.001, 0.02, 0.5, 0.03, 0.1)
			s += (_square(t, crunch_freq) * 0.25 + _noise() * 0.4) * crunch_e
		# Debris scatter — rapid short noise bursts
		for hit in range(5):
			var offset: float = 0.04 + float(hit) * 0.05
			var th: float = t - offset
			if th > 0.0 and th < 0.06:
				var debris_e: float = _env(th, 0.001, 0.01, 0.35, 0.01, 0.04)
				s += _noise() * debris_e * 0.2
		# Low rumble tail
		if t > 0.12:
			var rumble_t: float = t - 0.12
			var rumble_e: float = _env(rumble_t, 0.02, 0.08, 0.25, 0.1, 0.18)
			s += _square(t, 45.0 + 10.0 * sin(t * 8.0)) * rumble_e * 0.15
		samples[i] = s * 0.85
	return _make_stream(samples)


func _gen_armor_deflect() -> AudioStreamWAV:
	# Metallic clang + shimmering ring — sharp shield deflection
	var dur: float = 0.35
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var s: float = 0.0
		# Sharp metallic strike — high triangle wave with quick attack
		if t < 0.12:
			var strike_freq: float = 1400.0 + 200.0 * (1.0 - t / 0.12)
			var strike_e: float = _env(t, 0.001, 0.015, 0.55, 0.03, 0.07)
			s += _triangle(t, strike_freq) * strike_e * 0.4
			# Overtone for metallic bite
			s += _square(t, strike_freq * 2.5) * strike_e * 0.12
		# Ringing resonance — decaying sine at shield frequency
		var ring_freq: float = 880.0 + 60.0 * sin(t * 12.0)
		var ring_e: float = _env(t, 0.005, 0.04, 0.4, 0.1, 0.2)
		s += sin(2.0 * PI * ring_freq * t) * ring_e * 0.3
		# Second harmonic shimmer
		s += _triangle(t, ring_freq * 1.5) * ring_e * 0.1
		# Bright sparkle tail
		if t > 0.08 and t < 0.3:
			var sparkle_t: float = t - 0.08
			var sparkle_e: float = _env(sparkle_t, 0.01, 0.03, 0.25, 0.06, 0.12)
			s += _triangle(t, 2200.0 + 500.0 * sin(t * 25.0)) * sparkle_e * 0.08
		samples[i] = s * 0.75
	return _make_stream(samples)


# ─── Per-tower placement sounds ───

func _gen_place_archer() -> AudioStreamWAV:
	# Quick wooden thunk + string twang
	var dur: float = 0.25
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var s: float = 0.0
		# Wooden thud
		if t < 0.06:
			var e: float = _env(t, 0.001, 0.01, 0.6, 0.01, 0.03)
			s += _square(t, 120.0) * e * 0.3
		# String twang — decaying sine
		var twang_e: float = _env(t, 0.005, 0.02, 0.4, 0.06, 0.15)
		s += sin(2.0 * PI * 440.0 * t) * twang_e * 0.25
		s += _triangle(t, 880.0) * twang_e * 0.08
		samples[i] = s * 0.8
	return _make_stream(samples)


func _gen_place_crossbow() -> AudioStreamWAV:
	# Mechanical click + tight string snap
	var dur: float = 0.2
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var s: float = 0.0
		# Metallic click
		if t < 0.03:
			var e: float = _env(t, 0.001, 0.005, 0.7, 0.005, 0.01)
			s += _square(t, 800.0) * e * 0.3
			s += _noise() * e * 0.2
		# Tight snap
		if t > 0.02 and t < 0.12:
			var st: float = t - 0.02
			var e: float = _env(st, 0.002, 0.015, 0.45, 0.03, 0.06)
			s += sin(2.0 * PI * 600.0 * t) * e * 0.25
			s += _triangle(t, 1200.0) * e * 0.1
		samples[i] = s * 0.8
	return _make_stream(samples)


func _gen_place_cannon() -> AudioStreamWAV:
	# Heavy metallic clang + deep thud
	var dur: float = 0.3
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var s: float = 0.0
		# Deep impact thud
		if t < 0.1:
			var e: float = _env(t, 0.001, 0.02, 0.6, 0.02, 0.06)
			s += _square(t, 70.0) * e * 0.4
		# Heavy metal clang
		var clang_e: float = _env(t, 0.002, 0.02, 0.5, 0.08, 0.18)
		s += _triangle(t, 350.0) * clang_e * 0.25
		s += sin(2.0 * PI * 700.0 * t) * clang_e * 0.1
		samples[i] = s * 0.8
	return _make_stream(samples)


func _gen_place_poison() -> AudioStreamWAV:
	# Bubbly gurgle + hiss
	var dur: float = 0.3
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var s: float = 0.0
		# Bubbling — rapid wobbling tone
		var bubble_e: float = _env(t, 0.01, 0.04, 0.4, 0.08, 0.16)
		var bubble_freq: float = 250.0 + 150.0 * sin(t * 45.0)
		s += _square(t, bubble_freq) * bubble_e * 0.2
		# Hiss layer
		if t > 0.03 and t < 0.25:
			var hiss_t: float = t - 0.03
			var hiss_e: float = _env(hiss_t, 0.01, 0.03, 0.2, 0.06, 0.14)
			s += _noise() * hiss_e * 0.15
		# Low drip
		if t < 0.08:
			var drip_e: float = _env(t, 0.002, 0.01, 0.35, 0.02, 0.04)
			s += sin(2.0 * PI * 180.0 * t) * drip_e * 0.2
		samples[i] = s * 0.8
	return _make_stream(samples)


func _gen_place_ice_wizard() -> AudioStreamWAV:
	# Crystalline chime + frosty shimmer
	var dur: float = 0.35
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var s: float = 0.0
		# Crystal chime — high sine
		var chime_e: float = _env(t, 0.003, 0.02, 0.45, 0.1, 0.2)
		s += sin(2.0 * PI * 1200.0 * t) * chime_e * 0.25
		s += _triangle(t, 2400.0) * chime_e * 0.08
		# Frosty shimmer — wobbling high tone
		if t > 0.04 and t < 0.3:
			var sh_t: float = t - 0.04
			var sh_e: float = _env(sh_t, 0.01, 0.04, 0.2, 0.08, 0.16)
			var sh_freq: float = 1800.0 + 400.0 * sin(t * 20.0)
			s += _triangle(t, sh_freq) * sh_e * 0.1
		# Soft low body
		if t < 0.15:
			var body_e: float = _env(t, 0.005, 0.03, 0.25, 0.03, 0.08)
			s += sin(2.0 * PI * 300.0 * t) * body_e * 0.15
		samples[i] = s * 0.8
	return _make_stream(samples)


func _gen_place_lightning() -> AudioStreamWAV:
	# Electric crackle + sharp zap
	var dur: float = 0.25
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * dur))
	for i in range(samples.size()):
		var t: float = float(i) / float(RATE)
		var s: float = 0.0
		# Sharp zap — quick descending tone
		if t < 0.08:
			var zap_e: float = _env(t, 0.001, 0.01, 0.6, 0.02, 0.04)
			var zap_freq: float = 1500.0 - 800.0 * (t / 0.08)
			s += _square(t, zap_freq) * zap_e * 0.25
		# Electric crackle — noisy bursts
		if t < 0.2:
			var crack_e: float = _env(t, 0.002, 0.02, 0.35, 0.06, 0.12)
			s += _noise() * crack_e * 0.25 * (0.5 + 0.5 * sin(t * 200.0))
		# Buzzy resonance tail
		if t > 0.05 and t < 0.22:
			var buzz_t: float = t - 0.05
			var buzz_e: float = _env(buzz_t, 0.01, 0.03, 0.2, 0.05, 0.1)
			s += _square(t, 180.0 + 60.0 * sin(t * 30.0)) * buzz_e * 0.12
		samples[i] = s * 0.8
	return _make_stream(samples)


# ─── Music generators ───

func _gen_music_menu() -> AudioStreamWAV:
	# Chill 8-bit menu loop — arpeggiated chords with a melody on top
	# ~9.6 seconds at 100 BPM (4 bars), generated at 22050 Hz for speed
	var rate: int = 22050
	var bpm: float = 100.0
	var beat: float = 60.0 / bpm
	var bars: int = 4
	var dur: float = bars * 4.0 * beat
	var total_samples: int = int(rate * dur)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	# Chord progression (MIDI notes): Am - F - C - G
	var chords: Array = [
		[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62],
	]

	# Simple melody (MIDI notes per bar, 4 notes each at quarter-note pace)
	var melody: Array = [
		[72, 71, 69, 67],
		[65, 64, 65, 69],
		[67, 64, 60, 64],
		[67, 66, 67, 71],
	]

	var bar_dur: float = 4.0 * beat

	for i in range(total_samples):
		var t: float = float(i) / float(rate)
		var bar_idx: int = mini(int(t / bar_dur), bars - 1)
		var bar_t: float = t - float(bar_idx) * bar_dur
		var s: float = 0.0

		# ── Arpeggio layer (triangle wave, 16th note pattern) ──
		var arp_notes: Array = chords[bar_idx]
		var sixteenth: float = beat / 4.0
		var arp_step: int = int(bar_t / sixteenth) % (arp_notes.size() * 2)
		var arp_idx: int
		if arp_step < arp_notes.size():
			arp_idx = arp_step
		else:
			arp_idx = arp_notes.size() * 2 - 1 - arp_step
		arp_idx = clampi(arp_idx, 0, arp_notes.size() - 1)
		var arp_freq: float = _mtof(arp_notes[arp_idx])
		var arp_local_t: float = fmod(bar_t, sixteenth)
		var arp_env: float = _env(arp_local_t, 0.005, 0.02, 0.3, sixteenth * 0.4, sixteenth * 0.3)
		s += _triangle(t, arp_freq) * arp_env * 0.2

		# ── Bass layer (square wave, root of chord, half notes) ──
		var bass_note: int = chords[bar_idx][0] - 12
		var bass_freq: float = _mtof(bass_note)
		var half_note: float = beat * 2.0
		var bass_local_t: float = fmod(bar_t, half_note)
		var bass_env: float = _env(bass_local_t, 0.005, 0.1, 0.4, half_note * 0.4, half_note * 0.3)
		s += _square(t, bass_freq) * bass_env * 0.15

		# ── Melody layer (square wave, quarter notes) ──
		var mel_notes: Array = melody[bar_idx]
		var mel_step: int = mini(int(bar_t / beat), mel_notes.size() - 1)
		var mel_freq: float = _mtof(mel_notes[mel_step])
		var mel_local_t: float = fmod(bar_t, beat)
		var mel_env: float = _env(mel_local_t, 0.01, 0.05, 0.5, beat * 0.4, beat * 0.3)
		s += _square(t, mel_freq) * mel_env * 0.18

		samples[i] = s

	return _make_music_stream(samples, rate)


func _gen_music_gameplay() -> AudioStreamWAV:
	# Energetic 8-bit gameplay loop — faster, driving feel
	# ~6.9 seconds at 140 BPM (4 bars), generated at 22050 Hz for speed
	var rate: int = 22050
	var bpm: float = 140.0
	var beat: float = 60.0 / bpm
	var bars: int = 4
	var dur: float = bars * 4.0 * beat
	var total_samples: int = int(rate * dur)
	var samples := PackedFloat32Array()
	samples.resize(total_samples)

	# Dm - Bb - F - C
	var chords: Array = [
		[62, 65, 69], [58, 62, 65], [53, 57, 60], [48, 52, 55],
	]

	# Driving melody
	var melody: Array = [
		[74, 72, 69, 72],
		[70, 69, 70, 74],
		[72, 69, 65, 69],
		[72, 67, 64, 67],
	]

	var bar_dur: float = 4.0 * beat

	for i in range(total_samples):
		var t: float = float(i) / float(rate)
		var bar_idx: int = mini(int(t / bar_dur), bars - 1)
		var bar_t: float = t - float(bar_idx) * bar_dur
		var s: float = 0.0

		# ── Fast arpeggio (triangle, 16th notes) ──
		var arp_notes: Array = chords[bar_idx]
		var sixteenth: float = beat / 4.0
		var arp_step: int = int(bar_t / sixteenth) % (arp_notes.size() * 2)
		var arp_idx: int
		if arp_step < arp_notes.size():
			arp_idx = arp_step
		else:
			arp_idx = arp_notes.size() * 2 - 1 - arp_step
		arp_idx = clampi(arp_idx, 0, arp_notes.size() - 1)
		var arp_freq: float = _mtof(arp_notes[arp_idx])
		var arp_local_t: float = fmod(bar_t, sixteenth)
		var arp_env: float = _env(arp_local_t, 0.003, 0.015, 0.35, sixteenth * 0.3, sixteenth * 0.3)
		s += _triangle(t, arp_freq) * arp_env * 0.2

		# ── Punchy bass (square, 8th notes alternating root/fifth) ──
		var bass_root: int = chords[bar_idx][0] - 12
		var bass_fifth: int = bass_root + 7
		var eighth: float = beat / 2.0
		var bass_step: int = int(bar_t / eighth) % 2
		var bass_freq: float = _mtof(bass_root) if bass_step == 0 else _mtof(bass_fifth)
		var bass_local_t: float = fmod(bar_t, eighth)
		var bass_env: float = _env(bass_local_t, 0.003, 0.05, 0.4, eighth * 0.3, eighth * 0.3)
		s += _square(t, bass_freq) * bass_env * 0.18

		# ── Melody (square, quarter notes) ──
		var mel_notes: Array = melody[bar_idx]
		var mel_step: int = mini(int(bar_t / beat), mel_notes.size() - 1)
		var mel_freq: float = _mtof(mel_notes[mel_step])
		var mel_local_t: float = fmod(bar_t, beat)
		var mel_env: float = _env(mel_local_t, 0.008, 0.04, 0.5, beat * 0.35, beat * 0.25)
		s += _square(t, mel_freq) * mel_env * 0.2

		# ── Hi-hat noise on 8th notes ──
		var hat_local_t: float = fmod(bar_t, eighth)
		var hat_env: float = _env(hat_local_t, 0.001, 0.015, 0.0, 0.0, 0.0)
		s += _noise() * hat_env * 0.08

		samples[i] = s

	return _make_music_stream(samples, rate)
