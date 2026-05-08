class_name FogOfWar
extends Node2D
## Three-state fog of war overlay rendered on top of the tile map.
## States: UNSEEN (fully black), VISITED (dim/gray), VISIBLE (clear with distance fade).
##
## Uses a small image (1 pixel per cell) with BILINEAR texture filtering.
## The GPU smoothly interpolates between neighboring cells' fog values,
## creating soft gradient edges that match the original SPD look.
##
## Visible cells darken with distance from the hero, creating a natural
## torch-light falloff that limits how far the player can clearly see.

const TILE_SIZE: int = 16

# --- Fog Alpha Values ---
## Fully opaque black — cell has never been seen.
const ALPHA_UNSEEN: float = 1.0
## Semi-transparent — cell was visited but is not in current FOV.
const ALPHA_VISITED: float = 0.65
## Fully transparent — cell is currently visible and close to hero.
const ALPHA_VISIBLE: float = 0.0
## Slightly dimmed — visible cell on a DARK level.
const ALPHA_DARK_VISIBLE: float = 0.35

## Distance at which visible cells start to dim (in cells from hero).
const FADE_START: float = 4.0
## Distance at which visible cells reach max dimming.
const FADE_END: float = 7.0
## Maximum alpha applied to distant visible cells.
const FADE_MAX_ALPHA: float = 0.55

# --- References ---
var level: Variant = null

# --- Internal ---
## Small image: 1 pixel per cell (WIDTH+2 x HEIGHT+2 with border).
var _fog_image: Image = null
var _fog_texture: ImageTexture = null
var _fog_sprite: Sprite2D = null
var _is_dark: bool = false
var _initialized: bool = false
## Hero position for distance-based fog
var _hero_pos: int = -1

# Previous visibility state for efficient updates
var _prev_visible: Array[bool] = []
var _prev_visited: Array[bool] = []

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Fog renders above tiles and entities
	z_index = 100

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Initialize the fog of war for a given level.
func setup(p_level: Variant, is_dark: bool = false) -> void:
	level = p_level
	_is_dark = is_dark
	_create_fog()
	render_full()
	_initialized = true

## Full re-render of the fog (expensive, use sparingly).
func render_full() -> void:
	if level == null or _fog_image == null:
		return
	# Update hero position
	if GameManager and GameManager.hero:
		_hero_pos = GameManager.hero.pos
	for pos: int in range(ConstantsData.LENGTH):
		_set_fog_pixel(pos)
	_fog_texture.update(_fog_image)
	_prev_visible = level.visible.duplicate()
	_prev_visited = level.visited.duplicate()

## Efficient update — only redraws cells whose visibility changed.
func update_visibility() -> void:
	if level == null or _fog_image == null or not _initialized:
		render_full()
		return

	# Update hero position
	if GameManager and GameManager.hero:
		_hero_pos = GameManager.hero.pos

	# When hero moves, all visible cells need distance recalculation
	var changed: bool = false
	for pos: int in range(ConstantsData.LENGTH):
		var vis_changed: bool = false
		if pos < _prev_visible.size():
			vis_changed = _prev_visible[pos] != level.visible[pos]
		else:
			vis_changed = true
		if not vis_changed and pos < _prev_visited.size():
			vis_changed = _prev_visited[pos] != level.visited[pos]
		elif not vis_changed:
			vis_changed = true

		# Also update visible cells (distance may have changed as hero moved)
		if not vis_changed and level.visible[pos]:
			vis_changed = true

		if vis_changed:
			_set_fog_pixel(pos)
			changed = true

	if changed:
		_fog_texture.update(_fog_image)

	_prev_visible = level.visible.duplicate()
	_prev_visited = level.visited.duplicate()

## Reveal the entire map (e.g., magic mapping scroll).
func reveal_all() -> void:
	if _fog_image == null:
		return
	for pos: int in range(ConstantsData.LENGTH):
		level.mapped[pos] = true
		level.visited[pos] = true
	render_full()

## Set whether the level has the DARK feeling.
func set_dark(is_dark: bool) -> void:
	_is_dark = is_dark
	if _initialized:
		render_full()

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _create_fog() -> void:
	# Create fog image: 1 pixel per cell, with a 1-cell border for smooth edges
	var w: int = ConstantsData.WIDTH + 2
	var h: int = ConstantsData.HEIGHT + 2
	_fog_image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	_fog_image.fill(Color(0, 0, 0, ALPHA_UNSEEN))

	_fog_texture = ImageTexture.create_from_image(_fog_image)

	if _fog_sprite != null:
		_fog_sprite.queue_free()
	_fog_sprite = Sprite2D.new()
	_fog_sprite.centered = false
	_fog_sprite.texture = _fog_texture
	# Scale: each pixel covers one TILE_SIZE cell, offset by -1 cell for the border
	_fog_sprite.scale = Vector2(TILE_SIZE, TILE_SIZE)
	_fog_sprite.position = Vector2(-TILE_SIZE, -TILE_SIZE)
	_fog_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_fog_sprite)

	# Init prev arrays
	_prev_visible.resize(ConstantsData.LENGTH)
	_prev_visible.fill(false)
	_prev_visited.resize(ConstantsData.LENGTH)
	_prev_visited.fill(false)

func _set_fog_pixel(pos: int) -> void:
	if _fog_image == null or level == null:
		return
	var x: int = ConstantsData.pos_to_x(pos) + 1  # +1 for border offset
	var y: int = ConstantsData.pos_to_y(pos) + 1

	var alpha: float = ALPHA_UNSEEN
	if pos < level.visible.size() and level.visible[pos]:
		# Currently visible — apply distance-based dimming
		alpha = ALPHA_VISIBLE
		if _hero_pos >= 0:
			var hx: int = ConstantsData.pos_to_x(_hero_pos)
			var hy: int = ConstantsData.pos_to_y(_hero_pos)
			var cx: int = ConstantsData.pos_to_x(pos)
			var cy: int = ConstantsData.pos_to_y(pos)
			var dist: float = sqrt(float((cx - hx) * (cx - hx) + (cy - hy) * (cy - hy)))
			if dist > FADE_START:
				var t: float = clampf((dist - FADE_START) / (FADE_END - FADE_START), 0.0, 1.0)
				alpha = lerpf(ALPHA_VISIBLE, FADE_MAX_ALPHA, t)
		if _is_dark:
			alpha = maxf(alpha, ALPHA_DARK_VISIBLE)
	elif pos < level.visited.size() and level.visited[pos]:
		alpha = ALPHA_VISITED
	elif level.get("mapped") and pos < level.mapped.size() and level.mapped[pos]:
		alpha = ALPHA_VISITED

	_fog_image.set_pixel(x, y, Color(0, 0, 0, alpha))

