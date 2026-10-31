class_name ImpresoraBase
extends ModuloBase

# ImpresoraBase:
# Clase base para la línea de impresoras 3D diegéticas (Pequeña, Mediana, Grande).
# Funcionalidades:
# - Ciclado interactivo de recetas con botones 3D [<] y [>]
# - Display holográfico con nombre, coste, estado y barra de progreso
# - Proyección holográfica del producto (Ghost Blueprint) sobre la cama
# - Ranuras de entrada físicas (Slot.tscn) para recursos requeridos
# - Botón [CARGAR] para transferir materiales automáticamente desde la mochila
# - Impresión con cabezal animado, rayo láser emissive y consumo de BaseCore
# - Generación física del producto terminado sobre la cama

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

const ESCENAS_RECURSOS := {
	2: preload("res://escenas/planeta/ore_copper.tscn"),
	3: preload("res://escenas/planeta/ore_iron.tscn"),
	4: preload("res://escenas/planeta/ore_lithium.tscn"),
	12: preload("res://escenas/planeta/ingot_copper.tscn"),
	13: preload("res://escenas/planeta/ingot_iron.tscn"),
	14: preload("res://escenas/planeta/ingot_litio.tscn"),
	20: preload("res://escenas/planeta/item_compuesto.tscn"),
	21: preload("res://escenas/planeta/item_resina.tscn"),
	22: preload("res://escenas/planeta/item_arcilla.tscn"),
	23: preload("res://escenas/planeta/item_cuarzo.tscn")
}

@export var nivel_impresora: String = "IMPRESORA"

var _recetas: Array[Dictionary] = []
var _indice_receta: int = 0
var _imprimiendo: bool = false
var _progreso: float = 0.0

# Nodos diegéticos
@onready var display_titulo: Label3D = get_node_or_null("Display/LabelTitulo")
@onready var display_receta: Label3D = get_node_or_null("Display/LabelReceta")
@onready var display_coste: Label3D = get_node_or_null("Display/LabelCoste")
@onready var display_estado: Label3D = get_node_or_null("Display/LabelEstado")
@onready var barra_progreso: MeshInstance3D = get_node_or_null("Display/BarraProgreso")

@onready var boton_imprimir_mesh: MeshInstance3D = get_node_or_null("Panel/BotonImprimir/MeshInstance3D")
@onready var boton_cargar_mesh: MeshInstance3D = get_node_or_null("Panel/BotonCargar/MeshInstance3D")

@onready var punto_impresion: Marker3D = get_node_or_null("CamaImpresion/PuntoImpresion")
@onready var ghost_preview: MeshInstance3D = get_node_or_null("CamaImpresion/GhostPreview")

@onready var cabezal: Node3D = get_node_or_null("Cabezal")
@onready var luz_impresion: OmniLight3D = get_node_or_null("Cabezal/LuzImpresion")
@onready var rayo_laser: MeshInstance3D = get_node_or_null("Cabezal/RayoLaser")

@onready var contenedor_slots: Node3D = get_node_or_null("Slots")

var _mat_btn_listo: StandardMaterial3D
var _mat_btn_espera: StandardMaterial3D
var _mat_ghost: StandardMaterial3D

var _cabezal_y_inicial: float = 0.0


func _ready() -> void:
	add_to_group("impresoras_base")
	add_to_group("modulo_base")
	_crear_materiales()
	if cabezal:
		_cabezal_y_inicial = cabezal.position.y
	_configurar_recetas()
	await get_tree().process_frame
	actualizar_interfaz()


func _configurar_recetas() -> void:
	# Las subclases o escenas llenan _recetas
	pass


func _crear_materiales() -> void:
	_mat_btn_listo = StandardMaterial3D.new()
	_mat_btn_listo.albedo_color = Color(0.15, 0.9, 0.35)
	_mat_btn_listo.emission_enabled = true
	_mat_btn_listo.emission = Color(0.1, 0.85, 0.25)
	_mat_btn_listo.emission_energy_multiplier = 1.8

	_mat_btn_espera = StandardMaterial3D.new()
	_mat_btn_espera.albedo_color = Color(0.35, 0.2, 0.2)
	_mat_btn_espera.emission_enabled = false

	_mat_ghost = StandardMaterial3D.new()
	_mat_ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_ghost.albedo_color = Color(0.2, 0.8, 1.0, 0.35)
	_mat_ghost.emission_enabled = true
	_mat_ghost.emission = Color(0.1, 0.6, 0.9)
	_mat_ghost.emission_energy_multiplier = 0.8
	_mat_ghost.cull_mode = BaseMaterial3D.CULL_DISABLED


