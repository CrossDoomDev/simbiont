shader_type canvas_item;
// Feather atlas cell edges so expanding generated bursts dissolve naturally.
varying vec4 effect_tint;
void vertex() {
	effect_tint = COLOR;
}
void fragment() {
	vec2 cell = fract(UV * vec2(4.0,5.0));
	vec2 edge = smoothstep(vec2(0.0),vec2(0.075),cell) * smoothstep(vec2(0.0),vec2(0.075),vec2(1.0)-cell);
	COLOR = texture(TEXTURE,UV)*effect_tint;
	COLOR.a *= edge.x*edge.y;
}
