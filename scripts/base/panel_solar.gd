extends StaticBody3D

# Panel solar colocable (F3/Opción B): +1/s de energía a la base de día,
# y además extiende la red de oxígeno (simplificación con valor de juego).
# Dibuja un cable de energía amarillo conectado a la base/cápsula más cercana.

const RATE := 1.0
const O2_RADIUS := 10.0
const ENERGIA_LINK_MAX_DIST := 30.0

var _cable_energia: MeshInstance3D
var _mat_cable: StandardMaterial3D
var _nodo_destino: Node3D = null


func _ready() -> void:
	var base := get_tree().get_first_node_in_group("base_core")
	if base:
		base.registrar_fuente(self, RATE, true)
	var net := get_tree().get_first_node_in_group("oxygen_network")
	if net:
		net.register_source(self, O2_RADIUS)

	_crear_cable_energia()
	_buscar_conexion_base()


func _exit_tree() -> void:
	var base := get_tree().get_first_node_in_group("base_core")
	if base:
		base.desregistrar(self)
	var net := get_tree().get_first_node_in_group("oxygen_network")
	if net:
		net.unregister_source(self)


func _crear_cable_energia() -> void:
	_cable_energia = MeshInstance3D.new()
	_cable_energia.top_level = true
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.035
	cyl.height = 1.0
	cyl.radial_segments = 6
	_cable_energia.mesh = cyl

	_mat_cable = StandardMaterial3D.new()
	_mat_cable.albedo_color = Color(1.0, 0.75, 0.1)
	_mat_cable.emission_enabled = true
	_mat_cable.emission = Color(0.95, 0.65, 0.05)
	_mat_cable.emission_energy_multiplier = 2.0
	_mat_cable.roughness = 0.3
	_cable_energia.material_override = _mat_cable
	_cable_energia.visible = false
	add_child(_cable_energia)


func _buscar_conexion_base() -> void:
	var capsula := get_tree().get_first_node_in_group("capsula") as Node3D
	if capsula and global_position.distance_to(capsula.global_position) <= ENERGIA_LINK_MAX_DIST:
		_nodo_destino = capsula
	else:
		for b in get_tree().get_nodes_in_group("base_core"):
			if b is Node3D and global_position.distance_to(b.global_position) <= ENERGIA_LINK_MAX_DIST:
				_nodo_destino = b
				break

	if _nodo_destino:
		_actualizar_cable_posicion()


func _process(_delta: float) -> void:
	if _nodo_destino == null or not is_instance_valid(_nodo_destino):
		if _cable_energia:
			_cable_energia.visible = false
		return

	var dn := get_tree().get_first_node_in_group("day_night")
	var es_dia: bool = dn == null or dn.is_day()
	if _mat_cable:
		_mat_cable.emission_energy_multiplier = 2.0 if es_dia else 0.25
		_mat_cable.albedo_color = Color(1.0, 0.75, 0.1) if es_dia else Color(0.35, 0.28, 0.1)


func _actualizar_cable_posicion() -> void:
	if _cable_energia == null or _nodo_destino == null or not is_instance_valid(_nodo_destino):
		return

	var p_origen := global_position + Vector3.UP * 0.2
	var p_destino := _nodo_destino.global_position + Vector3.UP * 0.3
	var diff := p_destino - p_origen
	var dist := diff.length()
	if dist < 0.2:
		_cable_energia.visible = false
		return

	_cable_energia.visible = true
	var mid := (p_origen + p_destino) * 0.5
	var dir_y := diff.normalized()

	var arbitrary := Vector3.FORWARD if absf(dir_y.dot(Vector3.UP)) > 0.85 else Vector3.UP
	var dir_x := dir_y.cross(arbitrary).normalized()
	var dir_z := dir_x.cross(dir_y).normalized()

	_cable_energia.global_transform.basis = Basis(dir_x, dir_y * dist, dir_z)
	_cable_energia.global_position = mid
