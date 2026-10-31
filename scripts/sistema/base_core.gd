extends Node

# Pool de energía de la base (F3). Los módulos (fundición, cámara) consumen de
# aquí; las fuentes (cápsula, paneles solares) la recargan.
# v1: pool único global — redes por plataforma en F4+.

signal bateria_changed(value: float, max_value: float)

@export var bateria_max := 50.0

var bateria := 50.0
var _fuentes: Array = []  # [{ "node": Node, "rate": float, "solo_dia": bool }]


func registrar_fuente(node: Node, rate: float, solo_dia: bool) -> void:
	for f in _fuentes:
		if f["node"] == node:
			f["rate"] = rate
			return
	_fuentes.append({"node": node, "rate": rate, "solo_dia": solo_dia})


func desregistrar(node: Node) -> void:
	for i in range(_fuentes.size() - 1, -1, -1):
		if _fuentes[i]["node"] == node:
			_fuentes.remove_at(i)


func fuente_count() -> int:
	return _fuentes.size()


func _process(delta: float) -> void:
	var rate := 0.0
	var dn := get_tree().get_first_node_in_group("day_night")
	var es_dia: bool = dn == null or dn.is_day()
	for f in _fuentes:
		if not is_instance_valid(f["node"]):
			continue
		if f["solo_dia"] and not es_dia:
			continue
		rate += f["rate"]
	_set_bateria(bateria + rate * delta)


## Los módulos llaman esto cada frame mientras trabajan.
func consumir(cantidad: float) -> bool:
	if bateria < cantidad:
		return false
	_set_bateria(bateria - cantidad)
	return true


func _set_bateria(v: float) -> void:
	var nv := clampf(v, 0.0, bateria_max)
	if nv == bateria:
		return
	bateria = nv
	bateria_changed.emit(bateria, bateria_max)
