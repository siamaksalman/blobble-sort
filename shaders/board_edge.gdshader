shader_type canvas_item;
render_mode unshaded;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float x = smoothstep(0.0, 0.033, min(UV.x, 1.0 - UV.x));
	float y = smoothstep(0.0, 0.052, min(UV.y, 1.0 - UV.y));
	COLOR = vec4(tex.rgb, tex.a * x * y);
}
