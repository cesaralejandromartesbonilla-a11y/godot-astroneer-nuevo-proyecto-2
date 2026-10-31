extends Node3D

# Herramienta de terreno (Fase 2 de Mochila):
# Opera con 3 modos diegéticos coordinados con TerrainTool:
# - Modo 0: EXCAVAR -> Elimina voxels SDF, extrae minerales y acumula sedimento en Canister.
# - Modo 1: RELLENAR -> Añade voxels SDF consumiendo sedimento del Canister.
# - Modo 2: APLANAR  -> Muestrea la normal y plano tangente del clic inicial y nivela el terreno.
# Proyecta una retícula circular 3D adaptada a la normal del terreno.

@export var player_node: CharacterBody3D
@export var max_reach: float = 15.0

var brush_radius: float = 4.0
var drop_cooldown: float = 0.25
var _drop_timer: float = 0.0

# Relación volumétrica de sedimento:
# Para radio base 4.0, 1 esfera (~226 m³ de casquete) equivale a 10.0 unidades de sedimento (10% del canister de 100)
# El sedimento extraído o depositado es estrictamente proporcional al volumen esférico: V ∝ r³
const RADIO_BASE: float = 4.0
const SEDIMENTO_POR_ESFERA_BASE: float = 10.0
const SEDIMENTO_APLANAR_POR_SEGUNDO: float = 12.0

func _calcular_sedimento_por_radio(radio: float) -> float:
	return SEDIMENTO_POR_ESFERA_BASE * pow(radio / RADIO_BASE, 3.0)

const POLVO_SCENE := preload("res://escenas/efectos/polvo_excavacion.tscn")

# Variables para modo Aplanar (Flatten)
var _aplanar_activo: bool = false
var _aplanando: bool = false
var _plano_origen: Vector3 = Vector3.ZERO
var _plano_normal: Vector3 = Vector3.UP
var _terrain_ref: VoxelLodTerrain = null

# Reticula 3D proyectada en el suelo
var _reticula_mesh: MeshInstance3D = null
var _reticula_mat: StandardMaterial3D = null


func _ready() -> void:
	_crear_reticula()


func _emitir_polvo(pos: Vector3) -> void:
	var inst := POLVO_SCENE.instantiate()
	get_tree().current_scene.add_child(inst)
	inst.global_position = pos
	inst.emitting = true
	get_tree().create_timer(inst.lifetime + 0.1).timeout.connect(
		func(): if is_instance_valid(inst): inst.queue_free()
	)


func _crear_reticula() -> void:
	_reticula_mesh = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = brush_radius * 0.92
	torus.outer_radius = brush_radius
	torus.rings = 32
	torus.ring_segments = 16
	_reticula_mesh.mesh = torus

	_reticula_mat = StandardMaterial3D.new()
	_reticula_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_reticula_mat.albedo_color = Color(1.0, 0.45, 0.05, 0.8)
	_reticula_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_reticula_mesh.material_override = _reticula_mat
	_reticula_mesh.visible = false
	add_child(_reticula_mesh)


func _process(delta: float) -> void:
	if _drop_timer > 0.0:
		_drop_timer = max(_drop_timer - delta, 0.0)
	_actualizar_reticula()

	# Aplanar continuo: ejecutar cada frame mientras se mantiene presionado
	if _aplanando:
		var tool_active: bool = player_node != null and player_node.get("is_tool_active")
		if not tool_active:
			_aplanando = false
			_aplanar_activo = false
			return
		var t_tool = player_node.get("terrain_tool")
		var modo: int = t_tool.get("modo_actual") if t_tool else 0
		if modo == 2:
			_ejecutar_aplanar(delta)
		else:
			# Si el modo cambió mientras estaba presionado, cancelar
			_aplanando = false
			_aplanar_activo = false


func get_radio_efectivo() -> float:
	var t_tool: Node3D = player_node.get("terrain_tool") as Node3D if player_node else null
	var mult: float = t_tool.get_multiplicador_radio() if t_tool and t_tool.has_method("get_multiplicador_radio") else 1.0
	return brush_radius * mult


