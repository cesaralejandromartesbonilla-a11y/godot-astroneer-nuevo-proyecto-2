extends RigidBody3D

# Identidad del recurso (F3): lo asigna quien lo spawnea (minado, fundición).
# 0 = item genérico sin receta asociada.
var recurso_id: int = 0

# Sistema de trazas (F9): cada fragmento minado tiene un relleno parcial (0.0-1.0).
# El slot acumula trazas del mismo tipo hasta completar 1.0 (= recurso listo para usar).
var relleno: float = 0.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D


func set_physics_state(active: bool) -> void:
	if active:
		freeze = false
		collision_layer = 1
	else:
		freeze = true
		collision_layer = 0


func set_highlight(active: bool) -> void:
	if active:
		mesh_instance.scale = Vector3(1.15, 1.15, 1.15)
	else:
		actualizar_visual_relleno()


## Actualiza la escala de la esfera según el relleno actual (0.3 = traza mínima, 1.0 = completo).
func actualizar_visual_relleno() -> void:
	var t: float = clampf(relleno, 0.0, 1.0)
	var escala: float = lerpf(0.30, 1.0, t)
	mesh_instance.scale = Vector3(escala, escala, escala)


## Devuelve true si el recurso está completo y listo para usarse en fabricación.
func esta_completo() -> bool:
	return relleno >= 1.0
