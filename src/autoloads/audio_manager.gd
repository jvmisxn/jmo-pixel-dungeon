class_name AudioManagerNode
extends Node
## Audio manager singleton for Shattered Pixel Dungeon.
## Loads real SPD sound effects (MP3) and music tracks (OGG) from assets.
## Falls back to procedural generation only if real assets are missing.
## Supports per-region music with weighted random track selection matching
## the original Java source's Music.INSTANCE.playTracks() pattern.

# --- Audio Bus Names ---
const BUS_SFX: String = "SFX"
const BUS_MUSIC: String = "Music"

# --- Volume (linear 0.0–1.0) ---
var sfx_volume: float = 0.8
var music_volume: float = 0.5
var sfx_muted: bool = false
var music_muted: bool = false

# --- Internal ---
var _sfx_player_pool: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer = null
var _crossfade_player: AudioStreamPlayer = null
var _sfx_cache: Dictionary[String, AudioStream] = {}
var _music_cache: Dictionary[String, AudioStream] = {}
var _current_music_track: String = ""
var _current_region_tracks: Array[String] = []
var _crossfade_tween: Tween = null

const POOL_SIZE: int = 8
const SAMPLE_RATE: int = 22050
const CROSSFADE_DURATION: float = 1.5

# --- Asset Paths ---
const SFX_DIR: String = "res://assets/spd/sounds/"
const MUSIC_DIR: String = "res://assets/spd/music/"
const SFX_EXTENSIONS: Array[String] = ["mp3", "wav", "ogg"]
const MUSIC_EXTENSIONS: Array[String] = ["ogg", "mp3", "wav"]
const SFX_MANIFEST: Array[String] = [
	"alert",
	"atk_crossbow",
	"atk_spiritbow",
	"badge",
	"beacon",
	"bee",
	"blast",
	"bones",
	"boss",
	"burning",
	"chains",
	"challenge",
	"chargeup",
	"charms",
	"click",
	"cursed",
	"death",
	"debuff",
	"degrade",
	"descend",
	"dewdrop",
	"door_open",
	"drink",
	"eat",
	"evoke",
	"falling",
	"gas",
	"ghost",
	"gold",
	"grass",
	"health_critical",
	"health_warn",
	"hit",
	"hit_arrow",
	"hit_crush",
	"hit_magic",
	"hit_parry",
	"hit_slash",
	"hit_stab",
	"hit_strong",
	"item",
	"levelup",
	"lightning",
	"lullaby",
	"mastery",
	"meld",
	"mimic",
	"mine",
	"miss",
	"plant",
	"puff",
	"ray",
	"read",
	"rocks",
	"scan",
	"secret",
	"shatter",
	"sheep",
	"step",
	"sturdy",
	"teleport",
	"tomb",
	"trample",
	"trap",
	"unlock",
	"water",
	"zap",
]
const MUSIC_MANIFEST: Array[String] = [
	"caves_1",
	"caves_2",
	"caves_3",
	"caves_boss",
	"caves_boss_finale",
	"caves_tense",
	"city_1",
	"city_2",
	"city_3",
	"city_boss",
	"city_boss_finale",
	"city_tense",
	"halls_1",
	"halls_2",
	"halls_3",
	"halls_boss",
	"halls_boss_finale",
	"halls_tense",
	"prison_1",
	"prison_2",
	"prison_3",
	"prison_boss",
	"prison_tense",
	"sewers_1",
	"sewers_2",
	"sewers_3",
	"sewers_boss",
	"sewers_tense",
	"theme_1",
	"theme_2",
	"theme_finale",
]

