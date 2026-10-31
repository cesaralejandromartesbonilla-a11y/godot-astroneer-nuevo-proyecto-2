class_name GatewayChamber
extends Node3D

# GatewayChamber (Fase 7):
# Estructura alienígena monolítica en la superficie del planeta.
# Requiere una carga de energía continua (de tethers/base o jugador).
# Al activarse, proyecta un rayo emissivo al cielo y abre un portal gravitacional
# que teletransporta al jugador directamente al GatewayEngine en el núcleo del planeta.

signal activado_cambiado(nuevo_estado: bool)

@export var energia_requerida: float = 35.0
@export var tasa_carga: float = 8.0
@export var tasa_descarga: float = 4.0

var energia_actual: float = 0.0
var activado: bool = false
var destino_nucleo: Node3D = null

@onready var luz_rayo: OmniLight3D = get_node_or_null("LuzRayo")
@onready var rayo_mesh: MeshInstance3D = get_node_or_null("RayoVertical")
@onready var pedestal_mesh: MeshInstance3D = get_node_or_null("Pedestal/MeshPedestal")
@onready var barra_energia: MeshInstance3D = get_node_or_null("BarraEnergia")
@onready var area_teleport: Area3D = get_node_or_null("AreaTeleport")
@onready var label_estado: Label3D = get_node_or_null("LabelEstado")

var _jugador_cerca: Node3D = null
var _mat_rayo: StandardMaterial3D = null
var _mat_pedestal: StandardMaterial3D = null


func _ready() -> void:
	add_to_group("gateways")
	_crear_materiales()
	if area_teleport:
		area_teleport.body_entered.connect(_on_body_entered)
		area_teleport.body_exited.connect(_on_body_exited)
	actualizar_visuales()


func _crear_materiales() -> void:
	_mat_rayo = StandardMaterial3D.new()
	_mat_rayo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_rayo.albedo_color = Color(0.2, 0.75, 1.0, 0.38)
	_mat_rayo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if rayo_mesh:
		rayo_mesh.visible = true
		rayo_mesh.material_override = _mat_rayo

	_mat_pedestal = StandardMaterial3D.new()
	_mat_pedestal.albedo_color = Color(0.12, 0.14, 0.22, 1.0)
	_mat_pedestal.metallic = 0.8
	_mat_pedestal.roughness = 0.2
	_mat_pedestal.emission_enabled = true
	_mat_pedestal.emission = Color(0.1, 0.4, 0.8)
	if pedestal_mesh:
		pedestal_mesh.material_override = _mat_pedestal


func _process(delta: float) -> void:
	# Efecto de pulsación del rayo vertical en todo momento
	if rayo_mesh:
		var factor_pulsante := 0.06 if activado else 0.03
		var vel_pulso := 0.005 if activado else 0.002
		var escala_pulsante = 1.0 + sin(Time.get_ticks_msec() * vel_pulso) * factor_pulsante
		rayo_mesh.scale.x = escala_pulsante
		rayo_mesh.scale.z = escala_pulsante

	if activado:
		return

	# Si el jugador está dentro del área o hay red de energía
	var cargando := false
	if _jugador_cerca:
		# Cargar desde la energía del jugador si tiene suficiente
		if "stats" in _jugador_cerca:
			var stats = _jugador_cerca.stats
			if stats.power > 5.0 and stats.consume_power(tasa_carga * delta):
				cargando = true

	# O desde el BaseCore si hay red cerca (tether / base)
	if not cargando:
		var base_core = get_tree().get_first_node_in_group("base_core")
		if base_core and base_core.has_method("consumir"):
			# Si estamos conectados a una red de tethers
			var tethers = get_tree().get_nodes_in_group("tethers")
			for t in tethers:
				if t.global_position.distance_to(global_position) < 22.0:
					if base_core.consumir(tasa_carga * delta * 0.5):
						cargando = true
					break

	if cargando:
		energia_actual = minf(energia_actual + tasa_carga * delta, energia_requerida)
		if energia_actual >= energia_requerida:
			_activar_portal()
	else:
		energia_actual = maxf(energia_actual - tasa_descarga * delta, 0.0)

	actualizar_visuales()


func _activar_portal() -> void:
	activado = true
	energia_actual = energia_requerida
	activado_cambiado.emit(true)

	if _mat_rayo:
		_mat_rayo.albedo_color = Color(0.35, 0.95, 1.0, 0.85)
	if luz_rayo:
		luz_rayo.visible = true
		luz_rayo.light_energy = 6.0
	if _mat_pedestal:
		_mat_pedestal.emission = Color(0.2, 0.95, 1.0)
		_mat_pedestal.emission_energy_multiplier = 2.5

	AudioJuego.reproducir_imprimir()
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("mostrar_notificacion"):
		hud.mostrar_notificacion("¡CAMARA DE PORTAL ACTIVADA!")

	actualizar_visuales()


func actualizar_visuales() -> void:
	var ratio := clampf(energia_actual / energia_requerida, 0.0, 1.0)

	if barra_energia:
		barra_energia.scale.y = maxf(ratio * 3.5, 0.08)
		barra_energia.position.y = 2.5 + (ratio * 1.75)

	if _mat_rayo and not activado:
		var alpha = lerpf(0.35, 0.65, ratio)
		_mat_rayo.albedo_color = Color(0.2, 0.75 + ratio * 0.2, 1.0, alpha)

	if label_estado:
		if activado:
			label_estado.text = "GATEWAY: ACTIVO\n[Pisa el portal para viajar al Nucleo]"
			label_estado.modulate = Color(0.2, 0.95, 1.0)
		elif energia_actual > 0.1:
			label_estado.text = "CARGANDO ENERGIA: %d%%" % int(ratio * 100.0)
			label_estado.modulate = Color(1.0, 0.8, 0.2)
		else:
			label_estado.text = "CAMARA DE PORTAL\n[Requiere Energía de Base o Traje]"
			label_estado.modulate = Color(0.6, 0.7, 0.8)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_jugador_cerca = body
		if activado:
			var menu_tp = get_node_or_null("/root/MenuTeleport")
			if menu_tp and menu_tp.has_method("abrir_red"):
				menu_tp.abrir_red(self)
			elif destino_nucleo:
				_teletransportar_a_nucleo(body)


func _on_body_exited(body: Node3D) -> void:
	if body == _jugador_cerca:
		_jugador_cerca = null


func _teletransportar_a_nucleo(player: Node3D) -> void:
	if destino_nucleo == null:
		return
	var loading = get_node_or_null("/root/Loading")
	if loading and loading.has_method("show_message"):
		loading.show_message("DESCENDIENDO AL NUCLEO...")

	player.set_physics_process(false)
	var up_dest: Vector3 = destino_nucleo.global_transform.basis.y
	player.global_position = destino_nucleo.global_position + up_dest * 2.2
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
		hud.mostrar_notificacion("NUCLEO DEL PLANETA ALCANZADO")
