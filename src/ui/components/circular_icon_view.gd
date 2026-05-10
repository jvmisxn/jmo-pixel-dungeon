class_name CircularIconView
extends TextureRect
## Circular cropped portrait view with optional zoom for pixel-art profile icons.

@export var zoom_factor: float = 1.35:
	set(value):
		zoom_factor = maxf(1.0, value)
		if material is ShaderMaterial:
			(material as ShaderMaterial).set_shader_parameter("zoom_factor", zoom_factor)
@export var pan_offset: Vector2 = Vector2.ZERO:
	set(value):
		pan_offset = value
		if material is ShaderMaterial:
			(material as ShaderMaterial).set_shader_parameter("pan_offset", pan_offset)

func _ready() -> void:
	stretch_mode = TextureRect.STRETCH_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if material == null:
		var shader := Shader.new()
		shader.code = """
shader_type canvas_item;

uniform float zoom_factor = 1.35;
uniform vec2 pan_offset = vec2(0.0, 0.0);
uniform vec4 ring_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float ring_width = 0.0;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered);
	if (dist > 0.5) {
		discard;
	}

	vec2 zoomed_uv = centered / zoom_factor + vec2(0.5) + pan_offset;
	if (zoomed_uv.x < 0.0 || zoomed_uv.x > 1.0 || zoomed_uv.y < 0.0 || zoomed_uv.y > 1.0) {
		discard;
	}

	vec4 tex = texture(TEXTURE, zoomed_uv);
	if (ring_width > 0.0 && dist > 0.5 - ring_width) {
		COLOR = ring_color;
	} else {
		COLOR = tex;
	}
}
"""
		var shader_mat := ShaderMaterial.new()
		shader_mat.shader = shader
		material = shader_mat
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("zoom_factor", zoom_factor)
		(material as ShaderMaterial).set_shader_parameter("pan_offset", pan_offset)
		(material as ShaderMaterial).set_shader_parameter("ring_color", Color(0, 0, 0, 0))
		(material as ShaderMaterial).set_shader_parameter("ring_width", 0.0)

func set_ring(color: Color, width: float = 0.04) -> void:
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("ring_color", color)
		(material as ShaderMaterial).set_shader_parameter("ring_width", width)

func set_crop_adjustment(zoom: float, offset: Vector2) -> void:
	zoom_factor = maxf(1.0, zoom)
	pan_offset = offset
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("zoom_factor", zoom_factor)
		(material as ShaderMaterial).set_shader_parameter("pan_offset", pan_offset)
