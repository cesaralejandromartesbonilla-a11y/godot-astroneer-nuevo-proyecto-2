class_name ArbolArido
extends "res://scripts/planeta/arbol_alienigena.gd"

# ArbolArido (Fase 8 — Bioma Árido):
# Megacactus columnar ramificado. Tonos ocre/anaranjados con espinas prismáticas.
# Bioluminiscencia naranja suave — indica zonas ricas en titanio.


func _crear_materiales() -> void:
	var tronco: MeshInstance3D = get_node_or_null("Tronco")
	var rama_izq: MeshInstance3D = get_node_or_null("RamaIzq")
	var rama_der: MeshInstance3D = get_node_or_null("RamaDer")
	var luz: OmniLight3D = get_node_or_null("LuzBio")

	var mat_tronco := StandardMaterial3D.new()
	mat_tronco.albedo_color = Color(0.72, 0.42, 0.18)
	mat_tronco.roughness = 0.9
	mat_tronco.emission_enabled = true
	mat_tronco.emission = Color(0.6, 0.28, 0.08)
	mat_tronco.emission_energy_multiplier = 0.35
	if tronco:
		tronco.material_override = mat_tronco
	if rama_izq:
		rama_izq.material_override = mat_tronco
	if rama_der:
		rama_der.material_override = mat_tronco

	if luz:
		luz.light_color = Color(1.0, 0.55, 0.1)
		luz.light_energy = 0.6
		luz.omni_range = 7.0
