class_name PlantSprite
extends Node2D
## Lightweight procedural sprite for planted flora so seeds/plants read as
## distinct objects instead of only as terrain changes.

const CELL_SIZE: float = TileMapManager.TILE_SIZE

var cell_pos: int = -1
var plant_id: String = ""

var _primary_color: Color = Color(0.45, 0.85, 0.35)
var _accent_color: Color = Color(0.9, 0.95, 0.6)

func setup_for_plant(id: String) -> void:
	plant_id = id.to_lower()
	match plant_id:
		"firebloom":
			_primary_color = Color(0.88, 0.3, 0.12)
			_accent_color = Color(1.0, 0.75, 0.2)
		"icecap":
			_primary_color = Color(0.45, 0.75, 1.0)
			_accent_color = Color(0.9, 0.98, 1.0)
		"sorrowmoss":
			_primary_color = Color(0.28, 0.58, 0.3)
			_accent_color = Color(0.65, 0.85, 0.45)
		"stormvine":
			_primary_color = Color(0.55, 0.55, 0.9)
			_accent_color = Color(0.88, 0.9, 1.0)
		"sungrass":
			_primary_color = Color(0.72, 0.88, 0.28)
			_accent_color = Color(1.0, 0.95, 0.45)
		"earthroot":
			_primary_color = Color(0.48, 0.34, 0.18)
			_accent_color = Color(0.72, 0.58, 0.32)
		"fadeleaf":
			_primary_color = Color(0.56, 0.8, 0.54)
			_accent_color = Color(0.86, 0.96, 0.76)
		"rotberry":
			_primary_color = Color(0.58, 0.24, 0.34)
			_accent_color = Color(0.86, 0.22, 0.38)
		"blindweed":
			_primary_color = Color(0.34, 0.48, 0.26)
			_accent_color = Color(0.86, 0.86, 0.74)
		"dreamfoil":
			_primary_color = Color(0.58, 0.42, 0.82)
			_accent_color = Color(0.95, 0.9, 1.0)
		"starflower":
			_primary_color = Color(0.88, 0.82, 0.22)
			_accent_color = Color(1.0, 0.98, 0.72)
		"swiftthistle":
			_primary_color = Color(0.74, 0.45, 0.7)
			_accent_color = Color(0.98, 0.82, 0.96)
		_:
			_primary_color = Color(0.45, 0.85, 0.35)
			_accent_color = Color(0.9, 0.95, 0.6)
	queue_redraw()

func place_at(pos: int) -> void:
	cell_pos = pos
	var x: int = pos % ConstantsData.WIDTH
	@warning_ignore("integer_division")
	var y: int = pos / ConstantsData.WIDTH
	global_position = Vector2(x * CELL_SIZE + CELL_SIZE * 0.5, y * CELL_SIZE + CELL_SIZE * 0.5)

func set_visible_state(is_visible_now: bool) -> void:
	visible = is_visible_now

func _draw() -> void:
	var stem_color: Color = _primary_color.darkened(0.15)
	draw_line(Vector2(-3, 5), Vector2(-1, -4), stem_color, 1.6)
	draw_line(Vector2(0, 6), Vector2(0, -5), stem_color, 1.8)
	draw_line(Vector2(3, 5), Vector2(1, -3), stem_color, 1.6)
	draw_circle(Vector2(0, -3), 3.2, _accent_color)
	draw_circle(Vector2(-3, 0), 2.0, _primary_color)
	draw_circle(Vector2(3, 1), 2.0, _primary_color)
