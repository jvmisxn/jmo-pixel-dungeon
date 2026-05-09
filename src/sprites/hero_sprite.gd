class_name HeroSprite
extends CharSprite
## Sprite for the hero character. Color scheme varies by hero class.
## Generates a distinct look for each class: Warrior (heavy armor), Mage (robes),
## Rogue (dark cloak), Huntress (green), Duelist (purple).

# --- Class Color Schemes ---
static var CLASS_COLORS: Dictionary = {
	ConstantsData.HeroClass.WARRIOR: {
		"body": Color(0.75, 0.60, 0.45),
		"accent": Color(0.55, 0.55, 0.60),  # Steel armor
		"eye": Color(0.3, 0.5, 0.9),
		"weapon": Color(0.6, 0.6, 0.65),
		"detail": Color(0.7, 0.5, 0.1),  # Gold trim
	},
	ConstantsData.HeroClass.MAGE: {
		"body": Color(0.70, 0.55, 0.45),
		"accent": Color(0.3, 0.3, 0.7),  # Blue robes
		"eye": Color(0.6, 0.2, 0.9),
		"weapon": Color(0.5, 0.3, 0.2),  # Staff (wood)
		"detail": Color(0.4, 0.7, 0.9),  # Magic glow
	},
	ConstantsData.HeroClass.ROGUE: {
		"body": Color(0.65, 0.50, 0.40),
		"accent": Color(0.2, 0.2, 0.25),  # Dark cloak
		"eye": Color(0.9, 0.8, 0.1),
		"weapon": Color(0.5, 0.5, 0.55),  # Dagger
		"detail": Color(0.3, 0.3, 0.35),
	},
	ConstantsData.HeroClass.HUNTRESS: {
		"body": Color(0.70, 0.55, 0.42),
		"accent": Color(0.2, 0.45, 0.2),  # Green tunic
		"eye": Color(0.2, 0.7, 0.3),
		"weapon": Color(0.5, 0.35, 0.15),  # Bow (wood)
		"detail": Color(0.4, 0.6, 0.2),
	},
	ConstantsData.HeroClass.DUELIST: {
		"body": Color(0.72, 0.55, 0.45),
		"accent": Color(0.5, 0.2, 0.5),  # Purple garb
		"eye": Color(0.9, 0.3, 0.5),
		"weapon": Color(0.6, 0.6, 0.65),  # Rapier
		"detail": Color(0.7, 0.3, 0.6),
	},
}

# --- Hero sprite frame dimensions (matches original HeroSprite.java) ---
const FRAME_WIDTH: int = 12
const FRAME_HEIGHT: int = 15
const RUN_FRAMERATE: int = 20

# --- State ---
var hero_class: int = ConstantsData.HeroClass.WARRIOR
## Armor tier affects which row of the sprite sheet is used (0-5).
var armor_tier: int = 0
## Whether the hero is flying (levitating/flying buff).
var is_flying: bool = false
## Whether the hero is resting (shows sleep emote like original).
var is_resting: bool = false

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Hero class → sprite sheet filename.
static var _CLASS_SHEETS: Dictionary = {
	ConstantsData.HeroClass.WARRIOR:  "res://assets/spd/sprites/warrior.png",
	ConstantsData.HeroClass.MAGE:     "res://assets/spd/sprites/mage.png",
	ConstantsData.HeroClass.ROGUE:    "res://assets/spd/sprites/rogue.png",
	ConstantsData.HeroClass.HUNTRESS: "res://assets/spd/sprites/huntress.png",
	ConstantsData.HeroClass.DUELIST:  "res://assets/spd/sprites/duelist.png",
}

## Set up the sprite for a specific hero class.
func setup_for_class(p_class: int) -> void:
	hero_class = p_class
	update_armor(0)

## Update the sprite's armor tier (changes which row of the sheet is used).
## Matches original HeroSprite.updateArmor().
func update_armor(tier: int = 0) -> void:
	armor_tier = tier

	# Try loading real SPD sprite sheet
	var sheet_path: String = _CLASS_SHEETS.get(hero_class, "")
	if sheet_path != "":
		var sheet: Texture2D = load(sheet_path) as Texture2D
		if sheet != null:
			# Each armor tier is a row of FRAME_HEIGHT pixels.
			# First frame (idle) is at column 0 of that row.
			var row_y: int = armor_tier * FRAME_HEIGHT
			setup_from_sheet(sheet, Rect2(0, row_y, FRAME_WIDTH, FRAME_HEIGHT))
			return

	# Fallback: procedural generation
	var colors: Dictionary = CLASS_COLORS.get(hero_class, CLASS_COLORS[ConstantsData.HeroClass.WARRIOR])
	body_color = colors["body"]
	accent_color = colors["accent"]
	eye_color = colors["eye"]
	refresh_texture()

