extends CharacterBody3D

@export_group("Planetas")
@export var debug_planet: Node3D 

@export_group("Movimiento")
@export var speed := 8.0
@export var jump_force := 12.0
@export var gravity_force := 20.0
@export var acceleration := 8.0
@export var friction := 10.0

@export_group("Cámara")
@export var mouse_sensitivity := 0.002
@export var min_pitch := -80.0
@export var max_pitch := 60.0
@export var zoom_speed := 0.5
@export var min_zoom := 1.5
@export var max_zoom := 10.0


@onready var camera_mount: Node3D = $CameraMount
@onready var spring_arm: SpringArm3D = $CameraMount/SpringArm3D
@onready var visuals: Node3D = $Visuals
@onready var backpack_ui_root: Node3D = $Visuals/Mochila # Ajusta la ruta a tu mochila
@onready var camera: Camera3D = $CameraMount/SpringArm3D/Camera3D # Ajusta la ruta a tu cámara
@onready var mochila_impresora: Node3D = $Visuals/MochilaImpresora
@onready var terrain_tool: Node3D = $Visuals/TerrainTool
@onready var catalogo_holo: Node3D = $Visuals/CatalogoHolo

@export_group("Herramientas")
@export var tool_model: Node3D 
var is_tool_active := false

# Acumuladores de cámara
var cam_rot_h := 0.0 
var cam_rot_v := 0.0 
var is_rotating_camera := false

var target_planet_center := Vector3.ZERO
var is_inventory_mode := false
var held_item: Node3D = null
var current_hovered_item: Node3D = null

# --- Supervivencia (F2) ---
var stats := PlayerStats.new()

# --- Colocables (F3): clave → cantidad. Se fabrican en el menú (F) ---
const TETHER_SCENE := preload("res://escenas/planeta/tether.tscn")
const PANEL_SCENE := preload("res://escenas/planeta/panel_solar.tscn")
const ROVER_SCENE := preload("res://escenas/vehiculo/rover.tscn")
const SHUTTLE_SCENE := preload("res://escenas/vehiculo/shuttle.tscn")
const DEATH_BEACON_SCENE := preload("res://escenas/planeta/death_beacon.tscn")
const IMPRESORA_PEQUENA_SCENE := preload("res://escenas/planeta/impresora_pequena.tscn")
var placeables := {"tether": 10, "panel_solar": 1, "rover": 0, "shuttle": 0, "impresora_pequena": 0}

# --- Vehículo (F4/F5): rover o lanzadera (duck-typing: conductor/camara) ---
var en_vehiculo: Node3D = null
var _cable_o2_mesh: MeshInstance3D = null
var _mochila_tween: Tween = null
var _fuerza_viento: Vector3 = Vector3.ZERO
var _jump_cooldown: float = 0.0
var _exposicion_viento: float = 1.0
var _t_check_exposicion: float = 0.0


func aplicar_fuerza_viento(fuerza: Vector3) -> void:
	if en_vehiculo != null:
		return
	_fuerza_viento = fuerza * _exposicion_viento


func _actualizar_exposicion_viento(delta: float) -> void:
	_t_check_exposicion += delta
	if _t_check_exposicion < 0.2:
		return
	_t_check_exposicion = 0.0
	var up: Vector3 = up_direction if up_direction.length_squared() > 0.01 else Vector3.UP
	var espacio := get_world_3d().direct_space_state
	var origen: Vector3 = global_position + up * 0.6
	var params := PhysicsRayQueryParameters3D.create(origen, origen + up * 7.0)
	params.exclude = [get_rid()]
	params.collision_mask = 1
	var resultado: Dictionary = espacio.intersect_ray(params)
	if resultado.is_empty():
		_exposicion_viento = 1.0
	else:
		var dist_techo: float = global_position.distance_to(resultado["position"])
		_exposicion_viento = clampf((dist_techo - 1.0) / 5.0, 0.0, 1.0)


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	spring_arm.add_excluded_object(self.get_rid())
	stats.died.connect(_on_died)
	stats.oxygen_changed.connect(_on_o2_changed_impresora)
	stats.power_changed.connect(_on_power_changed_impresora)
	_crear_cable_oxigeno()

	# Configuración de adherencia a superficies y física de terreno irregular
	floor_snap_length = 0.8
	floor_max_angle = deg_to_rad(65.0)
	floor_stop_on_slope = true
	floor_constant_speed = true
	floor_block_on_wall = true

	# Aseguramos que no haya rotaciones residuales en el editor
	visuals.top_level = false
	camera_mount.top_level = false

