extends Node

# Red de oxígeno inteligente (Astroneer style):
# Fuentes primarias = Cápsula, Rovers, Lanzadera (generan O2 infinito).
# Repetidores = Tethers (solo transmiten O2 si están encadenados a una fuente primaria a <= 12m).
# Conecta cables visuales de luz entre tethers y filamento vital hacia la mochila del jugador.

const TETHER_LINK_MAX_DIST := 12.0
const TETHER_O2_RADIUS := 10.0

var _primary_sources: Array[Dictionary] = [] # [{ "node": Node3D, "radius": float }]
var _tethers: Array[Node3D] = []
var _recalc_timer := 0.0


func register_source(node: Node3D, radius: float) -> void:
	if not is_instance_valid(node):
		return
	if node.is_in_group("tethers") or node.has_method("es_tether"):
		if not _tethers.has(node):
			_tethers.append(node)
	else:
		for s in _primary_sources:
			if s["node"] == node:
				s["radius"] = radius
				recalcular_red()
				return
		_primary_sources.append({"node": node, "radius": radius})
	recalcular_red()


func unregister_source(node: Node3D) -> void:
	_tethers.erase(node)
	for i in range(_primary_sources.size() - 1, -1, -1):
		if _primary_sources[i]["node"] == node:
			_primary_sources.remove_at(i)
	recalcular_red()


func _process(delta: float) -> void:
	_recalc_timer += delta
	if _recalc_timer >= 0.4:
		_recalc_timer = 0.0
		recalcular_red()


## Recorre la red con BFS partiendo de las fuentes primarias para energizar tethers
func recalcular_red() -> void:
	for i in range(_primary_sources.size() - 1, -1, -1):
		if not is_instance_valid(_primary_sources[i]["node"]):
			_primary_sources.remove_at(i)
	for i in range(_tethers.size() - 1, -1, -1):
		if not is_instance_valid(_tethers[i]):
			_tethers.remove_at(i)

	var visitados := {}
	var queue: Array[Node3D] = []

	for s in _primary_sources:
		var n: Node3D = s["node"]
		visitados[n] = true
		queue.append(n)

	while queue.size() > 0:
		var actual = queue.pop_front()
		var p_actual: Vector3 = _get_emission_point(actual)

		for t in _tethers:
			if not visitados.has(t):
				var p_t: Vector3 = _get_emission_point(t)
				if p_actual.distance_to(p_t) <= TETHER_LINK_MAX_DIST:
					visitados[t] = true
					queue.append(t)
					if t.has_method("actualizar_conexion"):
						t.actualizar_conexion(true, actual)

	for t in _tethers:
		if not visitados.has(t):
			if t.has_method("actualizar_conexion"):
				t.actualizar_conexion(false, null)


func is_oxygenated(pos: Vector3) -> bool:
	for s in _primary_sources:
		var n: Node3D = s["node"]
		if is_instance_valid(n) and pos.distance_to(n.global_position) <= s["radius"]:
			return true
	for t in _tethers:
		if is_instance_valid(t) and t.get("esta_conectado") == true:
			var rad: float = t.get("O2_RADIUS") if t.get("O2_RADIUS") != null else TETHER_O2_RADIUS
			if pos.distance_to(t.global_position) <= rad:
				return true
	return false


## Encuentra el emisor activo más cercano a pos a menos de max_dist (para el cable del astronauta)
func get_closest_oxygen_emitter(pos: Vector3, max_dist: float = 10.0) -> Dictionary:
	var mejor_nodo: Node3D = null
	var mejor_punto := Vector3.ZERO
	var dist_min := max_dist

	for s in _primary_sources:
		var n: Node3D = s["node"]
		if is_instance_valid(n):
			var pt = _get_emission_point(n)
			var d = pos.distance_to(pt)
			if d < dist_min:
				dist_min = d
				mejor_nodo = n
				mejor_punto = pt

	for t in _tethers:
		if is_instance_valid(t) and t.get("esta_conectado") == true:
			var pt = _get_emission_point(t)
			var d = pos.distance_to(pt)
			if d < dist_min:
				dist_min = d
				mejor_nodo = t
				mejor_punto = pt

	if mejor_nodo != null:
		return {"nodo": mejor_nodo, "punto": mejor_punto, "dist": dist_min}
	return {}


func _get_emission_point(node: Node3D) -> Vector3:
	if not is_instance_valid(node):
		return Vector3.ZERO
	if node.has_node("Bombilla"):
		return node.get_node("Bombilla").global_position
	if node.has_node("Marker3D"):
		return node.get_node("Marker3D").global_position
	return node.global_position + node.global_transform.basis.y * 1.5


func source_count() -> int:
	var count := _primary_sources.size()
	for t in _tethers:
		if is_instance_valid(t) and t.get("esta_conectado") == true:
			count += 1
	return count
