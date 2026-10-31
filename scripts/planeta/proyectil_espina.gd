class_name ProyectilEspina
extends Area3D

# ProyectilEspina (Fase 8):
# Proyectil biológico disparado por la Flora Spitter.
# Vuela en línea recta hacia la dirección objetivo y drena oxígeno al impactar.

@export var velocidad: float = 16.0
@export var dano_oxigeno: float = 22.0
@export var tiempo_vida_max: float = 3.5

var direccion: Vector3 = Vector3.FORWARD
var _tiempo_vida: float = 0.0


func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_tiempo_vida += delta
	if _tiempo_vida >= tiempo_vida_max:
		queue_free()
		return

	global_position += direccion * (velocidad * delta)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if "stats" in body and body.stats != null:
			body.stats.consume_oxygen(dano_oxigeno, 1.0)
		if "velocity" in body:
			body.velocity += direccion * 5.0
		AudioJuego.reproducir_excavar()
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("mostrar_notificacion"):
			hud.mostrar_notificacion("¡IMPACTO DE ESPINA! Oxígeno comprometido")
		queue_free()
	elif not body.is_in_group("flora_peligrosa") and not body.is_in_group("arboles"):
		# Chocó contra el terreno o una roca
		queue_free()
