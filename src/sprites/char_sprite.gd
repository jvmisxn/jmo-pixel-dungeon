class_name CharSprite
extends Node2D
## Base class for character sprites (heroes, mobs).
## Supports loading from SPD sprite sheets via AtlasTexture, with procedural
## placeholder graphics as a fallback.  Animation and movement tweening are
## handled identically regardless of texture source.

const SPRITE_SIZE: int = 16
const TILE_SIZE: int = 16
const HP_BAR_WIDTH: float = 14.0
const HP_BAR_HEIGHT: float = 2.0

# --- Floating text color constants (matches original CharSprite.java) ---
const COLOR_DEFAULT: int = 0xFFFFFF
const COLOR_POSITIVE: int = 0x00FF00
const COLOR_NEGATIVE: int = 0xFF0000
const COLOR_WARNING: int = 0xFF8800
const COLOR_NEUTRAL: int = 0xFFFF00

# --- Animation States ---
enum AnimState { IDLE, MOVE, ATTACK, HURT, DIE, OPERATE, ZAP }

# --- Emote Icon Types (above-head indicators) ---
enum EmoType { NONE, SLEEP, ALERT, LOST, INVESTIGATE }

# --- Visual state effects (matches original CharSprite.State enum) ---
enum VisualState {
	BURNING, LEVITATING, INVISIBLE, PARALYSED, FROZEN,
	ILLUMINATED, CHILLED, DARKENED, MARKED, HEALING,
	SHIELDED, HEARTS, GLOWING, AURA
}

# --- Properties ---
## The character this sprite represents (Char or subclass).
var character: Node = null
## Current cell position (flat index).
var cell_pos: int = -1
## Target cell position for movement animation.
var target_pos: int = -1
## Whether the sprite is currently animating.
var is_animating: bool = false

# --- Visual Components ---
var _sprite: Sprite2D = null
var _hp_bar_bg: ColorRect = null
var _hp_bar_fill: ColorRect = null
var _flash_tween: Tween = null
var _anim_state: AnimState = AnimState.IDLE
var _move_tween: Tween = null

# --- Visual state tracking (mirrors original's HashSet<State>) ---
var _active_states: Dictionary[int, bool] = {}

# --- Shadow rendering (matches original CharSprite) ---
var render_shadow: bool = false
var shadow_width: float = 1.2
var shadow_height: float = 0.25
var shadow_offset: float = 0.25
var perspective_raise: float = 6.0 / 16.0

# --- Sleeping state (driven by Mob/Hero update, like original) ---
var sleeping: bool = false

# --- Emote icon ---
var _emo_type: EmoType = EmoType.NONE
var _emo_label: Label = null
var _emo_timer: float = 0.0

# --- Sprite-sheet support ---
## If set, the sprite uses this sheet instead of procedural generation.
var sprite_sheet: Texture2D = null
## Region within sprite_sheet for the idle frame.
var sprite_frame_rect: Rect2 = Rect2()

# --- Config (fallback procedural colors) ---
## Base body color for this character.
var body_color: Color = Color(0.6, 0.4, 0.3)
## Accent color (armor, special feature).
var accent_color: Color = Color(0.4, 0.4, 0.5)
## Eye color.
var eye_color: Color = Color(0.9, 0.1, 0.1)

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = true
	add_child(_sprite)
	_generate_sprite()
	_create_hp_bar()

func _process(delta: float) -> void:
	# Update sleeping state for emote icon
	if sleeping:
		show_sleep()
	elif _emo_type == EmoType.SLEEP:
		hide_emo()

	# Emote icon bob animation
	if _emo_label != null and _emo_type != EmoType.NONE:
		_emo_timer += delta
		_emo_label.position.y = -TILE_SIZE - 4 + sin(_emo_timer * 3.0) * 1.5

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Place the sprite at a cell position immediately (no animation).
func place_at(pos: int) -> void:
	cell_pos = pos
	var world_pos: Vector2 = _cell_to_world(pos)
	position = world_pos

