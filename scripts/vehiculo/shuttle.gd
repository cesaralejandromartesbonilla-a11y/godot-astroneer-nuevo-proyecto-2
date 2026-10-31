extends CharacterBody3D

# Lanzadera Espacial (CharacterBody3D):
# Colisiones físicas reales contra el terreno (imposible atravesar planetas).
# Control Directo con Ratón (Pitch Y, Yaw X, Roll A/D), Boost, y Aterrizaje Asistido.

enum EstadoNave { ATERRIZADO, DESPEGANDO, VUELO_AVION, VUELO_ESPACIO, ATERRIZANDO }

const O2_RADIUS := 16.0
const ALTURA_ATMOSFERA := 220.0

# Parámetros de Velocidad
const AVION_VEL_MIN := 8.0
const AVION_VEL_CRUCERO := 45.0
const AVION_VEL_BOOST := 100.0
const AVION_ACEL := 40.0
const AVION_FRENO := 45.0
const AVION_GRAVEDAD := 20.0

const ESPACIO_VEL_CRUCERO := 95.0
const ESPACIO_VEL_BOOST := 260.0
const ESPACIO_ACEL := 50.0
const ESPACIO_FRENO := 55.0

# Sensibilidad de Ratón
const SENS_PITCH := 0.003
const SENS_YAW := 0.0035
const RATE_ROLL := 3.0

# Boost
const BOOST_MAX := 100.0
const BOOST_CONSUMO := 22.0
const BOOST_REGEN := 16.0

var conductor: Node3D = null
var estado: int = EstadoNave.ATERRIZADO

# Dinámica lineal
var _potencia: float = 0.0
var _vel_actual: float = 0.0
var _boost_actual: float = BOOST_MAX
var _usando_boost: bool = false

# Dinámica angular
var _mouse_delta: Vector2 = Vector2.ZERO

# Sensores
var _distancia_superficie: float = INF
var _distancia_suelo_rayo: float = INF
var _puede_aterrizar: bool = false
var _tiempo_despegue: float = 0.0

# Nodos
@onready var spring_arm: SpringArm3D = $Camara
@onready var camara: Camera3D = $Camara/Camera3D
@onready var hud: CanvasLayer = $HUDNave
@onready var fuego_izq: MeshInstance3D = $MotorIzq/FuegoIzq
@onready var fuego_der: MeshInstance3D = $MotorDer/FuegoDer


func _ready() -> void:
	add_to_group("vehiculos")
	var net := get_tree().get_first_node_in_group("oxygen_network")
	if net:
		net.register_source(self, O2_RADIUS)
	_actualizar_efectos_motor(0.0)


func puede_desmontar() -> bool:
	return estado == EstadoNave.ATERRIZADO


func _input(event: InputEvent) -> void:
	if conductor == null or Global.ui_abierta > 0:
		return

	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and estado != EstadoNave.ATERRIZADO:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_delta += event.relative

	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E:
			if (estado == EstadoNave.VUELO_AVION or estado == EstadoNave.VUELO_ESPACIO) and _puede_aterrizar:
				_iniciar_aterrizaje()
			elif estado == EstadoNave.ATERRIZADO:
				var player = conductor
				if player and player.has_method("_salir_vehiculo"):
					player._salir_vehiculo()


func _physics_process(delta: float) -> void:
	_actualizar_sensores_planeta()

	# Configurar dirección "up" para CharacterBody3D relativa al planeta actual
	var up_planeta := _obtener_up_planeta()
	up_direction = up_planeta

	if conductor == null:
		if estado == EstadoNave.ATERRIZADO:
			velocity = Vector3.ZERO
			_vel_actual = 0.0
			_potencia = 0.0
			_actualizar_efectos_motor(0.0)
			_actualizar_hud()
			return
		else:
			_frenar_o_caer_pasivo(delta)
			_actualizar_hud()
			return

	if Global.ui_abierta > 0:
		if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	# Gestión de Boost
	_usando_boost = false
	if Input.is_action_pressed("press_shift") and _boost_actual > 5.0 and _potencia > 0.2:
		_usando_boost = true
		_boost_actual = maxf(0.0, _boost_actual - BOOST_CONSUMO * delta)
	else:
		_boost_actual = minf(BOOST_MAX, _boost_actual + BOOST_REGEN * delta)

	match estado:
		EstadoNave.ATERRIZADO:
			_procesar_aterrizado(delta)
		EstadoNave.DESPEGANDO:
			_procesar_despegue(delta)
		EstadoNave.VUELO_AVION:
			_procesar_vuelo_atmosfera(delta)
		EstadoNave.VUELO_ESPACIO:
			_procesar_vuelo_espacio(delta)
		EstadoNave.ATERRIZANDO:
			_procesar_aterrizaje(delta)

	_actualizar_camara(delta)
	_actualizar_hud()