# --- Per-Region Music Track Lists (matches original Java SewerLevel.playLevelMusic() etc.) ---
# Each region has ambient tracks (weighted equally), a tense track, and a boss track.
# Caves, City, and Halls also have a boss_finale track.
const REGION_TRACKS: Dictionary = {
	# Region.SEWERS = 0
	0: {
		"ambient": ["sewers_1", "sewers_2", "sewers_3"],
		"ambient_chances": [1.0, 1.0, 1.0],
		"tense": "sewers_tense",
		"boss": "sewers_boss",
	},
	# Region.PRISON = 1
	1: {
		"ambient": ["prison_1", "prison_2", "prison_3"],
		"ambient_chances": [1.0, 1.0, 1.0],
		"tense": "prison_tense",
		"boss": "prison_boss",
	},
	# Region.CAVES = 2
	2: {
		"ambient": ["caves_1", "caves_2", "caves_3"],
		"ambient_chances": [1.0, 1.0, 1.0],
		"tense": "caves_tense",
		"boss": "caves_boss",
		"boss_finale": "caves_boss_finale",
	},
	# Region.CITY = 3
	3: {
		"ambient": ["city_1", "city_2", "city_3"],
		"ambient_chances": [1.0, 1.0, 1.0],
		"tense": "city_tense",
		"boss": "city_boss",
		"boss_finale": "city_boss_finale",
	},
	# Region.HALLS = 4
	4: {
		"ambient": ["halls_1", "halls_2", "halls_3"],
		"ambient_chances": [1.0, 1.0, 1.0],
		"tense": "halls_tense",
		"boss": "halls_boss",
		"boss_finale": "halls_boss_finale",
	},
}

# --- SFX name mapping: maps game event names to actual asset filenames ---
# This allows play_sfx("item_pickup") to play "item.mp3", etc.
const SFX_ALIASES: Dictionary = {
	"item_pickup": "item",
	"potion_drink": "drink",
	"scroll_read": "read",
	"level_up": "levelup",
	"door_open": "door_open",
	"boss_music": "boss",  # legacy — the procedural boss music name
}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_ensure_audio_buses()
	_create_players()
	_load_real_sfx()
	_load_real_music()


# ---------------------------------------------------------------------------
# Audio Bus Setup
# ---------------------------------------------------------------------------

## Ensure SFX and Music buses exist. Creates them if missing.
func _ensure_audio_buses() -> void:
	if AudioServer.get_bus_index(BUS_SFX) == -1:
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, BUS_SFX)
		AudioServer.set_bus_send(idx, "Master")
	if AudioServer.get_bus_index(BUS_MUSIC) == -1:
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, BUS_MUSIC)
		AudioServer.set_bus_send(idx, "Master")
	_apply_sfx_volume()
	_apply_music_volume()


## Create AudioStreamPlayer nodes for SFX pool and music.
func _create_players() -> void:
	for i in POOL_SIZE:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_sfx_player_pool.append(p)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = BUS_MUSIC
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)

	_crossfade_player = AudioStreamPlayer.new()
	_crossfade_player.bus = BUS_MUSIC
	add_child(_crossfade_player)


# ---------------------------------------------------------------------------
# Asset Loading
# ---------------------------------------------------------------------------

## Load all real SPD sound effects from res://assets/spd/sounds/.
func _load_real_sfx() -> void:
	var loaded_count: int = _load_manifest_streams(
		_sfx_cache,
		SFX_DIR,
		SFX_MANIFEST,
		SFX_EXTENSIONS
	)
	print("AudioManager: Loaded %d sound effects from %s" % [loaded_count, SFX_DIR])

	# If no real assets loaded, fall back to procedural
	if loaded_count == 0:
		push_warning("AudioManager: No SFX assets found, using procedural fallback.")
		_generate_fallback_sfx()


## Load all real SPD music tracks from res://assets/spd/music/.
func _load_real_music() -> void:
	var loaded_count: int = _load_manifest_streams(
		_music_cache,
		MUSIC_DIR,
		MUSIC_MANIFEST,
		MUSIC_EXTENSIONS
	)
	print("AudioManager: Loaded %d music tracks from %s" % [loaded_count, MUSIC_DIR])


