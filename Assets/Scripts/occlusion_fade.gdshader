shader_type canvas_item;
// Partial-transparency shader: only the region near an occluder (enemy / decoration)
// fades out, leaving the rest of the sprite fully opaque.
// We ONLY modify alpha — RGB is left completely alone to avoid any colour tint.

varying vec2 world_pos;

// Up to 8 occluder world-space positions
uniform int occ_count : hint_range(0, 8) = 0;
uniform vec2 occ_0 = vec2(99999.0, 99999.0);
uniform vec2 occ_1 = vec2(99999.0, 99999.0);
uniform vec2 occ_2 = vec2(99999.0, 99999.0);
uniform vec2 occ_3 = vec2(99999.0, 99999.0);
uniform vec2 occ_4 = vec2(99999.0, 99999.0);
uniform vec2 occ_5 = vec2(99999.0, 99999.0);
uniform vec2 occ_6 = vec2(99999.0, 99999.0);
uniform vec2 occ_7 = vec2(99999.0, 99999.0);
uniform float occ_radius = 22.0;    // fade zone radius in world pixels
uniform float fade_alpha = 0.25;    // minimum alpha at occluder center

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// Sample the texture — let Godot handle modulate/vertex-colour on its own.
	vec4 tex = texture(TEXTURE, UV);

	// Compute occlusion alpha multiplier (1.0 = fully opaque, fade_alpha = faded)
	float alpha_mul = 1.0;

	if (occ_count > 0) {
		float min_dist = 99999.0;
		if (occ_count > 0) min_dist = min(min_dist, distance(world_pos, occ_0));
		if (occ_count > 1) min_dist = min(min_dist, distance(world_pos, occ_1));
		if (occ_count > 2) min_dist = min(min_dist, distance(world_pos, occ_2));
		if (occ_count > 3) min_dist = min(min_dist, distance(world_pos, occ_3));
		if (occ_count > 4) min_dist = min(min_dist, distance(world_pos, occ_4));
		if (occ_count > 5) min_dist = min(min_dist, distance(world_pos, occ_5));
		if (occ_count > 6) min_dist = min(min_dist, distance(world_pos, occ_6));
		if (occ_count > 7) min_dist = min(min_dist, distance(world_pos, occ_7));

		if (min_dist < occ_radius) {
			float t = smoothstep(0.0, occ_radius, min_dist);
			alpha_mul = mix(fade_alpha, 1.0, t);
		}
	}

	// Output: texture colour as-is, with alpha faded near occluders.
	// Do NOT multiply by COLOR — Godot applies modulate after the fragment shader
	// for canvas_item. Multiplying by COLOR would double-apply it, tinting the sprite.
	COLOR = tex;
	COLOR.a *= alpha_mul;
}
