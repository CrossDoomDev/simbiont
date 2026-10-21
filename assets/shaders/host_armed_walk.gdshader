shader_type canvas_item;
// Combine the original firing torso with the current native walking frame.
// The atlas has four columns (idle, step A, step B, attack) and four facings.
uniform bool armed_walk = false;
varying vec4 body_tint;

void vertex() {
	body_tint = COLOR;
}

void fragment() {
	vec4 walking = texture(TEXTURE, UV);
	if (!armed_walk) {
		COLOR = walking * body_tint;
	} else {
		vec2 cell = fract(UV * 4.0);
		float facing = floor(UV.y * 4.0);
		vec2 firing_uv = (vec2(3.0, facing) + cell) / 4.0;
		vec4 firing = texture(TEXTURE, firing_uv);
		vec2 pixel = cell * 64.0;
		// Below the waist replace the entire old stance, including wide boots.
		// Preserve the firing weapon/tendrils that extend below the waist, while
		// excluding the lowered purple arm from the walking source.
		bool legs = pixel.y >= 40.0;
		bool firing_arm = firing.b > firing.g * 1.3 && firing.r > firing.g * 1.2;
		bool lowered_arm = walking.b > walking.g * 1.3 && walking.r > walking.g * 1.2;
		vec4 lower_body = lowered_arm ? vec4(0.0) : walking;
		COLOR = (legs && !firing_arm ? lower_body : firing) * body_tint;
	}
}
