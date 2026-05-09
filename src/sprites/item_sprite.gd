class_name ItemSprite
extends Node2D
## Sprite for items on the ground or in UI. Supports loading icons from the
## SPD item sprite sheet (items.png, 256x512, 16x16 grid) with procedural
## fallback. Matches original ItemSpriteSheet.java layout.

const SPRITE_SIZE: int = 16

# --- SPD item sheet layout (256x512 PNG, 16 columns of 16x16 tiles) ---
const SHEET_PATH: String = "res://assets/spd/sprites/items.png"
const SHEET_COLUMNS: int = 16

## Cached item sheet texture.
static var _item_sheet: Texture2D = null
static var _item_sheet_loaded: bool = false

## Cache for procedurally generated textures, keyed by "category:color_hex".
## Avoids regenerating the same 16x16 image every time an item spawns.
static var _procedural_cache: Dictionary = {}

# --- Category Colors ---
static var CATEGORY_COLORS: Dictionary = {
	ConstantsData.ItemCategory.WEAPON: Color(0.6, 0.6, 0.65),
	ConstantsData.ItemCategory.ARMOR: Color(0.5, 0.5, 0.55),
	ConstantsData.ItemCategory.WAND: Color(0.4, 0.3, 0.2),
	ConstantsData.ItemCategory.RING: Color(0.8, 0.7, 0.2),
	ConstantsData.ItemCategory.ARTIFACT: Color(0.6, 0.3, 0.6),
	ConstantsData.ItemCategory.POTION: Color(0.3, 0.5, 0.8),
	ConstantsData.ItemCategory.SCROLL: Color(0.85, 0.8, 0.6),
	ConstantsData.ItemCategory.STONE: Color(0.5, 0.5, 0.5),
	ConstantsData.ItemCategory.SEED: Color(0.3, 0.6, 0.2),
	ConstantsData.ItemCategory.FOOD: Color(0.7, 0.5, 0.2),
	ConstantsData.ItemCategory.GOLD: Color(0.9, 0.8, 0.1),
	ConstantsData.ItemCategory.MISC: Color(0.6, 0.6, 0.6),
}

# --- Visual Components ---
var _sprite: Sprite2D = null

# --- Properties ---
var item_category: int = ConstantsData.ItemCategory.MISC
var item_color: Color = Color(0.6, 0.6, 0.6)
var cell_pos: int = -1
## SPD sprite sheet index (-1 = use procedural). Items with a valid sprite_index
## load their icon from the sheet instead of generating it procedurally.
var sprite_index: int = -1

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = true
	add_child(_sprite)
	_generate_sprite()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Set up from an item object (reads category, icon_color, and sprite_index if available).
func setup_from_item(item: Object) -> void:
	if item == null:
		_generate_sprite()
		return
	var cat_val: Variant = item.get("category")
	item_category = cat_val as int if cat_val is int else ConstantsData.ItemCategory.MISC
	var col_val: Variant = item.get("icon_color")
	item_color = col_val as Color if col_val is Color else CATEGORY_COLORS.get(item_category, Color(0.6, 0.6, 0.6))
	# Try to use SPD sheet index if the item provides one
	var idx_val: Variant = item.get("sprite_index")
	sprite_index = idx_val as int if idx_val is int else -1
	_generate_sprite()

## Set up with explicit category and color.
func setup_manual(category: int, color: Color = Color.WHITE) -> void:
	item_category = category
	item_color = color if color != Color.WHITE else CATEGORY_COLORS.get(category, Color(0.6, 0.6, 0.6))
	sprite_index = -1
	_generate_sprite()

## Set up from an SPD item sheet index directly.
func setup_from_sheet_index(index: int) -> void:
	sprite_index = index
	_generate_sprite()

## Place at a cell position.
func place_at(pos: int) -> void:
	cell_pos = pos
	var x: int = ConstantsData.pos_to_x(pos)
	var y: int = ConstantsData.pos_to_y(pos)
	@warning_ignore("integer_division")
	position = Vector2(x * SPRITE_SIZE + SPRITE_SIZE / 2, y * SPRITE_SIZE + SPRITE_SIZE / 2)

## Play pickup animation (float up and fade).
func play_pickup(duration: float = 0.3) -> void:
	if _sprite == null:
		queue_free()
		return
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 12.0, duration)
	tween.tween_property(_sprite, "modulate:a", 0.0, duration)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)

## Play drop animation (fall from above).
func play_drop() -> void:
	if _sprite == null:
		return
	var target_y: float = position.y
	position.y -= 16.0
	_sprite.modulate.a = 0.5
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", target_y, 0.25)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(_sprite, "modulate:a", 1.0, 0.15)

# ---------------------------------------------------------------------------
# Generation
# ---------------------------------------------------------------------------

