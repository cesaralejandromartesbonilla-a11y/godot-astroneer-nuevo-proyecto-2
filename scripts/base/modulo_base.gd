class_name ModuloBase
extends StaticBody3D

# Base para módulos de la base (F3/Opción B): se colocan solos al lado de la cápsula,
# alineados con el "up" del planeta, cuando la cápsula termina de asentarse.
# Proyecta un cable de energía amarillo que lo interconecta con la cápsula central.

@export var lado := 1        # 1 = un costado de la cápsula, -1 = el otro
@export var distancia := 4.5
@export var angulo_deg := 0.0 # rotación angular en grados alrededor del eje Up

var _colocado := false
var _cable_energia: MeshInstance3D
var _mat_cable: StandardMaterial3D
var _capsula_ref: Node3D = null


func _physics_process(_delta: float) -> void:
	if _colocado:
		set_physics_process(false)
		return
	var cap := get_tree().get_first_node_in_group("capsula") as Node3D
	if cap == null or not cap.get("_placed"):
		return
	var up: Vector3 = cap.global_position.normalized()
	var t: Vector3 = Vector3.RIGHT.slide(up)
	if t.length_squared() < 0.01:
		t = Vector3.FORWARD.slide(up)
	t = t.normalized()
	if absf(angulo_deg) > 0.01:
		t = t.rotated(up, deg_to_rad(angulo_deg))
	t = t * distancia * lado
	global_position = cap.global_position + t
	global_basis = Basis.looking_at(t.normalized(), up)
	_colocado = true
	_capsula_ref = cap
	_crear_cable_energia()


func _crear_cable_energia() -> void:
	if _capsula_ref == null:
		return
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
	_mat_cable.emission = Color(0.9, 0.65, 0.05)
	_mat_cable.emission_energy_multiplier = 1.5
	_mat_cable.roughness = 0.3
	_cable_energia.material_override = _mat_cable
	add_child(_cable_energia)

	var p_origen := global_position + Vector3.UP * 0.15
	var p_destino := _capsula_ref.global_position + Vector3.UP * 0.25
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
