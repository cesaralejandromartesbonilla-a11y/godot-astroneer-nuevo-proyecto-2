extends RigidBody3D

# Almacenamiento Mediano (Tier 2):
# Estructura en bastidor plegable que ofrece 8 ranuras para recursos o items pequeños.
# Puede acoplarse en cualquier slot de plataforma o colocarse en el suelo.

var recurso_id := 0

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
		scale = Vector3(1.08, 1.08, 1.08)
	else:
		scale = Vector3(1.0, 1.0, 1.0)
