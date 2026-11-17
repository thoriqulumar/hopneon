shader_type canvas_item;
render_mode unshaded;
uniform vec4 top_color : source_color = vec4(0.015, 0.02, 0.09, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.03, 0.005, 0.08, 1.0);
uniform vec4 glow_color : source_color = vec4(0.25, 0.0, 0.55, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.22;
void fragment() {
	float vertical = smoothstep(0.0, 1.0, UV.y);
	vec3 base = mix(top_color.rgb, bottom_color.rgb, vertical);
	vec2 center = UV - vec2(0.72, 0.24);
	float halo = exp(-dot(center, center) * 8.0);
	float wave = 0.5 + 0.5 * sin(TIME * 0.35 + UV.y * 7.0);
	base += glow_color.rgb * halo * intensity * (0.8 + wave * 0.2);
	COLOR = vec4(base, 1.0);
}
