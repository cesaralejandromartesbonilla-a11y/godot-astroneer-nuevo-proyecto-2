class_name ArbolAlienigena
extends Node3D

# ArbolAlienigena (Fase 8):
# Clase base para toda vegetación arbórea alienígena.
# Cada planeta tiene su propio árbol derivado con apariencia procedural propia.
# El árbol se ancla al terreno, verifica el suelo durante el meshing
# y, al ser derribado (la Terrain Tool excava sus raíces), suelta Materia Orgánica.

const ORGANICO_SCENE := preload("res://escenas/planeta/ore_organico.tscn")

@export var drop_organico: bool = true

var _derribado: bool = false
var _suelo_confirmado: bool = false
var _tiempo_vida: float = 0.0

@onready var raycast_suelo: RayCast3D = get_node_or_null("RayCastSuelo")


func _ready() -> void:
	add_to_group("arboles")
	_crear_materiales()
	if raycast_suelo:
		raycast_suelo.collision_mask = 1
		raycast_suelo.enabled = true
		# Rayo corto directo bajo la base (0.6m) para detectar pérdida de soporte inmediata
		raycast_suelo.position = Vector3(0.0, 0.2, 0.0)
		raycast_suelo.target_position = Vector3(0.0, -0.7, 0.0)
		for c in find_children("*", "CollisionObject3D", true, false):
			raycast_suelo.add_exception(c)


func _crear_materiales() -> void:
	pass


func _physics_process(delta: float) -> void:
	if _derribado:
		return

	_tiempo_vida += delta

	# 1. Confirmar suelo cuando el meshing del terreno voxel esté listo
	if raycast_suelo:
		if not _suelo_confirmado:
			if raycast_suelo.is_colliding():
				_suelo_confirmado = true
		else:
			# Detección de pérdida de suelo: tras confirmarse el suelo inicial y pasar 0.5s,
			# si se excava el suelo bajo las raíces, el raycast deja de colisionar
			if _tiempo_vida > 0.5 and not raycast_suelo.is_colliding():
				_derribar()


## Notificación directa desde la Terrain Tool o herramientas de excavación
func recibir_excavacion(pos_excavacion: Vector3, radio_excavacion: float) -> void:
	if _derribado:
		return
	var dist := global_position.distance_to(pos_excavacion)
	if dist <= radio_excavacion + 2.5:
		_derribar()


func derribar() -> void:
	_derribar()


func _derribar() -> void:
	if _derribado:
		return
	_derribado = true

	# Desactivar colisiones de inmediato para evitar bloqueos físicos
	for c in find_children("*", "CollisionShape3D", true, false):
		if c is CollisionShape3D:
			c.set_deferred("disabled", true)

	# Soltar 1 a 2 muestras de Materia Orgánica (recurso id 24) con impulso físico diegético
	if drop_organico:
		var cantidad := randi_range(1, 2)
		for _i in cantidad:
			var muestra: RigidBody3D = ORGANICO_SCENE.instantiate() as RigidBody3D
			if muestra:
				muestra.recurso_id = 24
				get_tree().current_scene.add_child(muestra)
				var dispersion := Vector3(randf_range(-0.5, 0.5), randf_range(0.3, 0.9), randf_range(-0.5, 0.5))
				muestra.global_position = global_position + global_transform.basis.y * 1.2 + dispersion
				if muestra.has_method("set_physics_state"):
					muestra.set_physics_state(true)
				var dir_impulso: Vector3 = (global_transform.basis.y * 2.2 + dispersion.normalized() * 1.5).normalized()
				muestra.apply_central_impulse(dir_impulso * randf_range(2.5, 4.5))

	AudioJuego.reproducir_recoger()

	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("mostrar_notificacion"):
		hud.mostrar_notificacion("Materia Orgánica recolectada (+Árbol derribado)")

	# Pequeña contracción elástica antes de desaparecer
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.finished.connect(queue_free)
