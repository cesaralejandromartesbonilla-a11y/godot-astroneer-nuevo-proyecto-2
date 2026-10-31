class_name FloraSpitter
extends Node3D

# FloraSpitter (Fase 8):
# Planta alienígena agresiva con catapulta de espinas.
# Rastrea al jugador en un radio de 14m, orienta su cabeza/cañón biológico
# hacia él y dispara proyectiles de espinas punzantes que dañan el oxígeno.
# Se neutraliza excavando sus raíces con la Herramienta de Terreno.

const PROYECTIL_SCENE := preload("res://escenas/planeta/proyectil_espina.tscn")
const RECOMPENSA_SCENE := preload("res://escenas/planeta/piedra_investigacion.tscn")

@export var rango_deteccion: float = 14.0
@export var intervalo_disparo: float = 2.8
@export var bytes_recompensa: int = 400

var _neutralizada: bool = false
var _tiempo_vida: float = 0.0
var _suelo_confirmado: bool = false
var _tiempo_recarga: float = 1.0
var _preparando_disparo: bool = false
var _tiempo_carga: float = 0.0

@onready var cabeza_nodo: Node3D = get_node_or_null("Cabeza")
@onready var boca_nodo: Node3D = get_node_or_null("Cabeza/Boca")
@onready var bulbo_mesh: MeshInstance3D = get_node_or_null("Cabeza/BulboDisparo")
@onready var luz_alerta: OmniLight3D = get_node_or_null("Cabeza/LuzAlerta")
@onready var raycast_suelo: RayCast3D = get_node_or_null("RayCastSuelo")

var _mat_bulbo: StandardMaterial3D = null


func _ready() -> void:
	add_to_group("flora_peligrosa")
	_crear_materiales()
	if raycast_suelo:
		raycast_suelo.collision_mask = 1
		raycast_suelo.enabled = true
		raycast_suelo.position = Vector3(0.0, 0.15, 0.0)
		raycast_suelo.target_position = Vector3(0.0, -0.6, 0.0)
		for c in find_children("*", "CollisionObject3D", true, false):
			raycast_suelo.add_exception(c)


func _crear_materiales() -> void:
	_mat_bulbo = StandardMaterial3D.new()
	_mat_bulbo.albedo_color = Color(0.8, 0.15, 0.15)
	_mat_bulbo.roughness = 0.4
	_mat_bulbo.emission_enabled = true
	_mat_bulbo.emission = Color(0.9, 0.2, 0.1)
	_mat_bulbo.emission_energy_multiplier = 1.2
	if bulbo_mesh:
		bulbo_mesh.material_override = _mat_bulbo


func _physics_process(delta: float) -> void:
	if _neutralizada:
		return

	_tiempo_vida += delta

	# 1. Verificación del suelo
	if raycast_suelo:
		if not _suelo_confirmado:
			if raycast_suelo.is_colliding():
				_suelo_confirmado = true
		else:
			if _tiempo_vida > 0.5 and not raycast_suelo.is_colliding():
				_neutralizar()
				return

	# 2. Rastreo del jugador
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	var dist := global_position.distance_to(player.global_position)
	if dist > rango_deteccion:
		_preparando_disparo = false
		_tiempo_carga = 0.0
		if luz_alerta:
			luz_alerta.light_energy = 0.5
		return

	# Orientar la cabeza hacia el jugador (en el plano de su "up" local)
	if cabeza_nodo:
		var dir_jugador := (player.global_position + Vector3.UP * 0.8 - cabeza_nodo.global_position).normalized()
		var up_local := global_transform.basis.y
		var fwd := dir_jugador.slide(up_local).normalized()
		if fwd.length_squared() > 0.01:
			var right := up_local.cross(fwd).normalized()
			cabeza_nodo.global_basis = Basis(right, up_local, fwd)

	# 3. Ciclo de disparo
	_tiempo_recarga += delta
	if not _preparando_disparo:
		if _tiempo_recarga >= intervalo_disparo:
			_preparando_disparo = true
			_tiempo_carga = 0.0
	else:
		_tiempo_carga += delta
		# Parpadeo de carga
		var pulso := sin(_tiempo_carga * 12.0)
		if luz_alerta:
			luz_alerta.light_energy = 2.0 + pulso * 1.5
			luz_alerta.light_color = Color(1.0, 0.2, 0.1)
		if bulbo_mesh:
			bulbo_mesh.scale = Vector3.ONE * (1.0 + _tiempo_carga * 0.35)

		if _tiempo_carga >= 0.8:
			_disparar(player)
			_preparando_disparo = false
			_tiempo_recarga = 0.0
			_tiempo_carga = 0.0
			if bulbo_mesh:
				bulbo_mesh.scale = Vector3.ONE


func _disparar(player: Node3D) -> void:
	var origen: Vector3 = boca_nodo.global_position if boca_nodo else global_position + global_transform.basis.y * 1.8
	var target: Vector3 = player.global_position + Vector3.UP * 0.8
	var dir := (target - origen).normalized()

	var proy: Area3D = PROYECTIL_SCENE.instantiate() as Area3D
	if proy:
		proy.set("direccion", dir)
		get_tree().current_scene.add_child(proy)
		proy.global_position = origen

	AudioJuego.reproducir_excavar()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("mostrar_notificacion"):
		hud.mostrar_notificacion("¡Espina disparada por flora hostil!")


func recibir_excavacion(pos_excavacion: Vector3, radio_excavacion: float) -> void:
	if _neutralizada:
		return
	if global_position.distance_to(pos_excavacion) <= radio_excavacion + 2.0:
		_neutralizar()


func neutralizar() -> void:
	_neutralizar()


func _neutralizar() -> void:
	if _neutralizada:
		return
	_neutralizada = true

	# Suelta recompensa valiosa de investigación
	var muestra := RECOMPENSA_SCENE.instantiate()
	muestra.set("bytes_valor", bytes_recompensa)
	muestra.set("freeze", true)
	get_tree().current_scene.add_child(muestra)
	muestra.global_position = global_position + global_transform.basis.y * 0.8

	AudioJuego.reproducir_recoger()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("mostrar_notificacion"):
		hud.mostrar_notificacion("¡Catapulta de espinas desenterrada! (+%d Bytes)" % bytes_recompensa)

	queue_free()
