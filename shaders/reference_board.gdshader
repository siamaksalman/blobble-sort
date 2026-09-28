shader_type canvas_item;
render_mode unshaded;

// Reassemble photographed clay gates, then inverse-map the whole reference tray.
uniform sampler2D clay_art : source_color, filter_linear;
uniform float source_x[6];
uniform float target_x[6];
uniform float source_y[8];
uniform float target_y[8];
uniform bool mirror = false;
uniform bool reference_layout = true;
uniform int horizontal[9]; // 0: closed, 1: middle, 2: lower, 3: upper opening.
uniform int vertical[8];
uniform int compact_count = 0;
uniform vec2 compact_offset = vec2(0.0);

vec4 clay_section(vec4 underneath, vec2 p, vec2 center, vec2 extent, vec2 donor, vec2 stretch, bool closed_wall) {
	vec2 local = p - center;
	if (abs(local.x) >= extent.x || abs(local.y) >= extent.y) { return underneath; }
	vec2 feather = vec2(1.0) - smoothstep(extent - vec2(28.0, 18.0), extent, abs(local));
	vec4 section = texture(clay_art, (donor + local * stretch) / vec2(941.0, 1672.0));
	if (closed_wall) {
		vec4 lower = texture(clay_art, (vec2(470.0, 1306.0) + local) / vec2(941.0, 1672.0));
		section = mix(section, lower, smoothstep(-45.0, 45.0, local.y));
	}
	return mix(underneath, section, feather.x * feather.y);
}

vec4 maze_art(vec2 p) {
	vec4 result = texture(clay_art, p / vec2(941.0, 1672.0));
	if (reference_layout) { return result; }
	float columns[4] = float[4](158.0, 369.0, 570.0, 782.0);
	float centers[3] = float[3](344.5, 817.5, 1306.0);
	float gates[2] = float[2](560.0, 1034.0);
	for (int row = 0; row < 3; row++) {
		for (int col = 0; col < 3; col++) {
			vec2 center = vec2((columns[col] + columns[col + 1]) * 0.5, centers[row]);
			int mode = horizontal[row * 3 + col];
			vec2 donor = vec2(470.0, 344.5);
			vec2 stretch = vec2(1.0);
			if (mode == 1) { donor = vec2(260.0, 344.5); stretch.y = 1.0; }
			if (mode == 2) { donor = vec2(470.0, 344.5); stretch.y = 1.0; }
			if (mode == 3) { donor = vec2(470.0, 1306.0); stretch.y = 1.0; }
			result = clay_section( result, p, center, vec2(98.0, 240.0), donor, stretch, mode == 0);
		}
	}
	for (int row = 0; row < 2; row++) {
		for (int col = 0; col < 4; col++) {
			vec2 center = vec2(columns[col], gates[row]);
			vec2 donor = vertical[row * 4 + col] == 1 ? vec2(158.0, 560.0) : vec2(570.0, 550.0);
			result = clay_section( result, p, center, vec2(98.0, 72.0), donor, vec2(1.0), false);
		}
	}
	return result;
}

// Remove complete pockets at the clay dividers. Feather only the join; the
// surviving cavities and outside rim still come directly from the photograph.
vec4 compact_row(vec2 p) {
	float cut = compact_count == 6 ? 206.0 : 0.0;
	if (compact_count == 10) {
		cut = 206.0 * (1.0 - smoothstep(530.0, 590.0, p.y) + smoothstep(1000.0, 1080.0, p.y));
	}
	vec2 rim_uv = vec2(p.x / 941.0, p.y / 1672.0);
	float side_source = -1.0;
	// Widen the solid side walls on three-pocket rows while retaining the
	// original rectangular outside silhouette on the ten-pocket tray.
	if (compact_count == 10 && p.x < 85.0 + cut * 0.5) {
		side_source = p.x < 50.0 ? p.x : 50.0 + (p.x - 50.0) * 35.0 / (35.0 + cut * 0.5);
	}
	if (compact_count == 10 && p.x > 856.0 - cut * 0.5) {
		side_source = p.x > 891.0 ? p.x : 891.0 - (891.0 - p.x) * 35.0 / (35.0 + cut * 0.5);
	}
	p.x -= cut * 0.5;
	float seam = 263.5;
	vec4 result;
	if (side_source >= 0.0) {
		result = maze_art(vec2(side_source, p.y));
	} else if (p.x < seam - 12.0) {
		result = maze_art(p);
	} else if (p.x > seam + 12.0) {
		result = maze_art(p + vec2(cut, 0.0));
	} else {
		result = mix(maze_art(p), maze_art(p + vec2(cut, 0.0)), smoothstep(seam - 12.0, seam + 12.0, p.x));
	}
	// Keep a continuous original rim above/below the cavities at the splice.
	if (compact_count != 10) { rim_uv.x = p.x / (941.0 - cut); }
	vec4 rim = texture(clay_art, rim_uv);
	float rim_weight = 1.0 - smoothstep(75.0, 115.0, p.y) + smoothstep(1495.0, 1540.0, p.y);
	return mix(result, rim, rim_weight);
}

vec4 compact_art(vec2 p) {
	p -= compact_offset;
	vec2 bounds = vec2(941.0, 1672.0);
	if (compact_count < 10) {
		p.y -= 237.0;
		bounds.y -= 474.0;
	}
	float cut_x = compact_count == 6 ? 206.0 : 0.0;
	float alpha = smoothstep(0.0, 31.0, min(p.x - cut_x * 0.5, bounds.x - cut_x * 0.5 - p.x));
	alpha *= smoothstep(0.0, 87.0, min(p.y, bounds.y - p.y));
	vec4 tex;
	if (compact_count >= 10 || p.y < 548.0) {
		tex = compact_row(p);
	} else if (p.y > 572.0) {
		tex = compact_row(p + vec2(0.0, 474.0));
	} else {
		tex = mix(compact_row(p), compact_row(p + vec2(0.0, 474.0)), smoothstep(548.0, 572.0, p.y));
	}
	return vec4(tex.rgb, tex.a * alpha);
}

void fragment() {
	vec2 p = UV * vec2(941.0, 1672.0);
	if (compact_count > 0) {
		COLOR = compact_art(p);
	} else {
		vec2 original = p;
		for (int i = 0; i < 5; i++) {
			if (p.x >= target_x[i] && p.x <= target_x[i + 1]) {
				original.x = mix(source_x[i], source_x[i + 1], (p.x - target_x[i]) / (target_x[i + 1] - target_x[i]));
			}
		}
		for (int i = 0; i < 7; i++) {
			if (p.y >= target_y[i] && p.y <= target_y[i + 1]) {
				original.y = mix(source_y[i], source_y[i + 1], (p.y - target_y[i]) / (target_y[i + 1] - target_y[i]));
			}
		}
		if (mirror) { original.x = 941.0 - original.x; }
		vec4 tex = maze_art(original);
		float x = smoothstep(0.0, 0.033, min(UV.x, 1.0 - UV.x));
		float y = smoothstep(0.0, 0.052, min(UV.y, 1.0 - UV.y));
		COLOR = vec4(tex.rgb, tex.a * x * y);
	}
}
