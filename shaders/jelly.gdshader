shader_type canvas_item;
render_mode unshaded;

uniform vec4 jelly_color : source_color = vec4(0.96, 0.39, 0.65, 1.0);
uniform vec2 rect_size = vec2(140.0, 140.0);
uniform float body_height = 104.0;
uniform float clock = 0.0;
uniform float seed = 0.0;
uniform float selected = 0.0;
uniform float asleep = 0.0;
uniform float symbols = 0.0;
uniform float color_id = 0.0;
// Merge neck: 1 = two blobs just touching at seam_y, 0 = one smooth body, <0 = brief bulge.
uniform float pinch = 0.0;
uniform float seam_y = 0.0;

float capsule(vec2 p, float half_line, float radius) {
	p.y -= clamp(p.y, -half_line, half_line);
	return length(p) - radius;
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 p = (UV - 0.5) * rect_size;
	float half_line = max(0.0, body_height * 0.5 - 49.0);
	float wiggle = sin(p.y * 0.028 + clock * 1.6 + seed) * (1.2 + selected * 1.1 + abs(pinch) * 3.0);
	p.x += wiggle;
	float neck = seam_y - p.y;
	float radius = 49.0 - pinch * 21.0 * exp(-neck * neck / 520.0);
	float d = capsule(p, half_line, radius);
	float shadow = exp(-max(capsule(p - vec2(2.0, 8.0), half_line, radius - 1.0), 0.0) * 0.16) * 0.25;
	float alpha = 1.0 - smoothstep(-1.1, 1.1, d);
	vec2 surface = vec2(p.x, p.y - clamp(p.y, -half_line, half_line)) / radius;
	float z = sqrt(max(0.0, 1.0 - dot(surface, surface)));
	vec3 n = normalize(vec3(surface, z));
	vec3 light = normalize(vec3(-0.48, -0.6, 0.9));
	float diffuse = max(dot(n, light), 0.0);
	vec3 base = jelly_color.rgb * (0.87 + 0.16 * diffuse);
	base = mix(base, vec3(1.0, 0.94, 0.88), pow(diffuse, 6.0) * 0.27);
	base += pow(max(dot(n, normalize(vec3(-0.38, -0.52, 1.4))), 0.0), 18.0) * 0.07;
	base += (hash(FRAGCOORD.xy) - 0.5) * 0.014;
	base = mix(base, jelly_color.rgb * 0.8, (1.0 - z) * 0.12);
	// One little face per merged jelly, just like the reference.
	vec2 face = p - vec2(1.0, -half_line - 5.0);
	float blink = step(0.983, sin(clock * 0.86 + seed * 7.0));
	float eye_h = mix(5.9, 1.2, max(blink, asleep));
	vec2 left = (face - vec2(-10.0, 0.5)) / vec2(5.1, eye_h);
	vec2 right = (face - vec2(10.0, -1.4)) / vec2(5.1, eye_h);
	float eyes = 1.0 - smoothstep(0.8, 1.08, min(length(left), length(right)));
	base = mix(base, vec3(0.035, 0.025, 0.038), eyes);
	float glint = max(1.0 - smoothstep(0.7, 1.5, length(face - vec2(-11.4, -1.6))), 1.0 - smoothstep(0.7, 1.5, length(face - vec2(8.6, -3.5))));
	base = mix(base, vec3(1.0), glint * (1.0 - max(blink, asleep)) * 0.7);
	// Optional 1–6 tactile freckles distinguish colors without reading hue.
	float mark = 0.0;
	for (int i = 0; i < 6; i++) {
		vec2 dot_position = vec2((float(i % 3) - 1.0) * 11.0, 19.0 + floor(float(i) / 3.0) * 10.0);
		mark = max(mark, (1.0 - smoothstep(2.4, 3.4, length(face - dot_position))) * step(float(i), color_id));
	}
	base = mix(base, jelly_color.rgb * 0.43, mark * symbols * 0.7);
	vec3 shadow_color = vec3(0.36, 0.23, 0.12);
	COLOR = vec4(mix(shadow_color, base, alpha), max(alpha, shadow));
}
