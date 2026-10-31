extends StaticBody3D

# Tether (F2/Opción B): extiende la red de oxígeno 10 unidades a la redonda.
# Solo transmite O2 si está encadenado a una fuente primaria (cápsula/rover/shuttle).
# Proyecta un cable de luz cian hacia el nodo padre del que recibe oxígeno.

const O2_RADIUS := 10.0

var esta_conectado := false
var nodo_padre: Node3D = null

@onready var bombilla: MeshInstance3D = $Bombilla

var _cable_mesh: MeshInstance3D
var _mat_encendido: StandardMaterial3D
var _mat_apagado: StandardMaterial3D
var _mat_cable: StandardMaterial3D


func _ready() -> void:
	add_to_group("tethers")
	_crear_materiales()
	_crear_cable_mesh()
	actualizar_conexion(false, null)
	var net := get_tree().get_first_node_in_group("oxygen_network")
	if net:
		net.register_source(self, O2_RADIUS)


func _exit_tree() -> void:
	var net := get_tree().get_first_node_in_group("oxygen_network")
	if net:
		net.unregister_source(self)


func es_tether() -> bool:
	return true


func _crear_materiales() -> void:
	_mat_encendido = StandardMaterial3D.new()
	_mat_encendido.albedo_color = Color(0.3, 0.85, 1.0)
	_mat_encendido.emission_enabled = true
	_mat_encendido.emission = Color(0.2, 0.7, 1.0)
	_mat_encendido.emission_energy_multiplier = 2.0

	_mat_apagado = StandardMaterial3D.new()
	_mat_apagado.albedo_color = Color(0.25, 0.25, 0.25)
	_mat_apagado.roughness = 0.8
	_mat_apagado.emission_enabled = false

	_mat_cable = StandardMaterial3D.new()
	_mat_cable.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_cable.albedo_color = Color(0.25, 0.85, 1.0, 0.85)
	_mat_cable.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _crear_cable_mesh() -> void:
	_cable_mesh = MeshInstance3D.new()
	_cable_mesh.top_level = true
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.025
	cyl.bottom_radius = 0.025
	cyl.height = 1.0
	cyl.radial_segments = 6
	_cable_mesh.mesh = cyl
	_cable_mesh.material_override = _mat_cable
	_cable_mesh.visible = false
	add_child(_cable_mesh)


func actualizar_conexion(conectado: bool, padre: Node3D) -> void:
	esta_conectado = conectado
	nodo_padre = padre

	if bombilla:
		bombilla.material_override = _mat_encendido if esta_conectado else _mat_apagado

	if not esta_conectado or nodo_padre == null or not is_instance_valid(nodo_padre):
		if _cable_mesh:
			_cable_mesh.visible = false
		return

	_actualizar_cable()


func _process(_delta: float) -> void:
	if esta_conectado and nodo_padre != null and is_instance_valid(nodo_padre):
		_actualizar_cable()


func _actualizar_cable() -> void:
	if _cable_mesh == null or nodo_padre == null or not is_instance_valid(nodo_padre):
		return

	var p_origen: Vector3 = bombilla.global_position if bombilla else global_position + Vector3.UP * 1.65
	var p_destino: Vector3 = nodo_padre.global_position
	if nodo_padre.has_node("Bombilla"):
		p_destino = nodo_padre.get_node("Bombilla").global_position
	elif nodo_padre.has_node("Marker3D"):
		p_destino = nodo_padre.get_node("Marker3D").global_position
	else:
		p_destino = nodo_padre.global_position + Vector3.UP * 1.5

	var diff := p_destino - p_origen
	var dist := diff.length()
	if dist < 0.1:
		_cable_mesh.visible = false
		return

	_cable_mesh.visible = true
	var mid := (p_origen + p_destino) * 0.5
	var dir_y := diff.normalized()

	var arbitrary := Vector3.FORWARD if absf(dir_y.dot(Vector3.UP)) > 0.85 else Vector3.UP
	var dir_x := dir_y.cross(arbitrary).normalized()
	var dir_z := dir_x.cross(dir_y).normalized()

	_cable_mesh.global_transform.basis = Basis(dir_x, dir_y * dist, dir_z)
	_cable_mesh.global_position = mid