func _unhandled_input(event: InputEvent) -> void:
	# Con consola o menús abiertos, el juego no responde al input
	if Global.ui_abierta > 0:
		return
	# Vehículo (F4): V sube/baja siempre; montado, el resto del input es del rover
	if event.is_action_pressed("press_v"):
		_alternar_vehiculo()
		return
	if en_vehiculo != null:
		return

# TOGGLE INVENTARIO (Tecla TAB o Q)
	if event.is_action_pressed("press_tab"): # Configura "toggle_inventory" en InputMap
		toggle_inventory_mode()
		return
		# Si estamos en modo inventario, NO rotamos la cámara con el ratón
	#if is_inventory_mode:
		#Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		#return
	# Click derecho para activar cámara
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_rotating_camera = true
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				is_rotating_camera = false
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Movimiento del ratón
	if event is InputEventMouseMotion and is_rotating_camera:
		cam_rot_h -= event.relative.x * mouse_sensitivity
		cam_rot_v -= event.relative.y * mouse_sensitivity
		cam_rot_v = clamp(cam_rot_v, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
	# (Asegúrate de meter tu lógica anterior dentro de un "else" o comprobar !is_inventory_mode)
	# ZOOM DE CÁMARA (Rueda del ratón)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_arm.spring_length = clamp(spring_arm.spring_length - zoom_speed, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_arm.spring_length = clamp(spring_arm.spring_length + zoom_speed, min_zoom, max_zoom)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var target = get_object_under_mouse()
		
		# CASO A: No tienes nada en la mano e intentas agarrar algo
		if held_item == null:
			if target and target.is_in_group("botones_impresora"):
				_interactuar_impresora(target)
				return
			if target and target.is_in_group("botones_catalogo"):
				_interactuar_catalogo(target)
				return
			if target and target.is_in_group("botones_centrifugadora"):
				_interactuar_centrifugadora(target)
				return
			if target and target.is_in_group("botones_impresora_base"):
				_interactuar_impresora_base(target)
				return
			if target and target.is_in_group("items"):
				grab_item(target)
			# ...o recuperar lo que hay dentro de un slot de la mochila
			elif target and target.is_in_group("slots") and target.has_method("remove_item"):
				var retrieved: Node3D = target.remove_item()
				if retrieved:
					grab_item(retrieved)
		
		# CASO B: Tienes algo en la mano e intentas interactuar
		else:
			if target and target.is_in_group("slots"):
				try_place_in_slot(target)
			elif target and target.is_in_group("botones_centrifugadora"):
				_interactuar_centrifugadora(target)
			elif target and target.is_in_group("botones_impresora_base"):
				_interactuar_impresora_base(target)
			else:
				drop_item()
	if event.is_action_pressed("press_e"):
		toggle_tool_mode()
	if is_tool_active and (event.is_action_pressed("press_r") or event.is_action_pressed("press_h")):
		if terrain_tool and terrain_tool.has_method("ciclar_modo"):
			terrain_tool.ciclar_modo()
	if is_tool_active and event.is_action_pressed("press_g"):
		if terrain_tool and terrain_tool.has_method("ciclar_augment"):
			terrain_tool.ciclar_augment()
	if event.is_action_pressed("press_t"):
		_place_placeable("tether", TETHER_SCENE)
	if event.is_action_pressed("press_p"):
		if placeables.get("panel_solar", 0) > 0:
			_place_placeable("panel_solar", PANEL_SCENE)
		elif placeables.get("rover", 0) > 0:
			_place_placeable("rover", ROVER_SCENE)
		elif placeables.get("shuttle", 0) > 0:
			_place_placeable("shuttle", SHUTTLE_SCENE)

func _process(_delta: float) -> void:
	if en_vehiculo != null:
		return
	if held_item:
		var mouse_pos = get_viewport().get_mouse_position()
		var target_pos = camera.project_position(mouse_pos, 4.0)
		held_item.global_position = held_item.global_position.lerp(target_pos, 0.2)
		
		# Si tenemos algo en la mano, quitamos el resaltado de cualquier otra cosa
		if current_hovered_item:
			if is_instance_valid(current_hovered_item) and current_hovered_item.has_method("set_highlight"):
				current_hovered_item.set_highlight(false)
			current_hovered_item = null
	
	# --- NUEVA LÓGICA DE DETECCIÓN (HOVER) ---
	# Solo detectamos si NO tenemos nada en la mano y NO estamos girando la cámara
	elif not is_rotating_camera:
		var target = get_object_under_mouse()
		
		# Si apuntamos a algo nuevo
		if target != current_hovered_item:
			
			# 1. Apagamos el objeto anterior (si había uno)
			if current_hovered_item and is_instance_valid(current_hovered_item):
				if current_hovered_item.has_method("set_highlight"):
					current_hovered_item.set_highlight(false)
			
			# 2. Guardamos el nuevo objeto
			current_hovered_item = target
			
			# 3. Encendemos el nuevo objeto (si es un Item)
			if current_hovered_item and current_hovered_item.is_in_group("items"):
				if current_hovered_item.has_method("set_highlight"):
					current_hovered_item.set_highlight(true)

func _physics_process(delta: float) -> void:
	# Montado en vehículo (F4): el rover lleva el control; solo sincronizar
	# posición (para redes de O2/respawn) y seguir respirando.
	if en_vehiculo != null:
		global_position = en_vehiculo.global_position + en_vehiculo.global_transform.basis.y * 1.5
		velocity = Vector3.ZERO
		_actualizar_supervivencia(delta)
		return

	# 1. ACTUALIZAR FUENTE DE GRAVEDAD Y ORIENTACIÓN
	update_gravity_source()
	
	var radial_up: Vector3 = (global_position - target_planet_center).normalized()
	var dist_al_centro: float = global_position.distance_to(target_planet_center)
	var g_actual: float = gravity_force
	var planet_up: Vector3 = radial_up

	# Zona de gravedad en el Núcleo Planetario (Gateway Engine):
	# En toda la caverna central (hasta 80m del centro), la gravedad se alinea
	# perpendicular a la plataforma del motor para máxima estabilidad y orientación natural.
	var engines = get_tree().get_nodes_in_group("gateway_engines")
	for eng in engines:
		if is_instance_valid(eng):
			var dist_eng: float = global_position.distance_to(eng.global_position)
			if dist_eng < 80.0:
				var eng_up: Vector3 = eng.global_transform.basis.y
				if dist_eng < 55.0:
					planet_up = eng_up
				else:
					var t: float = (dist_eng - 55.0) / 25.0
					planet_up = eng_up.slerp(radial_up, t).normalized()
				g_actual = 18.0
				break

	# Zona de gravedad local en Cámaras de Portal de superficie (Gateway Chamber)
	var chambers = get_tree().get_nodes_in_group("gateways")
	for ch in chambers:
		if is_instance_valid(ch) and global_position.distance_to(ch.global_position) < 24.0:
			planet_up = ch.global_transform.basis.y
			break

	# Parche de seguridad (centro del mundo)
	if dist_al_centro < 1.0 and planet_up == Vector3.ZERO: 
		planet_up = Vector3.UP
	
	# Alineación suave y estable con el eje gravitacional actual
	align_up_with_planet(planet_up)

	# Detección de suelo y normal de la superficie más cercana
	var en_suelo: bool = is_on_floor()
	var normal_suelo: Vector3 = planet_up
	if en_suelo:
		var fn: Vector3 = get_floor_normal()
		if fn.length_squared() > 0.01:
			normal_suelo = fn

	# 2. TEMPORIZADOR DE SALTO Y GESTIÓN DINÁMICA DE FLOOR SNAP
	if _jump_cooldown > 0.0:
		_jump_cooldown -= delta
		floor_snap_length = 0.0
	else:
		# Floor snap de 0.8m mantiene los pies del jugador pegados al suelo en bajadas y baches
		floor_snap_length = 0.8

	# 3. SALTO
	if Global.ui_abierta == 0 and Input.is_action_just_pressed("press_space") and en_suelo:
		velocity += planet_up * jump_force
		_jump_cooldown = 0.25 # Desactivar snap durante 0.25s para permitir el despegue limpio
		en_suelo = false

	# 4. GRAVEDAD Y ADHERENCIA ACTIVA A LA SUPERFICIE MÁS CERCANA
	if not en_suelo:
		# En el aire: gravedad acelerando hacia el suelo
		velocity += -planet_up * g_actual * delta

		# Succión de aterrizaje: si caemos cerca del suelo (<0.65m de los pies),
		# asistimos el agarre para evitar flotabilidad o retraso al re-adherirse a la superficie
		if _jump_cooldown <= 0.0 and velocity.dot(planet_up) <= 0.0:
			var hit_surf: Dictionary = _detectar_superficie_cercana(-planet_up, 2.2)
			if not hit_surf.is_empty():
				var dist_pies: float = (global_position - hit_surf["position"]).dot(planet_up) - 1.0
				if dist_pies > -0.1 and dist_pies < 0.65:
					velocity += -planet_up * (g_actual * 0.8) * delta
	else:
		# En el suelo: fuerza de adherencia continua perpendicular a la superficie real
		# Mantiene al jugador firme contra el suelo al descender pendientes o correr sobre terreno irregular
		velocity += -normal_suelo * (g_actual * 0.75) * delta

	# 5. MOVIMIENTO
	var input_dir := Vector2.ZERO
	if Global.ui_abierta == 0:
		input_dir = Input.get_vector("press_a", "press_d", "press_s", "press_w")
	var move_dir := Vector3.ZERO
	
	if input_dir != Vector2.ZERO:
		if is_inventory_mode:
			toggle_inventory_mode()
		var cam_basis := camera_mount.global_transform.basis
		
		# Proyectamos la dirección de la cámara sobre el plano de gravedad
		var forward := -cam_basis.z.slide(planet_up).normalized()
		var right := cam_basis.x.slide(planet_up).normalized()
		var move_horizontal := (forward * input_dir.y + right * input_dir.x).normalized()
		
		# Si estamos en el suelo y no es una pared vertical, adaptamos el movimiento a la pendiente
		if en_suelo and normal_suelo.dot(planet_up) > 0.35:
			move_dir = move_horizontal.slide(normal_suelo).normalized()
		else:
			move_dir = move_horizontal
		
		# Rotar visuales (El modelo 3D) hacia donde caminas
		if move_dir.length_squared() > 0.01:
			var current_quat := visuals.global_transform.basis.get_rotation_quaternion()
			var target_basis := Basis.looking_at(move_dir, planet_up)
			var target_quat := target_basis.get_rotation_quaternion()
			visuals.global_transform.basis = Basis(current_quat.slerp(target_quat, 0.2))

	# 6. APLICAR VELOCIDAD
	var v_vert: Vector3 = velocity.project(planet_up)
	var v_horiz: Vector3 = velocity - v_vert
	
	if move_dir != Vector3.ZERO:
		var dir_h := move_dir.slide(planet_up).normalized()
		if dir_h.length_squared() > 0.01:
			v_horiz = v_horiz.move_toward(dir_h * speed, acceleration * delta)
		else:
			v_horiz = v_horiz.move_toward(move_dir * speed, acceleration * delta)
	else:
		v_horiz = v_horiz.move_toward(Vector3.ZERO, friction * delta)
	
	# Aplicar viento exclusivamente a la velocidad horizontal de superficie
	_actualizar_exposicion_viento(delta)
	if _fuerza_viento != Vector3.ZERO:
		var viento_horiz: Vector3 = _fuerza_viento.slide(planet_up)
		v_horiz += viento_horiz
		_fuerza_viento = Vector3.ZERO

	# Clamp de seguridad física (Terminal Velocity):
	# Limita la velocidad vertical y horizontal para evitar que glitches de colisión proyecten al jugador a órbita
	var v_vert_mag := v_vert.dot(planet_up)
	v_vert_mag = clampf(v_vert_mag, -40.0, 16.0) # Salto max 12m/s, max ascenso 16m/s
	v_vert = planet_up * v_vert_mag
	if v_horiz.length() > 20.0:
		v_horiz = v_horiz.normalized() * 20.0

	velocity = v_vert + v_horiz
	up_direction = planet_up
	move_and_slide()

	# Protección post-colisión: evitar que impulsos de depenetración o rebotes extremos
	# catapulten al jugador fuera de la gravedad planetaria
	if velocity.length() > 24.0:
		velocity = velocity.normalized() * 24.0
	if velocity.dot(planet_up) > 16.0:
		var v_up := velocity.project(planet_up)
		var v_tang := velocity - v_up
		velocity = v_tang + planet_up * 16.0
	
	# --- CÁMARA (Lógica Local) ---
	# Actualizamos la cámara AQUÍ o en _process, pero usando rotación local
	camera_mount.rotation = Vector3.ZERO # Reseteamos rotación local
	camera_mount.rotate_object_local(Vector3.UP, cam_rot_h) # Giramos sobre SU eje Y (que es el del planeta)
	spring_arm.rotation = Vector3.ZERO
	spring_arm.rotate_object_local(Vector3.RIGHT, cam_rot_v)

	# --- SUPERVIVENCIA (F2): oxígeno y energía ---
	_actualizar_supervivencia(delta)


func _actualizar_supervivencia(delta: float) -> void:
	var net := get_tree().get_first_node_in_group("oxygen_network")
	var oxigenado := false
	if net and net.is_oxygenated(global_position):
		oxigenado = true
		stats.replenish_oxygen(PlayerStats.O2_REPLENISH_RATE, delta)
	else:
		stats.consume_oxygen(PlayerStats.O2_DRAIN_RATE, delta)

	_actualizar_cable_oxigeno(oxigenado)

	var dn := get_tree().get_first_node_in_group("day_night")
	if dn == null or dn.is_day():
		stats.replenish_power(PlayerStats.POWER_REGEN_DAY, delta)


func _crear_cable_oxigeno() -> void:
	_cable_o2_mesh = MeshInstance3D.new()
	_cable_o2_mesh.top_level = true
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.02
	cyl.bottom_radius = 0.02
	cyl.height = 1.0
	cyl.radial_segments = 6
	_cable_o2_mesh.mesh = cyl

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 0.9, 1.0, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cable_o2_mesh.material_override = mat
	_cable_o2_mesh.visible = false
	add_child(_cable_o2_mesh)


func _actualizar_cable_oxigeno(esta_oxigenado: bool) -> void:
	if not esta_oxigenado or en_vehiculo != null:
		if _cable_o2_mesh:
			_cable_o2_mesh.visible = false
		return

	var net := get_tree().get_first_node_in_group("oxygen_network")
	if net == null or not net.has_method("get_closest_oxygen_emitter"):
		if _cable_o2_mesh:
			_cable_o2_mesh.visible = false
		return

	var mochila_pos: Vector3 = backpack_ui_root.global_position if backpack_ui_root else global_position + Vector3.UP * 1.2
	var info: Dictionary = net.get_closest_oxygen_emitter(mochila_pos, 10.5)
	if info.is_empty():
		if _cable_o2_mesh:
			_cable_o2_mesh.visible = false
		return

	var p_emisor: Vector3 = info["punto"]
	var diff := p_emisor - mochila_pos
	var dist := diff.length()
	if dist < 0.15:
		if _cable_o2_mesh:
			_cable_o2_mesh.visible = false
		return

	_cable_o2_mesh.visible = true
	var mid := (mochila_pos + p_emisor) * 0.5
	var dir_y := diff.normalized()

	var arbitrary := Vector3.FORWARD if absf(dir_y.dot(Vector3.UP)) > 0.85 else Vector3.UP
	var dir_x := dir_y.cross(arbitrary).normalized()
	var dir_z := dir_x.cross(dir_y).normalized()

	_cable_o2_mesh.global_transform.basis = Basis(dir_x, dir_y * dist, dir_z)
	_cable_o2_mesh.global_position = mid


func _alternar_vehiculo() -> void:
	if en_vehiculo != null:
		if en_vehiculo.has_method("puede_desmontar") and not en_vehiculo.puede_desmontar():
			print("No puedes desmontar en pleno vuelo. Aterriza primero con [E].")
			return
		_salir_vehiculo()
		return
	var mejor_v: Node3D = null
	var dist_min := 7.0
	for v in get_tree().get_nodes_in_group("vehiculos"):
		var d = global_position.distance_to(v.global_position)
		if d < dist_min:
			dist_min = d
			mejor_v = v
	if mejor_v:
		_entrar_vehiculo(mejor_v)


func _entrar_vehiculo(v: Node3D) -> void:
	en_vehiculo = v
	v.conductor = self
	Global.estado = 0
	if held_item:
		drop_item()
	if _cable_o2_mesh:
		_cable_o2_mesh.visible = false
	visible = false
	$CollisionShape3D.set_deferred("disabled", true)
	v.camara.current = true
	camera.current = false
	print("Conduciendo rover — [V] para bajar")


func _salir_vehiculo() -> void:
	var v := en_vehiculo
	en_vehiculo = null
	v.conductor = null
	Global.estado = 1
	visible = true

	# Exclusión mutua de colisión temporal entre jugador y vehículo
	# para que bajo ninguna circunstancia se empujen o causen glitch de expulsión física
	add_collision_exception_with(v)
	if v.has_method("add_collision_exception_with"):
		v.add_collision_exception_with(self)

	# Calcular el 'up' gravitacional correcto del planeta donde aterrizó la nave
	update_gravity_source()
	var up: Vector3 = (v.global_position - target_planet_center).normalized()
	if up.length_squared() < 0.01:
		up = v.global_transform.basis.y

	# Alinear la orientación (basis) del jugador directamente con el planeta antes de reaparecer
	# para que la cápsula quede perpendicular a la superficie sin colisionar oblicuamente
	var fwd := up.cross(Vector3.RIGHT)
	if fwd.length_squared() < 0.01:
		fwd = up.cross(Vector3.FORWARD)
	fwd = fwd.normalized()
	var right := fwd.cross(up).normalized()
	global_transform.basis = Basis(right, up, fwd).orthonormalized()
	up_direction = up

	# Sondear con raycasts hacia el suelo real para situar los pies del jugador
	# exactamente sobre la superficie del terreno y nunca bajo tierra ni dentro de una montaña
	var space_state := get_world_3d().direct_space_state
	var pos_salida := v.global_position + up * 2.0
	var encontrado := false

	var v_x := v.global_transform.basis.x.slide(up).normalized()
	if v_x.length_squared() < 0.01:
		v_x = right
	var v_z := v.global_transform.basis.z.slide(up).normalized()
	if v_z.length_squared() < 0.01:
		v_z = fwd

	var intentos := [v_x * 4.0, -v_x * 4.0, v_z * 4.0, -v_z * 4.0]
	for off in intentos:
		var origen_rayo: Vector3 = v.global_position + off + up * 5.0
		var destino_rayo: Vector3 = v.global_position + off - up * 8.0
		var query := PhysicsRayQueryParameters3D.create(origen_rayo, destino_rayo)
		query.collision_mask = 1
		query.exclude = [get_rid(), v.get_rid()]
		var hit := space_state.intersect_ray(query)
		if not hit.is_empty():
			# 1.05m sobre el impacto = pies exactamente en el suelo para la cápsula de 2.0m
			pos_salida = hit.position + up * 1.05
			encontrado = true
			break

	if not encontrado:
		pos_salida = v.global_position + up * 2.5 + v_x * 4.2

	global_position = pos_salida
	up_direction = up
	velocity = Vector3.ZERO
	set_deferred("velocity", Vector3.ZERO)
	$CollisionShape3D.set_deferred("disabled", false)

	# Breve congelamiento de física (6 frames) para disipar cualquier inercia remanente
	set_physics_process(false)
	for i in 6:
		await get_tree().physics_frame
		velocity = Vector3.ZERO

	velocity = Vector3.ZERO
	set_physics_process(true)

	var dn := get_tree().get_first_node_in_group("day_night")
	if dn and dn.has_method("snap_atmosfera"):
		dn.snap_atmosfera()

	camera.current = true
	var v_camara: Camera3D = v.get("camara") as Camera3D
	if v_camara:
		v_camara.current = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_died() -> void:
	print("Sin oxígeno — iniciando secuencia de muerte y respawn")
	is_tool_active = false
	if _cable_o2_mesh:
		_cable_o2_mesh.visible = false
	
	# Guardar posición de muerte
	var death_pos := global_position
	
	# Recolectar items a transferir a la baliza
	var items_a_guardar: Array[Node3D] = []
	if held_item:
		items_a_guardar.append(held_item)
		held_item = null
	
	for c in visuals.get_children():
		if c.is_in_group("slots") and c.has_method("remove_item"):
			var it: Node3D = c.remove_item()
			if it:
				items_a_guardar.append(it)
	
	# Instanciar la baliza de rescate (Death Beacon)
	var beacon = DEATH_BEACON_SCENE.instantiate()
	get_tree().current_scene.add_child(beacon)
	beacon.global_position = death_pos
	for it in items_a_guardar:
		beacon.agregar_item(it)
	
	# Transición en HUD (Fade out a negro)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("mostrar_fade_muerte"):
		await hud.mostrar_fade_muerte()
	else:
		await get_tree().create_timer(1.5).timeout
	
	# Teletransportar al punto de reaparición (Cápsula)
	var rp := get_tree().get_first_node_in_group("respawn_point") as Node3D
	if rp:
		global_position = rp.global_position + Vector3.UP * 2.0
		velocity = Vector3.ZERO
	stats.reset()
	
	# Quitar fade y notificar
	if hud and hud.has_method("ocultar_fade"):
		await hud.ocultar_fade()
	
	if hud and hud.has_method("mostrar_notificacion"):
		if items_a_guardar.size() > 0:
			hud.mostrar_notificacion("Has muerto. Se creó una Baliza de Rescate con tus objetos.")
		else:
			hud.mostrar_notificacion("Has muerto. Has reaparecido en la cápsula.")


func _place_placeable(clave: String, escena: PackedScene) -> void:
	if placeables.get(clave, 0) <= 0:
		print("Sin %s — fabrícalos en el menú (F)" % clave)
		return
	# Plantar en el suelo bajo el jugador
	var space_state := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 12.0)
	query.exclude = [get_rid()]
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var obj := escena.instantiate()
	obj.set_meta("tipo", clave)
	obj.add_to_group("colocados")
	get_tree().current_scene.add_child(obj)
	obj.global_position = hit.position
	placeables[clave] = placeables.get(clave, 0) - 1


