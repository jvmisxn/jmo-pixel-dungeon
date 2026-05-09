class_name MobSprite
extends CharSprite
## Sprite for dungeon mobs. Generates unique procedural appearances based on mob_id.
## Each mob type has a distinct silhouette and color scheme.
## Death animation: fades out over FADE_TIME seconds (matches original MobSprite).
## Fall animation: spins and shrinks into a pit (matches original MobSprite.fall()).

const FADE_TIME: float = 3.0
const FALL_TIME: float = 1.0

# --- Mob Visual Data ---
# Maps mob_id -> { body, accent, eye, shape }
# shape: "humanoid", "beast", "large", "flying", "small"
static var MOB_VISUALS: Dictionary = {
	# --- Sewers ---
	"rat": { "body": Color(0.5, 0.4, 0.3), "accent": Color(0.6, 0.5, 0.35), "eye": Color(0.9, 0.2, 0.2), "shape": "small" },
	"fetid_rat": { "body": Color(0.4, 0.45, 0.3), "accent": Color(0.5, 0.55, 0.3), "eye": Color(0.7, 0.9, 0.1), "shape": "small" },
	"gnoll": { "body": Color(0.55, 0.45, 0.3), "accent": Color(0.4, 0.35, 0.25), "eye": Color(0.8, 0.6, 0.1), "shape": "humanoid" },
	"gnoll_trickster": { "body": Color(0.55, 0.45, 0.3), "accent": Color(0.5, 0.4, 0.3), "eye": Color(0.9, 0.7, 0.1), "shape": "humanoid" },
	"crab": { "body": Color(0.8, 0.3, 0.2), "accent": Color(0.9, 0.4, 0.25), "eye": Color(0.1, 0.1, 0.1), "shape": "small" },
	"great_crab": { "body": Color(0.7, 0.25, 0.15), "accent": Color(0.8, 0.35, 0.2), "eye": Color(0.1, 0.1, 0.1), "shape": "large" },
	"snake": { "body": Color(0.3, 0.6, 0.3), "accent": Color(0.4, 0.7, 0.3), "eye": Color(0.9, 0.9, 0.1), "shape": "small" },
	"slime": { "body": Color(0.3, 0.7, 0.3), "accent": Color(0.2, 0.8, 0.4), "eye": Color(0.9, 0.9, 0.9), "shape": "blob" },
	"swarm": { "body": Color(0.2, 0.2, 0.2), "accent": Color(0.3, 0.3, 0.3), "eye": Color(0.9, 0.5, 0.1), "shape": "flying" },
	# --- Prison ---
	"skeleton": { "body": Color(0.85, 0.82, 0.75), "accent": Color(0.7, 0.68, 0.6), "eye": Color(0.9, 0.3, 0.1), "shape": "humanoid" },
	"thief": { "body": Color(0.6, 0.5, 0.4), "accent": Color(0.4, 0.3, 0.5), "eye": Color(0.8, 0.7, 0.1), "shape": "humanoid" },
	"bandit": { "body": Color(0.5, 0.3, 0.3), "accent": Color(0.6, 0.2, 0.2), "eye": Color(0.9, 0.7, 0.1), "shape": "humanoid" },
	"guard": { "body": Color(0.5, 0.5, 0.55), "accent": Color(0.6, 0.6, 0.65), "eye": Color(0.3, 0.3, 0.8), "shape": "large" },
	"necromancer": { "body": Color(0.3, 0.2, 0.3), "accent": Color(0.5, 0.2, 0.5), "eye": Color(0.3, 0.9, 0.3), "shape": "humanoid" },
	# --- Caves ---
	"bat": { "body": Color(0.35, 0.25, 0.2), "accent": Color(0.45, 0.3, 0.25), "eye": Color(0.9, 0.5, 0.1), "shape": "flying" },
	"brute": { "body": Color(0.4, 0.35, 0.3), "accent": Color(0.5, 0.4, 0.3), "eye": Color(0.9, 0.2, 0.1), "shape": "large" },
	"shaman": { "body": Color(0.3, 0.5, 0.3), "accent": Color(0.4, 0.6, 0.4), "eye": Color(0.2, 0.8, 0.9), "shape": "humanoid" },
	"spinner": { "body": Color(0.2, 0.25, 0.2), "accent": Color(0.3, 0.35, 0.3), "eye": Color(0.9, 0.1, 0.1), "shape": "beast" },
	"dm100": { "body": Color(0.45, 0.45, 0.5), "accent": Color(0.55, 0.55, 0.6), "eye": Color(0.9, 0.5, 0.1), "shape": "humanoid" },
	"dm200": { "body": Color(0.5, 0.5, 0.55), "accent": Color(0.6, 0.6, 0.65), "eye": Color(0.9, 0.3, 0.1), "shape": "large" },
	"dm201": { "body": Color(0.5, 0.5, 0.55), "accent": Color(0.7, 0.4, 0.1), "eye": Color(0.9, 0.2, 0.1), "shape": "large" },
	# --- City ---
	"warlock": { "body": Color(0.25, 0.2, 0.3), "accent": Color(0.4, 0.2, 0.4), "eye": Color(0.8, 0.2, 0.8), "shape": "humanoid" },
	"monk": { "body": Color(0.7, 0.5, 0.35), "accent": Color(0.6, 0.4, 0.2), "eye": Color(0.1, 0.5, 0.9), "shape": "humanoid" },
	"golem": { "body": Color(0.5, 0.45, 0.4), "accent": Color(0.6, 0.55, 0.5), "eye": Color(0.9, 0.6, 0.1), "shape": "large" },
	"elemental": { "body": Color(0.9, 0.4, 0.1), "accent": Color(1.0, 0.6, 0.1), "eye": Color(1.0, 1.0, 0.5), "shape": "blob" },
	# --- Halls ---
	"succubus": { "body": Color(0.6, 0.3, 0.4), "accent": Color(0.7, 0.2, 0.4), "eye": Color(0.9, 0.1, 0.5), "shape": "humanoid" },
	"eye": { "body": Color(0.5, 0.2, 0.3), "accent": Color(0.6, 0.3, 0.4), "eye": Color(0.9, 0.9, 0.1), "shape": "flying" },
	"scorpio": { "body": Color(0.4, 0.2, 0.2), "accent": Color(0.5, 0.25, 0.2), "eye": Color(0.9, 0.3, 0.1), "shape": "beast" },
	"ripper": { "body": Color(0.3, 0.15, 0.2), "accent": Color(0.4, 0.2, 0.25), "eye": Color(0.9, 0.1, 0.1), "shape": "beast" },
	# --- Bosses ---
	"goo": { "body": Color(0.2, 0.3, 0.2), "accent": Color(0.3, 0.5, 0.2), "eye": Color(0.9, 0.9, 0.1), "shape": "blob" },
	"tengu": { "body": Color(0.2, 0.2, 0.3), "accent": Color(0.3, 0.3, 0.5), "eye": Color(0.9, 0.5, 0.1), "shape": "humanoid" },
	"dm300": { "body": Color(0.45, 0.45, 0.5), "accent": Color(0.55, 0.55, 0.6), "eye": Color(0.9, 0.2, 0.1), "shape": "large" },
	"king": { "body": Color(0.5, 0.4, 0.5), "accent": Color(0.7, 0.5, 0.1), "eye": Color(0.9, 0.2, 0.9), "shape": "large" },
	"yog": { "body": Color(0.3, 0.1, 0.15), "accent": Color(0.5, 0.15, 0.2), "eye": Color(0.9, 0.1, 0.3), "shape": "blob" },
	"yog_fist": { "body": Color(0.4, 0.1, 0.15), "accent": Color(0.6, 0.15, 0.2), "eye": Color(0.9, 0.2, 0.2), "shape": "large" },
	"rotting_fist": { "body": Color(0.3, 0.4, 0.2), "accent": Color(0.4, 0.5, 0.2), "eye": Color(0.7, 0.9, 0.1), "shape": "large" },
	"burning_fist": { "body": Color(0.7, 0.3, 0.1), "accent": Color(0.9, 0.4, 0.1), "eye": Color(1.0, 0.8, 0.2), "shape": "large" },
	# --- Special ---
	"piranha": { "body": Color(0.2, 0.4, 0.7), "accent": Color(0.3, 0.5, 0.8), "eye": Color(0.9, 0.2, 0.1), "shape": "small" },
	"mimic": { "body": Color(0.5, 0.35, 0.2), "accent": Color(0.6, 0.4, 0.2), "eye": Color(0.9, 0.9, 0.1), "shape": "large" },
	"wraith": { "body": Color(0.2, 0.2, 0.3), "accent": Color(0.3, 0.3, 0.4), "eye": Color(0.9, 0.9, 0.9), "shape": "humanoid" },
	"bee": { "body": Color(0.9, 0.7, 0.1), "accent": Color(0.2, 0.2, 0.2), "eye": Color(0.1, 0.1, 0.1), "shape": "flying" },
	"animated_statue": { "body": Color(0.6, 0.6, 0.65), "accent": Color(0.5, 0.5, 0.55), "eye": Color(0.4, 0.7, 0.9), "shape": "large" },
	"golden_statue": { "body": Color(0.9, 0.75, 0.2), "accent": Color(1.0, 0.85, 0.3), "eye": Color(0.9, 0.2, 0.2), "shape": "large" },
	# --- NPCs ---
	"sad_ghost": { "body": Color(0.7, 0.7, 0.8), "accent": Color(0.8, 0.8, 0.9), "eye": Color(0.5, 0.5, 0.9), "shape": "humanoid" },
	"wandmaker": { "body": Color(0.4, 0.3, 0.5), "accent": Color(0.5, 0.4, 0.6), "eye": Color(0.3, 0.8, 0.3), "shape": "humanoid" },
	"blacksmith": { "body": Color(0.5, 0.4, 0.3), "accent": Color(0.6, 0.5, 0.4), "eye": Color(0.9, 0.5, 0.1), "shape": "large" },
	"shopkeeper": { "body": Color(0.6, 0.5, 0.4), "accent": Color(0.7, 0.6, 0.5), "eye": Color(0.2, 0.2, 0.7), "shape": "humanoid" },
	"ambitious_imp": { "body": Color(0.5, 0.2, 0.2), "accent": Color(0.6, 0.3, 0.3), "eye": Color(0.9, 0.9, 0.1), "shape": "small" },
	# --- Caves extras ---
	"ghoul": { "body": Color(0.35, 0.30, 0.25), "accent": Color(0.45, 0.38, 0.30), "eye": Color(0.9, 0.3, 0.1), "shape": "humanoid" },
	"guardian": { "body": Color(0.50, 0.50, 0.55), "accent": Color(0.65, 0.55, 0.2), "eye": Color(0.4, 0.7, 0.9), "shape": "large" },
	# --- Fungi ---
	"fungal_core": { "body": Color(0.35, 0.5, 0.25), "accent": Color(0.4, 0.6, 0.3), "eye": Color(0.7, 0.9, 0.3), "shape": "blob" },
	"fungal_sentry": { "body": Color(0.3, 0.45, 0.2), "accent": Color(0.35, 0.55, 0.25), "eye": Color(0.8, 0.9, 0.2), "shape": "small" },
	"fungal_spinner": { "body": Color(0.25, 0.4, 0.2), "accent": Color(0.3, 0.5, 0.25), "eye": Color(0.9, 0.1, 0.1), "shape": "beast" },
	# --- Gnoll extras ---
	"gnoll_guard": { "body": Color(0.55, 0.45, 0.3), "accent": Color(0.5, 0.5, 0.55), "eye": Color(0.8, 0.6, 0.1), "shape": "large" },
	"gnoll_sapper": { "body": Color(0.55, 0.45, 0.3), "accent": Color(0.4, 0.3, 0.2), "eye": Color(0.9, 0.7, 0.1), "shape": "humanoid" },
	"gnoll_geomancer": { "body": Color(0.5, 0.4, 0.3), "accent": Color(0.6, 0.5, 0.3), "eye": Color(0.9, 0.8, 0.2), "shape": "humanoid" },
	# --- Crystal mobs ---
	"crystal_guardian": { "body": Color(0.6, 0.7, 0.8), "accent": Color(0.7, 0.8, 0.9), "eye": Color(0.3, 0.6, 0.9), "shape": "large" },
	"crystal_spire": { "body": Color(0.5, 0.6, 0.7), "accent": Color(0.7, 0.8, 0.9), "eye": Color(0.4, 0.7, 1.0), "shape": "large" },
	"crystal_wisp": { "body": Color(0.6, 0.7, 0.9), "accent": Color(0.8, 0.9, 1.0), "eye": Color(1.0, 1.0, 1.0), "shape": "flying" },
	# --- Rot mobs ---
	"rot_heart": { "body": Color(0.4, 0.3, 0.2), "accent": Color(0.5, 0.35, 0.2), "eye": Color(0.7, 0.9, 0.1), "shape": "blob" },
	"rot_lasher": { "body": Color(0.3, 0.4, 0.15), "accent": Color(0.4, 0.5, 0.2), "eye": Color(0.8, 0.9, 0.2), "shape": "small" },
	# --- Other specials ---
	"demon_spawner": { "body": Color(0.3, 0.1, 0.15), "accent": Color(0.5, 0.15, 0.2), "eye": Color(0.9, 0.2, 0.2), "shape": "large" },
	"pylon": { "body": Color(0.4, 0.4, 0.5), "accent": Color(0.6, 0.6, 0.7), "eye": Color(0.9, 0.5, 0.1), "shape": "large" },
	"larva": { "body": Color(0.5, 0.4, 0.3), "accent": Color(0.6, 0.5, 0.35), "eye": Color(0.9, 0.2, 0.1), "shape": "small" },
	"sheep": { "body": Color(0.9, 0.9, 0.85), "accent": Color(0.8, 0.8, 0.75), "eye": Color(0.2, 0.2, 0.2), "shape": "small" },
	"ratking": { "body": Color(0.5, 0.4, 0.3), "accent": Color(0.7, 0.6, 0.1), "eye": Color(0.9, 0.8, 0.1), "shape": "small" },
}

