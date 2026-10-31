class_name ArbolHielo
extends "res://scripts/planeta/arbol_alienigena.gd"

# ArbolHielo (Fase 8 — Bioma Hielo):
# Dendrita cristalina: estructura ramificada angular como escarcha gigante.
# Translúcida, azul-blanca gélida. Emite luz fría tenue; puede congelar el suelo
# a su alrededor (efecto cosmético). Rica en criolita y litio bajo sus raíces.


func _crear_materiales() -> void:
	var cristal_a: MeshInstance3D = get_node_or_null("CristalA")
	var cristal_b: MeshInstance3D = get_node_or_null("CristalB")
	var cristal_c: MeshInstance3D = get_node_or_null("CristalC")
	var luz: OmniLight3D = get_node_or_null("LuzBio")

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.88, 1.0, 0.7)
	mat.roughness = 0.05
	mat.metallic = 0.2
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.75, 1.0)
	mat.emission_energy_multiplier = 0.9
	for cristal: MeshInstance3D in [cristal_a, cristal_b, cristal_c]:
		if cristal:
			cristal.material_override = mat

	if luz:
		luz.light_color = Color(0.5, 0.85, 1.0)
		luz.light_energy = 1.0
		luz.omni_range = 11.0
