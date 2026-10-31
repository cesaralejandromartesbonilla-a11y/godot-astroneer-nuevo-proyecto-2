extends ModuloBase

# Cámara de investigación (F3): piedra de investigación en el slot →
# bytes para el catálogo (consume energía de la base mientras analiza).

@export var duracion := 25.0
@export var consumo := 2.0

var _progreso := 0.0

@onready var slot: Area3D = $Slot
@onready var barra: MeshInstance3D = $Barra


func _process(delta: float) -> void:
	var item = slot.stored_item
	if item == null:
		_progreso = 0.0
		_upd_barra()
		return

	var valor: int = item.get("bytes_valor")
	if valor <= 0:
		_upd_barra()
		return

	var base := get_tree().get_first_node_in_group("base_core")
	if base == null or not base.consumir(consumo * delta):
		_upd_barra()
		return

	_progreso += delta / duracion
	if _progreso >= 1.0:
		_progreso = 0.0
		slot.stored_item = null
		item.queue_free()
		var cat := get_tree().get_first_node_in_group("catalogo")
		if cat:
			cat.sumar_bytes(valor)
	_upd_barra()


func _upd_barra() -> void:
	barra.scale.x = maxf(0.01, _progreso)