## Inventario de recursos en los slots de la mochila: {recurso_id: unidades_completas}
## Solo cuenta recursos con relleno >= 1.0 (completos y listos para fabricar).
func contar_items() -> Dictionary:
	var counts: Dictionary = {}
	for c in visuals.get_children():
		if c.is_in_group("slots") and c.stored_item:
			var rid: int = c.stored_item.get("recurso_id") if c.stored_item.get("recurso_id") != null else 0
			if rid > 0:
				var relleno: float = c.stored_item.get("relleno") if c.stored_item.get("relleno") != null else 1.0
				if relleno >= 1.0:
					counts[rid] = counts.get(rid, 0) + 1
	return counts


## Quita qty recursos completos (relleno >= 1.0) con ese recurso_id de la mochila.
func quitar_items(rid: int, qty: int) -> bool:
	if contar_items().get(rid, 0) < qty:
		return false
	var faltan: int = qty
	for c in visuals.get_children():
		if faltan == 0:
			break
		if not c.is_in_group("slots"):
			continue
		if c.stored_item == null:
			continue
		if c.stored_item.get("recurso_id") != rid:
			continue
		var relleno: float = c.stored_item.get("relleno") if c.stored_item.get("relleno") != null else 1.0
		if relleno >= 1.0:
			faltan -= 1
			c.stored_item.queue_free()
			c.stored_item = null
	return true

