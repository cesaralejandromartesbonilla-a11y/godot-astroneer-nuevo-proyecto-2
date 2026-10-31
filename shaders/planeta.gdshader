shader_type spatial;

// Shader de planeta parametrizado (F5): cada cuerpo setea sus uniforms.
// El campo de vetas se muestrea desde el espacio LOCAL al planeta
// (bounds relativos a su posición) para que funcione en cualquier órbita.

uniform sampler3D ore_tex;
uniform vec3 centro = vec3(0.0);
uniform float radio = 250.0;
uniform vec3 bounds_pos = vec3(-512.0, -512.0, -512.0);
uniform vec3 bounds_size = vec3(1024.0, 1152.0, 1024.0);
uniform vec3 col_suelo = vec3(0.25, 0.5, 0.15);
uniform vec3 col_roca = vec3(0.7, 0.3, 0.1);
uniform vec3 col_r = vec3(0.72, 0.45, 0.20);
uniform vec3 col_g = vec3(0.35, 0.35, 0.35);
uniform vec3 col_b = vec3(0.75, 0.88, 0.95);

void fragment() {
    float depth = length(NODE_POSITION_WORLD - centro) - radio;
    vec3 uvw = (NODE_POSITION_WORLD - bounds_pos) / bounds_size;
    vec3 ore = texture(ore_tex, uvw).rgb;

    vec3 albedo;
    float roughness = 0.85;
    float metallic = 0.0;

    if (ore.r > 0.55) {
        albedo = col_r;
        roughness = 0.4;
        metallic = 0.7;
    } else if (ore.g > 0.55) {
        albedo = col_g;
        roughness = 0.5;
        metallic = 0.8;
    } else if (ore.b > 0.55) {
        albedo = col_b;
        roughness = 0.3;
        metallic = 0.6;
    } else if (depth > -5.0) {
        albedo = col_suelo + (sin(NODE_POSITION_WORLD.x * 0.1) * 0.03);
    } else {
        albedo = col_roca + (cos(NODE_POSITION_WORLD.z * 0.1) * 0.05);
    }

    ALBEDO = albedo;
    ROUGHNESS = roughness;
    METALLIC = metallic;
}