func _actualizar_reticula() -> void:
	if _reticula_mesh == null:
		return

	var tool_active: bool = player_node != null and player_node.get("is_tool_active")
	if not tool_active:
		_reticula_mesh.visible = false
		return

	var hit = _hacer_raycast_terreno()
	if hit.is_empty():
		_reticula_mesh.visible = false
		return

	_reticula_mesh.visible = true
	_reticula_mesh.global_position = hit.position + hit.normal * 0.05
	var escala_radio := get_radio_efectivo() / brush_radius
	_reticula_mesh.scale = Vector3(escala_radio, 1.0, escala_radio)

	# Alinear retícula perpendicular a la normal de la superficie
	var up = hit.normal
	var fwd = Vector3.FORWARD
	if abs(up.dot(fwd)) > 0.9:
		fwd = Vector3.RIGHT
	var right = up.cross(fwd).normalized()
	fwd = right.cross(up).normalized()
	_reticula_mesh.global_basis = Basis(right, up, fwd)

	# Sincronizar color de la retícula con el modo de TerrainTool
	var t_tool = player_node.get("terrain_tool")
	if t_tool and _reticula_mat:
		var modo: int = t_tool.get("modo_actual")
		match modo:
			0: _reticula_mat.albedo_color = Color(1.0, 0.45, 0.05, 0.85) # Naranja Excavar
			1: _reticula_mat.albedo_color = Color(0.2, 0.9, 0.25, 0.85)  # Verde Rellenar
			2: _reticula_mat.albedo_color = Color(0.15, 0.75, 1.0, 0.85) # Cian Aplanar


func _unhandled_input(event: InputEvent) -> void:
	if Global.ui_abierta > 0: return

	if event is InputEventMouseButton:
		var tool_active: bool = player_node != null and player_node.get("is_tool_active")
		if not tool_active: return

		if event.button_index == MOUSE_BUTTON_LEFT:
			var t_tool = player_node.get("terrain_tool")
			var modo: int = t_tool.get("modo_actual") if t_tool else 0

			if not event.pressed:
				# Soltar: siempre resetear el plano de aplanado
				_aplanando = false
				_aplanar_activo = false
				_terrain_ref = null
				return

			# ── Presionar ────────────────────────────────────────────────────
			if modo == 2:
				# APLANAR: activar estado "hold", el _process se encarga de ejecutar
				_aplanando = true
			else:
				# EXCAVAR / RELLENAR: click único (sin coste de energía en Aplanar)
				var stats = player_node.get("stats") if player_node else null
				if stats and not stats.consume_power(PlayerStats.DIG_COST):
					return
				match modo:
					0: _ejecutar_excavar()
					1: _ejecutar_rellenar()


func _hacer_raycast_terreno() -> Dictionary:
	var camera = get_viewport().get_camera_3d()
	if camera == null: return {}
	var mouse_pos = get_viewport().get_mouse_position()
	var origin = camera.project_ray_origin(mouse_pos)
	var dir = camera.project_ray_normal(mouse_pos)

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(origin, origin + dir * max_reach)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	if player_node:
		query.exclude = [player_node.get_rid()]
	var hit = space_state.intersect_ray(query)
	if hit.is_empty(): return {}
	var collider = hit.collider
	if collider == null or collider.is_in_group("items"): return {}
	return hit


# ─── MODO 0: EXCAVAR ──────────────────────────────────────────────────────────

