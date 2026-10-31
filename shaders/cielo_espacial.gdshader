shader_type sky;

uniform vec3 color_cenit : source_color = vec3(0.2, 0.52, 0.95);
uniform vec3 color_horizonte : source_color = vec3(0.55, 0.82, 0.98);
uniform vec3 color_espacio : source_color = vec3(0.008, 0.01, 0.022);
uniform float fuerza_atmosfera : hint_range(0.0, 1.0) = 1.0;
uniform vec3 planet_up = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_dir = vec3(0.0, 0.7, 0.7);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform float sol_intensidad : hint_range(0.0, 5.0) = 1.2;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 dir = EYEDIR;

	// 1. Campo de estrellas en 360 grados continuo
	vec3 grid = floor(dir * 160.0);
	float val = hash3(grid);
	vec3 estrellas = vec3(0.0);
	if (val > 0.982) {
		float brillo = pow((val - 0.982) / 0.018, 3.5);
		estrellas = vec3(brillo * 1.8);
	}

	// 2. Sol directo y corona
	vec3 sdir = normalize(sun_dir);
	float sun_dot = max(dot(dir, sdir), 0.0);
	float sun_disk = smoothstep(0.9985, 0.9996, sun_dot);
	float sun_glow = pow(sun_dot, 24.0) * 0.6 + pow(sun_dot, 128.0) * 1.2;
	vec3 sol = sun_color * (sun_disk * 4.5 + sun_glow * sol_intensidad);

	// 3. Gradiente atmosférico local relativo a la normal del planeta
	vec3 pup = normalize(planet_up);
	float elev = dot(dir, pup);
	
	float sol_elev = dot(sdir, pup);
	float luz_dia = clamp(sol_elev * 2.5 + 0.35, 0.02, 1.0);
	
	float h_factor = 1.0 - abs(elev);
	h_factor = pow(clamp(h_factor, 0.0, 1.0), 1.8);
	
	vec3 atmo = mix(color_cenit, color_horizonte, h_factor) * luz_dia;
	vec3 estrellas_atenuadas = estrellas * (1.0 - fuerza_atmosfera * luz_dia * 0.95);

	float factor_cielo = clamp(elev * 0.8 + 0.5, 0.0, 1.0);
	vec3 fondo = mix(color_espacio + estrellas_atenuadas, atmo, fuerza_atmosfera * factor_cielo);
	
	if (elev < 0.0) {
		vec3 bruma_suelo = color_horizonte * 0.4 * luz_dia;
		fondo = mix(fondo, bruma_suelo, fuerza_atmosfera * clamp(-elev * 1.2, 0.0, 1.0));
	}

	COLOR = fondo + sol;
}
