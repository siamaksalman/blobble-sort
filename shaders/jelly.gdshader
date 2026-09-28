shader_type canvas_item;
render_mode unshaded;

uniform sampler2D reference_art : source_color, filter_linear;
uniform vec4 source_rect = vec4(106.0, 160.0, 105.0, 99.0);
uniform vec4 eye_centers = vec4(158.0, 203.0, 180.0, 201.0);
uniform bool single = true;
uniform vec4 jelly_color : source_color = vec4(0.96, 0.39, 0.65, 1.0);
uniform vec2 rect_size = vec2(140.0, 140.0);
uniform float body_height = 104.0;
uniform float clock = 0.0;
uniform float seed = 0.0;
uniform float selected = 0.0;
uniform float asleep = 0.0;
uniform float symbols = 0.0;
uniform float color_id = 0.0;
uniform float pinch = 0.0;
uniform float seam_y = 0.0;

float capsule(vec2 p, float half_line, float radius) {
	p.y -= clamp(p.y, -half_line, half_line);
	return length(p) - radius;
}

float blink_at(float time) {
	return smoothstep(0.0, 0.07, time) * (1.0 - smoothstep(0.10, 0.22, time));
}

float eye_catchlight(vec2 source, vec2 center) {
	float distance = length(source - center - vec2(-1.4, -1.8));
	float core = 1.0 - smoothstep(0.65, 1.45, distance);
	float glow = (1.0 - smoothstep(1.0, 2.2, distance)) * 0.14;
	return max(core * 0.96, glow);
}

vec3 source_pair(vec2 source, float offset) {
	return texture(reference_art, (source + vec2(offset, 0.0)) / vec2(941.0, 1672.0)).rgb
		+ texture(reference_art, (source - vec2(offset, 0.0)) / vec2(941.0, 1672.0)).rgb;
}

vec3 smooth_stretched_body(vec2 source) {
	// Short photographs have only a few belly rows. Filter across those rows
	// so individual JPEG columns cannot become full-height stripes.
	return texture(reference_art, source / vec2(941.0, 1672.0)).rgb * 0.204
		+ source_pair(source, 2.0) * 0.18
		+ source_pair(source, 4.0) * 0.124
		+ source_pair(source, 6.0) * 0.066
		+ source_pair(source, 8.0) * 0.028;
}

// Warp only the photographed eyes, keeping their highlights and soft edges.
vec2 animate_eye(vec2 source, vec2 center, float openness, vec2 glance, float tilt, float curve) {
	vec2 local = source - center;
	float region = (1.0 - smoothstep(7.0, 10.0, abs(local.x)))
		* (1.0 - smoothstep(8.0, 13.0, abs(local.y)));
	local -= glance * region;
	float angle = tilt * region;
	local = vec2(cos(angle) * local.x + sin(angle) * local.y,
		-sin(angle) * local.x + cos(angle) * local.y);
	// Arched closed eyes read as a smile, rather than a stern straight squint.
	local.y -= curve * clamp(local.x * local.x - 6.0, -6.0, 30.0) * region;
	float inner = 7.0 * openness;
	float distance_y = abs(local.y);
	float sample_y = distance_y < inner ? distance_y / openness
		: mix(7.0, 13.0, clamp((distance_y - inner) / (13.0 - inner), 0.0, 1.0));
	float lid_mask = (1.0 - smoothstep(7.0, 10.0, abs(local.x))) * step(distance_y, 13.0);
	local.y = mix(local.y, sign(local.y) * sample_y, lid_mask);
	return center + local;
}