# --- Mob sprite sheet data: mob_id → { path, fw, fh } ---
static var _MOB_SHEETS: Dictionary = {
	# --- Sewers ---
	"rat":             { "path": "rat.png",            "fw": 16, "fh": 15 },
	"fetid_rat":       { "path": "rat.png",            "fw": 16, "fh": 15, "row": 1 },
	"gnoll":           { "path": "gnoll.png",          "fw": 12, "fh": 15 },
	"gnoll_trickster": { "path": "gnoll.png",          "fw": 12, "fh": 15, "row": 1 },
	"crab":            { "path": "crab.png",           "fw": 16, "fh": 16 },
	"great_crab":      { "path": "crab.png",           "fw": 16, "fh": 16, "row": 1 },
	"snake":           { "path": "snake.png",          "fw": 12, "fh": 15 },
	"slime":           { "path": "slime.png",          "fw": 12, "fh": 14 },
	"swarm":           { "path": "swarm.png",          "fw": 16, "fh": 15 },
	# --- Prison ---
	"skeleton":        { "path": "skeleton.png",       "fw": 12, "fh": 15 },
	"thief":           { "path": "thief.png",          "fw": 12, "fh": 13 },
	"bandit":          { "path": "thief.png",          "fw": 12, "fh": 13, "row": 1 },
	"guard":           { "path": "guard.png",          "fw": 12, "fh": 16 },
	"necromancer":     { "path": "necromancer.png",    "fw": 12, "fh": 15 },
	# --- Caves ---
	"bat":             { "path": "bat.png",            "fw": 15, "fh": 15 },
	"brute":           { "path": "brute.png",          "fw": 12, "fh": 16 },
	"shaman":          { "path": "shaman.png",         "fw": 12, "fh": 14 },
	"spinner":         { "path": "spinner.png",        "fw": 16, "fh": 16 },
	"dm100":           { "path": "dm100.png",          "fw": 12, "fh": 14 },
	"dm200":           { "path": "dm200.png",          "fw": 21, "fh": 18 },
	"dm201":           { "path": "dm200.png",          "fw": 21, "fh": 18, "row": 1 },
	# --- City ---
	"warlock":         { "path": "warlock.png",        "fw": 12, "fh": 15 },
	"monk":            { "path": "monk.png",           "fw": 15, "fh": 14 },
	"golem":           { "path": "golem.png",          "fw": 16, "fh": 16 },
	"elemental":       { "path": "elemental.png",      "fw": 12, "fh": 14 },
	# --- Halls ---
	"succubus":        { "path": "succubus.png",       "fw": 12, "fh": 15 },
	"eye":             { "path": "eye.png",            "fw": 16, "fh": 18 },
	"scorpio":         { "path": "scorpio.png",        "fw": 18, "fh": 17 },
	# --- Special ---
	"mimic":           { "path": "mimic.png",          "fw": 16, "fh": 16 },
}

