class_name GatewayEngine
extends Node3D

# GatewayEngine (Fase 7):
# Núcleo geométrico alienígena en el centro del planeta.
# Zona de baja gravedad. Requiere un recurso refinado o mineral clave del planeta
# para despertar el núcleo y desbloquear el viaje interplanetario instantáneo.

signal nucleo_activado(planeta_id: int)

@export var planeta_id: int = 0
@export var recurso_requerido_id: int = 23  # 23 = Cuarzo (Terra), 5 = Titanio (Árido), 6 = Criolita (Hielo)
@export var nombre_recurso: String = "Cuarzo"

var activado: bool = false
var destino_superficie: Node3D = null

@onready var altar_mesh: MeshInstance3D = get_node_or_null("Altar/MeshAltar")
@onready var nucleo_flotante: MeshInstance3D = get_node_or_null("NucleoFlotante")
@onready var luz_nucleo: OmniLight3D = get_node_or_null("LuzNucleo")
@onready var area_interaccion: Area3D = get_node_or_null("AreaInteraccion")
@onready var area_retorno: Area3D = get_node_or_null("AreaRetorno")
@onready var label_info: Label3D = get_node_or_null("LabelInfo")

var _mat_nucleo: StandardMaterial3D = null
var _jugador_cerca: Node3D = null
var _area_baja_grav: Area3D = null


func _ready() -> void:
	add_to_group("gateway_engines")
	_crear_area_baja_gravedad()
	_crear_materiales()
	if area_interaccion:
		area_interaccion.body_entered.connect(_on_interaccion_entered)
		area_interaccion.body_exited.connect(_on_interaccion_exited)
	if area_retorno:
		area_retorno.body_entered.connect(_on_retorno_entered)
	actualizar_interfaz()


func _crear_area_baja_gravedad() -> void:
	# Zona de gravedad controlada perpendicular a la plataforma del motor: radio 45 m
	_area_baja_grav = Area3D.new()
	_area_baja_grav.name = "AreaBajaGravedad"
	_area_baja_grav.gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE
	_area_baja_grav.gravity = 18.0
	_area_baja_grav.gravity_point = false
	_area_baja_grav.gravity_direction = -global_transform.basis.y
	_area_baja_grav.priority = 10        # Mayor prioridad que el area del planeta
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 45.0
	cs.shape = sh
	_area_baja_grav.add_child(cs)
	add_child(_area_baja_grav)


func _crear_materiales() -> void:
	_mat_nucleo = StandardMaterial3D.new()
	_mat_nucleo.albedo_color = Color(0.1, 0.15, 0.25)
	_mat_nucleo.metallic = 0.9
	_mat_nucleo.roughness = 0.15
	_mat_nucleo.emission_enabled = true
	_mat_nucleo.emission = Color(0.3, 0.1, 0.6)
	_mat_nucleo.emission_energy_multiplier = 1.0
	if nucleo_flotante:
		nucleo_flotante.material_override = _mat_nucleo


func _process(delta: float) -> void:
	# Rotación lenta y flotación geométrica del núcleo
	if nucleo_flotante:
		nucleo_flotante.rotate_y(0.5 * delta)
		nucleo_flotante.rotate_x(0.3 * delta)
		var offset_y = sin(Time.get_ticks_msec() * 0.002) * 0.2
		nucleo_flotante.position.y = 2.0 + offset_y


func _unhandled_input(event: InputEvent) -> void:
	if not activado and _jugador_cerca and event.is_action_pressed("press_e"):
		_intentar_activar(_jugador_cerca)


func _intentar_activar(player: Node3D) -> void:
	# Comprobar si el jugador tiene el recurso requerido en la mano o en la mochila
	var encontrado := false
	var item_a_consumir: Node = null

	if player.get("held_item") != null:
		var item = player.held_item
		if item.get("recurso_id") == recurso_requerido_id or item.name.to_lower().contains(nombre_recurso.to_lower()):
			encontrado = true
			item_a_consumir = item
			player.held_item = null

	if not encontrado:
		var mochila = player.get_node_or_null("Visuals/Mochila")
		if mochila:
			for slot in mochila.find_children("", "Area3D", true, false):
				if slot.is_in_group("slots") and slot.has_method("remove_item"):
					var held = slot.get("item_held")
					if held and (held.get("recurso_id") == recurso_requerido_id or held.name.to_lower().contains(nombre_recurso.to_lower())):
						item_a_consumir = slot.remove_item()
						encontrado = true
						break

	if encontrado:
		if is_instance_valid(item_a_consumir):
			item_a_consumir.queue_free()
		_despertar_nucleo()
	else:
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("mostrar_notificacion"):
			hud.mostrar_notificacion("Requiere: 1x %s para activar el Núcleo" % nombre_recurso)


func _despertar_nucleo() -> void:
	activado = true
	nucleo_activado.emit(planeta_id)

	if _mat_nucleo:
		_mat_nucleo.emission = Color(0.9, 0.4, 1.0)
		_mat_nucleo.emission_energy_multiplier = 4.0
	if luz_nucleo:
		luz_nucleo.light_color = Color(0.9, 0.4, 1.0)
		luz_nucleo.light_energy = 5.0

	AudioJuego.reproducir_imprimir()

	# Recompensa de bytes masiva
	var catalogo = get_tree().get_first_node_in_group("catalogo")
	if catalogo and "bytes" in catalogo:
		catalogo.bytes += 2500

	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("mostrar_notificacion"):
		hud.mostrar_notificacion("¡NUCLEO PLANETARIO RESTAURADO! (+2500 Bytes)")

	actualizar_interfaz()


func actualizar_interfaz() -> void:
	if label_info == null:
		return
	if activado:
		label_info.text = "MOTOR ALIENIGENA ACTIVADO\n[Pisa el centro para regresar a la superficie]"
		label_info.modulate = Color(0.9, 0.5, 1.0)
	else:
		label_info.text = "NUCLEO PLANETARIO\nInserte: 1x %s [E]" % nombre_recurso
		label_info.modulate = Color(0.8, 0.85, 0.95)


func _on_interaccion_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_jugador_cerca = body


func _on_interaccion_exited(body: Node3D) -> void:
	if body == _jugador_cerca:
		_jugador_cerca = null


func _on_retorno_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		var menu_tp = get_node_or_null("/root/MenuTeleport")
		if menu_tp and menu_tp.has_method("abrir_red"):
			menu_tp.abrir_red(self)
		elif activado and destino_superficie:
			_retornar_a_superficie(body)


func _retornar_a_superficie(player: Node3D) -> void:
	var loading = get_node_or_null("/root/Loading")
	if loading and loading.has_method("show_message"):
		loading.show_message("ASCENDIENDO A LA SUPERFICIE...")

	player.set_physics_process(false)
	var up_dest: Vector3 = destino_superficie.global_transform.basis.y
	player.global_position = destino_superficie.global_position + up_dest * 2.2
	player.up_direction = up_dest
	player.velocity = Vector3.ZERO
	if player.has_method("update_gravity_source"):
		player.update_gravity_source()
	if player.has_method("align_up_with_planet"):
		player.align_up_with_planet(up_dest)

	var dn := get_tree().get_first_node_in_group("day_night")
	if dn and dn.has_method("snap_atmosfera"):
		dn.snap_atmosfera(player.global_position)

	AudioJuego.reproducir_recoger()

	await get_tree().create_timer(0.6).timeout
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)

	if loading and loading.has_method("hide_screen"):
		loading.hide_screen()

	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("mostrar_notificacion"):
		hud.mostrar_notificacion("SUPERFICIE ALCANZADA")
