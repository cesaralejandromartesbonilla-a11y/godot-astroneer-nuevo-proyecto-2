shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec3 col_suelo : source_color = vec3(0.25, 0.5, 0.15);
uniform vec3 col_roca : source_color = vec3(0.7, 0.3, 0.1);
uniform vec3 col_halo : source_color = vec3(0.3, 0.7, 1.0);
uniform float halo_intensidad : hint_range(0.0, 3.0) = 1.2;

void fragment() {
	vec3 p = normalize(VERTEX);
	float n1 = sin(p.x * 6.0) * cos(p.y * 6.0 + p.z * 4.0);
	float n2 = sin(p.x * 14.0 + p.y * 10.0) * cos(p.z * 12.0);
	float blend_continente = clamp(n1 * 0.6 + n2 * 0.3 + 0.5, 0.0, 1.0);

	vec3 albedo = mix(col_suelo, col_roca, blend_continente);

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.5);
	vec3 halo = col_halo * fresnel * halo_intensidad;

	ALBEDO = albedo;
	ROUGHNESS = 0.85;
	METALLIC = 0.05;
	EMISSION = halo;
}