func _ejecutar_excavar() -> void:
	var hit = _hacer_raycast_terreno()
	if hit.is_empty(): return
	var collider = hit.collider
	var hit_pos: Vector3 = hit.position
	var hit_normal: Vector3 = hit.normal
	var radio_actual := get_radio_efectivo()
	var target_pos = hit_pos - hit_normal * (radio_actual * 0.5)

	# Si el jugador apuntó directamente a un árbol o flora:
	var entidad_apuntada: Node = collider as Node
	while entidad_apuntada != null:
		if entidad_apuntada.is_in_group("arboles") or entidad_apuntada is ArbolAlienigena:
			if entidad_apuntada.has_method("derribar"):
				entidad_apuntada.derribar()
			elif entidad_apuntada.has_method("_derribar"):
				entidad_apuntada._derribar()
			break
		elif entidad_apuntada.is_in_group("flora_peligrosa"):
			if entidad_apuntada.has_method("neutralizar"):
				entidad_apuntada.neutralizar()
			elif entidad_apuntada.has_method("_neutralizar"):
				entidad_apuntada._neutralizar()
			break
		entidad_apuntada = entidad_apuntada.get_parent()

	_try_mine_ore(collider, hit_pos)
	_destruir_entidades_cercanas(target_pos, radio_actual)

	# Consumo de energía si se usa Augment de Impulso
	var t_tool: Node3D = player_node.get("terrain_tool") as Node3D
	if t_tool and t_tool.has_method("get_multiplicador_impulso"):
		var mult_imp: float = t_tool.get_multiplicador_impulso()
		if mult_imp > 1.0 and "stats" in player_node:
			player_node.stats.consume_power(2.0)

	# Aplicar modificación SDF de excavado resolviendo terreno de forma infalible
	var terrain: VoxelLodTerrain = _obtener_terreno_de(collider, hit_pos)
	if terrain == null: return
	var tool = terrain.get_voxel_tool()
	if tool == null: return
	tool.channel = VoxelBuffer.CHANNEL_SDF
	tool.mode = VoxelTool.MODE_REMOVE
	tool.do_sphere(terrain.to_local(target_pos), radio_actual)

	# Acumular tierra en el Canister proporcional al volumen extraído (V ∝ r³)
	if t_tool and t_tool.has_method("agregar_sedimento"):
		var sedimento_ganado: float = _calcular_sedimento_por_radio(radio_actual)
		t_tool.agregar_sedimento(sedimento_ganado)
	_emitir_polvo(hit_pos)
	AudioJuego.reproducir_excavar()


# ─── MODO 1: RELLENAR ─────────────────────────────────────────────────────────

func _ejecutar_rellenar() -> void:
	# Verificar si hay sedimento disponible en el Canister
	var t_tool: Node3D = player_node.get("terrain_tool") as Node3D
	if t_tool == null or not t_tool.has_method("consumir_sedimento"):
		return

	var sedimento_disponible: float = t_tool.get("sedimento") if "sedimento" in t_tool else 0.0
	if sedimento_disponible <= 0.1:
		return # Canister vacío: no se puede colocar tierra

	var hit = _hacer_raycast_terreno()
	if hit.is_empty(): return
	var collider = hit.collider
	var hit_pos: Vector3 = hit.position
	var hit_normal: Vector3 = hit.normal

	var radio_base := get_radio_efectivo()
	var sedimento_requerido: float = _calcular_sedimento_por_radio(radio_base)
	var radio_efectivo: float = radio_base

	if sedimento_disponible < sedimento_requerido:
		# Si queda poco sedimento, depositar una esfera menor proporcional al volumen restante
		radio_efectivo = radio_base * pow(sedimento_disponible / sedimento_requerido, 1.0 / 3.0)
		t_tool.consumir_sedimento(sedimento_disponible)
	else:
		t_tool.consumir_sedimento(sedimento_requerido)

	var target_pos = hit_pos + hit_normal * (radio_efectivo * 0.5)

	# Empuje antienterramiento
	if player_node:
		var player_feet = player_node.global_position
		var dist_to_player = target_pos.distance_to(player_feet)
		if dist_to_player < radio_efectivo + 1.0:
			var push_dir = (player_feet - target_pos).normalized()
			if push_dir.length() < 0.1:
				push_dir = Vector3.UP
			player_node.global_position += push_dir * ((radio_efectivo + 1.2) - dist_to_player)

	var terrain: VoxelLodTerrain = _obtener_terreno_de(collider, hit_pos)
	if terrain == null: return
	var tool = terrain.get_voxel_tool()
	if tool == null: return
	tool.channel = VoxelBuffer.CHANNEL_SDF
	tool.mode = VoxelTool.MODE_ADD
	tool.do_sphere(terrain.to_local(target_pos), radio_efectivo)


# ─── MODO 2: APLANAR (FLATTEN) ────────────────────────────────────────────────

