class_name DamageNumber
extends Node2D
## Floating damage/heal/status number that rises and fades out.
## Uses Godot Tweens instead of manual _process delta tracking.

const RISE_SPEED: float = 30.0
const DURATION: float = 0.8
const CRIT_SCALE: float = 1.5

var _label: Label = null
var _rise_speed: float = RISE_SPEED

# ---------------------------------------------------------------------------
# Setup Methods
# ---------------------------------------------------------------------------

## Set up as a damage number.
func setup(amount: int, is_crit: bool = false) -> void:
	_create_label()
	_label.text = str(amount)
	if is_crit:
		_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.1))
		_label.scale = Vector2(CRIT_SCALE, CRIT_SCALE)
		_rise_speed *= 1.3
	else:
		_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))

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
	_label.position = Vector2(-20, -8)
	_label.size = Vector2(40, 16)
	add_child(_label)
