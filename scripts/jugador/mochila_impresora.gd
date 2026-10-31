extends Node3D

# MochilaImpresora (Fase 1):
# 1. Barras volumétricas diegéticas de Oxígeno (Cian) y Energía (Amarillo).
# 2. Micro-Impresora 3D interactiva en la base de la mochila con selector [<] [>]
#    y botón de impresión. Consume recursos directamente de los 8 slots.

const RECETAS_MOCHILA: Array[RecetaData] = [
	preload("res://recursos/receta_tethers.tres"),
	preload("res://recursos/receta_panel_solar.tres"),
	preload("res://recursos/receta_bateria.tres"),
	preload("res://recursos/receta_tanque_o2.tres"),
	preload("res://recursos/receta_impresora_pequena.tres"),
]

const NOMBRES_RECURSOS := {
	2: "Cobre",
	3: "Hierro",
	4: "Litio",
	5: "Titanio",
	6: "Criolita",
	12: "Lingote Cobre",
	13: "Lingote Hierro",
	14: "Lingote Litio",
	20: "Compuesto",
	21: "Resina",
	22: "Arcilla",
	23: "Cuarzo"
}

var _indice_receta := 0
var _player: Node3D = null

@onready var barra_o2_nivel: MeshInstance3D = $BarraO2Nivel
@onready var barra_power_nivel: MeshInstance3D = $BarraPowerNivel

@onready var display_nombre: Label3D = $Impresora/HoloNombre
@onready var display_coste: Label3D = $Impresora/HoloCoste
@onready var boton_imprimir_mesh: MeshInstance3D = $Impresora/BotonImprimir/MeshInstance3D
@onready var luz_impresion: OmniLight3D = $Impresora/LuzImpresion

var _mat_btn_listo: StandardMaterial3D
var _mat_btn_falta: StandardMaterial3D


func _ready() -> void:
	_crear_materiales()
	await get_tree().process_frame
	_player = get_parent().get_parent() # Visuals -> Player
	actualizar_interfaz()


func _crear_materiales() -> void:
	_mat_btn_listo = StandardMaterial3D.new()
	_mat_btn_listo.albedo_color = Color(0.15, 0.9, 0.3)
	_mat_btn_listo.emission_enabled = true
	_mat_btn_listo.emission = Color(0.1, 0.8, 0.25)
	_mat_btn_listo.emission_energy_multiplier = 1.8

	_mat_btn_falta = StandardMaterial3D.new()
	_mat_btn_falta.albedo_color = Color(0.4, 0.15, 0.15)
	_mat_btn_falta.emission_enabled = false


# ─── BARRAS DIEGÉTICAS ────────────────────────────────────────────────────────

func actualizar_o2(val: float, max_val: float) -> void:
	if barra_o2_nivel == null:
		return
	var ratio := clampf(val / maxf(1.0, max_val), 0.001, 1.0)
	barra_o2_nivel.scale.y = ratio
	barra_o2_nivel.position.y = (ratio - 1.0) * 0.25


func actualizar_power(val: float, max_val: float) -> void:
	if barra_power_nivel == null:
		return
	var ratio := clampf(val / maxf(1.0, max_val), 0.001, 1.0)
	barra_power_nivel.scale.y = ratio
	barra_power_nivel.position.y = (ratio - 1.0) * 0.25


# ─── MICRO-IMPRESORA 3D ──────────────────────────────────────────────────────

func receta_siguiente() -> void:
	_indice_receta = (_indice_receta + 1) % RECETAS_MOCHILA.size()
	actualizar_interfaz()


func receta_anterior() -> void:
	_indice_receta = (_indice_receta - 1 + RECETAS_MOCHILA.size()) % RECETAS_MOCHILA.size()
	actualizar_interfaz()


func get_receta_actual() -> RecetaData:
	return RECETAS_MOCHILA[_indice_receta]


func puede_fabricar() -> bool:
	if _player == null:
		return false
	var receta := get_receta_actual()
	var inv: Dictionary = _player.contar_items()
	for rid in receta.inputs:
		if inv.get(rid, 0) < int(receta.inputs[rid]):
			return false
	return true


func fabricar() -> bool:
	if not puede_fabricar():
		return false

	var receta := get_receta_actual()
	for rid in receta.inputs:
		_player.quitar_items(rid, int(receta.inputs[rid]))

	if receta.colocable != "":
		_player.placeables[receta.colocable] = _player.placeables.get(receta.colocable, 0) + receta.salida_cantidad
	if receta.mejora_o2_max > 0:
		_player.stats.mejorar_o2_max(receta.mejora_o2_max)
	if receta.mejora_power_max > 0:
		_player.stats.mejorar_power_max(receta.mejora_power_max)

	_animar_impresion()

	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("mostrar_notificacion"):
		hud.mostrar_notificacion("Impreso en mochila: %s" % receta.nombre)

	actualizar_interfaz()
	return true


func _animar_impresion() -> void:
	if luz_impresion:
		var tw = create_tween()
		luz_impresion.light_energy = 3.5
		tw.tween_property(luz_impresion, "light_energy", 0.0, 0.6)


func actualizar_interfaz() -> void:
	var receta := get_receta_actual()
	if display_nombre:
		display_nombre.text = receta.nombre

	if display_coste:
		var partes: Array[String] = []
		var inv: Dictionary = _player.contar_items() if _player else {}
		for rid in receta.inputs:
			var nom = NOMBRES_RECURSOS.get(rid, "Recurso %d" % rid)
			var tiene = inv.get(rid, 0)
			var need = int(receta.inputs[rid])
			partes.append("%s: %d/%d" % [nom, tiene, need])
		display_coste.text = ", ".join(partes)

	var listo := puede_fabricar()
	if boton_imprimir_mesh:
		boton_imprimir_mesh.material_override = _mat_btn_listo if listo else _mat_btn_falta
