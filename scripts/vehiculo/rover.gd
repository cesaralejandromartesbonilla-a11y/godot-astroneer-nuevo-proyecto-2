extends VehicleBody3D

# Rover (F4): tracción a las ruedas traseras, dirección a las delanteras,
# alineado al "up" del planeta (la gravedad la da el Area3D del planeta).
# Batería propia: drena conduciendo, recarga aparcado junto a la cápsula.
# Mientras hay conductor, el rover actúa como tether con ruedas (O2 r=10).

signal bateria_changed(value: float, max_value: float)

const O2_RADIUS := 10.0
const FUERZA_MOTOR := 400.0
const GIRO := 0.5
const VELOCIDAD_MAX := 12.0
const DRENAJE := 2.0
const RECARGA := 10.0
const RADIO_RECARGA := 15.0
const GANANCIA_ALINEACION := 4.0

@export var bateria_max := 100.0
var bateria := 100.0
var conductor: Node3D = null

var _cam_rot_h := 0.0
var _cam_rot_v := 0.0
var _rotando_camara := false

@onready var rueda_di: VehicleWheel3D = $RuedaDelanteIzq
@onready var rueda_dd: VehicleWheel3D = $RuedaDelanteDer
@onready var rueda_ti: VehicleWheel3D = $RuedaAtrasIzq
@onready var rueda_td: VehicleWheel3D = $RuedaAtrasDer
@onready var spring_arm: SpringArm3D = $Camara
@onready var camara: Camera3D = $Camara/Camera3D


func _ready() -> void:
	var net := get_tree().get_first_node_in_group("oxygen_network")
	if net:
		net.register_source(self, O2_RADIUS)
	spring_arm.add_excluded_object(get_rid())


func _physics_process(delta: float) -> void:
	_alinear_al_planeta(delta)
	_gestionar_bateria(delta)
	_leer_conduccion(delta)

	if linear_velocity.length() > VELOCIDAD_MAX:
		linear_velocity = linear_velocity.normalized() * VELOCIDAD_MAX

	# Rescate si cae al núcleo por un agujero profundo
	if global_position.length() < 150.0:
		var cap := get_tree().get_first_node_in_group("capsula") as Node3D
		if cap:
			global_position = cap.global_position + cap.global_position.normalized() * 8.0
			linear_velocity = Vector3.ZERO


## Aplica motor/dirección. Ignora el acelerador sin conductor o sin batería.
## Sin acelerar frena, y aparcado (sin conductor) frena fuerte: el rover no
## debe deslizarse al generarlo en una cuesta.
## Ojo al signo: en VehicleBody3D el engine_force positivo empuja hacia +Z
## (la parte trasera), de ahí el negativo para que W sea "adelante" (-Z).
func aplicar_motor(acelerar: float, girar: float) -> void:
	if conductor == null or bateria <= 0.0:
		acelerar = 0.0
	rueda_ti.engine_force = -acelerar * FUERZA_MOTOR
	rueda_td.engine_force = -acelerar * FUERZA_MOTOR
	rueda_di.steering = girar * GIRO
	rueda_dd.steering = girar * GIRO
	var freno := 8.0 if absf(acelerar) < 0.05 else 0.0
	var aparcado := 25.0 if conductor == null else 0.0
	rueda_ti.brake = freno + aparcado
	rueda_td.brake = freno + aparcado
	rueda_di.brake = aparcado
	rueda_dd.brake = aparcado


func _leer_conduccion(delta: float) -> void:
	if conductor == null:
		aplicar_motor(0.0, 0.0)
		return
	# Con consola/menús abiertos, el rover tampoco responde
	if Global.ui_abierta > 0:
		aplicar_motor(0.0, 0.0)
		return
	var acelerar := Input.get_axis("press_s", "press_w")
	var girar := Input.get_axis("press_d", "press_a")
	aplicar_motor(acelerar, girar)
	if absf(acelerar) > 0.1:
		_set_bateria(bateria - DRENAJE * delta)


func _alinear_al_planeta(delta: float) -> void:
	var centro := _centro_planeta()
	var up_planeta: Vector3 = (global_position - centro).normalized()
	var up_actual: Vector3 = global_transform.basis.y
	var eje := up_actual.cross(up_planeta)
	if eje.length_squared() > 0.000001:
		angular_velocity += eje.normalized() * up_actual.angle_to(up_planeta) * GANANCIA_ALINEACION * delta


func _gestionar_bateria(delta: float) -> void:
	if bateria >= bateria_max:
		return
	var cap := get_tree().get_first_node_in_group("capsula") as Node3D
	if cap and global_position.distance_to(cap.global_position) <= RADIO_RECARGA:
		_set_bateria(bateria + RECARGA * delta)


func _set_bateria(v: float) -> void:
	var nv := clampf(v, 0.0, bateria_max)
	if nv == bateria:
		return
	bateria = nv
	bateria_changed.emit(bateria, bateria_max)


func _centro_planeta() -> Vector3:
	var c := get_tree().get_first_node_in_group("planetas") as Node3D
	return c.global_position if c else Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	# Cámara persecutora: mismo esquema que el player (botón central + rueda)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_rotando_camara = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_arm.spring_length = clampf(spring_arm.spring_length - 0.5, 2.0, 12.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_arm.spring_length = clampf(spring_arm.spring_length + 0.5, 2.0, 12.0)
	elif event is InputEventMouseMotion and _rotando_camara:
		_cam_rot_h -= event.relative.x * 0.002
		_cam_rot_v = clampf(_cam_rot_v - event.relative.y * 0.002, -1.2, 0.7)
		spring_arm.rotation = Vector3(_cam_rot_v, _cam_rot_h, 0)
