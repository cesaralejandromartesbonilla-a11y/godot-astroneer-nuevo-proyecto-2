extends StaticBody3D

# Cápsula de aterrizaje (F2): fuente inicial de oxígeno + punto de respawn.
# Se coloca sola sobre el terreno debajo de drop_origin (espera a que el
# collider del terreno exista alrededor del spawn).

const O2_RADIUS := 15.0

@export var drop_origin := Vector3(0, 320, 0)

var _attempts := 0
var _placed := false


func _ready() -> void:
	# Intentar cada 20 frames hasta 60 intentos (~20 s)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if _placed:
		set_physics_process(false)
		return
	_attempts += 1
	# El collider del terreno tarda en generarse alrededor del spawn:
	# esperar ~2 s antes del primer intento y reintentar cada segundo.
	if _attempts < 120 or _attempts % 60 != 0:
		return
	if _attempts > 900:
		push_warning("Capsula: no encontró terreno; queda en drop_origin")
		_finish(drop_origin)
		return

	# Raycast hacia abajo, excluyendo al jugador y saltando obstáculos
	# (cristales de mineral, items...) hasta dar con el terreno real.
	var space_state := get_world_3d().direct_space_state
	var exclude_rids: Array[RID] = []
	var player := get_tree().get_first_node_in_group("player")
	if player is CollisionObject3D:
		exclude_rids.append(player.get_rid())
	var from := drop_origin
	for i in 6:
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 200.0)
		query.exclude = exclude_rids
		var hit := space_state.intersect_ray(query)
		if hit.is_empty():
			return
		if hit.collider is VoxelLodTerrain:
			_finish(hit.position)
			return
		from = hit.position + Vector3.DOWN * 0.2


const DEPOSIT_SCENE := preload("res://escenas/planeta/ore_deposit.tscn")


func _finish(ground_pos: Vector3) -> void:
	_placed = true
	global_position = ground_pos
	var net := get_tree().get_first_node_in_group("oxygen_network")
	if net:
		net.register_source(self, O2_RADIUS)
	# La cápsula también gotea energía a la base (diseño F3: base semilla)
	var base := get_tree().get_first_node_in_group("base_core")
	if base:
		base.registrar_fuente(self, 0.5, false)
	$Marker3D.add_to_group("respawn_point")
	_garantizar_cobre_semilla(ground_pos)


func _garantizar_cobre_semilla(ground_pos: Vector3) -> void:
	# Verificar si ya existe un depósito de cobre en un radio de 45m
	for dep in get_tree().get_nodes_in_group("ore_deposits"):
		if not is_instance_valid(dep):
			continue
		if dep.get("ore_id") == 2 and dep.global_position.distance_to(ground_pos) < 45.0:
			return

	var terra: Node3D = null
	for p in get_tree().get_nodes_in_group("planetas"):
		if p.name == "Terra" or p.get("nombre") == "Terra":
			terra = p
			break
	if terra == null:
		terra = get_tree().get_first_node_in_group("planetas")

	var col_cobre := Color(0.72, 0.45, 0.2, 1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col_cobre
	mat.emission_enabled = true
	mat.emission = col_cobre * 0.6
	mat.roughness = 0.4

	var space_state := get_world_3d().direct_space_state
	var offsets := [Vector3(22.0, 0.0, 12.0), Vector3(24.5, 0.0, 14.0), Vector3(21.0, 0.0, 15.5)]

	for offset in offsets:
		var dep = DEPOSIT_SCENE.instantiate()
		dep.ore_id = 2
		var pos_candidata = ground_pos + offset
		var ray_from = pos_candidata + Vector3.UP * 40.0
		var ray_to = pos_candidata + Vector3.DOWN * 40.0
		var query = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
		var hit = space_state.intersect_ray(query)
		var spawn_pos = hit.position if not hit.is_empty() else pos_candidata

		if terra:
			terra.add_child(dep)
		else:
			get_tree().current_scene.add_child(dep)

		dep.global_position = spawn_pos - Vector3.UP * 0.2
		for c in dep.get_children():
			if c is MeshInstance3D:
				c.material_override = mat

	print("Capsula: veta de cobre semilla colocada a ~25m del spawn")