func _load_manifest_streams(
	cache: Dictionary,
	asset_dir: String,
	manifest: Array[String],
	extensions: Array[String]
) -> int:
	var loaded_count: int = 0
	for asset_name: String in manifest:
		var stream: AudioStream = _load_manifest_stream(asset_dir, asset_name, extensions)
		if stream == null:
			push_warning("AudioManager: Missing audio asset '%s' in %s" % [asset_name, asset_dir])
			continue
		cache[asset_name] = stream
		loaded_count += 1
	return loaded_count


func _load_manifest_stream(
	asset_dir: String,
	asset_name: String,
	extensions: Array[String]
) -> AudioStream:
	for ext: String in extensions:
		var stream: AudioStream = load("%s%s.%s" % [asset_dir, asset_name, ext]) as AudioStream
		if stream != null:
			return stream
	return null


# ---------------------------------------------------------------------------
# Public API — SFX
# ---------------------------------------------------------------------------

## Play a named sound effect. Checks real assets first, then aliases, then cache.
func play_sfx(sfx_name: String) -> void:
	if sfx_muted:
		return

	# Resolve alias if one exists (e.g. "item_pickup" -> "item")
	var resolved: String = SFX_ALIASES.get(sfx_name, sfx_name) as String
	var stream: AudioStream = _sfx_cache.get(resolved) as AudioStream
	if stream == null:
		# Try the original name too
		stream = _sfx_cache.get(sfx_name) as AudioStream
	if stream == null:
		push_warning("AudioManager: Unknown SFX '%s' (resolved: '%s')" % [sfx_name, resolved])
		return

	var player: AudioStreamPlayer = _get_free_sfx_player()
	if player == null:
		return
	player.stream = stream
	player.play()


## Set SFX volume (0.0–1.0).
func set_sfx_volume(vol: float) -> void:
	sfx_volume = clampf(vol, 0.0, 1.0)
	_apply_sfx_volume()


## Toggle SFX mute.
func set_sfx_muted(muted: bool) -> void:
	sfx_muted = muted
	_apply_sfx_volume()


# ---------------------------------------------------------------------------
# Public API — Music
# ---------------------------------------------------------------------------

## Play a named music track (looping). If already playing this track, does nothing.
## Checks music cache first, then SFX cache for legacy "boss_music" etc.
func play_music(track_name: String) -> void:
	if track_name == _current_music_track and _music_player.playing:
		return

	var stream: AudioStream = _music_cache.get(track_name) as AudioStream
	if stream == null:
		# Try SFX cache for legacy procedural tracks
		stream = _sfx_cache.get(track_name) as AudioStream
	if stream == null:
		push_warning("AudioManager: Unknown music track '%s'" % track_name)
		return

	_crossfade_to(stream, track_name)


## Play title/menu theme music.
## Original plays theme_2 first, then alternates with theme_1 (equal weighting).
func play_theme_music() -> void:
	var theme_tracks: Array[String] = ["theme_1", "theme_2"]
	_current_region_tracks = theme_tracks
	# Original SurfaceScene: playTracks({theme_2, theme_1}, {1, 1})
	# Start with theme_2 to match original ordering
	play_music("theme_2")


## Play the finale theme music (used for ascension victory).
func play_theme_finale() -> void:
	_current_region_tracks = []
	play_music("theme_finale")


## Play per-region music matching the original's playLevelMusic() pattern.
## region: ConstantsData.Region enum value (0=SEWERS, 1=PRISON, etc.)
## quest_active: if true, plays the tense variant instead of ambient.
## is_boss: if true, plays the boss track.
## is_boss_finale: if true, plays the boss_finale track (caves/city/halls only).
func play_region_music(region: int, quest_active: bool = false, is_boss: bool = false, is_boss_finale: bool = false) -> void:
	var region_data: Dictionary = REGION_TRACKS.get(region, {}) as Dictionary
	if region_data.is_empty():
		push_warning("AudioManager: No music data for region %d" % region)
		return

	if is_boss_finale and region_data.has("boss_finale"):
		play_music(region_data["boss_finale"] as String)
		_current_region_tracks = []
		return

	if is_boss:
		play_music(region_data["boss"] as String)
		_current_region_tracks = []
		return

	if quest_active:
		play_music(region_data["tense"] as String)
		_current_region_tracks = []
		return

	# Normal ambient: weighted random selection from region's ambient tracks
	var ambient: Array = region_data.get("ambient", [])
	var chances: Array = region_data.get("ambient_chances", [])
	if ambient.is_empty():
		return

	_current_region_tracks.clear()
	for t in ambient:
		_current_region_tracks.append(t as String)

	var pick: String = _weighted_random_pick(ambient, chances)
	play_music(pick)


