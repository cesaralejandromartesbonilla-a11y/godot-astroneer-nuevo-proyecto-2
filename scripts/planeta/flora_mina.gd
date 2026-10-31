class_name FloraMina
extends Node3D

# FloraMina (Fase 8):
# Bulbo volátil alienígena / Mina biológica (Popping Pod).
# Crece a ras de suelo en cavernas o valles.
# Al acercarse el jugador (<3.8m), activa una secuencia de sobrecarga con
# parpadeo carmesí de 1.4s antes de detonar violentamente.
# Si el jugador excava sus raíces a tiempo con la Terrain Tool, se neutraliza
# de forma segura y otorga una muestra de alto valor (+500 Bytes).

const RECOMPENSA_SCENE := preload("res://escenas/planeta/piedra_investigacion.tscn")

@export var radio_activacion: float = 3.8
@export var tiempo_detonacion: float = 1.4
@export var bytes_recompensa: int = 500

var _neutralizada: bool = false
var _detonada: bool = false
var _armada: bool = false
var _tiempo_cuenta: float = 0.0
var _suelo_confirmado: bool = false
var _tiempo_vida: float = 0.0

@onready var bulbo_mesh: MeshInstance3D = get_node_or_null("BulboMina")
@onready var luz_mina: OmniLight3D = get_node_or_null("LuzMina")
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
	_mat_bulbo.albedo_color = Color(0.85, 0.2, 0.1)
	_mat_bulbo.roughness = 0.3
	_mat_bulbo.emission_enabled = true
	_mat_bulbo.emission = Color(0.9, 0.1, 0.1)
	_mat_bulbo.emission_energy_multiplier = 1.0
	if bulbo_mesh:
		bulbo_mesh.material_override = _mat_bulbo


func _physics_process(delta: float) -> void:
	if _neutralizada or _detonada:
		return

	_tiempo_vida += delta

	# 1. Comprobación de raíces (desentierro desactiva la mina)
	if raycast_suelo:
		if not _suelo_confirmado:
			if raycast_suelo.is_colliding():
				_suelo_confirmado = true
		else:
			if _tiempo_vida > 0.5 and not raycast_suelo.is_colliding():
				_neutralizar()
				return

	# 2. Detección de proximidad del jugador
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	var dist := global_position.distance_to(player.global_position)

	if not _armada:
		if dist <= radio_activacion:
			_armar_mina()
	else:
		_tiempo_cuenta += delta
		# Parpadeo acelerado
		var freq := 6.0 + (_tiempo_cuenta / tiempo_detonacion) * 16.0
		var pulso := sin(_tiempo_cuenta * freq)
		var factor_alerta := _tiempo_cuenta / tiempo_detonacion

		if bulbo_mesh:
			var esc := 1.0 + factor_alerta * 0.45 + pulso * 0.15
			bulbo_mesh.scale = Vector3.ONE * esc

		if luz_mina:
			luz_mina.light_energy = 1.5 + pulso * 1.5 + factor_alerta * 2.5
			luz_mina.light_color = Color(1.0, 0.05, 0.05)

		# Si el jugador se aleja a más de 5.5m antes de llegar a la mitad del tiempo, se desactiva la cuenta
		if dist > radio_activacion + 2.0 and factor_alerta < 0.5:
			_desarmar_mina()
			return

		if _tiempo_cuenta >= tiempo_detonacion:
			_detonar(player)


func _armar_mina() -> void:
	_armada = true
	_tiempo_cuenta = 0.0
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("mostrar_notificacion"):
		hud.mostrar_notificacion("¡SOBRECARGA INESTABLE! Aléjate del bulbo volátil")


func _desarmar_mina() -> void:
	_armada = false
	_tiempo_cuenta = 0.0
	if bulbo_mesh:
		bulbo_mesh.scale = Vector3.ONE
	if luz_mina:
		luz_mina.light_energy = 0.8
		luz_mina.light_color = Color(0.9, 0.2, 0.1)


func _detonar(player: Node3D) -> void:
	_detonada = true

	# Impacto de choque radial
	var dist := global_position.distance_to(player.global_position)
	if dist < 7.0:
		if "stats" in player and player.stats != null:
			player.stats.consume_oxygen(32.0, 1.0)
		if "velocity" in player:
			var dir := (player.global_position - global_position).normalized()
			if dir.length_squared() < 0.01:
				dir = global_transform.basis.y
			player.velocity += dir * 14.0

	AudioJuego.reproducir_excavar()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("mostrar_notificacion"):
		hud.mostrar_notificacion("¡DETONACION DE BULBO VOLATIL!")

	queue_free()


func recibir_excavacion(pos_excavacion: Vector3, radio_excavacion: float) -> void:
	if _neutralizada or _detonada:
		return
	if global_position.distance_to(pos_excavacion) <= radio_excavacion + 2.0:
		_neutralizar()


func neutralizar() -> void:
	_neutralizar()


func _neutralizar() -> void:
	if _neutralizada or _detonada:
		return
	_neutralizada = true

	# Suelta recompensa valiosa intacta
	var muestra := RECOMPENSA_SCENE.instantiate()
	muestra.set("bytes_valor", bytes_recompensa)
	muestra.set("freeze", true)
	get_tree().current_scene.add_child(muestra)
	muestra.global_position = global_position + global_transform.basis.y * 0.5

	AudioJuego.reproducir_recoger()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("mostrar_notificacion"):
		hud.mostrar_notificacion("¡Bulbo volátil desactivado! Muestra preservada (+%d Bytes)" % bytes_recompensa)

	queue_free()
