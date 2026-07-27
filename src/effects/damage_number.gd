class_name DamageNumber
extends Node2D
## Floating damage/heal/status number that rises and fades out.
## Uses Godot Tweens instead of manual _process delta tracking.

const RISE_SPEED: float = 30.0
const DURATION: float = 0.8
const CRIT_SCALE: float = 1.5

var _label: Label = null
var _rise_speed: float = RISE_SPEED
var _damage_type: String = "physical"
var _damage_color: Color = Color(1.0, 0.2, 0.2)

# ---------------------------------------------------------------------------
# Setup Methods
# ---------------------------------------------------------------------------

## Set up as a damage number.
func setup(amount: int, is_crit: bool = false, damage_type: String = "physical") -> void:
	_create_label()
	_damage_type = _normalize_damage_type(damage_type)
	_damage_color = _color_for_damage_type(_damage_type)
	_label.text = str(amount)
	if is_crit:
		_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.1))
		_label.scale = Vector2(CRIT_SCALE, CRIT_SCALE)
		_rise_speed *= 1.3
	else:
		_label.add_theme_color_override("font_color", _damage_color)
	queue_redraw()

## Set up as a healing number.
func setup_heal(amount: int) -> void:
	_create_label()
	_label.text = "+" + str(amount)
	_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))

## Set up as arbitrary status text.
func setup_text(text: String, color: Color) -> void:
	_create_label()
	_label.text = text
	_label.add_theme_color_override("font_color", color)

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Slight random horizontal offset to avoid stacking
	position.x += randf_range(-4.0, 4.0)
	_start_animation()


func _start_animation() -> void:
	var start_y: float = position.y
	var end_y: float = start_y - _rise_speed
	var tween: Tween = create_tween()
	# Rise over full duration
	tween.tween_property(self, "position:y", end_y, DURATION).set_ease(Tween.EASE_OUT)
	# Fade out in second half (delay 0.4s, then fade over 0.4s)
	tween.parallel().tween_property(self, "modulate:a", 0.0, DURATION * 0.5).set_delay(DURATION * 0.5)
	# Self destruct when done
	tween.tween_callback(queue_free)

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _create_label() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 10)
	_label.position = Vector2(-12, -8)
	_label.size = Vector2(40, 16)
	add_child(_label)

func _draw() -> void:
	if _label == null:
		return
	var center: Vector2 = Vector2(-15, 0)
	match _damage_type:
		"magic":
			draw_circle(center, 3.0, Color(0.55, 0.65, 1.0))
			draw_line(center + Vector2(-4, 0), center + Vector2(4, 0), Color.WHITE, 1.0)
			draw_line(center + Vector2(0, -4), center + Vector2(0, 4), Color.WHITE, 1.0)
		"fire":
			draw_polygon(
				[center + Vector2(0, -5), center + Vector2(4, 3), center + Vector2(-4, 3)],
				[Color(1.0, 0.45, 0.05), Color(1.0, 0.75, 0.1), Color(0.9, 0.1, 0.0)]
			)
		"poison":
			draw_circle(center + Vector2(0, 1), 3.5, Color(0.25, 0.85, 0.25))
			draw_circle(center + Vector2(1, -3), 1.5, Color(0.55, 1.0, 0.35))
		"bleed":
			draw_circle(center + Vector2(0, 1), 3.5, Color(0.85, 0.0, 0.08))
			draw_polygon([center + Vector2(0, -5), center + Vector2(3, 0), center + Vector2(-3, 0)], [Color(0.95, 0.05, 0.1)])
		"acid":
			draw_rect(Rect2(center + Vector2(-4, -2), Vector2(8, 5)), Color(0.55, 0.95, 0.25))
			draw_line(center + Vector2(-3, 2), center + Vector2(3, -2), Color(0.15, 0.35, 0.05), 1.0)
		"fall":
			draw_line(center + Vector2(0, -5), center + Vector2(0, 4), Color(0.65, 0.8, 1.0), 2.0)
			draw_line(center + Vector2(0, 4), center + Vector2(-3, 1), Color(0.65, 0.8, 1.0), 1.0)
			draw_line(center + Vector2(0, 4), center + Vector2(3, 1), Color(0.65, 0.8, 1.0), 1.0)
		"hunger":
			draw_arc(center, 4.0, 0.6, TAU - 0.6, 10, Color(0.95, 0.75, 0.25), 2.0)
		"trap":
			draw_polygon(
				[center + Vector2(0, -5), center + Vector2(5, 4), center + Vector2(-5, 4)],
				[Color(0.95, 0.8, 0.15)]
			)
			draw_line(center + Vector2(0, -2), center + Vector2(0, 1), Color(0.15, 0.1, 0.0), 1.0)
		_:
			draw_line(center + Vector2(-4, 4), center + Vector2(4, -4), Color(0.95, 0.95, 0.95), 2.0)
			draw_line(center + Vector2(1, -4), center + Vector2(4, -4), Color(0.95, 0.95, 0.95), 1.0)

func _normalize_damage_type(damage_type: String) -> String:
	var normalized: String = damage_type.to_lower()
	if ["physical", "magic", "fire", "poison", "bleed", "acid", "fall", "hunger", "trap"].has(normalized):
		return normalized
	return "physical"

func _color_for_damage_type(damage_type: String) -> Color:
	match damage_type:
		"magic":
			return Color(0.55, 0.65, 1.0)
		"fire":
			return Color(1.0, 0.45, 0.05)
		"poison":
			return Color(0.35, 0.9, 0.25)
		"bleed":
			return Color(0.95, 0.05, 0.1)
		"acid":
			return Color(0.55, 0.95, 0.25)
		"fall":
			return Color(0.65, 0.8, 1.0)
		"hunger":
			return Color(0.95, 0.75, 0.25)
		"trap":
			return Color(0.95, 0.8, 0.15)
		_:
			return Color(1.0, 0.2, 0.2)