# --- FUNCIÓN MAGICA DE ALINEACIÓN ---
func align_up_with_planet(new_up: Vector3):
	# Esta función evita el jitter alineando solo lo necesario
	var current_up = global_transform.basis.y
	
	# Si ya estamos alineados, no hacemos nada (ahorra cálculos y vibración)
	if current_up.is_equal_approx(new_up):
		return
		
	# Calculamos el quaternion que rota de "current_up" a "new_up"
	var axis = current_up.cross(new_up)
	if axis.length_squared() < 0.0001: 
		# Si son antiparalelos (180 grados opuestos al cambiar de planeta o polo)
		if current_up.dot(new_up) < 0.0:
			axis = current_up.cross(Vector3.FORWARD)
			if axis.length_squared() < 0.0001:
				axis = current_up.cross(Vector3.RIGHT)
			axis = axis.normalized()
		else:
			return # Son paralelos exactos
	else:
		axis = axis.normalized()
	
	var angle = current_up.angle_to(new_up)
	var correction_quat = Quaternion(axis, angle)
	
	# Aplicamos la rotación a la base actual
	global_transform.basis = Basis(correction_quat) * global_transform.basis
	
	# Orto-normalizamos para evitar deformaciones con el tiempo
	global_transform.basis = global_transform.basis.orthonormalized()