# --- State ---
var mob_id: String = "rat"
var _death_fading: bool = false

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Set up the sprite for a specific mob type.
func setup_for_mob(p_mob_id: String) -> void:
	mob_id = p_mob_id
	var visuals: Dictionary = MOB_VISUALS.get(mob_id, MOB_VISUALS["rat"])
	body_color = visuals.get("body", Color(0.5, 0.4, 0.3))
	accent_color = visuals.get("accent", Color(0.4, 0.35, 0.25))
	eye_color = visuals.get("eye", Color(0.9, 0.2, 0.2))

	# Try loading SPD sprite sheet
	var sheet_data: Dictionary = _MOB_SHEETS.get(mob_id, {})
	if sheet_data.size() > 0:
		var path: String = "res://assets/spd/sprites/" + sheet_data.get("path", "")
		var sheet: Texture2D = load(path) as Texture2D
		if sheet != null:
			var fw: int = sheet_data.get("fw", 16)
			var fh: int = sheet_data.get("fh", 16)
			var row: int = sheet_data.get("row", 0)
			setup_from_sheet(sheet, Rect2(0, row * fh, fw, fh))
			return

	# Fallback: procedural generation
	refresh_texture()

# ---------------------------------------------------------------------------
# Override — Procedural Drawing
# ---------------------------------------------------------------------------