func _ejecutar_aplanar(delta: float) -> void:
	# ── Primer frame: capturar plano alineado con la superficie del planeta ─────
	if not _aplanar_activo:
		var hit = _hacer_raycast_terreno()
		if hit.is_empty(): return
		var n: Vector3 = hit.normal                    # tipo explícito: evita error de inferencia
		if n.length_squared() < 0.01: return           # normal inválida
		_aplanar_activo = true
		_plano_origen   = hit.position
		_plano_normal   = n.normalized()               # normal de superficie = "arriba" del planeta
		_terrain_ref    = _obtener_terreno_de(hit.collider, hit.position)
		if _terrain_ref == null: return

	if _terrain_ref == null or not is_instance_valid(_terrain_ref): return

	# ── Frames siguientes: proyección rayo→plano (sin raycast al terreno) ───────
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	var mouse_pos  := get_viewport().get_mouse_position()
	var ray_origin : Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_dir    : Vector3 = camera.project_ray_normal(mouse_pos)

	# Intersección general rayo / plano orientado a la normal de la superficie
	var denom : float = ray_dir.dot(_plano_normal)
	if abs(denom) < 0.01: return                         # rayo paralelo al plano
	var t : float = (_plano_origen - ray_origin).dot(_plano_normal) / denom
	if t < 0.0 or t > max_reach * 2.0: return           # detrás o demasiado lejos

	var cursor_world  : Vector3 = ray_origin + ray_dir * t
	var local_en_plano: Vector3 = _terrain_ref.to_local(cursor_world)

	# Normal del plano en espacio local del terrain
	var local_normal: Vector3 = _plano_normal           # fallback si el terrain tiene rotación 0
	var basis := _terrain_ref.global_transform.basis
	if abs(basis.determinant()) > 0.0001:
		local_normal = (basis.inverse() * _plano_normal).normalized()

	var tool := _terrain_ref.get_voxel_tool()
	if tool == null: return
	tool.channel = VoxelBuffer.CHANNEL_SDF

	# Detección volumétrica: comprobar si hay relieve por encima o hueco por debajo del plano
	var space_state := get_world_3d().direct_space_state
	var ray_end := cursor_world + ray_dir * (brush_radius * 2.0)
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	if player_node:
		query.exclude = [player_node.get_rid()]
	var hit_cam := space_state.intersect_ray(query)

	var hay_terreno_arriba: bool = false
	var hay_hueco_abajo: bool = false
	var dist_plano: float = ray_origin.distance_to(cursor_world)

	if not hit_cam.is_empty():
		var dist_hit: float = ray_origin.distance_to(hit_cam.position)
		if dist_hit < dist_plano - 0.2:
			hay_terreno_arriba = true
		elif dist_hit > dist_plano + 0.2:
			hay_hueco_abajo = true
	else:
		hay_hueco_abajo = true

	# Tasa de sedimento por segundo proporcional al volumen del radio
	var radio_actual := get_radio_efectivo()
	var tasa_segundo: float = SEDIMENTO_APLANAR_POR_SEGUNDO * pow(radio_actual / RADIO_BASE, 3.0)
	var sedimento_frame: float = tasa_segundo * delta
	var t_tool: Node3D = player_node.get("terrain_tool") as Node3D

	# 1. REMOVE: raspar relieve por encima del plano y acumular sedimento en el canister
	tool.mode = VoxelTool.MODE_REMOVE
	var pos_raspado: Vector3 = _terrain_ref.to_global(local_en_plano + local_normal * radio_actual)
	tool.do_sphere(local_en_plano + local_normal * radio_actual, radio_actual)
	_destruir_entidades_cercanas(pos_raspado, radio_actual)

	if hay_terreno_arriba and t_tool and t_tool.has_method("agregar_sedimento"):
		t_tool.agregar_sedimento(sedimento_frame)

	# 2. ADD: rellenar huecos bajo el plano (solo con sedimento disponible)
	if hay_hueco_abajo:
		var puede_rellenar: bool = false
		if t_tool and t_tool.has_method("consumir_sedimento"):
			puede_rellenar = t_tool.consumir_sedimento(sedimento_frame)

		if puede_rellenar:
			tool.mode = VoxelTool.MODE_ADD
			tool.do_sphere(local_en_plano - local_normal * radio_actual, radio_actual)