func _generate_sprite() -> void:
	# Try SPD item sprite sheet first (matches ItemSpriteSheet.java layout)
	if sprite_index >= 0:
		if not _item_sheet_loaded:
			_item_sheet_loaded = true
			_item_sheet = load(SHEET_PATH) as Texture2D
		if _item_sheet != null:
			var col: int = sprite_index % SHEET_COLUMNS
			var row: int = sprite_index / SHEET_COLUMNS
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = _item_sheet
			atlas.region = Rect2(col * SPRITE_SIZE, row * SPRITE_SIZE, SPRITE_SIZE, SPRITE_SIZE)
			if _sprite:
				_sprite.texture = atlas
				_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			return

	# Fallback: procedural generation with caching
	var cache_key: String = str(item_category) + ":" + item_color.to_html()
	var cached_tex: Variant = _procedural_cache.get(cache_key)
	if cached_tex is ImageTexture:
		if _sprite:
			_sprite.texture = cached_tex
			_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		return

	var img: Image = Image.create(SPRITE_SIZE, SPRITE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	match item_category:
		ConstantsData.ItemCategory.WEAPON:
			_draw_weapon(img)
		ConstantsData.ItemCategory.ARMOR:
			_draw_armor(img)
		ConstantsData.ItemCategory.WAND:
			_draw_wand(img)
		ConstantsData.ItemCategory.RING:
			_draw_ring(img)
		ConstantsData.ItemCategory.ARTIFACT:
			_draw_artifact(img)
		ConstantsData.ItemCategory.POTION:
			_draw_potion(img)
		ConstantsData.ItemCategory.SCROLL:
			_draw_scroll(img)
		ConstantsData.ItemCategory.STONE:
			_draw_stone(img)
		ConstantsData.ItemCategory.SEED:
			_draw_seed(img)
		ConstantsData.ItemCategory.FOOD:
			_draw_food(img)
		ConstantsData.ItemCategory.GOLD:
			_draw_gold(img)
		_:
			_draw_misc(img)

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_procedural_cache[cache_key] = tex
	if _sprite:
		_sprite.texture = tex
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _draw_weapon(img: Image) -> void:
	# Sword shape (diagonal)
	var blade: Color = item_color
	var handle: Color = Color(0.4, 0.25, 0.1)
	# Blade
	for i: int in range(10):
		var x: int = 4 + i
		var y: int = 12 - i
		if x < SPRITE_SIZE and y >= 0 and y < SPRITE_SIZE:
			img.set_pixel(x, y, blade)
			if x + 1 < SPRITE_SIZE:
				img.set_pixel(x + 1, y, blade.darkened(0.2))
	# Handle
	for i: int in range(3):
		var x: int = 2 + i
		var y: int = 13 - i
		if x >= 0 and y < SPRITE_SIZE:
			img.set_pixel(x, y, handle)
	# Crossguard
	img.set_pixel(3, 10, handle.lightened(0.2))
	img.set_pixel(4, 11, handle.lightened(0.2))
	img.set_pixel(5, 10, handle.lightened(0.2))

func _draw_armor(img: Image) -> void:
	var col: Color = item_color
	# Chestplate shape
	for x: int in range(4, 12):
		for y: int in range(3, 12):
			img.set_pixel(x, y, col)
	# Neckline
	for x: int in range(6, 10):
		img.set_pixel(x, 3, col.lightened(0.2))
	# Shoulders
	for x: int in range(3, 5):
		for y: int in range(4, 7):
			img.set_pixel(x, y, col.lightened(0.1))
	for x: int in range(11, 13):
		for y: int in range(4, 7):
			img.set_pixel(x, y, col.lightened(0.1))
	# Belt
	for x: int in range(4, 12):
		img.set_pixel(x, 10, col.darkened(0.3))

func _draw_wand(img: Image) -> void:
	var wood: Color = item_color
	var tip: Color = Color(0.5, 0.8, 1.0)
	# Staff body (diagonal)
	for i: int in range(12):
		var x: int = 3 + i
		var y: int = 13 - i
		if x < SPRITE_SIZE and y >= 0:
			img.set_pixel(x, y, wood)
	# Glowing tip
	img.set_pixel(13, 2, tip)
	img.set_pixel(14, 1, tip)
	img.set_pixel(12, 1, tip.lerp(Color.WHITE, 0.3))
	img.set_pixel(14, 3, tip.lerp(Color.WHITE, 0.3))

func _draw_ring(img: Image) -> void:
	var col: Color = item_color
	# Ring circle
	for angle: int in range(16):
		var a: float = float(angle) * TAU / 16.0
		var x: int = int(cos(a) * 4.0) + 8
		var y: int = int(sin(a) * 4.0) + 8
		if x >= 0 and x < SPRITE_SIZE and y >= 0 and y < SPRITE_SIZE:
			img.set_pixel(x, y, col)
	# Gem on top
	img.set_pixel(8, 4, col.lightened(0.5))
	img.set_pixel(7, 4, col.lightened(0.3))
	img.set_pixel(9, 4, col.lightened(0.3))

func _draw_artifact(img: Image) -> void:
	var col: Color = item_color
	# Mysterious object — diamond shape with glow
	for i: int in range(5):
		for j: int in range(5 - i):
			img.set_pixel(8 + j, 4 + i + j, col)
			img.set_pixel(8 - j, 4 + i + j, col)
			img.set_pixel(8 + j, 12 - i - j, col)
			img.set_pixel(8 - j, 12 - i - j, col)
	# Center glow
	img.set_pixel(8, 8, col.lightened(0.6))
	img.set_pixel(7, 8, col.lightened(0.3))
	img.set_pixel(9, 8, col.lightened(0.3))

func _draw_potion(img: Image) -> void:
	var liquid: Color = item_color
	var glass: Color = Color(0.8, 0.85, 0.9, 0.7)
	# Bottle body
	for x: int in range(5, 11):
		for y: int in range(7, 14):
			img.set_pixel(x, y, glass)
	# Liquid fill (lower 2/3)
	for x: int in range(6, 10):
		for y: int in range(9, 13):
			img.set_pixel(x, y, liquid)
	# Neck
	for x: int in range(7, 9):
		for y: int in range(4, 7):
			img.set_pixel(x, y, glass)
	# Cork
	for x: int in range(7, 9):
		img.set_pixel(x, 3, Color(0.5, 0.35, 0.15))
		img.set_pixel(x, 4, Color(0.5, 0.35, 0.15))

func _draw_scroll(img: Image) -> void:
	var paper: Color = item_color
	var seal: Color = Color(0.8, 0.2, 0.1)
	# Rolled scroll body
	for x: int in range(4, 12):
		for y: int in range(5, 12):
			img.set_pixel(x, y, paper)
	# Roll edges (darker)
	for y: int in range(5, 12):
		img.set_pixel(4, y, paper.darkened(0.2))
		img.set_pixel(11, y, paper.darkened(0.2))
	# Roll ends
	for x: int in range(3, 13):
		img.set_pixel(x, 4, paper.darkened(0.1))
		img.set_pixel(x, 12, paper.darkened(0.1))
	# Wax seal
	img.set_pixel(7, 8, seal)
	img.set_pixel(8, 8, seal)
	img.set_pixel(7, 9, seal)
	img.set_pixel(8, 9, seal)

func _draw_stone(img: Image) -> void:
	var col: Color = item_color
	# Rough stone shape
	for x: int in range(5, 11):
		for y: int in range(6, 11):
			img.set_pixel(x, y, col)
	# Irregular edges
	img.set_pixel(5, 7, col.darkened(0.2))
	img.set_pixel(10, 9, col.darkened(0.2))
	img.set_pixel(6, 6, col.lightened(0.1))
	img.set_pixel(9, 10, col.lightened(0.1))

func _draw_seed(img: Image) -> void:
	var col: Color = item_color
	# Small seed shape
	for x: int in range(6, 10):
		for y: int in range(7, 11):
			img.set_pixel(x, y, col)
	# Rounded top
	img.set_pixel(7, 6, col)
	img.set_pixel(8, 6, col)
	# Stem
	img.set_pixel(8, 5, col.darkened(0.3))
	img.set_pixel(8, 4, col.darkened(0.3))
	# Leaf
	img.set_pixel(9, 4, Color(0.3, 0.6, 0.2))
	img.set_pixel(10, 3, Color(0.3, 0.6, 0.2))

func _draw_food(img: Image) -> void:
	var col: Color = item_color
	# Meat/ration shape (rounded rectangle)
	for x: int in range(4, 12):
		for y: int in range(6, 12):
			img.set_pixel(x, y, col)
	# Rounded edges
	img.set_pixel(4, 6, Color(0, 0, 0, 0))
	img.set_pixel(11, 6, Color(0, 0, 0, 0))
	img.set_pixel(4, 11, Color(0, 0, 0, 0))
	img.set_pixel(11, 11, Color(0, 0, 0, 0))
	# Highlight
	for x: int in range(5, 10):
		img.set_pixel(x, 7, col.lightened(0.2))

func _draw_gold(img: Image) -> void:
	var col: Color = item_color
	# Stack of coins
	for x: int in range(5, 11):
		for y: int in range(8, 12):
			img.set_pixel(x, y, col)
	# Top coin (slightly offset)
	for x: int in range(4, 10):
		for y: int in range(6, 9):
			img.set_pixel(x, y, col.lightened(0.15))
	# Shine
	img.set_pixel(5, 6, col.lightened(0.4))
	img.set_pixel(6, 7, col.lightened(0.3))

func _draw_misc(img: Image) -> void:
	var col: Color = item_color
	# Generic item: small box
	for x: int in range(5, 11):
		for y: int in range(5, 11):
			img.set_pixel(x, y, col)
	# Border
	for x: int in range(5, 11):
		img.set_pixel(x, 5, col.darkened(0.2))
		img.set_pixel(x, 10, col.darkened(0.2))
	for y: int in range(5, 11):
		img.set_pixel(5, y, col.darkened(0.2))
		img.set_pixel(10, y, col.darkened(0.2))