func _draw_character(img: Image) -> void:
	var visuals: Dictionary = MOB_VISUALS.get(mob_id, MOB_VISUALS["rat"])
	var shape: String = visuals.get("shape", "humanoid")

	match shape:
		"humanoid":
			_draw_humanoid(img)
		"small":
			_draw_small(img)
		"large":
			_draw_large(img)
		"beast":
			_draw_beast(img)
		"flying":
			_draw_flying(img)
		"blob":
			_draw_blob(img)
		_:
			_draw_humanoid(img)

# ---------------------------------------------------------------------------
# Death Animation (overrides CharSprite for fade-out)
# ---------------------------------------------------------------------------

func die() -> void:
	_death_fading = true
	play_death(FADE_TIME)

func fall() -> void:
	_death_fading = true
	is_animating = true
	if _move_tween != null:
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.set_parallel(true)
	_move_tween.tween_property(_sprite, "modulate:a", 0.0, FALL_TIME)
	_move_tween.tween_property(_sprite, "scale", Vector2(0.2, 0.2), FALL_TIME)
	_move_tween.tween_property(_sprite, "rotation", TAU, FALL_TIME)
	_move_tween.set_parallel(false)
	_move_tween.tween_callback(queue_free)

# ---------------------------------------------------------------------------
# Shape Drawing Functions
# ---------------------------------------------------------------------------

