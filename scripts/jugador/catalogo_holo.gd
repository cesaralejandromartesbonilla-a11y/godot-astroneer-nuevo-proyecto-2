extends Node3D

# CatalogoHolo (Fase 3 de la Mochila):
# Terminal holografica 3D retractil.
# MarcoSup (BotonToggleCatalogo) siempre visible — actua de pestana.
# Al hacer click despliega/pliega la Pantalla con tween de escala.

const RECETAS_TECNOLOGICAS: Array[RecetaData] = [
	preload("res://recursos/receta_tethers.tres"),
	preload("res://recursos/receta_panel_solar.tres"),
	preload("res://recursos/receta_bateria.tres"),
	preload("res://recursos/receta_tanque_o2.tres"),
	preload("res://recursos/receta_tanque_grande.tres"),
	preload("res://recursos/receta_rover.tres"),
	preload("res://recursos/receta_traje.tres"),
	preload("res://recursos/receta_lanzadera.tres"),
]

var _indice: int = 0
var _catalogo_node: Node = null
var _player: Node3D = null
var _desplegado: bool = false

@onready var pantalla: MeshInstance3D = $Pantalla
@onready var display_titulo: Label3D = $Pantalla/Titulo
@onready var display_item: Label3D = $Pantalla/ItemNombre
@onready var display_coste: Label3D = $Pantalla/ItemCoste
@onready var display_estado: Label3D = $Pantalla/ItemEstado
@onready var display_bytes: Label3D = $Pantalla/BytesDisponibles
@onready var boton_desbloquear_mesh: MeshInstance3D = $Pantalla/BotonDesbloquear/MeshInstance3D
@onready var luz_pantalla: OmniLight3D = $LuzPantalla

var _mat_btn_desbloquear: StandardMaterial3D


func _ready() -> void:
	_mat_btn_desbloquear = StandardMaterial3D.new()
	if boton_desbloquear_mesh:
		boton_desbloquear_mesh.material_override = _mat_btn_desbloquear
	await get_tree().process_frame
	_catalogo_node = get_tree().get_first_node_in_group("catalogo")
	_player = get_tree().get_first_node_in_group("player")
	if _catalogo_node:
		_catalogo_node.bytes_changed.connect(func(_b): actualizar_interfaz())
	# Empezar plegado: solo el BotonToggleCatalogo visible
	_set_desplegado(false)


# ─── Retractable toggle ───────────────────────────────────────────────────────

func toggle_despliegue() -> void:
	_set_desplegado(not _desplegado)


func _set_desplegado(valor: bool) -> void:
	_desplegado = valor
	if not is_node_ready():
		return
	if pantalla == null:
		return
	if valor:
		# Desplegar: primero hacer visible, luego animar escala Y 0.001->1
		pantalla.visible = true
		pantalla.scale = Vector3(1.0, 0.001, 1.0)
		var tw = create_tween()
		tw.tween_property(pantalla, "scale:y", 1.0, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		if luz_pantalla:
			var tw2 = create_tween()
			tw2.tween_property(luz_pantalla, "light_energy", 0.8, 0.3)
		actualizar_interfaz()
	else:
		# Plegar: animar escala Y 1->0.001, luego ocultar y restaurar
		var tw = create_tween()
		tw.tween_property(pantalla, "scale:y", 0.001, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		tw.tween_callback(func():
			if is_instance_valid(pantalla):
				pantalla.visible = false
				pantalla.scale = Vector3.ONE
		)
		if luz_pantalla:
			var tw2 = create_tween()
			tw2.tween_property(luz_pantalla, "light_energy", 0.0, 0.15)


# ─── Navegacion ──────────────────────────────────────────────────────────────

func anterior() -> void:
	_indice = (_indice - 1 + RECETAS_TECNOLOGICAS.size()) % RECETAS_TECNOLOGICAS.size()
	actualizar_interfaz()


func siguiente() -> void:
	_indice = (_indice + 1) % RECETAS_TECNOLOGICAS.size()
	actualizar_interfaz()


func actualizar_interfaz() -> void:
	if not _desplegado:
		return
	if _catalogo_node == null:
		_catalogo_node = get_tree().get_first_node_in_group("catalogo")

	var receta: RecetaData = RECETAS_TECNOLOGICAS[_indice]
	var bytes_actuales: int = _catalogo_node.bytes if _catalogo_node else 0
	var desbloqueada: bool = _catalogo_node.esta_desbloqueada(receta.id) if _catalogo_node else false

	if display_bytes:
		display_bytes.text = "BYTES: %d" % bytes_actuales

	if display_item:
		display_item.text = receta.nombre

	if display_coste:
		if desbloqueada:
			display_coste.text = "COSTE: DESBLOQUEADO"
			display_coste.modulate = Color(0.3, 0.95, 0.4, 1.0)
		else:
			display_coste.text = "COSTE: %d BYTES" % receta.coste_bytes
			display_coste.modulate = Color(1.0, 0.85, 0.2, 1.0)

	if display_estado:
		if desbloqueada:
			display_estado.text = "[YA DESBLOQUEADO]"
			display_estado.modulate = Color(0.2, 0.9, 0.3, 1.0)
		elif bytes_actuales >= receta.coste_bytes:
			display_estado.text = "[LISTO PARA DESBLOQUEAR]"
			display_estado.modulate = Color(0.3, 0.85, 1.0, 1.0)
		else:
			display_estado.text = "[BYTES INSUFICIENTES]"
			display_estado.modulate = Color(0.9, 0.3, 0.3, 1.0)

	if _mat_btn_desbloquear:
		if desbloqueada:
			_mat_btn_desbloquear.albedo_color = Color(0.18, 0.22, 0.25)
			_mat_btn_desbloquear.emission_enabled = false
		elif bytes_actuales >= receta.coste_bytes:
			_mat_btn_desbloquear.albedo_color = Color(0.15, 0.85, 0.35)
			_mat_btn_desbloquear.emission_enabled = true
			_mat_btn_desbloquear.emission = Color(0.1, 0.8, 0.3)
			_mat_btn_desbloquear.emission_energy_multiplier = 1.6
		else:
			_mat_btn_desbloquear.albedo_color = Color(0.4, 0.15, 0.15)
			_mat_btn_desbloquear.emission_enabled = false


func desbloquear_actual() -> void:
	if _catalogo_node == null: return
	var receta: RecetaData = RECETAS_TECNOLOGICAS[_indice]
	if _catalogo_node.esta_desbloqueada(receta.id):
		return

	if _catalogo_node.intentar_desbloquear(receta.id, receta.coste_bytes):
		actualizar_interfaz()
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("mostrar_notificacion"):
			hud.mostrar_notificacion("TECNOLOGIA DESBLOQUEADA: %s!" % receta.nombre.to_upper())