# --- FASE 1: ATERRIZADO ---
func _procesar_aterrizado(_delta: float) -> void:
	velocity = Vector3.ZERO
	_vel_actual = 0.0
	_potencia = 0.0
	_actualizar_efectos_motor(0.0)

	if Input.is_action_pressed("press_w") or Input.is_action_pressed("press_space"):
		_iniciar_despegue()


func _iniciar_despegue() -> void:
	estado = EstadoNave.DESPEGANDO
	_tiempo_despegue = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- FASE 2: DESPEGANDO ---
func _procesar_despegue(delta: float) -> void:
	_tiempo_despegue += delta
	var up_planeta := _obtener_up_planeta()
	
	velocity = up_planeta * 18.0
	move_and_slide()
	_actualizar_efectos_motor(0.5)

	if _tiempo_despegue >= 1.4:
		estado = EstadoNave.VUELO_AVION
		_potencia = 0.5
		_vel_actual = AVION_VEL_CRUCERO * 0.5


# --- FASE 3: VUELO EN ATMÓSFERA ---
func _procesar_vuelo_atmosfera(delta: float) -> void:
	if _distancia_superficie > ALTURA_ATMOSFERA:
		estado = EstadoNave.VUELO_ESPACIO
		return

	# Acelerador
	if Input.is_action_pressed("press_w"):
		var tope := 1.8 if _usando_boost else 1.0
		_potencia = move_toward(_potencia, tope, 1.0 * delta)
	elif Input.is_action_pressed("press_s"):
		_potencia = move_toward(_potencia, 0.0, 1.4 * delta)
	elif _usando_boost:
		_potencia = move_toward(_potencia, 1.6, 1.0 * delta)

	var vel_objetivo := lerpf(AVION_VEL_MIN, AVION_VEL_BOOST if _usando_boost else AVION_VEL_CRUCERO, _potencia)
	_vel_actual = move_toward(_vel_actual, vel_objetivo, (AVION_ACEL if vel_objetivo > _vel_actual else AVION_FRENO) * delta)

	# Rotación 1:1 con ratón
	_aplicar_rotacion_vuelo(delta)

	# Sustentación y avance físico con colisión
	var up_planeta := _obtener_up_planeta()
	var forward := -global_transform.basis.z.normalized()
	var ala_up := global_transform.basis.y.normalized()

	var factor_sustentacion := clampf(_vel_actual / AVION_VEL_CRUCERO, 0.0, 1.2)
	var sustentacion := ala_up * (AVION_GRAVEDAD * factor_sustentacion)
	var gravedad := -up_planeta * AVION_GRAVEDAD

	velocity = (forward * _vel_actual) + ((sustentacion + gravedad) * delta)
	move_and_slide()

	# Si roza el suelo a muy baja velocidad, estabilizar
	if is_on_floor() and _vel_actual < AVION_VEL_MIN * 1.2:
		_vel_actual = AVION_VEL_MIN * 1.2

	_actualizar_efectos_motor(_vel_actual / AVION_VEL_BOOST)


# --- FASE 4: VUELO EN ESPACIO ---
func _procesar_vuelo_espacio(delta: float) -> void:
	if _distancia_superficie <= ALTURA_ATMOSFERA * 0.95:
		estado = EstadoNave.VUELO_AVION
		_potencia = minf(_potencia, 0.6)
		_vel_actual = minf(_vel_actual, AVION_VEL_CRUCERO * 1.3)
		return

	if Input.is_action_pressed("press_w"):
		var tope := 1.8 if _usando_boost else 1.0
		_potencia = move_toward(_potencia, tope, 0.8 * delta)
	elif Input.is_action_pressed("press_s"):
		_potencia = move_toward(_potencia, 0.0, 1.5 * delta)
	elif _usando_boost:
		_potencia = move_toward(_potencia, 1.6, 0.9 * delta)

	var vel_objetivo := lerpf(0.0, ESPACIO_VEL_BOOST if _usando_boost else ESPACIO_VEL_CRUCERO, _potencia)
	_vel_actual = move_toward(_vel_actual, vel_objetivo, (ESPACIO_ACEL if vel_objetivo > _vel_actual else ESPACIO_FRENO) * delta)

	_aplicar_rotacion_vuelo(delta)

	var forward := -global_transform.basis.z.normalized()
	velocity = forward * _vel_actual
	move_and_slide()

	_actualizar_efectos_motor(_vel_actual / ESPACIO_VEL_BOOST)