func _draw_humanoid(img: Image) -> void:
	# Head
	for x: int in range(6, 10):
		for y: int in range(2, 5):
			img.set_pixel(x, y, body_color)
	# Eyes
	img.set_pixel(6, 3, eye_color)
	img.set_pixel(9, 3, eye_color)
	# Body
	for x: int in range(5, 11):
		for y: int in range(5, 10):
			img.set_pixel(x, y, accent_color)
	# Legs
	for x: int in range(5, 8):
		for y: int in range(10, 14):
			img.set_pixel(x, y, body_color.darkened(0.2))
	for x: int in range(8, 11):
		for y: int in range(10, 14):
			img.set_pixel(x, y, body_color.darkened(0.2))

func _draw_small(img: Image) -> void:
	# Small creature (rat, crab, etc.)
	for x: int in range(5, 11):
		for y: int in range(7, 12):
			img.set_pixel(x, y, body_color)
	# Eyes
	img.set_pixel(5, 8, eye_color)
	img.set_pixel(10, 8, eye_color)
	# Tail or feature
	img.set_pixel(4, 10, accent_color)
	img.set_pixel(3, 11, accent_color)

func _draw_large(img: Image) -> void:
	# Large creature (golem, guard, boss, etc.)
	for x: int in range(3, 13):
		for y: int in range(2, 12):
			img.set_pixel(x, y, body_color)
	# Accent overlay
	for x: int in range(4, 12):
		for y: int in range(4, 10):
			img.set_pixel(x, y, accent_color)
	# Eyes
	img.set_pixel(5, 4, eye_color)
	img.set_pixel(10, 4, eye_color)
	# Legs
	for x: int in range(4, 7):
		for y: int in range(12, 15):
			img.set_pixel(x, y, body_color.darkened(0.2))
	for x: int in range(9, 12):
		for y: int in range(12, 15):
			img.set_pixel(x, y, body_color.darkened(0.2))

