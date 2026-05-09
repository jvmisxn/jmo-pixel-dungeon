class_name FogOfWar
extends Node2D
## Three-state fog of war overlay using a GPU shader.
## States: UNSEEN (fully black), VISITED (dim), VISIBLE (clear with distance fade).
##
## The GDScript side writes a tiny data texture (1 pixel per cell) encoding
## the visibility state. The shader reads this texture and computes distance-
## based torch-light falloff entirely on the GPU — no per-cell GDScript math.

const TILE_SIZE: int = 16

# --- Fog state values written to the data texture's R channel ---
const STATE_UNSEEN: float = 0.0
const STATE_VISITED: float = 0.5
const STATE_VISIBLE: float = 1.0

# --- References ---
var level: Variant = null

# --- Internal ---
var _fog_image: Image = null
var _fog_texture: ImageTexture = null
var _fog_sprite: Sprite2D = null
var _shader_material: ShaderMaterial = null
var _is_dark: bool = false
var _initialized: bool = false
var _hero_pos: int = -1

# Previous visibility state for efficient delta updates
var _prev_visible: Array[bool] = []
var _prev_visited: Array[bool] = []

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
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


## Full re-render of the fog data texture (use sparingly).
func render_full() -> void:
	if level == null or _fog_image == null:
		return
	if GameManager and GameManager.hero:
		_hero_pos = GameManager.hero.pos
	for pos: int in range(ConstantsData.LENGTH):
		_set_fog_pixel(pos)
	_fog_texture.update(_fog_image)
	_update_shader_uniforms()
	_prev_visible = level.visible.duplicate()
	_prev_visited = level.visited.duplicate()


## Efficient update — only redraws cells whose visibility state changed.
## Distance-based fade is handled by the shader, so we only need to update
## cells that transitioned between unseen/visited/visible.
func update_visibility() -> void:
	if level == null or _fog_image == null or not _initialized:
		render_full()
		return

	if GameManager and GameManager.hero:
		_hero_pos = GameManager.hero.pos

	var changed: bool = false
	for pos: int in range(ConstantsData.LENGTH):
		var vis_now: bool = level.visible[pos] if pos < level.visible.size() else false
		var vis_prev: bool = _prev_visible[pos] if pos < _prev_visible.size() else false
		var vst_now: bool = level.visited[pos] if pos < level.visited.size() else false
		var vst_prev: bool = _prev_visited[pos] if pos < _prev_visited.size() else false

		if vis_now != vis_prev or vst_now != vst_prev:
			_set_fog_pixel(pos)
			changed = true

	if changed:
		_fog_texture.update(_fog_image)

	# Always update hero position uniform (shader uses it for distance fade)
	_update_shader_uniforms()
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
	if _shader_material:
		_shader_material.set_shader_parameter("is_dark", _is_dark)

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _create_fog() -> void:
	# Data image: 1 pixel per cell with a 1-cell border for smooth filtering
	var w: int = ConstantsData.WIDTH + 2
	var h: int = ConstantsData.HEIGHT + 2
	_fog_image = Image.create(w, h, false, Image.FORMAT_R8)
	_fog_image.fill(Color(STATE_UNSEEN, 0, 0))

	_fog_texture = ImageTexture.create_from_image(_fog_image)

	# Load the shader
	var shader: Shader = load("res://src/tiles/fog_of_war.gdshader") as Shader
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	_shader_material.set_shader_parameter("fog_data", _fog_texture)
	_shader_material.set_shader_parameter("map_size", Vector2(ConstantsData.WIDTH, ConstantsData.HEIGHT))
	_shader_material.set_shader_parameter("is_dark", _is_dark)

	if _fog_sprite != null:
		_fog_sprite.queue_free()
	_fog_sprite = Sprite2D.new()
	_fog_sprite.centered = false
	_fog_sprite.texture = _fog_texture
	# Scale: each pixel covers one TILE_SIZE cell, offset by -1 cell for the border
	_fog_sprite.scale = Vector2(TILE_SIZE, TILE_SIZE)
	_fog_sprite.position = Vector2(-TILE_SIZE, -TILE_SIZE)
	_fog_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_fog_sprite.material = _shader_material
	add_child(_fog_sprite)

	_prev_visible.resize(ConstantsData.LENGTH)
	_prev_visible.fill(false)
	_prev_visited.resize(ConstantsData.LENGTH)
	_prev_visited.fill(false)


func _set_fog_pixel(pos: int) -> void:
	if _fog_image == null or level == null:
		return
	var x: int = ConstantsData.pos_to_x(pos) + 1  # +1 for border offset
	var y: int = ConstantsData.pos_to_y(pos) + 1

	var state: float = STATE_UNSEEN
	if pos < level.visible.size() and level.visible[pos]:
		state = STATE_VISIBLE
	elif pos < level.visited.size() and level.visited[pos]:
		state = STATE_VISITED
	elif level.get("mapped") and pos < level.mapped.size() and level.mapped[pos]:
		state = STATE_VISITED

	_fog_image.set_pixel(x, y, Color(state, 0, 0))


func _update_shader_uniforms() -> void:
	if _shader_material == null:
		return
	if _hero_pos >= 0:
		var hx: float = float(ConstantsData.pos_to_x(_hero_pos))
		var hy: float = float(ConstantsData.pos_to_y(_hero_pos))
		_shader_material.set_shader_parameter("hero_cell", Vector2(hx, hy))
