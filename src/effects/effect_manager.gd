class_name EffectManager
extends Node2D
## Manages visual effects (damage numbers, projectiles, particles, etc.).
## Effects are spawned as child nodes and self-destruct when complete.
## Singleton-like: one instance per GameScene.

# --- Effect Pool Limits ---
const MAX_EFFECTS: int = 50
const MAX_DAMAGE_NUMBERS: int = 20

# --- Counters ---
var _active_effects: int = 0
var _active_numbers: int = 0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	z_index = 50  # Above sprites, below fog

# ---------------------------------------------------------------------------
# Public API — Damage Numbers
# ---------------------------------------------------------------------------

## Show a floating damage number at a cell position.
func show_damage(pos: int, amount: int, is_crit: bool = false) -> void:
	if _active_numbers >= MAX_DAMAGE_NUMBERS:
		return
	var num: DamageNumber = DamageNumber.new()
	num.setup(amount, is_crit)
	num.position = _cell_to_world(pos) + Vector2(0, -4)
	add_child(num)
	_active_numbers += 1
	num.tree_exited.connect(func() -> void: _active_numbers -= 1)

## Show a healing number (green).
func show_heal(pos: int, amount: int) -> void:
	if _active_numbers >= MAX_DAMAGE_NUMBERS:
		return
	var num: DamageNumber = DamageNumber.new()
	num.setup_heal(amount)
	num.position = _cell_to_world(pos) + Vector2(0, -4)
	add_child(num)
	_active_numbers += 1
	num.tree_exited.connect(func() -> void: _active_numbers -= 1)

## Show a status text (e.g., "Missed!", "Blocked!").
func show_status(pos: int, text: String, color: Color = Color.WHITE) -> void:
	if _active_numbers >= MAX_DAMAGE_NUMBERS:
		return
	var num: DamageNumber = DamageNumber.new()
	num.setup_text(text, color)
	num.position = _cell_to_world(pos) + Vector2(0, -4)
	add_child(num)
	_active_numbers += 1
	num.tree_exited.connect(func() -> void: _active_numbers -= 1)

# ---------------------------------------------------------------------------
# Public API — Projectiles
# ---------------------------------------------------------------------------

## Fire a projectile from one cell to another.
func shoot_projectile(
	from_pos: int, to_pos: int, color: Color = Color.WHITE, speed: float = 300.0
) -> void:
	if _active_effects >= MAX_EFFECTS:
		return
	var proj: ProjectileEffect = ProjectileEffect.new()
	proj.setup(_cell_to_world(from_pos), _cell_to_world(to_pos), color, speed)
	add_child(proj)
	_active_effects += 1
	proj.tree_exited.connect(func() -> void: _active_effects -= 1)

# ---------------------------------------------------------------------------
# Public API — Particles
# ---------------------------------------------------------------------------

## Burst of particles at a cell (e.g., potion shatter, explosion).
func particle_burst(pos: int, color: Color, count: int = 8) -> void:
	if _active_effects >= MAX_EFFECTS:
		return
	var burst: ParticleBurst = ParticleBurst.new()
	burst.setup(color, count)
	burst.position = _cell_to_world(pos)
	add_child(burst)
	_active_effects += 1
	burst.tree_exited.connect(func() -> void: _active_effects -= 1)

## Ring/expanding circle effect (e.g., scroll of lullaby).
func ring_effect(pos: int, color: Color, radius: float = 48.0, duration: float = 0.5) -> void:
	if _active_effects >= MAX_EFFECTS:
		return
	var burst: ParticleBurst = ParticleBurst.new()
	burst.setup_ring(color, radius, duration)
	burst.position = _cell_to_world(pos)
	add_child(burst)
	_active_effects += 1
	burst.tree_exited.connect(func() -> void: _active_effects -= 1)

# ---------------------------------------------------------------------------
# Public API — Lightning
# ---------------------------------------------------------------------------

## Draw a lightning bolt between two cells.
func lightning(from_pos: int, to_pos: int, color: Color = Color(0.7, 0.8, 1.0)) -> void:
	if _active_effects >= MAX_EFFECTS:
		return
	var bolt: LightningEffect = LightningEffect.new()
	bolt.setup(_cell_to_world(from_pos), _cell_to_world(to_pos), color)
	add_child(bolt)
	_active_effects += 1
	bolt.tree_exited.connect(func() -> void: _active_effects -= 1)

# ---------------------------------------------------------------------------
# Public API — Screen Effects
# ---------------------------------------------------------------------------

## Flash the screen (e.g., scroll of retribution).
func screen_flash(color: Color = Color(1, 1, 1, 0.5), duration: float = 0.2) -> void:
	var flash_rect: ColorRect = ColorRect.new()
	flash_rect.color = color
	# Use viewport size instead of hardcoded resolution for resolution independence
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	flash_rect.size = vp_size * 2.0  # Oversized to cover camera movement/zoom
	flash_rect.position = -vp_size
	flash_rect.z_index = 200
	add_child(flash_rect)
	var tween: Tween = create_tween()
	tween.tween_property(flash_rect, "color:a", 0.0, duration)
	tween.tween_callback(flash_rect.queue_free)

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _cell_to_world(pos: int) -> Vector2:
	var cx: int = ConstantsData.pos_to_x(pos)
	var cy: int = ConstantsData.pos_to_y(pos)
	@warning_ignore("integer_division")
	return Vector2(cx * 16 + 16 / 2, cy * 16 + 16 / 2)