func _obtener_terreno_de(collider: Object, ref_pos: Vector3) -> VoxelLodTerrain:
	if collider is VoxelLodTerrain:
		return collider as VoxelLodTerrain

	if collider is Node:
		var n: Node = collider
		while n != null:
			if n is VoxelLodTerrain:
				return n as VoxelLodTerrain
			if n.has_node("Terreno") and n.get_node("Terreno") is VoxelLodTerrain:
				return n.get_node("Terreno") as VoxelLodTerrain
			if "terrain" in n and n.terrain is VoxelLodTerrain:
				return n.terrain as VoxelLodTerrain
			n = n.get_parent()

	var planetas := get_tree().get_nodes_in_group("planetas")
	var min_d := 1e9
	var closest_terrain: VoxelLodTerrain = null
	for p in planetas:
		if p is Node3D and "terrain" in p and p.terrain is VoxelLodTerrain:
			var d := ref_pos.distance_to(p.global_position)
			if d < min_d:
				min_d = d
				closest_terrain = p.terrain as VoxelLodTerrain
	return closest_terrain


func _destruir_entidades_cercanas(pos: Vector3, radio: float) -> void:
	_break_deposits_near(pos)
	_derribar_arboles_cerca(pos, radio)
	_neutralizar_flora_cerca(pos, radio)


func _derribar_arboles_cerca(pos: Vector3, radio: float) -> void:
	var radio_tala := radio + 2.5
	for arbol in get_tree().get_nodes_in_group("arboles"):
		if not is_instance_valid(arbol) or not (arbol is Node3D):
			continue
		if arbol.global_position.distance_to(pos) <= radio_tala:
			if arbol.has_method("recibir_excavacion"):
				arbol.recibir_excavacion(pos, radio)
			elif arbol.has_method("derribar"):
				arbol.derribar()
			elif arbol.has_method("_derribar"):
				arbol._derribar()


func _neutralizar_flora_cerca(pos: Vector3, radio: float) -> void:
	var radio_flora := radio + 2.0
	for flora in get_tree().get_nodes_in_group("flora_peligrosa"):
		if not is_instance_valid(flora) or not (flora is Node3D):
			continue
		if flora.global_position.distance_to(pos) <= radio_flora:
			if flora.has_method("recibir_excavacion"):
				flora.recibir_excavacion(pos, radio)
			elif flora.has_method("neutralizar"):
				flora.neutralizar()
			elif flora.has_method("_neutralizar"):
				flora._neutralizar()


func _try_mine_ore(collider, world_pos: Vector3) -> void:
	if _drop_timer > 0.0:
		return
	var planeta = collider.get_parent() if collider is Node else null
	if planeta == null or not planeta.has_method("minar_en"):
		# Probar con el planeta más cercano
		var planetas := get_tree().get_nodes_in_group("planetas")
		for p in planetas:
			if p is Node3D and p.has_method("minar_en"):
				if world_pos.distance_to(p.global_position) < float(p.get("radio")) * 1.5:
					planeta = p
					break
	if planeta == null or not planeta.has_method("minar_en"):
		return
	var ore: RecursoData = planeta.minar_en(world_pos)
	if ore:
		_spawn_ore_item(ore, world_pos)
		_drop_timer = drop_cooldown


func _break_deposits_near(pos: Vector3) -> void:
	for dep in get_tree().get_nodes_in_group("ore_deposits"):
		if not is_instance_valid(dep):
			continue
		if dep.global_position.distance_to(pos) < brush_radius + 1.5:
			var planeta = dep.get_parent()
			var ore: RecursoData = null
			if planeta:
				for r in planeta.ore_catalog:
					if r.id == dep.get("ore_id"):
						ore = r
						break
			dep.queue_free()
			if ore:
				_spawn_ore_item(ore, dep.global_position + Vector3.UP * 0.5)


func _spawn_ore_item(ore: RecursoData, pos: Vector3) -> void:
	if not ore.escena_item:
		return
	var item = ore.escena_item.instantiate()
	item.recurso_id = ore.id
	get_tree().current_scene.add_child(item)
	item.global_position = pos + Vector3.UP * 1.0
	if item is RigidBody3D:
		item.apply_central_impulse(Vector3.UP * 3.0)
