extends Node

# Aplica una partida guardada al arrancar la escena (Global.slot_a_cargar).
# La db del terreno del slot se asigna ANTES de que el terreno genere.
# Muestra la pantalla de carga y congela al player hasta que exista terreno
# bajo sus pies (sin esto, el player atraviesa el planeta sin generar).
# Debe ser el ULTIMO nodo hijo de la escena de juego.

const Guardado := preload("res://scripts/sistema/guardado.gd")

const ESCENAS := {
	"tether":            "res://escenas/planeta/tether.tscn",
	"panel_solar":       "res://escenas/planeta/panel_solar.tscn",
	"rover":             "res://escenas/vehiculo/rover.tscn",
	"centrifugadora":    "res://escenas/planeta/centrifugadora.tscn",
	"impresora_pequena": "res://escenas/planeta/impresora_pequena.tscn",
	"impresora_mediana": "res://escenas/planeta/impresora_mediana.tscn",
	"impresora_grande":  "res://escenas/planeta/impresora_grande.tscn",
}


func _ready() -> void:
	var slot := Global.slot_a_cargar
	Global.slot_a_cargar = -1
	if slot < 0:
		return
	var datos := Guardado.leer(slot)
	if datos.is_empty():
		push_warning("GameState: slot %d vacio" % slot)
		return

	var loading := get_node_or_null("/root/Loading")
	if loading:
		loading.show_message("Cargando planeta...")

	# Dbs de terreno por planeta (antes de que generen) y seed
	Global.slot_actual = slot
	for planeta in get_tree().get_nodes_in_group("cuerpos"):
		planeta.asignar_db(Guardado.ruta_db_planeta(slot, planeta.planeta_id))
	Global.world_seed = int(datos.get("seed", Global.world_seed))

	# Dar un par de frames a que toda la escena este lista y aplicar
	await get_tree().process_frame
	await get_tree().process_frame
	_aplicar(datos)
	await _esperar_terreno()
	# Los colocados van DESPUES de la espera: si no, el rover cae por terreno
	# sin generar o nace dentro del LOD grueso (suspension comprimida 20-30 s)
	_colocar_guardados(datos)

	if loading:
		loading.hide_screen()
	print("GameState: slot %d aplicado" % slot)


func _esperar_terreno() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	var space_state := player.get_world_3d().direct_space_state
	var t := 0.0
	while t < 25.0:
		var up: Vector3 = player.global_position.normalized()
		if up.length_squared() < 0.5:
			up = Vector3.UP
		var from := player.global_position + up * 2.0
		var query := PhysicsRayQueryParameters3D.create(from, player.global_position - up * 10.0)
		query.exclude = [player.get_rid()]
		var hit := space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider != player:
			break
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	if t >= 25.0:
		push_warning("GameState: el terreno no aparecio en 25 s; se libera al player igualmente")
	player.set_physics_process(true)


func _aplicar(datos: Dictionary) -> void:
	var player := get_tree().get_first_node_in_group("player")
	var pd: Dictionary = datos.get("player", {})
	if player and not pd.is_empty():
		var pos: Array = pd.get("pos", [])
		if pos.size() == 3:
			player.global_position = Vector3(pos[0], pos[1], pos[2])
			player.velocity = Vector3.ZERO
		var s = player.stats
		s.oxygen_max = float(pd.get("o2max", 100.0))
		s.power_max  = float(pd.get("pwmax", 100.0))
		s.oxygen     = float(pd.get("o2", s.oxygen_max))
		s.power      = float(pd.get("pw", s.power_max))
		player.placeables.clear()
		var pl: Dictionary = pd.get("placeables", {})
		for k in pl:
			player.placeables[k] = int(pl[k])

	var cat := get_tree().get_first_node_in_group("catalogo")
	var cd: Dictionary = datos.get("catalogo", {})
	if cat:
		cat.bytes = int(cd.get("bytes", 0))
		cat.desbloqueadas.clear()
		for d in cd.get("desbloqueadas", ["tethers"]):
			cat.desbloqueadas.append(String(d))


func _colocar_guardados(datos: Dictionary) -> void:
	for c in datos.get("colocados", []):
		var tipo: String = c.get("tipo", "")
		if not ESCENAS.has(tipo):
			continue
		var obj = load(ESCENAS[tipo]).instantiate()
		obj.set_meta("tipo", tipo)
		obj.add_to_group("colocados")
		get_tree().current_scene.add_child(obj)
		var p: Array = c.get("pos", [])
		if p.size() == 3:
			var pos := Vector3(p[0], p[1], p[2])
			if tipo == "rover":
				pos += pos.normalized() * 2.0
			obj.global_position = pos
		var r: Array = c.get("rot", [])
		if r.size() == 3:
			obj.global_rotation = Vector3(r[0], r[1], r[2])