func _draw_beast(img: Image) -> void:
	# Four-legged beast (spinner, scorpio, etc.)
	for x: int in range(4, 12):
		for y: int in range(5, 10):
			img.set_pixel(x, y, body_color)
	# Head (front)
	for x: int in range(10, 14):
		for y: int in range(6, 9):
			img.set_pixel(x, y, accent_color)
	# Eyes
	img.set_pixel(12, 6, eye_color)
	img.set_pixel(12, 8, eye_color)
	# Legs
	img.set_pixel(5, 10, body_color.darkened(0.2))
	img.set_pixel(5, 11, body_color.darkened(0.2))
	img.set_pixel(7, 10, body_color.darkened(0.2))
	img.set_pixel(7, 11, body_color.darkened(0.2))
	img.set_pixel(9, 10, body_color.darkened(0.2))
	img.set_pixel(9, 11, body_color.darkened(0.2))
	img.set_pixel(11, 10, body_color.darkened(0.2))
	img.set_pixel(11, 11, body_color.darkened(0.2))

func _draw_flying(img: Image) -> void:
	# Winged/floating creature (bat, swarm, etc.)
	# Body
	for x: int in range(6, 10):
		for y: int in range(6, 10):
			img.set_pixel(x, y, body_color)
	# Eyes
	img.set_pixel(6, 7, eye_color)
	img.set_pixel(9, 7, eye_color)
	# Wings
	for x: int in range(2, 6):
		img.set_pixel(x, 5, accent_color)
		img.set_pixel(x, 6, accent_color)
	for x: int in range(10, 14):
		img.set_pixel(x, 5, accent_color)
		img.set_pixel(x, 6, accent_color)

func _draw_blob(img: Image) -> void:
	# Amorphous blob (slime, goo, elemental, etc.)
	# Irregular round shape
	for x: int in range(4, 12):
		for y: int in range(5, 13):
			var dx: float = float(x) - 8.0
			var dy: float = float(y) - 9.0
			if dx * dx + dy * dy < 20.0:
				img.set_pixel(x, y, body_color)
	# Accent spots
	img.set_pixel(6, 7, accent_color)
	img.set_pixel(9, 10, accent_color)
	img.set_pixel(7, 11, accent_color)
	# Eyes
	img.set_pixel(6, 8, eye_color)
	img.set_pixel(9, 8, eye_color)