func update_gravity_source():
	if debug_planet:
		target_planet_center = debug_planet.global_position
		return

	var planetas = get_tree().get_nodes_in_group("planetas")
	if planetas.is_empty(): return
	
	var closest = planetas[0]
	var d_min = global_position.distance_to(closest.global_position)
	
	for p in planetas:
		var d = global_position.distance_to(p.global_position)
		if d < d_min:
			d_min = d
			closest = p
	target_planet_center = closest.global_position

func toggle_inventory_mode():
	is_inventory_mode = !is_inventory_mode
	if is_inventory_mode:
		is_tool_active = false
		is_rotating_camera = false

	if _mochila_tween and _mochila_tween.is_valid():
		_mochila_tween.kill()
	_mochila_tween = create_tween()
	_mochila_tween.set_parallel(true)
	_mochila_tween.set_trans(Tween.TRANS_CUBIC)
	_mochila_tween.set_ease(Tween.EASE_OUT)

	if is_inventory_mode:
		# Orientar la cámara exactamente hacia la espalda de Visuals
		# Visuals.looking_at mira a -Z, por lo que su espalda es +Z local.
		var espalda_local := visuals.transform.basis.z
		var target_rot_h := atan2(espalda_local.x, espalda_local.z)
		
		# Ajustar cam_rot_h para rotar por el camino más corto hacia la espalda
		var diff := wrapf(target_rot_h - cam_rot_h, -PI, PI)
		var final_cam_h := cam_rot_h + diff
		
		_mochila_tween.tween_property(self, "cam_rot_h", final_cam_h, 0.35)
		_mochila_tween.tween_property(self, "cam_rot_v", deg_to_rad(-4.0), 0.35)
		_mochila_tween.tween_property(spring_arm, "position:y", 0.35, 0.35)
		_mochila_tween.tween_property(spring_arm, "spring_length", 2.0, 0.35)
	else:
		# Al cerrar restauramos altura normal y zoom de tercera persona
		_mochila_tween.tween_property(spring_arm, "position:y", 1.2, 0.25)
		_mochila_tween.tween_property(spring_arm, "spring_length", 6.0, 0.25)

	if is_inventory_mode and catalogo_holo and catalogo_holo.has_method("actualizar_interfaz"):
		catalogo_holo.actualizar_interfaz()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func get_object_under_mouse():
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 20.0

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)

	# Detectar AMBOS para que funcionen Slots (Areas) e Items (Bodies)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	# Excluir al propio jugador para que el rayo no choque con tu casco
	query.exclude = [self.get_rid()]

	var result = space_state.intersect_ray(query)
	return result.get("collider", null)


