extends Node3D

# Coloca depósitos de mineral visibles (cristales 3D) sobre la superficie del
# planeta, en ubicaciones aproximadas de las vetas. Determinista: misma seed →
# mismos depósitos (la superficie se calcula con los mismos ruidos del generador).

const DEPOSIT_SCENE := preload("res://escenas/planeta/ore_deposit.tscn")
const PIEDRA_SCENE := preload("res://escenas/planeta/piedra_investigacion.tscn")

@export var terrain_node: VoxelLodTerrain
@export var ore_catalog: Array[RecursoData] = []
@export var sites := 600

# Debe coincidir con planeta_01.tres: montañas (nodo 9, b=40) y rugosidad (nodo 15, b=3)
const MOUNTAIN_AMP := 40.0
const ROUGHNESS_AMP := 3.0
const PLANET_RADIUS := 250.0

# Umbral de "aquí debajo hay veta" — algo más bajo que el de minado para que
# los depósitos sean más frecuentes que las vetas exactas.
const DEPOSIT_THRESHOLD := 0.66

# Profundidad de sondeo bajo la superficie por mineral (aprox. centro de su banda)
const PROBE_DEPTHS := {2: 20.0, 3: 55.0, 4: 95.0}

var _mountains: ZN_FastNoiseLite
var _roughness: ZN_FastNoiseLite
var _ore_field := OreField.new()


func _ready() -> void:
	# Ruidos del generador del terreno: las MISMAS instancias y seeds que produjeron
	# las montañas reales, así la superficie calculada coincide con la generada.
	var gen := terrain_node.generator as VoxelGeneratorGraph
	if gen:
		var gd = gen._get_graph_data()
		var nodes = gd["nodes"]
		if nodes.has("7"):
			_mountains = nodes["7"]["noise"]
		if nodes.has("14"):
			_roughness = nodes["14"]["noise"]
	_ore_field.setup(Global.world_seed, PLANET_RADIUS)
	_place_deposits()


func _sdf(pos: Vector3) -> float:
	var v := pos.length() - PLANET_RADIUS
	if _mountains:
		v += _mountains.get_noise_3dv(pos) * MOUNTAIN_AMP
	if _roughness:
		v += _roughness.get_noise_3dv(pos) * ROUGHNESS_AMP
	return v


func _surface_point(dir: Vector3) -> Vector3:
	# Escaneo radial de fuera hacia dentro hasta cruzar la superficie (SDF<0)
	for r in range(330, 200, -1):
		var p := dir * float(r)
		if _sdf(p) < 0.0:
			return p
	return dir * 230.0


func _place_deposits() -> void:
	var golden := PI * (1.0 + sqrt(5.0))
	var count := 0
	var piedras := 0
	for i in sites:
		var y := 1.0 - 2.0 * (float(i) + 0.5) / float(sites)
		var rad := sqrt(maxf(0.0, 1.0 - y * y))
		var th := golden * float(i)
		var dir := Vector3(rad * cos(th), y, rad * sin(th)).normalized()

		var surf := _surface_point(dir)

		var type := 0
		for ore_id in [2, 3, 4]:
			var depth: float = PROBE_DEPTHS[ore_id]
			var sample := surf - dir * depth
			if _ore_field.get_ore_signal(sample, ore_id) > DEPOSIT_THRESHOLD:
				type = ore_id
				break
		if type == 0:
			# Piedras de investigación: las 3 primeras van junto al spawn (los
			# primeros sitios de la fib-sphere están junto al polo = cápsula) y
			# luego ~1 de cada 18 sitios sin depósito.
			if piedras < 3 or i % 18 == 0:
				var piedra := PIEDRA_SCENE.instantiate()
				# Congeladas al colocar: el collider del terreno aún no existe
				# y caerían al núcleo. Se reactivan al soltarlas tras cogerlas.
				piedra.freeze = true
				add_child(piedra)
				piedra.global_position = surf + dir * 0.3
				piedras += 1
				count += 1
			continue

		var dep := DEPOSIT_SCENE.instantiate()
		dep.ore_id = type
		add_child(dep)
		# Hundido medio metro en el terreno: los cristales "brotan", no flotan
		dep.global_position = surf - dir * 0.5
		_apply_material(dep, _color_for(type))
		count += 1
	print("OreDeposits: %d depósitos colocados en %d sitios" % [count, sites])


func _color_for(ore_id: int) -> Color:
	for ore in ore_catalog:
		if ore.id == ore_id:
			return ore.color_albedo
	return Color(1, 1, 1)


func _apply_material(dep: Node3D, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.6
	mat.roughness = 0.4
	for c in dep.get_children():
		if c is MeshInstance3D:
			c.material_override = mat