## Stop currently playing music.
func stop_music() -> void:
	if _crossfade_tween:
		_crossfade_tween.kill()
		_crossfade_tween = null
	_music_player.stop()
	_crossfade_player.stop()
	_current_music_track = ""
	_current_region_tracks = []


## Set music volume (0.0–1.0).
func set_music_volume(vol: float) -> void:
	music_volume = clampf(vol, 0.0, 1.0)
	_apply_music_volume()


## Toggle music mute.
func set_music_muted(muted: bool) -> void:
	music_muted = muted
	_apply_music_volume()
	if music_muted:
		_music_player.stop()
		_crossfade_player.stop()
	elif _current_music_track != "":
		_music_player.play()


# ---------------------------------------------------------------------------
# Volume Helpers
# ---------------------------------------------------------------------------

func _apply_sfx_volume() -> void:
	var idx: int = AudioServer.get_bus_index(BUS_SFX)
	if idx == -1:
		return
	if sfx_muted:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(sfx_volume))


func _apply_music_volume() -> void:
	var idx: int = AudioServer.get_bus_index(BUS_MUSIC)
	if idx == -1:
		return
	if music_muted:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(music_volume))


func _get_free_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_player_pool:
		if not p.playing:
			return p
	# All busy — steal the first one
	return _sfx_player_pool[0]


# ---------------------------------------------------------------------------
# Crossfade & Track Selection
# ---------------------------------------------------------------------------

## Crossfade from current track to a new stream.
func _crossfade_to(new_stream: AudioStream, track_name: String) -> void:
	_current_music_track = track_name

	if not _music_player.playing:
		# Nothing playing — just start directly
		_music_player.stream = new_stream
		_music_player.volume_db = 0.0
		if not music_muted:
			_music_player.play()
		return

	# Kill any existing crossfade
	if _crossfade_tween:
		_crossfade_tween.kill()

	# Move current track to crossfade player (it will fade out)
	_crossfade_player.stream = _music_player.stream
	_crossfade_player.volume_db = _music_player.volume_db
	_crossfade_player.play(_music_player.get_playback_position())

	# Start new track on main player at silent, fade in
	_music_player.stream = new_stream
	_music_player.volume_db = -40.0
	if not music_muted:
		_music_player.play()

	_crossfade_tween = create_tween().set_parallel(true)
	_crossfade_tween.tween_property(_music_player, "volume_db", 0.0, CROSSFADE_DURATION)
	_crossfade_tween.tween_property(_crossfade_player, "volume_db", -40.0, CROSSFADE_DURATION)
	_crossfade_tween.chain().tween_callback(_crossfade_player.stop)


## When the current music track finishes, pick another from the region playlist.
func _on_music_finished() -> void:
	if _current_region_tracks.is_empty():
		return
	# Pick a different track from the list
	var pick: String = _current_region_tracks[randi() % _current_region_tracks.size()]
	# Avoid repeating the same track if possible
	if _current_region_tracks.size() > 1:
		while pick == _current_music_track:
			pick = _current_region_tracks[randi() % _current_region_tracks.size()]
	play_music(pick)


## Weighted random selection from parallel arrays of items and weights.
func _weighted_random_pick(items: Array, weights: Array) -> String:
	if items.is_empty():
		return ""
	var total: float = 0.0
	for w in weights:
		total += float(w)
	var roll: float = randf() * total
	var cumulative: float = 0.0
	for i in items.size():
		cumulative += float(weights[i]) if i < weights.size() else 1.0
		if roll <= cumulative:
			return items[i] as String
	return items[items.size() - 1] as String


