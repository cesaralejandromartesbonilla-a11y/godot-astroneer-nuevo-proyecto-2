extends Area3D

signal slot_clicked(slot_ref)

# Objeto almacenado en este slot (uno por slot; acumula relleno de trazas hasta 1.0).
var stored_item: Node3D = null
@onready var item_point: Marker3D = $ItemPoint
@onready var visual_mesh: MeshInstance3D = $MeshInstance3D

var color_idle := Color(0.2, 0.2, 0.2)
var color_hover := Color(1.0, 0.6, 0.0)


func _ready() -> void:
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color_idle
	visual_mesh.material_override = mat


func _on_mouse_entered() -> void:
	visual_mesh.material_override.albedo_color = color_hover


func _on_mouse_exited() -> void:
	visual_mesh.material_override.albedo_color = color_idle


func _on_input_event(_camera: Node, _event: InputEvent, _position: Vector3,
		_normal: Vector3, _shape_idx: int) -> void:
	if _event is InputEventMouseButton and _event.pressed \
			and _event.button_index == MOUSE_BUTTON_LEFT:
		slot_clicked.emit(self)


## Devuelve true si este slot puede absorber trazas del item entrante
## (mismo recurso_id y relleno actual < 1.0).
func puede_fusionar(item: Node3D) -> bool:
	if stored_item == null:
		return false
	var rid_stored: int = stored_item.get("recurso_id") if stored_item.get("recurso_id") != null else -1
	var rid_new: int = item.get("recurso_id") if item.get("recurso_id") != null else -2
	if rid_stored != rid_new or rid_stored <= 0:
		return false
	var relleno_actual: float = stored_item.get("relleno") if stored_item.get("relleno") != null else 1.0
	return relleno_actual < 1.0


## Fusiona las trazas del item entrante en el item almacenado.
## El excedente (relleno > 1.0 del fragmento) se pierde (la traza fue absorbida parcialmente).
## Destruye el nodo entrante tras la fusión.
func fusionar(item: Node3D) -> void:
	if stored_item == null or not puede_fusionar(item):
		return
	var relleno_actual: float = stored_item.get("relleno") if stored_item.get("relleno") != null else 0.0
	var relleno_nuevo: float = item.get("relleno") if item.get("relleno") != null else 0.0
	stored_item.set("relleno", minf(relleno_actual + relleno_nuevo, 1.0))
	if stored_item.has_method("actualizar_visual_relleno"):
		stored_item.actualizar_visual_relleno()
	item.queue_free()


## Coloca un item en el slot. Intenta fusionar trazas si es del mismo tipo y el slot no está completo.
## Devuelve true si el item fue colocado o fusionado, false si el slot está ocupado por otro tipo.
func equip_item(item: Node3D) -> bool:
	if stored_item != null:
		if puede_fusionar(item):
			fusionar(item)
			return true
		return false
	stored_item = item
	item.get_parent().remove_child(item)
	item_point.add_child(item)
	item.position = Vector3.ZERO
	item.rotation = Vector3.ZERO
	if item.has_method("set_physics_state"):
		item.set_physics_state(false)
	if item.has_method("actualizar_visual_relleno"):
		item.actualizar_visual_relleno()
	return true


## Saca el item del slot y lo devuelve suelto a la escena (con su relleno actual).
## Retorna null si el slot estaba vacío.
func remove_item() -> Node3D:
	if stored_item == null:
		return null
	var item := stored_item
	stored_item = null
	var root := get_tree().current_scene
	item.get_parent().remove_child(item)
	root.add_child(item)
	item.global_transform = item_point.global_transform
	if item.has_method("set_physics_state"):
		item.set_physics_state(true)
	if item.has_method("set_highlight"):
		item.set_highlight(false)
	return item
