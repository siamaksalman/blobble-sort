shader_type canvas_item;
render_mode unshaded;

uniform sampler2D reference_art : source_color, filter_linear;
uniform vec4 source_rect = vec4(106.0, 160.0, 105.0, 99.0);
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
	vec3 color = texture(reference_art, source / vec2(941.0, 1672.0)).rgb;
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
