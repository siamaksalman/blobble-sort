shader_type canvas_item;
render_mode unshaded;

uniform vec4 wells[12];
uniform float well_radii[12];
uniform vec4 corridors[14];
uniform float corridor_radii[14];
uniform int corridor_count = 0;
uniform float corner = 100.0;
uniform float wave = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

vec4 capsule_field(vec2 p, vec4 ends, float radius) {
	vec2 axis = ends.zw - ends.xy;
	vec2 offset = p - ends.xy;
	float t = clamp(dot(offset, axis) / max(dot(axis, axis), 0.01), 0.0, 1.0);
	vec2 v = offset - axis * t;
	float len = length(v);
	return vec4(len - radius, v / max(len, 0.001), radius);
}

vec4 smooth_union(vec4 a, vec4 b) {
	float k = 13.0;
	float h = clamp(0.5 + 0.5 * (b.x - a.x) / k, 0.0, 1.0);
	return vec4(mix(b.x, a.x, h) - k * h * (1.0 - h), mix(b.yzw, a.yzw, h));
}

float outline(vec2 p) {
	p += vec2(sin(p.y * 0.013 + wave) * 5.0, sin(p.x * 0.014 + wave) * 6.0);
	vec2 q = abs(p - vec2(470.5, 834.0)) - vec2(433.0, 782.0) + corner;
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - corner;
}

void fragment() {
	vec2 p = UV * vec2(941.0, 1672.0);
	float outer = outline(p);
	float alpha = 1.0 - smoothstep(-1.0, 1.0, outer);
	float shadow = exp(-max(outline(p - vec2(3.0, 12.0)), 0.0) / 13.0) * 0.24;
	vec4 field = vec4(10000.0, 0.0, 1.0, 60.0);
	for (int i = 0; i < 12; i++) {
		field = smooth_union(field, capsule_field(p, wells[i], well_radii[i]));
	}
	for (int i = 0; i < 14; i++) {
		if (i < corridor_count) {
			field = smooth_union(field, capsule_field(p, corridors[i], corridor_radii[i]));
		}
	}
	vec3 light = normalize(vec3(-0.5, -0.65, 1.0));
	float edge_height = clamp(-outer / 26.0, 0.0, 1.0);
	vec2 outer_gradient = vec2(dFdx(outer), dFdy(outer));
	vec3 edge_normal = normalize(vec3(outer_gradient * (1.0 - edge_height) * 1.4, 0.75));
	vec3 clay = mix(vec3(0.72, 0.58, 0.40), vec3(0.995, 0.966, 0.893), 0.65 + 0.35 * max(dot(edge_normal, light), 0.0));
	float bevel = clamp(field.w * 0.54, 17.0, 38.0);
	float t = clamp((4.0 - field.x) / (bevel + 4.0), 0.0, 1.0);
	float depth = t * t * (3.0 - 2.0 * t);
	float slope = 6.0 * t * (1.0 - t) * 0.92;
	vec3 cavity_normal = normalize(vec3(-field.yz * slope, 1.0));
	float diffuse = max(dot(cavity_normal, light), 0.0);
	vec3 interior = mix(vec3(0.99, 0.958, 0.88), vec3(0.925, 0.839, 0.713), depth);
	interior = mix(vec3(0.67, 0.49, 0.29), interior, 0.62 + diffuse * 0.38);
	interior -= vec3(0.14, 0.11, 0.085) * exp(-max(-field.x, 0.0) / 25.0) * depth;
	interior += vec3(0.038) * exp(-abs(field.x - 6.0) / 8.0);
	vec3 color = mix(clay, interior, 1.0 - smoothstep(6.0, 32.0, field.x));
	float grain = (hash(floor(p * 1.7)) - 0.5) * 0.023;
	grain += (hash(floor(p * 0.3)) - 0.5) * 0.009;
	color += grain;
	COLOR = vec4(mix(vec3(0.46, 0.32, 0.18), color, alpha), max(alpha, shadow));
}