func grab_item(item):
	held_item = item
	held_item.set_physics_state(false)
	AudioJuego.reproducir_recoger()
	if mochila_impresora and mochila_impresora.has_method("actualizar_interfaz"):
		mochila_impresora.actualizar_interfaz()

func drop_item():
	if held_item:
		held_item.set_physics_state(true)
		held_item = null
		if mochila_impresora and mochila_impresora.has_method("actualizar_interfaz"):
			mochila_impresora.actualizar_interfaz()

func try_place_in_slot(slot: Node) -> void:
	if held_item.is_in_group("small_items"):
		var ok: bool = slot.equip_item(held_item)
		if ok:
			held_item = null
			if mochila_impresora and mochila_impresora.has_method("actualizar_interfaz"):
				mochila_impresora.actualizar_interfaz()
		# Si no cabe (slot lleno y tipos distintos), el held_item sigue en la mano
	else:
		print("Este objeto es demasiado grande para este slot")


func _interactuar_catalogo(boton: Node) -> void:
	if catalogo_holo == null:
		return
	if boton.name == "BotonToggleCatalogo":
		catalogo_holo.toggle_despliegue()
	elif boton.name == "BotonAnt":
		catalogo_holo.anterior()
	elif boton.name == "BotonSig":
		catalogo_holo.siguiente()
	elif boton.name == "BotonDesbloquear":
		catalogo_holo.desbloquear_actual()

