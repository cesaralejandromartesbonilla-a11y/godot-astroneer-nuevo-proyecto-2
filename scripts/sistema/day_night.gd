extends Node

# Ciclo día/noche (F2) y Gestor de Atmósfera/Cielo Local (F5):
# - Rota el sol DirectionalLight3D
# - Sincroniza la atmósfera del shader de cielo 360° según el planeta más cercano
# - Alinea la atmósfera a la normal esférica del jugador (planet_up)
# - Transiciona al espacio profundo con estrellas al salir de la atmósfera
# - Snap instantáneo en teletransportes para erradicar el glitch visual transitorio

@export var sun: DirectionalLight3D
@export var day_seconds := 350.0
@export var night_seconds := 250.0

var phase := 0.15 # empezar a media mañana

var _env: Environment = null
var _sky_mat: ShaderMaterial = null

var _cur_cenit := Color(0.2, 0.52, 0.95)
var _cur_horizonte := Color(0.55, 0.82, 0.98)
var _cur_fuerza := 1.0
var _cur_up := Vector3.UP
var _last_cam_pos: Vector3 = Vector3.ZERO
var _snap_pendiente: bool = true
var _tiempo_fuerza_baja: float = 0.0


func snap_atmosfera(pos_referencia: Vector3 = Vector3.INF) -> void:
	_snap_pendiente = true
	if _sky_mat == null:
		_conectar_cielo()
	if pos_referencia != Vector3.INF:
		_forzar_actualizacion(pos_referencia)
	else:
		var p := get_tree().get_first_node_in_group("player") as Node3D
		if p:
			_forzar_actualizacion(p.global_position)


func _ready() -> void:
	add_to_group("day_night")
	await get_tree().process_frame
	_conectar_cielo()
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p:
		_forzar_actualizacion(p.global_position)


func _conectar_cielo() -> void:
	var we := get_tree().get_first_node_in_group("world_environment")
	if we == null:
		we = get_parent().get_node_or_null("WorldEnvironment")
	if we and we.environment:
		_env = we.environment
		if _env.sky and _env.sky.sky_material is ShaderMaterial:
			_sky_mat = _env.sky.sky_material as ShaderMaterial


func _process(delta: float) -> void:
	var total := day_seconds + night_seconds
	phase = fmod(phase + delta / total, 1.0)
	_apply_sun()
	_actualizar_cielo_y_atmosfera(delta)


func _apply_sun() -> void:
	if sun == null:
		return
	var elev := sin(TAU * phase)
	sun.rotation_degrees = Vector3(rad_to_deg(TAU * phase) - 90.0, 30.0, 0.0)
	sun.light_energy = clampf(elev * 1.4, 0.0, 1.2)


func _forzar_actualizacion(pos: Vector3) -> void:
	if _sky_mat == null:
		_conectar_cielo()
		if _sky_mat == null:
			return

	var planetas := get_tree().get_nodes_in_group("planetas")
	var closest: Node3D = null
	var min_dist := 1e9

	for p in planetas:
		if p is Node3D:
			var d := pos.distance_to(p.global_position)
			if d < min_dist:
				min_dist = d
				closest = p

	var target_cenit := Color(0.008, 0.01, 0.022)
	var target_horizonte := Color(0.01, 0.015, 0.03)
	var target_fuerza := 0.0
	var target_up := Vector3.UP

	if closest != null:
		var radio: float = float(closest.get("radio")) if closest.get("radio") != null else 250.0
		var r_atmo := radio * 2.6
		if min_dist < r_atmo:
			target_fuerza = clampf(1.0 - (min_dist - radio) / (radio * 1.6), 0.0, 1.0)
			var pc_cenit = closest.get("atmo_cenit")
			if pc_cenit is Color:
				target_cenit = pc_cenit
			var pc_hor = closest.get("atmo_horizonte")
			if pc_hor is Color:
				target_horizonte = pc_hor
			var diff := pos - closest.global_position
			if diff.length_squared() > 1.0:
				target_up = diff.normalized()

	_cur_cenit = target_cenit
	_cur_horizonte = target_horizonte
	_cur_fuerza = target_fuerza
	if target_up.length_squared() > 0.01:
		_cur_up = target_up
	_last_cam_pos = pos
	_snap_pendiente = false

	_sky_mat.set_shader_parameter("color_cenit", _cur_cenit)
	_sky_mat.set_shader_parameter("color_horizonte", _cur_horizonte)
	_sky_mat.set_shader_parameter("fuerza_atmosfera", _cur_fuerza)
	_sky_mat.set_shader_parameter("planet_up", _cur_up)

	if _env:
		_env.ambient_light_color = _cur_horizonte.lerp(Color.WHITE, 0.25)
		_env.ambient_light_energy = clampf(0.2 + _cur_fuerza * 0.45, 0.15, 0.75)


