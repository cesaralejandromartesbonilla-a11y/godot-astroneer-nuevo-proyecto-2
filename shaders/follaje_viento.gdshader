shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Shader de follaje con balanceo de viento y bioluminiscencia (Fase 8)
uniform vec4 albedo_color : source_color = vec4(0.2, 0.6, 0.35, 1.0);
uniform vec4 emission_color : source_color = vec4(0.1, 0.8, 0.4, 1.0);
uniform float emission_energy : hint_range(0.0, 5.0) = 1.2;
uniform float roughness : hint_range(0.0, 1.0) = 0.6;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

uniform float wind_speed : hint_range(0.1, 10.0) = 2.0;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.15;
uniform float wind_turbulence : hint_range(0.1, 5.0) = 1.5;

void vertex() {
	// Balanceo orgánico: mayor en la parte superior del mesh (VERTEX.y > 0)
	float height_factor = clamp(VERTEX.y * 0.5, 0.0, 2.0);
	float wave_a = sin(TIME * wind_speed + VERTEX.x * wind_turbulence + VERTEX.z * wind_turbulence);
	float wave_b = cos(TIME * (wind_speed * 0.7) + (VERTEX.x + VERTEX.z) * 0.5);

	vec3 sway = vec3(wave_a, wave_b * 0.25, wave_a * 0.5) * wind_strength * height_factor;
	VERTEX += sway;
}

void fragment() {
	ALBEDO = albedo_color.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;

	// Bioluminiscencia reactiva
	float pulse = 0.85 + 0.15 * sin(TIME * 2.5);
	EMISSION = emission_color.rgb * emission_energy * pulse;
}