# ---------------------------------------------------------------------------
# Procedural Fallback (only used when real assets are missing)
# ---------------------------------------------------------------------------

func _generate_fallback_sfx() -> void:
	_sfx_cache["hit"] = _gen_hit()
	_sfx_cache["miss"] = _gen_miss()
	_sfx_cache["step"] = _gen_step()
	_sfx_cache["door_open"] = _gen_door_open()
	_sfx_cache["item"] = _gen_item_pickup()
	_sfx_cache["drink"] = _gen_potion_drink()
	_sfx_cache["read"] = _gen_scroll_read()
	_sfx_cache["levelup"] = _gen_level_up()
	_sfx_cache["death"] = _gen_death()
	_sfx_cache["gold"] = _gen_gold()
	_sfx_cache["trap"] = _gen_trap()
	_sfx_cache["descend"] = _gen_descend()
	_sfx_cache["boss"] = _gen_boss_music()
	_sfx_cache["victory"] = _gen_victory()
	# Additional commonly-triggered SFX from original Assets.Sounds
	_sfx_cache["click"] = _gen_click()
	_sfx_cache["badge"] = _gen_badge()
	_sfx_cache["eat"] = _gen_eat()
	_sfx_cache["shatter"] = _gen_shatter()
	_sfx_cache["blast"] = _gen_blast()
	_sfx_cache["zap"] = _gen_zap()
	_sfx_cache["lightning"] = _gen_lightning_sfx()
	_sfx_cache["water"] = _gen_water()
	_sfx_cache["grass"] = _gen_grass()
	_sfx_cache["trample"] = _gen_trample()
	_sfx_cache["unlock"] = _gen_unlock()
	_sfx_cache["cursed"] = _gen_cursed()
	_sfx_cache["alert"] = _gen_alert()
	_sfx_cache["burning"] = _gen_burning()
	_sfx_cache["ghost"] = _gen_ghost()
	_sfx_cache["secret"] = _gen_secret()
	_sfx_cache["teleport"] = _gen_teleport()
	_sfx_cache["health_warn"] = _gen_health_warn()
	_sfx_cache["health_critical"] = _gen_health_critical()
	_sfx_cache["puff"] = _gen_puff()
	_sfx_cache["chargeup"] = _gen_chargeup()
	_sfx_cache["debuff"] = _gen_debuff()

## Create an AudioStreamWAV from raw float samples (-1.0 to 1.0).
func _make_wav(samples: PackedFloat32Array, _loop: bool = false) -> AudioStreamWAV:
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.mix_rate = SAMPLE_RATE
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	var byte_data: PackedByteArray = PackedByteArray()
	for s: float in samples:
		var clamped: float = clampf(s, -1.0, 1.0)
		var val: int = int(clamped * 32767.0)
		byte_data.append(val & 0xFF)
		byte_data.append((val >> 8) & 0xFF)
	wav.data = byte_data
	return wav

## Generate a short silent clip as fallback.
func _gen_silent(duration: float = 0.05) -> AudioStreamWAV:
	var sample_count: int = int(SAMPLE_RATE * duration)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(sample_count)
	return _make_wav(samples)

func _gen_alert() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_badge() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_blast() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_boss_music() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_burning() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_chargeup() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_click() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_cursed() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_death() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_debuff() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_descend() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_door_open() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_eat() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_ghost() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_gold() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_grass() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_health_critical() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_health_warn() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_hit() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_item_pickup() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_level_up() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_lightning_sfx() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_miss() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_potion_drink() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_puff() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_scroll_read() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_secret() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_shatter() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_step() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_teleport() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_trample() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_trap() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_unlock() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_victory() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_water() -> AudioStreamWAV:
	return _gen_silent(0.05)

func _gen_zap() -> AudioStreamWAV:
	return _gen_silent(0.05)