func _actualizar_cielo_y_atmosfera(delta: float) -> void:
	if _sky_mat == null:
		_conectar_cielo()
		if _sky_mat == null:
			return

	var p_node := get_tree().get_first_node_in_group("player") as Node3D
	var cam := get_viewport().get_camera_3d()
	var ref_pos: Vector3 = p_node.global_position if p_node else (cam.global_position if cam else Vector3(0, 300, 0))

	var planetas := get_tree().get_nodes_in_group("planetas")
	var closest: Node3D = null
	var min_dist := 1e9

	for p in planetas:
		if p is Node3D:
			var d := ref_pos.distance_to(p.global_position)
			if d < min_dist:
				min_dist = d
				closest = p

	var target_cenit := Color(0.008, 0.01, 0.022)
	var target_horizonte := Color(0.01, 0.015, 0.03)
	var target_fuerza := 0.0
	var target_up := Vector3.UP

	if closest != null:
		var radio: float = float(closest.get("radio")) if closest.get("radio") != null else 250.0
		var r_atmo := radio * 2.6
		if min_dist < r_atmo:
			target_fuerza = clampf(1.0 - (min_dist - radio) / (radio * 1.6), 0.0, 1.0)
			var pc_cenit = closest.get("atmo_cenit")
			if pc_cenit is Color:
				target_cenit = pc_cenit
			var pc_hor = closest.get("atmo_horizonte")
			if pc_hor is Color:
				target_horizonte = pc_hor
			var diff := ref_pos - closest.global_position
			if diff.length_squared() > 1.0:
				target_up = diff.normalized()

	var es_salto: bool = _snap_pendiente or (_last_cam_pos != Vector3.ZERO and ref_pos.distance_to(_last_cam_pos) > 60.0)
	_last_cam_pos = ref_pos
	_snap_pendiente = false

	if es_salto:
		_cur_cenit = target_cenit
		_cur_horizonte = target_horizonte
		_cur_fuerza = target_fuerza
		_tiempo_fuerza_baja = 0.0
		if target_up.length_squared() > 0.01:
			_cur_up = target_up
	else:
		_cur_cenit = _cur_cenit.lerp(target_cenit, delta * 2.5)
		_cur_horizonte = _cur_horizonte.lerp(target_horizonte, delta * 2.5)
		# Histéresis: la fuerza solo puede bajar si el jugador lleva >0.3 s alejado
		if target_fuerza < _cur_fuerza:
			_tiempo_fuerza_baja += delta
			if _tiempo_fuerza_baja > 0.3:
				_cur_fuerza = lerpf(_cur_fuerza, target_fuerza, delta * 2.5)
		else:
			_tiempo_fuerza_baja = 0.0
			_cur_fuerza = lerpf(_cur_fuerza, target_fuerza, delta * 2.5)
		if target_up.length_squared() > 0.01:
			_cur_up = _cur_up.lerp(target_up, delta * 3.0).normalized()

	_sky_mat.set_shader_parameter("color_cenit", _cur_cenit)
	_sky_mat.set_shader_parameter("color_horizonte", _cur_horizonte)
	_sky_mat.set_shader_parameter("fuerza_atmosfera", _cur_fuerza)
	_sky_mat.set_shader_parameter("planet_up", _cur_up)

	if sun:
		var sdir := -sun.global_transform.basis.z
		_sky_mat.set_shader_parameter("sun_dir", sdir)
		_sky_mat.set_shader_parameter("sun_color", sun.light_color)
		_sky_mat.set_shader_parameter("sol_intensidad", sun.light_energy)

	if _env:
		_env.ambient_light_color = _cur_horizonte.lerp(Color.WHITE, 0.25)
		_env.ambient_light_energy = clampf(0.2 + _cur_fuerza * 0.45, 0.15, 0.75)


func is_day() -> bool:
	return sin(TAU * phase) > 0.0
