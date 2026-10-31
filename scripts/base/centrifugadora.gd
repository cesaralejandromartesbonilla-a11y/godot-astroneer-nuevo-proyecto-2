extends ModuloBase

# Centrifugadora de Suelo (Soil Centrifuge):
# Convierte sedimento recolectado con la TerrainTool en recursos primarios
# (Compuesto, Resina, Arcilla, Cuarzo, Cobre, Hierro) consumiendo energía de BaseCore.
# Cuenta con display diegético 3D, animación de tambor y 4 slots de salida.

const RECETAS: Array[Dictionary] = [
	{
		"nombre": "Compuesto ×4",
		"coste": 50.0,
		"duracion": 12.0,
		"consumo": 2.5,
		"cantidad": 4,
		"id": 20,
		"escena": preload("res://escenas/planeta/item_compuesto.tscn")
	},
	{
		"nombre": "Resina ×4",
		"coste": 50.0,
		"duracion": 12.0,
		"consumo": 2.5,
		"cantidad": 4,
		"id": 21,
		"escena": preload("res://escenas/planeta/item_resina.tscn")
	},
	{
		"nombre": "Arcilla ×2",
		"coste": 50.0,
		"duracion": 14.0,
		"consumo": 2.5,
		"cantidad": 2,
		"id": 22,
		"escena": preload("res://escenas/planeta/item_arcilla.tscn")
	},
	{
		"nombre": "Cuarzo ×2",
		"coste": 50.0,
		"duracion": 14.0,
		"consumo": 2.5,
		"cantidad": 2,
		"id": 23,
		"escena": preload("res://escenas/planeta/item_cuarzo.tscn")
	},
	{
		"nombre": "Mena Cobre ×1",
		"coste": 75.0,
		"duracion": 18.0,
		"consumo": 3.0,
		"cantidad": 1,
		"id": 2,
		"escena": preload("res://escenas/planeta/ore_copper.tscn")
	},
	{
		"nombre": "Mena Hierro ×1",
		"coste": 100.0,
		"duracion": 22.0,
		"consumo": 3.5,
		"cantidad": 1,
		"id": 3,
		"escena": preload("res://escenas/planeta/ore_iron.tscn")
	}
]

var sedimento: float = 0.0
var sedimento_max: float = 100.0
var en_proceso: bool = false
var progreso: float = 0.0
var indice_receta: int = 0

@onready var salidas: Array[Node] = [
	$Salidas/Salida1,
	$Salidas/Salida2,
	$Salidas/Salida3,
	$Salidas/Salida4
]

@onready var tubo_nivel: MeshInstance3D = $TanqueSuelo/NivelSuelo
@onready var tambor: Node3D = $Camara/Tambor
@onready var luz_camara: OmniLight3D = $Camara/LuzCamara
@onready var barra_progreso: MeshInstance3D = $Display/BarraProgreso
@onready var label_receta: Label3D = $Display/LabelReceta
@onready var label_coste: Label3D = $Display/LabelCoste
@onready var label_sedimento: Label3D = $Display/LabelSedimento
@onready var label_estado: Label3D = $Display/LabelEstado
@onready var mesh_btn_iniciar: MeshInstance3D = $Panel/BotonCentrifugar/MeshInstance3D

var _mat_btn_iniciar: StandardMaterial3D
var _mat_suelo: StandardMaterial3D


func _ready() -> void:
	_crear_materiales()
	actualizar_interfaz()


func _crear_materiales() -> void:
	_mat_btn_iniciar = StandardMaterial3D.new()
	_mat_btn_iniciar.emission_enabled = true
	_mat_btn_iniciar.roughness = 0.3
	if mesh_btn_iniciar:
		mesh_btn_iniciar.material_override = _mat_btn_iniciar

	_mat_suelo = StandardMaterial3D.new()
	_mat_suelo.albedo_color = Color(0.48, 0.32, 0.18, 1.0) # Color tierra Astroneer
	_mat_suelo.roughness = 0.95
	if tubo_nivel:
		tubo_nivel.material_override = _mat_suelo


func receta_anterior() -> void:
	if en_proceso: return
	indice_receta = (indice_receta - 1 + RECETAS.size()) % RECETAS.size()
	actualizar_interfaz()


func receta_siguiente() -> void:
	if en_proceso: return
	indice_receta = (indice_receta + 1) % RECETAS.size()
	actualizar_interfaz()


func cargar_sedimento_desde_jugador(player: Node3D) -> bool:
	if en_proceso: return false
	if sedimento >= sedimento_max:
		_mostrar_feedback_temporal("TANQUE DE SEDIMENTO LLENO")
		return false

	var t_tool: Node3D = player.get("terrain_tool") as Node3D if player else null
	if t_tool == null or not t_tool.has_method("consumir_sedimento"):
		_mostrar_feedback_temporal("HERRAMIENTA NO DISPONIBLE")
		return false

	var disp: float = t_tool.get("sedimento") if "sedimento" in t_tool else 0.0
	if disp <= 0.1:
		_mostrar_feedback_temporal("CANISTER VACÍO")
		return false

	var libre: float = sedimento_max - sedimento
	var a_transferir: float = minf(libre, disp)
	if t_tool.consumir_sedimento(a_transferir):
		sedimento = minf(sedimento + a_transferir, sedimento_max)
		actualizar_interfaz()
		_mostrar_feedback_temporal("+%.0f%% SEDIMENTO CARGADO" % a_transferir)
		return true

	return false