## Animate movement to a target cell.
func move_to(pos: int, duration: float = 0.15) -> void:
	if pos == cell_pos:
		return
	# Flip sprite to face movement direction
	var old_world: Vector2 = _cell_to_world(cell_pos)
	var new_world: Vector2 = _cell_to_world(pos)
	var dx: float = new_world.x - old_world.x
	if dx > 0.1:
		_sprite.flip_h = false
	elif dx < -0.1:
		_sprite.flip_h = true

	target_pos = pos
	cell_pos = pos
	is_animating = true
	_anim_state = AnimState.MOVE

	var target_world: Vector2 = new_world

	if _move_tween != null:
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", target_world, duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_move_tween.tween_callback(_on_move_complete)

## Play attack animation toward a target position.
func play_attack(target: int, duration: float = 0.2) -> void:
	_anim_state = AnimState.ATTACK
	is_animating = true
	var target_world: Vector2 = _cell_to_world(target)
	var dir: Vector2 = (target_world - position).normalized()
	var lunge_pos: Vector2 = position + dir * (SPRITE_SIZE * 0.5)

	if _move_tween != null:
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", lunge_pos, duration * 0.4)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_move_tween.tween_property(self, "position", _cell_to_world(cell_pos), duration * 0.6)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_move_tween.tween_callback(_on_attack_complete)

## Flash the sprite (damage taken visual feedback).
func flash(color: Color = Color.RED, duration: float = 0.2) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_sprite.modulate = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_sprite, "modulate", Color.WHITE, duration)

## Play death animation (fade out and shrink).
func play_death(duration: float = 0.5) -> void:
	_anim_state = AnimState.DIE
	is_animating = true
	if _hp_bar_bg:
		_hp_bar_bg.visible = false
	hide_emo()
	if _move_tween != null:
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.set_parallel(true)
	_move_tween.tween_property(_sprite, "modulate:a", 0.0, duration)
	_move_tween.tween_property(_sprite, "scale", Vector2(0.85, 0.85), duration)
	_move_tween.tween_property(self, "position:y", position.y + 3.0, duration)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	_move_tween.set_parallel(false)
	_move_tween.tween_callback(_on_death_complete)

## Play operate animation (using items, interacting with objects).
## Mirrors original CharSprite.operate() — same lunge but toward the cell.
func play_operate(target: int, duration: float = 0.3) -> void:
	_anim_state = AnimState.OPERATE
	is_animating = true
	var target_world: Vector2 = _cell_to_world(target)
	var dir: Vector2 = (target_world - position).normalized()
	var lean_pos: Vector2 = position + dir * (SPRITE_SIZE * 0.25)

	if _move_tween != null:
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", lean_pos, duration * 0.5)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_move_tween.tween_property(self, "position", _cell_to_world(cell_pos), duration * 0.5)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	_move_tween.tween_callback(_on_operate_complete)

## Play zap animation (wand use, ranged attack).
## Mirrors original CharSprite.zap() — same as attack but may use different frame.
func play_zap(target: int, duration: float = 0.2) -> void:
	_anim_state = AnimState.ZAP
	is_animating = true
	play_attack(target, duration)

## Jump to a target cell with a parabolic arc. Matches original CharSprite.jump().
## Used for Pitfall landing, Heroic Leap, and various teleport effects.
func jump(from: int, to: int, height: float = -1.0, duration: float = -1.0) -> void:
	var dist: float = maxf(1.0, _cell_to_world(from).distance_to(_cell_to_world(to)) / float(TILE_SIZE))
	if height < 0.0:
		height = dist * 2.0
	if duration < 0.0:
		duration = dist * 0.1
	is_animating = true
	var start_world: Vector2 = _cell_to_world(from)
	var end_world: Vector2 = _cell_to_world(to)
	cell_pos = to

	# Flip sprite toward destination
	if end_world.x > start_world.x + 0.1:
		_sprite.flip_h = false
	elif end_world.x < start_world.x - 0.1:
		_sprite.flip_h = true

	if _move_tween != null:
		_move_tween.kill()
	_move_tween = create_tween()
	# Animate position with a manual parabolic arc via method tween
	var steps: int = maxi(int(duration / 0.016), 2)
	var step_time: float = duration / float(steps)
	for i: int in range(steps + 1):
		var t: float = float(i) / float(steps)
		var pos_lerp: Vector2 = start_world.lerp(end_world, t)
		var arc_offset: float = -height * 4.0 * t * (1.0 - t)
		var arc_pos: Vector2 = Vector2(pos_lerp.x, pos_lerp.y + arc_offset)
		if i == 0:
			_move_tween.tween_property(self, "position", arc_pos, 0.001)
		else:
			_move_tween.tween_property(self, "position", arc_pos, step_time)
	_move_tween.tween_callback(_on_jump_complete)

