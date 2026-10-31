class_name SistemaTormentas
extends Node

# SistemaTormentas (Fase 7):
# Controla eventos meteorológicos dinámicos en el planeta.
# Ciclo: calma (60 s) -> tormenta activa (40 s).
# Durante la tormenta, genera ráfagas de viento tangenciales que empujan
# al jugador y activan partículas de polvo y vendaval.

const PART_VIENTO_SCENE := preload("res://escenas/efectos/tormenta_viento.tscn")

@export var habilitado: bool = true
@export var periodo_calma: float = 60.0
@export var duracion_tormenta: float = 40.0
@export var fuerza_viento: float = 2.0

var tormenta_activa: bool = false
var _tiempo_estado: float = 0.0
var _planeta: Node3D = null
var _particulas: GPUParticles3D = null
var _dir_viento_tangente: Vector3 = Vector3.RIGHT


func _ready() -> void:
	_planeta = get_parent() as Node3D
	_tiempo_estado = randf_range(5.0, 15.0) # Primera tormenta en 5-15 s
	_particulas = PART_VIENTO_SCENE.instantiate()
	_particulas.emitting = false
	add_child(_particulas)


func _physics_process(delta: float) -> void:
	if not habilitado or _planeta == null:
		return

	_tiempo_estado += delta

	if not tormenta_activa:
		if _tiempo_estado >= periodo_calma:
			_iniciar_tormenta()
	else:
		_actualizar_tormenta(delta)
		if _tiempo_estado >= duracion_tormenta:
			_finalizar_tormenta()


func _iniciar_tormenta() -> void:
	tormenta_activa = true
	_tiempo_estado = 0.0

	var player = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	var dist := _planeta.global_position.distance_to(player.global_position)
	var radio: float = _planeta.get("radio") if "radio" in _planeta else 250.0

	# Solo alertar si el jugador está en este planeta
	if dist <= radio * 1.5:
		_particulas.emitting = true
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("mostrar_notificacion"):
			hud.mostrar_notificacion("¡ALERTA METEOROLOGICA! Tormenta de arena en curso")
		AudioJuego.reproducir_excavar()


func _actualizar_tormenta(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	var dist := _planeta.global_position.distance_to(player.global_position)
	var radio: float = _planeta.get("radio") if "radio" in _planeta else 250.0

	if dist > radio * 1.5:
		if _particulas.emitting:
			_particulas.emitting = false
		return

	if not _particulas.emitting:
		_particulas.emitting = true

	# Mantener partículas centradas en el jugador
	_particulas.global_position = player.global_position + Vector3(0, 2.0, 0)

	# Calcular dirección tangente a la esfera planetaria
	var up: Vector3 = (player.global_position - _planeta.global_position).normalized()
	var tangente: Vector3 = up.cross(Vector3.UP)
	if tangente.length_squared() < 0.01:
		tangente = up.cross(Vector3.FORWARD)
	tangente = tangente.normalized()

	# Modulación de ráfagas (oscilación lenta y suave, no intermitente violenta)
	var rafaga: float = 1.0 + sin(Time.get_ticks_msec() * 0.0003) * 0.20
	var empuje: Vector3 = tangente * (fuerza_viento * rafaga)

	# Orientar partículas hacia el viento
	_particulas.look_at(_particulas.global_position + tangente, up)

	# Aplicar empuje al jugador si está en este planeta
	var dist_al_planeta := _planeta.global_position.distance_to(player.global_position)
	if dist_al_planeta <= radio * 1.2 and player.has_method("aplicar_fuerza_viento"):
		# Proyectar en el plano tangencial para que el viento nunca levante al jugador
		var empuje_tang: Vector3 = empuje - up * empuje.dot(up)
		player.aplicar_fuerza_viento(empuje_tang * delta)


func _finalizar_tormenta() -> void:
	tormenta_activa = false
	_tiempo_estado = 0.0
	if _particulas:
		_particulas.emitting = false

	var player = get_tree().get_first_node_in_group("player") as Node3D
	if player:
		var dist := _planeta.global_position.distance_to(player.global_position)
		var radio: float = _planeta.get("radio") if "radio" in _planeta else 250.0
		if dist <= radio * 1.5:
			var hud = get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("mostrar_notificacion"):
				hud.mostrar_notificacion("Tormenta disipada. Condiciones estables.")