func _process(delta: float) -> void:
	if ghost_preview and ghost_preview.visible:
		ghost_preview.rotation.y += delta * 1.0

	if not _imprimiendo:
		return

	var receta: Dictionary = get_receta_actual()
	if receta.is_empty():
		_imprimiendo = false
		return

	var base = get_tree().get_first_node_in_group("base_core")
	var consumo: float = receta.get("consumo", 2.0)
	var tiene_energia: bool = (base != null and base.consumir(consumo * delta))

	if not tiene_energia:
		if display_estado:
			display_estado.text = "[SIN ENERGIA]"
			display_estado.modulate = Color(1.0, 0.25, 0.25)
		if luz_impresion:
			luz_impresion.light_energy = 0.0
		if rayo_laser:
			rayo_laser.visible = false
		return

	var duracion: float = maxf(1.0, receta.get("tiempo", 8.0))
	_progreso += delta / duracion

	if barra_progreso:
		barra_progreso.scale.x = clampf(_progreso, 0.01, 1.0)

	# Animación del cabezal y láser
	if cabezal:
		var oscilacion: float = sin(_progreso * PI * 12.0) * 0.15
		cabezal.position.y = _cabezal_y_inicial - (_progreso * 0.4) + oscilacion

	if luz_impresion:
		luz_impresion.visible = true
		luz_impresion.light_energy = randf_range(1.8, 3.8)

	if rayo_laser:
		rayo_laser.visible = true

	if display_estado:
		display_estado.text = "IMPRIMIENDO: %d%%" % int(_progreso * 100.0)
		display_estado.modulate = Color(0.2, 0.9, 1.0)

	if _progreso >= 1.0:
		_finalizar_impresion()


func _finalizar_impresion() -> void:
	_imprimiendo = false
	_progreso = 0.0

	if luz_impresion:
		luz_impresion.light_energy = 0.0
	if rayo_laser:
		rayo_laser.visible = false
	if cabezal:
		cabezal.position.y = _cabezal_y_inicial
	if barra_progreso:
		barra_progreso.scale.x = 0.01

	var receta: Dictionary = get_receta_actual()
	_consumir_materiales(receta.get("inputs", {}))

	var escena: PackedScene = receta.get("escena", null)
	if escena and punto_impresion:
		var prod = escena.instantiate()
		get_tree().current_scene.add_child(prod)
		prod.global_position = punto_impresion.global_position
		prod.global_basis = global_basis
		if prod.has_method("set_physics_state"):
			prod.set_physics_state(true)
		if prod.get("_colocado") != null:
			prod.set("_colocado", true)

	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("mostrar_notificacion"):
		hud.mostrar_notificacion("Fabricado: %s" % receta.get("nombre", "Objeto"))

	AudioJuego.reproducir_imprimir()
	actualizar_interfaz()


# ─── NAVEGACIÓN Y ACCIONES ───────────────────────────────────────────────────

func receta_siguiente() -> void:
	if _imprimiendo or _recetas.is_empty():
		return
	_indice_receta = (_indice_receta + 1) % _recetas.size()
	actualizar_interfaz()


func receta_anterior() -> void:
	if _imprimiendo or _recetas.is_empty():
		return
	_indice_receta = (_indice_receta - 1 + _recetas.size()) % _recetas.size()
	actualizar_interfaz()


func get_receta_actual() -> Dictionary:
	if _recetas.is_empty():
		return {}
	return _recetas[_indice_receta]


func iniciar_impresion() -> void:
	if _imprimiendo:
		return
	var receta: Dictionary = get_receta_actual()
	if receta.is_empty():
		return

	if not puede_imprimir():
		# Feedback si faltan materiales
		if display_estado:
			display_estado.text = "[FALTAN MATERIALES]"
			display_estado.modulate = Color(1.0, 0.4, 0.2)
		return

	_imprimiendo = true
	_progreso = 0.0
	actualizar_interfaz()