## Turn the sprite to face from one cell toward another. Matches original turnTo().
func turn_to(from: int, to: int) -> void:
	var fx: int = from % ConstantsData.WIDTH
	var tx: int = to % ConstantsData.WIDTH
	if tx > fx:
		_sprite.flip_h = false
	elif tx < fx:
		_sprite.flip_h = true

# ---------------------------------------------------------------------------
# Visual State Management (mirrors original CharSprite.State system)
# ---------------------------------------------------------------------------

## Add a visual state effect (burning particles, ice block, etc.).
func add_visual_state(state: VisualState) -> void:
	if _active_states.get(state, false):
		return
	_active_states[state] = true
	_process_state_addition(state)

## Remove a visual state effect.
func remove_visual_state(state: VisualState) -> void:
	if not _active_states.get(state, false):
		return
	_active_states[state] = false
	_process_state_removal(state)

## Check if a visual state is active.
func has_visual_state(state: VisualState) -> bool:
	return _active_states.get(state, false)

func _process_state_addition(state: VisualState) -> void:
	match state:
		VisualState.INVISIBLE:
			_sprite.modulate.a = 0.4
		VisualState.PARALYSED:
			# Pause animation (original sets paused=true on MovieClip)
			pass
		VisualState.FROZEN:
			_sprite.modulate = Color(0.6, 0.8, 1.0, 0.9)
		VisualState.BURNING:
			_sprite.modulate = Color(1.0, 0.6, 0.3)
		VisualState.CHILLED:
			_sprite.modulate = Color(0.7, 0.85, 1.0)
		VisualState.DARKENED:
			_sprite.modulate = Color(0.5, 0.5, 0.6)
		VisualState.MARKED:
			_sprite.modulate = Color(1.0, 0.5, 0.5)
		VisualState.HEALING:
			_sprite.modulate = Color(0.5, 1.0, 0.5)
		VisualState.SHIELDED:
			_sprite.modulate = Color(0.8, 0.8, 1.0)
		VisualState.ILLUMINATED:
			_sprite.modulate = Color(1.0, 1.0, 0.8)
		VisualState.HEARTS:
			pass  # Particle effect — stub
		VisualState.GLOWING:
			_sprite.modulate = Color(1.0, 1.0, 0.7)
		VisualState.AURA:
			pass  # Particle effect — stub

func _process_state_removal(_state: int) -> void:
	# Reset modulate then re-apply any remaining active states
	if _sprite:
		_sprite.modulate = Color.WHITE
	for s: int in _active_states.keys():
		if _active_states[s]:
			_process_state_addition(s)

# ---------------------------------------------------------------------------
# Visibility & HP Bar
# ---------------------------------------------------------------------------

## Show or hide the sprite (fog of war driven).
func set_visible_state(shown: bool) -> void:
	visible = shown

## Update the HP bar display.
func update_hp_bar(hp: int, ht: int) -> void:
	if _hp_bar_bg == null or _hp_bar_fill == null:
		return
	if ht <= 0:
		_hp_bar_bg.visible = false
		return
	_hp_bar_bg.visible = true
	var ratio: float = clampf(float(hp) / float(ht), 0.0, 1.0)
	_hp_bar_fill.size.x = HP_BAR_WIDTH * ratio
	if ratio > 0.5:
		_hp_bar_fill.color = Color(0.2, 0.8, 0.2)
	elif ratio > 0.25:
		_hp_bar_fill.color = Color(0.9, 0.8, 0.1)
	else:
		_hp_bar_fill.color = Color(0.9, 0.2, 0.1)