void fragment() {
	vec2 p = (UV - 0.5) * rect_size;
	float half_line = max(0.0, body_height * 0.5 - 52.0);
	float neck = seam_y - p.y;
	float radius = 52.0 - pinch * 21.0 * exp(-neck * neck / 520.0);
	vec2 warped = p;
	warped.x += sin(p.y * 0.028 + clock * 1.6 + seed) * (selected + abs(pinch) * 2.0);
	warped.x *= 52.0 / radius;
	float y = warped.y + body_height * 0.5;
	float source_y = y / body_height * source_rect.w;
	if (!single) {
		// Keep the photographed cap and face intact; stretch only the middle.
		float top_cap = min(60.0, source_rect.w * 0.57);
		float bottom_cap = min(44.0, source_rect.w * 0.4);
		if (y < 60.0) {
			source_y = y / 60.0 * top_cap;
		} else if (y > body_height - 44.0) {
			source_y = source_rect.w - (body_height - y) / 44.0 * bottom_cap;
		} else {
			source_y = mix(top_cap, source_rect.w - bottom_cap, (y - 60.0) / (body_height - 104.0));
		}
	}
	// Sample just inside the photographed outline so the source tray and JPEG
	// edge color never leak into a sprite. The smooth silhouette supplies alpha.
	float inset_y = 0.0;
	if (single) {
		inset_y = mix(source_rect.w * 0.06, source_rect.w * 0.94, source_y / source_rect.w);
	} else {
		inset_y = mix(4.0, source_rect.w - 4.0, source_y / source_rect.w);
	}
	vec2 source = source_rect.xy + vec2((warped.x / 108.0 * 0.90 + 0.5) * source_rect.z, inset_y);
	vec2 body_source = source;
	// A 220 ms blink every 6–9 seconds, independently phased per blob.
	float blink_period = 6.0 + fract(seed * 0.73) * 3.0;
	float blink_clock = clock + fract(seed * 0.37) * 5.0;
	float blink_time = mod(blink_clock, blink_period) - (blink_period - 0.22);
	float blink = blink_at(blink_time);
	// Every third blink has a quick companion, with a clear open-eyed pause.
	float double_blink = 1.0 - step(0.5, abs(mod(floor(blink_clock / blink_period) + floor(seed), 3.0) - 1.0));
	blink = max(blink, blink_at(blink_time + 0.3) * double_blink);
	// Rare, staggered reactions with a readable hold and a long quiet pause.
	float mood_period = 20.0 + fract(seed * 0.29) * 8.0;
	float mood_clock = clock + fract(seed * 0.53) * 14.0;
	float mood_time = mod(mood_clock, mood_period) - (mood_period - 3.2);
	float expression = smoothstep(0.0, 0.4, mood_time) * (1.0 - smoothstep(2.5, 3.2, mood_time));
	float mood = mod(floor(mood_clock / mood_period) + floor(seed), 5.0);
	vec2 lids = vec2(0.32);
	vec2 tilt = vec2(0.0);
	vec2 curve = vec2(0.13);
	vec2 left_look = vec2(0.0);
	vec2 right_look = vec2(0.0);
	if (mood > 0.5 && mood < 1.5) {
		lids = vec2(0.5);
		curve = vec2(0.0);
		left_look = vec2(0.0, 0.8);
		right_look = left_look;
	} else if (mood > 1.5 && mood < 2.5) {
		lids = vec2(1.0, 0.5);
		curve = vec2(0.0);
		tilt = vec2(-0.13, 0.18);
		left_look = vec2(-0.6, -1.8);
		right_look = vec2(-0.6, 0.8);
	} else if (mood > 2.5 && mood < 3.5) {
		// A tiny mock-serious pout, with rounded eyes instead of an angry glare.
		lids = vec2(0.5);
		tilt = vec2(0.4, -0.4);
		curve = vec2(0.025);
	} else if (mood > 3.5) {
		lids = vec2(1.0, 0.14);
		tilt = vec2(-0.08, 0.0);
		curve = vec2(0.0, 0.10);
		left_look = vec2(0.6, -0.5);
		right_look = vec2(0.6, 0.0);
	}
	vec2 openness = min(vec2(1.0 - blink * 0.88), mix(vec2(1.0), lids, expression));
	tilt *= expression * (1.0 - blink);
	curve *= expression * (1.0 - blink);
	// Mostly look forward, with a slow, tiny glance and a gentle return.
	float glance_period = 9.0 + fract(seed * 0.43) * 4.0;
	float glance_clock = clock + fract(seed * 0.61) * 6.0;
	float glance_cycle = floor(glance_clock / glance_period);
	float glance_time = mod(glance_clock, glance_period) - (glance_period - 1.4);
	float glance_amount = smoothstep(0.0, 0.3, glance_time) * (1.0 - smoothstep(0.9, 1.4, glance_time));
	vec2 glance = vec2(cos(seed * 2.4 + glance_cycle * 2.4) * 1.5,
		sin(seed * 1.7 + glance_cycle * 1.8) * 0.85) * glance_amount;
	source = animate_eye(source, eye_centers.xy, openness.x, mix(glance, left_look, expression), tilt.x, curve.x);
	source = animate_eye(source, eye_centers.zw, openness.y, mix(glance, right_look, expression), tilt.y, curve.y);
	vec3 color = texture(reference_art, source / vec2(941.0, 1672.0)).rgb;
	if (!single && source_rect.w < 110.0) {
		float belly = smoothstep(60.0, 84.0, y) * (1.0 - smoothstep(body_height - 64.0, body_height - 36.0, y));
		// Leave the photographed outline untouched; wide taps could sample the tray.
		belly *= 1.0 - smoothstep(34.0, 48.0, abs(warped.x));
		if (belly > 0.0) {
			color = mix(color, smooth_stretched_body(body_source), belly);
		}
	}
	// A tiny glossy reflection follows the same source-space warp as each eye.
	float catchlight = max(eye_catchlight(source, eye_centers.xy) * smoothstep(0.2, 0.55, openness.x),
		eye_catchlight(source, eye_centers.zw) * smoothstep(0.2, 0.55, openness.y));
	color = mix(color, vec3(0.98, 0.99, 1.0), catchlight);
	float silhouette = capsule(warped, half_line, 52.0);
	float alpha = 1.0 - smoothstep(-1.0, 1.0, silhouette);
	float shadow = exp(-max(capsule(p - vec2(2.0, 6.0), half_line, 48.0), 0.0) * 0.22) * 0.2;
	float border = min(min(UV.x, 1.0 - UV.x) * rect_size.x, min(UV.y, 1.0 - UV.y) * rect_size.y);
	shadow *= smoothstep(0.0, 10.0, border);
	// Optional tactile color marks stay below the photograph's original face.
	vec2 face = p - vec2(1.0, -half_line + 5.0);
	float mark = 0.0;
	for (int i = 0; i < 6; i++) {
		vec2 dot_position = vec2((float(i % 3) - 1.0) * 11.0, 19.0 + floor(float(i) / 3.0) * 10.0);
		mark = max(mark, (1.0 - smoothstep(2.4, 3.4, length(face - dot_position))) * step(float(i), color_id));
	}
	color = mix(color, jelly_color.rgb * 0.43, mark * symbols * 0.7);
	float opacity = alpha + shadow * (1.0 - alpha);
	vec3 result = (color * alpha + vec3(0.36, 0.23, 0.12) * shadow * (1.0 - alpha)) / max(opacity, 0.001);
	COLOR = vec4(result, opacity);
}
