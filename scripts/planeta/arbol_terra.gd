class_name ArbolTerra
extends "res://scripts/planeta/arbol_alienigena.gd"

# ArbolTerra (Fase 8 — Bioma Terra):
# Hongo arbóreo bioluminiscente. Tronco cónico achatado con sombrero esférico
# aplastado y bioluminiscencia esmeralda. Propio de zonas húmedas de Terra.


func _crear_materiales() -> void:
	var tallo: MeshInstance3D = get_node_or_null("Tallo")
	var sombrero: MeshInstance3D = get_node_or_null("Sombrero")
	var luz: OmniLight3D = get_node_or_null("LuzBio")

	var mat_tallo := StandardMaterial3D.new()
	mat_tallo.albedo_color = Color(0.22, 0.38, 0.28)
	mat_tallo.roughness = 0.85
	mat_tallo.emission_enabled = true
	mat_tallo.emission = Color(0.08, 0.35, 0.18)
	mat_tallo.emission_energy_multiplier = 0.5
	if tallo:
		tallo.material_override = mat_tallo

	var mat_somb := StandardMaterial3D.new()
	mat_somb.albedo_color = Color(0.18, 0.62, 0.4)
	mat_somb.roughness = 0.5
	mat_somb.emission_enabled = true
	mat_somb.emission = Color(0.1, 0.9, 0.45)
	mat_somb.emission_energy_multiplier = 1.4
	if sombrero:
		sombrero.material_override = mat_somb

	if luz:
		luz.light_color = Color(0.15, 1.0, 0.5)
		luz.light_energy = 0.8
		luz.omni_range = 9.0