# --- ROTACIÓN PRECISA 1:1 ---
func _aplicar_rotacion_vuelo(delta: float) -> void:
	var rot_pitch := -_mouse_delta.y * SENS_PITCH
	var rot_yaw := -_mouse_delta.x * SENS_YAW
	_mouse_delta = Vector2.ZERO

	rotate_object_local(Vector3.RIGHT, rot_pitch)
	rotate_object_local(Vector3.UP, rot_yaw)

	var roll_input := 0.0
	if Input.is_action_pressed("press_a"):
		roll_input += 1.0
	if Input.is_action_pressed("press_d"):
		roll_input -= 1.0

	if absf(roll_input) > 0.01:
		rotate_object_local(Vector3.FORWARD, roll_input * RATE_ROLL * delta)


# --- FASE 5: ATERRIZAJE ASISTIDO (SIN ATRAVESAR PLANETAS) ---
func _iniciar_aterrizaje() -> void:
	estado = EstadoNave.ATERRIZANDO
	_usando_boost = false


func _procesar_aterrizaje(delta: float) -> void:
	_vel_actual = move_toward(_vel_actual, 0.0, 35.0 * delta)
	var up_planeta := _obtener_up_planeta()
	_alinear_con_up(up_planeta, 7.0 * delta)

	var forward := -global_transform.basis.z.normalized()
	# Descenso suave en dirección a la superficie del planeta
	var vel_descenso: Vector3 = -up_planeta * 7.5
	var vel_avance: Vector3 = forward * _vel_actual

	velocity = vel_avance + vel_descenso
	move_and_slide()
	_actualizar_efectos_motor(0.2)

	# Si toca el suelo físicamente (is_on_floor o colisión detectada):
	if is_on_floor() or get_slide_collision_count() > 0 or _distancia_suelo_rayo <= 1.4:
		velocity = Vector3.ZERO
		_vel_actual = 0.0
		_potencia = 0.0
		estado = EstadoNave.ATERRIZADO
		_alinear_con_up(up_planeta, 1.0)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_actualizar_efectos_motor(0.0)


func _alinear_con_up(up_target: Vector3, t: float) -> void:
	var up_actual := global_transform.basis.y
	var q_actual := global_transform.basis.get_rotation_quaternion()
	var eje := up_actual.cross(up_target)
	if eje.length_squared() > 0.0001:
		var q_rot := Quaternion(eje.normalized(), up_actual.angle_to(up_target))
		var q_dest := q_rot * q_actual
		global_transform.basis = Basis(q_actual.slerp(q_dest, clampf(t, 0.0, 1.0))).orthonormalized()


# --- GRAVEDAD PASIVA (SI QUEDÓ EN EL AIRE SIN CONDUCTOR) ---
func _frenar_o_caer_pasivo(delta: float) -> void:
	var mas_cercano := _planeta_cercano()
	if mas_cercano and _distancia_superficie < ALTURA_ATMOSFERA * 2.5:
		var up_planeta := (global_position - mas_cercano.global_position).normalized()
		velocity = velocity.move_toward(-up_planeta * 10.0, 20.0 * delta)
		move_and_slide()

		if is_on_floor() or get_slide_collision_count() > 0 or _distancia_suelo_rayo <= 1.5:
			velocity = Vector3.ZERO
			_vel_actual = 0.0
			_potencia = 0.0
			estado = EstadoNave.ATERRIZADO
			_alinear_con_up(up_planeta, 1.0)
			_actualizar_efectos_motor(0.0)
			return
	else:
		velocity = velocity.move_toward(Vector3.ZERO, 30.0 * delta)
		move_and_slide()

	_actualizar_efectos_motor(0.0)