func _interactuar_impresora(boton: Node) -> void:
	if mochila_impresora == null:
		return
	if boton.name == "BotonAnt":
		mochila_impresora.receta_anterior()
	elif boton.name == "BotonSig":
		mochila_impresora.receta_siguiente()
	elif boton.name == "BotonImprimir":
		mochila_impresora.fabricar()

func _interactuar_centrifugadora(boton: Node) -> void:
	var cent: Node = boton.get_owner()
	if cent == null or not cent.is_in_group("centrifugadora"):
		cent = get_tree().get_first_node_in_group("centrifugadora")
	if cent == null:
		return

	if boton.name == "BotonAnt" and cent.has_method("receta_anterior"):
		cent.receta_anterior()
	elif boton.name == "BotonSig" and cent.has_method("receta_siguiente"):
		cent.receta_siguiente()
	elif boton.name == "BotonCentrifugar" and cent.has_method("iniciar_centrifugado"):
		cent.iniciar_centrifugado()
	elif boton.name == "BotonCargarSuelo" and cent.has_method("cargar_sedimento_desde_jugador"):
		cent.cargar_sedimento_desde_jugador(self)


func _interactuar_impresora_base(boton: Node) -> void:
	var imp: Node = boton.get_owner()
	if imp == null or not imp.is_in_group("impresoras_base"):
		var p = boton.get_parent()
		while p != null and not p.is_in_group("impresoras_base"):
			p = p.get_parent()
		imp = p
	if imp == null:
		return

	if boton.name == "BotonAnt" and imp.has_method("receta_anterior"):
		imp.receta_anterior()
	elif boton.name == "BotonSig" and imp.has_method("receta_siguiente"):
		imp.receta_siguiente()
	elif boton.name == "BotonImprimir" and imp.has_method("iniciar_impresion"):
		imp.iniciar_impresion()
	elif boton.name == "BotonCargar" and imp.has_method("cargar_materiales_desde_jugador"):
		imp.cargar_materiales_desde_jugador(self)



func _on_o2_changed_impresora(val: float, max_val: float) -> void:
	if mochila_impresora and mochila_impresora.has_method("actualizar_o2"):
		mochila_impresora.actualizar_o2(val, max_val)


func _on_power_changed_impresora(val: float, max_val: float) -> void:
	if mochila_impresora and mochila_impresora.has_method("actualizar_power"):
		mochila_impresora.actualizar_power(val, max_val)

func toggle_tool_mode():
	is_tool_active = !is_tool_active
	if is_tool_active:
		is_inventory_mode = false
	if terrain_tool and terrain_tool.has_method("set_activa"):
		terrain_tool.set_activa(is_tool_active)


func _detectar_superficie_cercana(dir_abajo: Vector3, dist_max: float = 2.5) -> Dictionary:
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + dir_abajo * dist_max
	)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	return space_state.intersect_ray(query)
