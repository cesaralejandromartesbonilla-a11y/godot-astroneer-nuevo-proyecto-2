extends ModuloBase

# Fundición (F3): mena del slot de entrada → lingote en el slot de salida.
# Consume energía de BaseCore mientras trabaja (2/s durante duracion s).

const LINGOTES := {
	2: {"id": 12, "escena": preload("res://escenas/planeta/ingot_copper.tscn")},
	3: {"id": 13, "escena": preload("res://escenas/planeta/ingot_iron.tscn")},
	4: {"id": 14, "escena": preload("res://escenas/planeta/ingot_litio.tscn")},
}

@export var duracion := 20.0
@export var consumo := 2.0

var _progreso := 0.0

@onready var entrada: Area3D = $Entrada
@onready var salida: Area3D = $Salida
@onready var barra: MeshInstance3D = $Barra


func _process(delta: float) -> void:
	var mena = entrada.stored_item
	if mena == null or salida.stored_item != null:
		_progreso = maxf(0.0, _progreso - delta * 0.5)
		_upd_barra()
		return

	var info = LINGOTES.get(mena.get("recurso_id"))
	if info == null:
		_upd_barra()
		return

	var base := get_tree().get_first_node_in_group("base_core")
	if base == null or not base.consumir(consumo * delta):
		_upd_barra()
		return

	_progreso += delta / duracion
	if _progreso >= 1.0:
		_progreso = 0.0
		entrada.stored_item = null
		mena.queue_free()
		var lingote: RigidBody3D = info["escena"].instantiate()
		lingote.recurso_id = info["id"]
		get_tree().current_scene.add_child(lingote)
		lingote.set_physics_state(false)
		salida.equip_item(lingote)
	_upd_barra()


func _upd_barra() -> void:
	barra.scale.x = maxf(0.01, _progreso)