# --- SENSORES DE DISTANCIA ROBUSTOS ---
func _actualizar_sensores_planeta() -> void:
	var mas_cercano: Node3D = _planeta_cercano()
	if mas_cercano == null:
		_distancia_superficie = INF
		_distancia_suelo_rayo = INF
		_puede_aterrizar = false
		return

	var radio_p: float = mas_cercano.radio if "radio" in mas_cercano else 250.0
	var dist_centro: float = global_position.distance_to(mas_cercano.global_position)
	_distancia_superficie = maxf(0.0, dist_centro - radio_p)

	# Rayo hacia el centro del planeta para medir distancia real al terreno con colisión
	var up_planeta := (global_position - mas_cercano.global_position).normalized()
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position - up_planeta * 60.0)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var hit := space_state.intersect_ray(query)
	if not hit.is_empty():
		_distancia_suelo_rayo = global_position.distance_to(hit.position)
	else:
		_distancia_suelo_rayo = INF

	_puede_aterrizar = (_distancia_suelo_rayo < 45.0 or _distancia_superficie < 45.0) and _vel_actual < 50.0


func _obtener_up_planeta() -> Vector3:
	var mas_cercano: Node3D = _planeta_cercano()
	if mas_cercano:
		return (global_position - mas_cercano.global_position).normalized()
	return Vector3.UP


func _planeta_cercano() -> Node3D:
	var mejor: Node3D = null
	var d_min := INF
	for p in get_tree().get_nodes_in_group("cuerpos"):
		var d: float = global_position.distance_to(p.global_position)
		if d < d_min:
			d_min = d
			mejor = p
	return mejor


func _actualizar_efectos_motor(intensidad: float) -> void:
	var escala_z := lerpf(0.1, 2.6 if _usando_boost else 1.5, clampf(intensidad, 0.0, 1.0))
	var visible_fuego := intensidad > 0.05
	if fuego_izq:
		fuego_izq.visible = visible_fuego
		fuego_izq.scale = Vector3(1.0, escala_z, 1.0)
	if fuego_der:
		fuego_der.visible = visible_fuego
		fuego_der.scale = Vector3(1.0, escala_z, 1.0)


func _actualizar_camara(delta: float) -> void:
	if spring_arm == null or camara == null:
		return

	var target_dist: float = 10.0 + (_vel_actual * 0.035)
	if _usando_boost:
		target_dist += 3.0
	spring_arm.spring_length = lerpf(spring_arm.spring_length, target_dist, 5.0 * delta)

	var target_fov: float = 75.0
	if _usando_boost:
		target_fov = 100.0
	elif _vel_actual > 25.0:
		target_fov = 85.0
	camara.fov = lerpf(camara.fov, target_fov, 4.0 * delta)


func _actualizar_hud() -> void:
	if hud == null:
		return
	if conductor == null:
		hud.mostrar(false)
		return

	hud.mostrar(true)
	var txt_estado: String = "ESPACIO"
	match estado:
		EstadoNave.ATERRIZADO:
			txt_estado = "ATERRIZADO ([W] Despegar | [E]/[V] Bajar)"
		EstadoNave.DESPEGANDO:
			txt_estado = "DESPEGANDO..."
		EstadoNave.ATERRIZANDO:
			txt_estado = "ATERRIZANDO..."
		EstadoNave.VUELO_AVION:
			txt_estado = "ATMÓSFERA"
		EstadoNave.VUELO_ESPACIO:
			txt_estado = "ESPACIO EXTERIOR"

	hud.actualizar_datos(_vel_actual, _boost_actual / BOOST_MAX, txt_estado, _puede_aterrizar and (estado == EstadoNave.VUELO_AVION or estado == EstadoNave.VUELO_ESPACIO))


## Salto orbital (llamado desde MenuViaje con tecla M)
func viajar_a(destino: Node3D) -> void:
	var dir := (global_position - destino.global_position)
	if dir.length_squared() < 1.0:
		dir = Vector3(0.3, 1.0, 0.1)
	dir = dir.normalized()
	var radio_d: float = destino.radio if "radio" in destino else 250.0
	global_position = destino.global_position + dir * radio_d * 2.2
	velocity = Vector3.ZERO
	_vel_actual = 0.0
	_potencia = 0.0
	estado = EstadoNave.VUELO_ESPACIO

	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	look_at(destino.global_position, up)
