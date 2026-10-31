extends CanvasLayer

# Menú de fabricación (F3), tecla F. Lista las recetas con su coste;
# fabricar consume materiales de la mochila y (la primera vez) bytes.

@export var recetas: Array[RecetaData] = []
@export var recursos: Array[RecursoData] = []  # para nombres en los costes

@onready var panel: PanelContainer = $Panel
@onready var filas: VBoxContainer = $Panel/VBox/Filas

var _player: Node3D


func _ready() -> void:
	visible = false


func _unhandled_input(_event: InputEvent) -> void:
	# Desactivado: el catálogo de investigación ahora es diegético en la mochila (CatalogoHolo)
	pass


func _nombre_recurso(rid: int) -> String:
	for r in recursos:
		if r.id == rid:
			return r.nombre
	return "Recurso %d" % rid


func _rebuild() -> void:
	_player = get_tree().get_first_node_in_group("player")
	for c in filas.get_children():
		c.queue_free()
	var cat := get_tree().get_first_node_in_group("catalogo")
	if _player == null or cat == null:
		return
	for receta in recetas:
		var btn := Button.new()
		btn.text = _texto(receta, cat)
		btn.disabled = not _puede(receta, cat)
		btn.pressed.connect(_fabricar.bind(receta))
		filas.add_child(btn)


func _texto(receta: RecetaData, cat: Node) -> String:
	var partes: Array[String] = []
	var inv: Dictionary = _player.contar_items()
	for rid in receta.inputs:
		var need: int = receta.inputs[rid]
		var tiene: int = inv.get(rid, 0)
		partes.append("%s %d/%d" % [_nombre_recurso(rid), tiene, need])
	var txt := "%s — %s" % [receta.nombre, ", ".join(partes)]
	if not cat.esta_desbloqueada(receta.id):
		txt += " — 🔒 %d bytes (tienes %d)" % [receta.coste_bytes, cat.bytes]
	return txt


func _puede(receta: RecetaData, cat: Node) -> bool:
	if not cat.esta_desbloqueada(receta.id) and cat.bytes < receta.coste_bytes:
		return false
	var inv: Dictionary = _player.contar_items()
	for rid in receta.inputs:
		if inv.get(rid, 0) < int(receta.inputs[rid]):
			return false
	return true


func _fabricar(receta: RecetaData) -> void:
	var cat := get_tree().get_first_node_in_group("catalogo")
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if cat == null or _player == null:
		return
	# 1. materiales (comprobar y consumir)
	var inv: Dictionary = _player.contar_items()
	for rid in receta.inputs:
		if inv.get(rid, 0) < int(receta.inputs[rid]):
			print("Faltan materiales para %s" % receta.nombre)
			return
	for rid in receta.inputs:
		_player.quitar_items(rid, int(receta.inputs[rid]))
	# 2. desbloqueo (gasta bytes solo la primera vez)
	if not cat.intentar_desbloquear(receta.id, receta.coste_bytes):
		print("Bytes insuficientes para %s" % receta.nombre)
		return
	# 3. entrega
	if receta.colocable != "":
		_player.placeables[receta.colocable] = _player.placeables.get(receta.colocable, 0) + receta.salida_cantidad
		print("Fabricado: %s (colocar con %s)" % [receta.nombre, "T" if receta.colocable == "tether" else "P"])
	if receta.mejora_o2_max > 0:
		_player.stats.mejorar_o2_max(receta.mejora_o2_max)
		print("Fabricado: %s" % receta.nombre)
	if receta.mejora_power_max > 0:
		_player.stats.mejorar_power_max(receta.mejora_power_max)
		print("Fabricado: %s" % receta.nombre)
	_rebuild()