# ---------------------------------------------------------------------------
# Sprite Sheet Support
# ---------------------------------------------------------------------------

## Load a sprite from a texture atlas (SPD sprite sheet).
func setup_from_sheet(sheet: Texture2D, region: Rect2) -> void:
	sprite_sheet = sheet
	sprite_frame_rect = region
	if _sprite:
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = region
		_sprite.texture = atlas
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## Regenerate the procedural texture from current colors.
func refresh_texture() -> void:
	_generate_sprite()

# ---------------------------------------------------------------------------
# Emote Icons (sleep Z, alert !, etc.)
# ---------------------------------------------------------------------------

func show_sleep() -> void:
	_show_emo(EmoType.SLEEP, "Z")

func show_alert() -> void:
	_show_emo(EmoType.ALERT, "!")

func hide_emo() -> void:
	_emo_type = EmoType.NONE
	if _emo_label and is_instance_valid(_emo_label):
		_emo_label.queue_free()
		_emo_label = null

func _show_emo(emo: EmoType, text: String) -> void:
	if _emo_type == emo:
		return
	hide_emo()
	_emo_type = emo
	_emo_timer = 0.0
	_emo_label = Label.new()
	_emo_label.text = text
	_emo_label.add_theme_font_size_override("font_size", 8)
	_emo_label.add_theme_color_override("font_color", Color.WHITE)
	_emo_label.position = Vector2(-4, -TILE_SIZE - 4)
	add_child(_emo_label)

# ---------------------------------------------------------------------------
# Internal — Sprite Generation
# ---------------------------------------------------------------------------

func _generate_sprite() -> void:
	# If a sprite sheet was loaded, use it
	if sprite_sheet != null and sprite_frame_rect.size.x > 0:
		setup_from_sheet(sprite_sheet, sprite_frame_rect)
		return
	# Otherwise generate procedurally
	var img: Image = Image.create(SPRITE_SIZE, SPRITE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_draw_character(img)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	if _sprite:
		_sprite.texture = tex
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## Override in subclasses for class-specific drawing.
func _draw_character(img: Image) -> void:
	# Base fallback: simple colored humanoid silhouette
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

func _create_hp_bar() -> void:
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	_hp_bar_bg.color = Color(0.2, 0.2, 0.2, 0.8)
	_hp_bar_bg.position = Vector2(-HP_BAR_WIDTH / 2.0, -SPRITE_SIZE / 2.0 - HP_BAR_HEIGHT - 1)
	_hp_bar_bg.visible = false
	add_child(_hp_bar_bg)

	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	_hp_bar_fill.color = Color(0.2, 0.8, 0.2)
	_hp_bar_fill.position = Vector2.ZERO
	_hp_bar_bg.add_child(_hp_bar_fill)

# ---------------------------------------------------------------------------
# Animation Callbacks
# ---------------------------------------------------------------------------

func _on_move_complete() -> void:
	_anim_state = AnimState.IDLE
	is_animating = false

func _on_attack_complete() -> void:
	_anim_state = AnimState.IDLE
	is_animating = false

func _on_death_complete() -> void:
	_anim_state = AnimState.IDLE
	is_animating = false
	queue_free()

func _on_operate_complete() -> void:
	_anim_state = AnimState.IDLE
	is_animating = false

func _on_jump_complete() -> void:
	_anim_state = AnimState.IDLE
	is_animating = false

# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

func _cell_to_world(pos: int) -> Vector2:
	var cx: int = ConstantsData.pos_to_x(pos)
	var cy: int = ConstantsData.pos_to_y(pos)
	@warning_ignore("integer_division")
	return Vector2(cx * TILE_SIZE + TILE_SIZE / 2, cy * TILE_SIZE + TILE_SIZE / 2)