## Adjust run animation speed. Original HeroSprite.sprint() changes run.delay.
func sprint(speed: float) -> void:
	# Higher speed = shorter move_to duration
	# Base move is 0.15s; sprint scales inversely
	pass  # Move duration is passed per-call in move_to(); this is a stub for future frame-animation support.

## Play read animation (scroll reading). Matches original HeroSprite.read().
func read() -> void:
	_anim_state = AnimState.OPERATE
	is_animating = true
	play_operate(cell_pos, 0.5)


## Hero death should read as a distinct collapse, not just the generic mob fade.
func play_hero_death(duration: float = 0.9) -> void:
	_anim_state = AnimState.DIE
	is_animating = true
	if _hp_bar_bg:
		_hp_bar_bg.visible = false
	hide_emo()
	if _flash_tween != null:
		_flash_tween.kill()
	_sprite.modulate = Color(1.0, 0.45, 0.45, 1.0)
	if _move_tween != null:
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.set_parallel(true)
	_move_tween.tween_property(_sprite, "modulate", Color(0.35, 0.15, 0.15, 0.0), duration)
	_move_tween.tween_property(_sprite, "rotation", deg_to_rad(90.0), duration * 0.8)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_move_tween.tween_property(_sprite, "scale", Vector2(0.9, 0.7), duration)
	_move_tween.tween_property(self, "position:y", position.y + 5.0, duration)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)

## Override: Hero characters do NOT show blood bursts.
## Original HeroSprite.bloodBurstA() is intentionally empty for content rating.
func blood_burst_a(_from_pos: Vector2, _damage: int) -> void:
	pass  # No blood for heroes — matches original

# ---------------------------------------------------------------------------
# Override
# ---------------------------------------------------------------------------

func _draw_character(img: Image) -> void:
	var colors: Dictionary = CLASS_COLORS.get(hero_class, CLASS_COLORS[ConstantsData.HeroClass.WARRIOR])
	var body: Color = colors["body"]
	var armor: Color = colors["accent"]
	var eyes: Color = colors["eye"]
	var weapon_col: Color = colors["weapon"]
	var detail: Color = colors["detail"]

	match hero_class:
		ConstantsData.HeroClass.WARRIOR:
			_draw_warrior(img, body, armor, eyes, weapon_col, detail)
		ConstantsData.HeroClass.MAGE:
			_draw_mage(img, body, armor, eyes, weapon_col, detail)
		ConstantsData.HeroClass.ROGUE:
			_draw_rogue(img, body, armor, eyes, weapon_col, detail)
		ConstantsData.HeroClass.HUNTRESS:
			_draw_huntress(img, body, armor, eyes, weapon_col, detail)
		ConstantsData.HeroClass.DUELIST:
			_draw_duelist(img, body, armor, eyes, weapon_col, detail)

# ---------------------------------------------------------------------------
# Class-specific Drawing
# ---------------------------------------------------------------------------

func _draw_warrior(img: Image, body: Color, armor: Color, eyes: Color, weapon: Color, detail: Color) -> void:
	# Head with helmet
	for x: int in range(5, 11):
		for y: int in range(1, 6):
			img.set_pixel(x, y, armor.lightened(0.1))
	# Face opening
	for x: int in range(6, 10):
		for y: int in range(3, 5):
			img.set_pixel(x, y, body)
	# Eyes
	img.set_pixel(6, 3, eyes)
	img.set_pixel(9, 3, eyes)
	# Heavy body armor
	for x: int in range(4, 12):
		for y: int in range(6, 11):
			img.set_pixel(x, y, armor)
	# Gold trim on armor
	for x: int in range(4, 12):
		img.set_pixel(x, 6, detail)
	# Legs
	for x: int in range(5, 8):
		for y: int in range(11, 15):
			img.set_pixel(x, y, armor.darkened(0.2))
	for x: int in range(8, 11):
		for y: int in range(11, 15):
			img.set_pixel(x, y, armor.darkened(0.2))
	# Sword on right side
	for y: int in range(4, 14):
		img.set_pixel(12, y, weapon)
	img.set_pixel(12, 3, weapon.lightened(0.3))  # tip shine

func _draw_mage(img: Image, body: Color, armor: Color, eyes: Color, weapon: Color, detail: Color) -> void:
	# Head with hood
	for x: int in range(5, 11):
		for y: int in range(1, 6):
			img.set_pixel(x, y, armor.darkened(0.2))
	# Face
	for x: int in range(6, 10):
		for y: int in range(2, 5):
			img.set_pixel(x, y, body)
	# Glowing eyes
	img.set_pixel(6, 3, eyes)
	img.set_pixel(9, 3, eyes)
	# Flowing robes
	for x: int in range(4, 12):
		for y: int in range(6, 14):
			var shade: float = float(y - 6) / 8.0
			img.set_pixel(x, y, armor.lerp(armor.darkened(0.3), shade))
	# Robe hem widens
	for y: int in range(12, 15):
		img.set_pixel(3, y, armor.darkened(0.2))
		img.set_pixel(12, y, armor.darkened(0.2))
	# Staff
	for y: int in range(1, 15):
		img.set_pixel(13, y, weapon)
	# Orb on staff top
	img.set_pixel(13, 0, detail)
	img.set_pixel(12, 0, detail)
	img.set_pixel(14, 0, detail)
	img.set_pixel(13, 1, detail)

