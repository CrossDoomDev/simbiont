shader_type canvas_item;
// A fixed cutout for ONE independent sprite. No frame/pose mixing here.
uniform bool lower_body = false;
varying vec4 body_tint;
void vertex() {
	body_tint = COLOR;
}
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 pixel = fract(UV * 4.0) * 64.0;
	bool weapon = source.b > source.g * 1.3 && source.r > source.g * 1.2;
	bool legs = pixel.y >= 40.0 && !weapon;
	if (legs != lower_body) {
		discard;
	}
	COLOR = source * body_tint;
}