func cargar_materiales_desde_jugador(player: Node) -> bool:
	if _imprimiendo or player == null:
		return false

	var receta: Dictionary = get_receta_actual()
	var inputs: Dictionary = receta.get("inputs", {})
	var cargados: Dictionary = contar_materiales_cargados()
	var slots := get_slots_entrada()

	var cargo_algo := false

	for rid in inputs:
		var necesario: int = int(inputs[rid])
		var actual: int = cargados.get(rid, 0)
		var falta: int = necesario - actual

		while falta > 0:
			if player.contar_items().get(rid, 0) <= 0:
				break

			# Buscar un slot libre
			var slot_libre: Area3D = null
			for s in slots:
				if s.stored_item == null:
					slot_libre = s
					break

			if slot_libre == null:
				break

			if player.quitar_items(rid, 1):
				var escena_recurso: PackedScene = ESCENAS_RECURSOS.get(rid, null)
				if escena_recurso:
					var item_nuevo = escena_recurso.instantiate()
					item_nuevo.recurso_id = rid
					get_tree().current_scene.add_child(item_nuevo)
					if item_nuevo.has_method("set_physics_state"):
						item_nuevo.set_physics_state(false)
					slot_libre.equip_item(item_nuevo)
					cargo_algo = true
					falta -= 1
					cargados[rid] = cargados.get(rid, 0) + 1

	actualizar_interfaz()
	return cargo_algo


func get_slots_entrada() -> Array[Area3D]:
	var res: Array[Area3D] = []
	if contenedor_slots:
		for c in contenedor_slots.get_children():
			if c.is_in_group("slots"):
				res.append(c as Area3D)
	return res


func contar_materiales_cargados() -> Dictionary:
	var counts := {}
	for s in get_slots_entrada():
		if s.stored_item:
			var rid: int = s.stored_item.get("recurso_id")
			if rid > 0:
				counts[rid] = counts.get(rid, 0) + 1
	return counts


func puede_imprimir() -> bool:
	var receta: Dictionary = get_receta_actual()
	if receta.is_empty():
		return false
	var inputs: Dictionary = receta.get("inputs", {})
	var cargados: Dictionary = contar_materiales_cargados()

	for rid in inputs:
		var necesario: int = int(inputs[rid])
		if cargados.get(rid, 0) < necesario:
			return false
	return true


func _consumir_materiales(inputs: Dictionary) -> void:
	var slots := get_slots_entrada()
	var restantes := inputs.duplicate()

	for s in slots:
		if s.stored_item:
			var rid: int = s.stored_item.get("recurso_id")
			if restantes.get(rid, 0) > 0:
				restantes[rid] -= 1
				var item = s.stored_item
				s.stored_item = null
				item.queue_free()


func actualizar_interfaz() -> void:
	var receta: Dictionary = get_receta_actual()
	if receta.is_empty():
		return

	if display_titulo:
		display_titulo.text = nivel_impresora

	if display_receta:
		display_receta.text = receta.get("nombre", "")

	if display_coste:
		var partes: Array[String] = []
		var inputs: Dictionary = receta.get("inputs", {})
		var cargados: Dictionary = contar_materiales_cargados()
		for rid in inputs:
			var nom = NOMBRES_RECURSOS.get(rid, "Recurso %d" % rid)
			var tiene = cargados.get(rid, 0)
			var need = int(inputs[rid])
			partes.append("%s: %d/%d" % [nom, tiene, need])
		display_coste.text = ", ".join(partes)

	var listo := puede_imprimir()

	if display_estado:
		if _imprimiendo:
			display_estado.text = "IMPRIMIENDO: %d%%" % int(_progreso * 100.0)
			display_estado.modulate = Color(0.2, 0.9, 1.0)
		elif listo:
			display_estado.text = "[LISTO PARA IMPRIMIR]"
			display_estado.modulate = Color(0.2, 0.95, 0.4)
		else:
			display_estado.text = "[FALTAN MATERIALES]"
			display_estado.modulate = Color(0.9, 0.6, 0.2)

	if boton_imprimir_mesh:
		boton_imprimir_mesh.material_override = _mat_btn_listo if listo else _mat_btn_espera

	# Actualizar preview holográfico
	if ghost_preview:
		var preview_mesh: Mesh = receta.get("preview_mesh", null)
		if preview_mesh:
			ghost_preview.mesh = preview_mesh
			ghost_preview.material_override = _mat_ghost
			ghost_preview.visible = true
		else:
			ghost_preview.visible = false