func _draw_rogue(img: Image, body: Color, armor: Color, eyes: Color, weapon: Color, detail: Color) -> void:
	# Head with cowl
	for x: int in range(5, 11):
		for y: int in range(1, 6):
			img.set_pixel(x, y, armor)
	# Visible eyes only
	img.set_pixel(6, 3, eyes)
	img.set_pixel(9, 3, eyes)
	# Slim body with cloak
	for x: int in range(5, 11):
		for y: int in range(6, 11):
			img.set_pixel(x, y, armor)
	# Cloak trailing
	for y: int in range(8, 14):
		img.set_pixel(4, y, armor.lightened(0.05))
		img.set_pixel(3, y, armor.lerp(Color(0, 0, 0, 0), 0.3))
	# Legs (slim)
	for x: int in range(6, 8):
		for y: int in range(11, 15):
			img.set_pixel(x, y, detail)
	for x: int in range(8, 10):
		for y: int in range(11, 15):
			img.set_pixel(x, y, detail)
	# Dagger
	for y: int in range(7, 12):
		img.set_pixel(11, y, weapon)
	img.set_pixel(11, 6, weapon.lightened(0.4))

func _draw_huntress(img: Image, body: Color, armor: Color, eyes: Color, weapon: Color, detail: Color) -> void:
	# Head
	for x: int in range(6, 10):
		for y: int in range(1, 5):
			img.set_pixel(x, y, body)
	# Hair
	for x: int in range(5, 11):
		img.set_pixel(x, 1, body.darkened(0.4))
		img.set_pixel(x, 2, body.darkened(0.4))
	# Eyes
	img.set_pixel(6, 3, eyes)
	img.set_pixel(9, 3, eyes)
	# Green tunic
	for x: int in range(5, 11):
		for y: int in range(5, 10):
			img.set_pixel(x, y, armor)
	# Belt
	for x: int in range(5, 11):
		img.set_pixel(x, 9, detail.darkened(0.3))
	# Legs
	for x: int in range(6, 8):
		for y: int in range(10, 14):
			img.set_pixel(x, y, armor.darkened(0.15))
	for x: int in range(8, 10):
		for y: int in range(10, 14):
			img.set_pixel(x, y, armor.darkened(0.15))
	# Bow on right side
	for y: int in range(3, 13):
		img.set_pixel(12, y, weapon)
	img.set_pixel(11, 3, weapon.lightened(0.2))
	img.set_pixel(11, 12, weapon.lightened(0.2))
	# Bowstring
	for y: int in range(4, 12):
		img.set_pixel(13, y, detail.lightened(0.3))

func _draw_duelist(img: Image, body: Color, armor: Color, eyes: Color, weapon: Color, detail: Color) -> void:
	# Head
	for x: int in range(6, 10):
		for y: int in range(1, 5):
			img.set_pixel(x, y, body)
	# Hair (styled)
	for x: int in range(5, 11):
		img.set_pixel(x, 1, armor.lightened(0.1))
	img.set_pixel(5, 2, armor.lightened(0.1))
	img.set_pixel(10, 2, armor.lightened(0.1))
	# Eyes
	img.set_pixel(6, 3, eyes)
	img.set_pixel(9, 3, eyes)
	# Purple garb (fitted)
	for x: int in range(5, 11):
		for y: int in range(5, 10):
			img.set_pixel(x, y, armor)
	# Detail trim
	for x: int in range(5, 11):
		img.set_pixel(x, 5, detail)
	# Belt with buckle
	for x: int in range(5, 11):
		img.set_pixel(x, 9, detail.darkened(0.3))
	img.set_pixel(7, 9, detail.lightened(0.2))
	# Legs (slim)
	for x: int in range(6, 8):
		for y: int in range(10, 14):
			img.set_pixel(x, y, armor.darkened(0.2))
	for x: int in range(8, 10):
		for y: int in range(10, 14):
			img.set_pixel(x, y, armor.darkened(0.2))
	# Rapier (thin, right side)
	for y: int in range(3, 14):
		img.set_pixel(12, y, weapon)
	img.set_pixel(12, 2, weapon.lightened(0.4))  # tip shine
	# Handguard
	img.set_pixel(11, 8, weapon.lightened(0.2))
	img.set_pixel(13, 8, weapon.lightened(0.2))
