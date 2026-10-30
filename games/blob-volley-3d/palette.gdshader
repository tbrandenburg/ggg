shader_type spatial;
render_mode unshaded;

uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec3 light_direction = normalize(vec3(-0.4, 0.8, 1.0));
	float shade = 0.74 + 0.26 * max(dot(normalize(NORMAL), light_direction), 0.0);
	ALBEDO = tint.rgb * shade;
}