func iniciar_centrifugado() -> void:
	if en_proceso: return
	var r: Dictionary = RECETAS[indice_receta]

	if sedimento < float(r["coste"]):
		_mostrar_feedback_temporal("SEDIMENTO INSUFICIENTE (REQUIERE %.0f%%)" % float(r["coste"]))
		return

	# Verificar slots de salida libres
	var libres: int = 0
	for s in salidas:
		if s.get("stored_item") == null:
			libres += 1

	if libres < int(r["cantidad"]):
		_mostrar_feedback_temporal("SLOTS DE SALIDA OCUPADOS (REQUIERE %d)" % int(r["cantidad"]))
		return

	sedimento = maxf(0.0, sedimento - float(r["coste"]))
	en_proceso = true
	progreso = 0.0
	actualizar_interfaz()


func _finalizar_centrifugado() -> void:
	en_proceso = false
	progreso = 0.0
	var r: Dictionary = RECETAS[indice_receta]
	var colocados: int = 0

	for s in salidas:
		if s.get("stored_item") == null and colocados < int(r["cantidad"]):
			var escena: PackedScene = r["escena"]
			var item: RigidBody3D = escena.instantiate()
			item.set("recurso_id", int(r["id"]))
			get_tree().current_scene.add_child(item)
			if item.has_method("set_physics_state"):
				item.set_physics_state(false)
			s.equip_item(item)
			colocados += 1

	actualizar_interfaz()
	_mostrar_feedback_temporal("¡PRODUCCIÓN COMPLETADA: %s!" % String(r["nombre"]))


func _process(delta: float) -> void:
	if en_proceso:
		var r: Dictionary = RECETAS[indice_receta]
		var base := get_tree().get_first_node_in_group("base_core")
		var consumo: float = float(r["consumo"])
		var duracion: float = float(r["duracion"])

		var tiene_energia: bool = (base != null and base.consumir(consumo * delta))
		if not tiene_energia:
			if label_estado:
				label_estado.text = "[SIN ENERGÍA EN LA BASE]"
				label_estado.modulate = Color(1.0, 0.3, 0.2)
			if tambor:
				tambor.rotate_y(0.8 * delta)
			return

		if tambor:
			tambor.rotate_y(22.0 * delta)

		progreso += delta / duracion
		if barra_progreso:
			barra_progreso.scale.x = maxf(0.01, progreso)

		if label_estado:
			label_estado.text = "[CENTRIFUGANDO... %d%%]" % int(progreso * 100.0)
			label_estado.modulate = Color(0.2, 0.9, 1.0)

		if progreso >= 1.0:
			_finalizar_centrifugado()

	else:
		if tambor:
			tambor.rotate_y(0.4 * delta)
		if barra_progreso:
			barra_progreso.scale.x = 0.01


func actualizar_interfaz() -> void:
	var r: Dictionary = RECETAS[indice_receta]
	var coste: float = float(r["coste"])

	if label_receta:
		label_receta.text = String(r["nombre"])
	if label_coste:
		label_coste.text = "Coste: %d%% Sedimento" % int(coste)
	if label_sedimento:
		label_sedimento.text = "Sedimento: %d%%" % int(sedimento)

	# Nivel físico terroso en el tubo de vidrio
	if tubo_nivel:
		var ratio: float = clampf(sedimento / sedimento_max, 0.0, 1.0)
		tubo_nivel.scale.y = maxf(ratio, 0.01)
		tubo_nivel.position.y = 0.45 * (ratio - 1.0)

	# Botón Iniciar (Verde si hay suficiente sedimento, ámbar/rojo si falta)
	var puede_iniciar: bool = (not en_proceso and sedimento >= coste)
	if _mat_btn_iniciar:
		if puede_iniciar:
			_mat_btn_iniciar.albedo_color = Color(0.15, 0.85, 0.25)
			_mat_btn_iniciar.emission = Color(0.1, 0.9, 0.2)
			_mat_btn_iniciar.emission_energy_multiplier = 1.5
		else:
			_mat_btn_iniciar.albedo_color = Color(0.4, 0.4, 0.4)
			_mat_btn_iniciar.emission = Color(0.2, 0.2, 0.2)
			_mat_btn_iniciar.emission_energy_multiplier = 0.2

	if not en_proceso and label_estado:
		if sedimento >= coste:
			label_estado.text = "[LISTO PARA INICIAR]"
			label_estado.modulate = Color(0.2, 0.9, 0.3)
		else:
			label_estado.text = "[FALTA SEDIMENTO]"
			label_estado.modulate = Color(1.0, 0.6, 0.1)


func _mostrar_feedback_temporal(mensaje: String) -> void:
	if label_estado:
		label_estado.text = mensaje
		label_estado.modulate = Color(1.0, 0.85, 0.2)
