extends Node3D

# Cuerpo planetario (F5): empaqueta terreno voxel + gravedad + campo de vetas
# + depósitos/piedras, todo construido por código y parametrizado por exports.
# La posición del nodo = centro del planeta en el mundo.
#
# OJO (lección F4): el generador del terreno trabaja en coords LOCALES al nodo;
# el análisis analítico de superficie también debe muestrear los ruidos en
# local (world - global_position) o los depósitos flotan.

@export var planeta_id := 0
@export var nombre := "Planeta"
@export var radio := 250.0
@export var generador: VoxelGeneratorGraph
@export var ore_catalog: Array[RecursoData] = []
# { ore_id: {"band": Vector2(prof_min, prof_max), "wl": float} } — vacío = Terra
@export var ore_config: Dictionary = {}
@export var col_suelo := Color(0.25, 0.5, 0.15)
@export var col_roca := Color(0.7, 0.3, 0.1)
@export var col_mena_r := Color(0.72, 0.45, 0.20)
@export var col_mena_g := Color(0.35, 0.35, 0.35)
@export var col_mena_b := Color(0.75, 0.88, 0.95)
@export var col_halo := Color(0.3, 0.7, 1.0)
@export var atmo_cenit := Color(0.2, 0.52, 0.95)
@export var atmo_horizonte := Color(0.55, 0.82, 0.98)
@export var piedra_bytes := 300
@export var sitios := 600
@export var deposit_threshold := 0.66
# Deben coincidir con el .tres del generador (amplitudes de montañas/rugosidad)
@export var montanas_amp := 40.0
@export var rugosidad_amp := 3.0
@export var bounds_half := Vector3(512, 576, 512)

const SHADER := preload("res://shaders/planeta.gdshader")
const IMPOSTOR_SHADER := preload("res://shaders/impostor_planeta.gdshader")
const DEPOSIT_SCENE := preload("res://escenas/planeta/ore_deposit.tscn")
const PIEDRA_SCENE := preload("res://escenas/planeta/piedra_investigacion.tscn")
const GATEWAY_CHAMBER_SCENE := preload("res://escenas/planeta/gateway_chamber.tscn")
const GATEWAY_ENGINE_SCENE := preload("res://escenas/planeta/gateway_engine.tscn")
const FLORA_SCENE := preload("res://escenas/planeta/flora_peligrosa.tscn")
const ARBOL_TERRA_SCENE := preload("res://escenas/planeta/arbol_terra.tscn")
const ARBOL_ARIDO_SCENE := preload("res://escenas/planeta/arbol_arido.tscn")
const ARBOL_HIELO_SCENE := preload("res://escenas/planeta/arbol_hielo.tscn")
const FLORA_SPITTER_SCENE := preload("res://escenas/planeta/flora_spitter.tscn")
const FLORA_GAS_SCENE := preload("res://escenas/planeta/flora_gas.tscn")
const FLORA_MINA_SCENE := preload("res://escenas/planeta/flora_mina.tscn")
const SISTEMA_TORMENTAS_SCRIPT := preload("res://scripts/planeta/sistema_tormentas.gd")

var terrain: VoxelLodTerrain
var ore_field := OreField.new()
var _impostor: MeshInstance3D = null

var _montanas: ZN_FastNoiseLite
var _rugosidad: ZN_FastNoiseLite
var _ore_map: Dictionary = {}


func _ready() -> void:
	add_to_group("cuerpos")
	add_to_group("planetas")
	_extraer_ruidos()
	_construir_terreno()
	_construir_gravedad()
	_construir_impostor()
	_rebuild_ore_map()
	ore_field.setup(Global.world_seed + planeta_id * 1000, radio, ore_config,
			global_position - bounds_half, bounds_half * 2.0)
	_aplicar_textura()
	_colocar_senales()
	_construir_gateways_y_nucleo()

	# Sistema de tormentas dinámicas (Fase 7)
	var sis_tormentas: Node = SISTEMA_TORMENTAS_SCRIPT.new()
	sis_tormentas.name = "SistemaTormentas"
	add_child(sis_tormentas)


func centro() -> Vector3:
	return global_position

func _process(_delta: float) -> void:
	if _impostor == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var dist := global_position.distance_to(cam.global_position)
	# Si estamos a menos de 2.2 radios, el terreno voxel de superficie toma el control
	# Si estamos lejos (en órbita o en otro planeta), mostramos el globo impostor en el firmamento
	_impostor.visible = (dist >= radio * 2.2)


func _construir_impostor() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = radio
	sphere.height = radio * 2.0
	sphere.radial_segments = 48
	sphere.rings = 24

	var mat := ShaderMaterial.new()
	mat.shader = IMPOSTOR_SHADER
	mat.set_shader_parameter("col_suelo", col_suelo)
	mat.set_shader_parameter("col_roca", col_roca)
	mat.set_shader_parameter("col_halo", col_halo)
	mat.set_shader_parameter("halo_intensidad", 1.2)

	_impostor = MeshInstance3D.new()
	_impostor.name = "ImpostorPlaneta"
	_impostor.mesh = sphere
	_impostor.material_override = mat
	_impostor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_impostor)



## Recurso (o null) si hay veta de mineral en esa posición mundial.
func minar_en(world_pos: Vector3) -> RecursoData:
	var ore_id := ore_field.get_ore_id(world_pos, global_position)
	return _ore_map.get(ore_id)


## Asigna la db de terreno (guardado). Copia la actual si cambia de archivo.
func asignar_db(ruta: String) -> void:
	if terrain == null or not (terrain.stream is VoxelStreamSQLite):
		return
	var st: VoxelStreamSQLite = terrain.stream
	if st.database_path == ruta:
		return
	terrain.save_modified_blocks()  # vaciar ediciones pendientes antes de copiar
	if FileAccess.file_exists(st.database_path):
		DirAccess.copy_absolute(
			ProjectSettings.globalize_path(st.database_path),
			ProjectSettings.globalize_path(ruta))
	st.database_path = ruta


func _extraer_ruidos() -> void:
	if generador == null:
		return
	var gd = generador._get_graph_data()
	if gd == null or not gd.has("nodes"):
		return
	var nodes = gd["nodes"]
	if nodes.has("7"):
		_montanas = nodes["7"]["noise"]
	if nodes.has("14"):
		_rugosidad = nodes["14"]["noise"]


func _construir_terreno() -> void:
	terrain = VoxelLodTerrain.new()
	terrain.name = "Terreno"
	terrain.generator = generador
	terrain.voxel_bounds = AABB(-bounds_half, bounds_half * 2.0)
	var mesher := VoxelMesherTransvoxel.new()
	terrain.mesher = mesher
	var stream := VoxelStreamSQLite.new()
	# db temporal de sesión; al guardar/cargar se apunta al slot (asignar_db)
	stream.database_path = "user://temp_p%d.db" % planeta_id
	terrain.stream = stream

	# Rendimiento dinámico de LOD (Fase 6)
	var lod_dist: float = 48.0
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("config_get"):
		lod_dist = float(sm.config_get("video", "lod_distance", 48.0))
	terrain.lod_distance = lod_dist

	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("centro", global_position)
	mat.set_shader_parameter("radio", radio)
	mat.set_shader_parameter("bounds_pos", global_position - bounds_half)
	mat.set_shader_parameter("bounds_size", bounds_half * 2.0)
	mat.set_shader_parameter("col_suelo", Vector3(col_suelo.r, col_suelo.g, col_suelo.b))
	mat.set_shader_parameter("col_roca", Vector3(col_roca.r, col_roca.g, col_roca.b))
	mat.set_shader_parameter("col_r", Vector3(col_mena_r.r, col_mena_r.g, col_mena_r.b))
	mat.set_shader_parameter("col_g", Vector3(col_mena_g.r, col_mena_g.g, col_mena_g.b))
	mat.set_shader_parameter("col_b", Vector3(col_mena_b.r, col_mena_b.g, col_mena_b.b))
	terrain.material = mat
	add_child(terrain)


func _construir_gravedad() -> void:
	var area := Area3D.new()
	area.name = "Gravedad"
	area.gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE
	area.gravity_point = true
	area.gravity_point_center = Vector3.ZERO  # local => centro del planeta
	area.gravity = 20.0
	area.monitoring = false
	area.monitorable = false
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = radio * 2.5
	cs.shape = sh
	area.add_child(cs)
	add_child(area)


func _rebuild_ore_map() -> void:
	_ore_map.clear()
	for ore in ore_catalog:
		_ore_map[ore.id] = ore


func _aplicar_textura() -> void:
	if terrain and terrain.material is ShaderMaterial:
		var tex := ore_field.build_texture_3d()
		if tex:
			terrain.material.set_shader_parameter("ore_tex", tex)


## SDF analítico en coords mundiales (ruidos muestreados en LOCAL).
func _sdf(world: Vector3) -> float:
	var local := world - global_position
	var v := local.length() - radio
	if _montanas:
		v += _montanas.get_noise_3dv(local) * montanas_amp
	if _rugosidad:
		v += _rugosidad.get_noise_3dv(local) * rugosidad_amp
	return v


func _surface_point(dir: Vector3) -> Vector3:
	for r in range(int(radio) + 80, int(radio) - 60, -1):
		var p := global_position + dir * float(r)
		if _sdf(p) < 0.0:
			return p
	return global_position + dir * (radio - 30.0)


func _colocar_senales() -> void:
	var golden := PI * (1.0 + sqrt(5.0))
	var piedras := 0
	for i in maxi(1, sitios):
		var y := 1.0 - 2.0 * (float(i) + 0.5) / float(sitios)
		var rad := sqrt(maxf(0.0, 1.0 - y * y))
		var th := golden * float(i)
		var dir := Vector3(rad * cos(th), y, rad * sin(th)).normalized()

		var surf := _surface_point(dir)

		# ¿Hay veta (aprox) bajo la superficie? → cristal del color del mineral
		var tipo := 0
		for ore_id in ore_field._ids_por_prioridad():
			var band: Vector2 = ore_field.config[ore_id]["band"]
			var prof := (band.x + band.y) * 0.5
			var muestra := surf - dir * absf(prof)
			if ore_field.get_ore_signal(muestra, ore_id) > deposit_threshold:
				tipo = int(ore_id)
				break

		if tipo > 0:
			var dep := DEPOSIT_SCENE.instantiate()
			dep.ore_id = tipo
			add_child(dep)
			dep.global_position = surf - dir * 0.5
			_aplicar_material_deposito(dep, _color_de(tipo))
			_aplicar_culling_distancia(dep, radio * 3.2)
			continue

		# Piedras de investigación: en Terra las 3 primeras junto al spawn;
		# en todos los planetas ~1 de cada 18 sitios sin depósito.
		if (planeta_id == 0 and piedras < 3) or i % 18 == 0:
			var piedra := PIEDRA_SCENE.instantiate()
			piedra.freeze = true
			piedra.bytes_valor = piedra_bytes
			add_child(piedra)
			piedra.global_position = surf + dir * 0.3
			_aplicar_culling_distancia(piedra, radio * 3.2)
			piedras += 1
		# Flora peligrosa alienígena (Fases 7 y 8):
		# Spitter (catapulta), Gas (nube densa), Mina (bulbo volátil) y Clásica (esporas).
		# En Terra: muestras cerca de la base (sitios 4=Spitter, 7=Gas, 11=Mina).
		# En todos los mundos: 1 de cada 8 sitios sin depósito alberga flora hostil.
		elif (planeta_id == 0 and i in [4, 7, 11]) or i % 8 == 0:
			var flora_escena: PackedScene = FLORA_SCENE
			if (planeta_id == 0 and i == 4) or i % 32 == 0:
				flora_escena = FLORA_SPITTER_SCENE
			elif (planeta_id == 0 and i == 7) or i % 24 == 0:
				flora_escena = FLORA_GAS_SCENE
			elif (planeta_id == 0 and i == 11) or i % 16 == 0:
				flora_escena = FLORA_MINA_SCENE

			var flora := flora_escena.instantiate()
			add_child(flora)
			var up_surf := dir
			var fwd := up_surf.cross(Vector3.UP)
			if fwd.length_squared() < 0.01:
				fwd = up_surf.cross(Vector3.RIGHT)
			fwd = fwd.normalized()
			var right := fwd.cross(up_surf).normalized()
			flora.global_basis = Basis(right, up_surf, fwd)
			flora.global_position = surf + up_surf * 0.15
			_aplicar_culling_distancia(flora, radio * 3.5)
		# Árboles alienígenas por bioma (Fase 8):
		# En Terra: bosques garantizados cerca de la base inicial (sitios 3, 5, 8, 10, 13, 17, 21).
		# En todos los mundos: 1 de cada 4 sitios restantes sin depósito alberga árboles nativos.
		elif (planeta_id == 0 and i in [3, 5, 8, 10, 13, 17, 21]) or i % 4 == 0:
			var arbol_escena: PackedScene
			match planeta_id:
				0: arbol_escena = ARBOL_TERRA_SCENE
				1: arbol_escena = ARBOL_ARIDO_SCENE
				2: arbol_escena = ARBOL_HIELO_SCENE
				_: arbol_escena = ARBOL_TERRA_SCENE
			var arbol := arbol_escena.instantiate()
			add_child(arbol)
			var up_a := dir
			var fwd_a := up_a.cross(Vector3.UP)
			if fwd_a.length_squared() < 0.01:
				fwd_a = up_a.cross(Vector3.RIGHT)
			fwd_a = fwd_a.normalized()
			var right_a := fwd_a.cross(up_a).normalized()
			arbol.global_basis = Basis(right_a, up_a, fwd_a)
			arbol.global_position = surf + up_a * 0.1
			_aplicar_culling_distancia(arbol, radio * 3.5)


func _color_de(tipo: int) -> Color:
	if tipo in _ore_map:
		return _ore_map[tipo].color_albedo
	match tipo:
		_: return Color(1, 1, 1)


func _aplicar_material_deposito(dep: Node3D, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.6
	mat.roughness = 0.4
	for c in dep.get_children():
		if c is MeshInstance3D:
			c.material_override = mat


func _aplicar_culling_distancia(nodo: Node, max_dist: float) -> void:
	if nodo is GeometryInstance3D:
		var geom := nodo as GeometryInstance3D
		geom.visibility_range_end = max_dist
		geom.visibility_range_end_margin = 50.0
		geom.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	for c in nodo.get_children():
		_aplicar_culling_distancia(c, max_dist)


func _construir_gateways_y_nucleo() -> void:
	# 1. Gateway Engine en el centro GEOMETRICO del planeta (posicion LOCAL = cero)
	var engine = GATEWAY_ENGINE_SCENE.instantiate()
	engine.planeta_id = planeta_id
	match planeta_id:
		0:
			engine.recurso_requerido_id = 23
			engine.nombre_recurso = "Cuarzo"
		1:
			engine.recurso_requerido_id = 5
			engine.nombre_recurso = "Titanio"
		2:
			engine.recurso_requerido_id = 6
			engine.nombre_recurso = "Criolita"
	add_child(engine)
	# IMPORTANTE: usar posicion LOCAL (0,0,0) para que quede siempre
	# en el centro geometrico del planeta, independientemente del transform global.
	engine.position = Vector3.ZERO

	# 2. Gateway Chamber monumental en la superficie
	# En Terra (planeta_id 0): situado a un ángulo de ~20° respecto al polo norte (~87m de arco),
	# de modo que se alce en el horizonte visible con su haz de 300m sin apiñarse contra la cápsula inicial.
	# En Árido e Hielo: colocados en latitudes accesibles con terreno firme.
	var dir_superficie: Vector3
	match planeta_id:
		0:
			dir_superficie = Vector3(0.342, 0.940, 0.0).normalized()  # Terra: ~87m al este del spawn
		1:
			dir_superficie = Vector3(0.25, 0.968, 0.0).normalized()   # Árido: latitud visible
		_:
			dir_superficie = Vector3(0.0, 0.968, 0.25).normalized()   # Hielo: latitud visible
	var pos_surf := _surface_point(dir_superficie)
	var chamber = GATEWAY_CHAMBER_SCENE.instantiate()
	add_child(chamber)

	var up: Vector3 = (pos_surf - global_position).normalized()
	var fwd: Vector3 = up.cross(Vector3.UP)
	if fwd.length_squared() < 0.01:
		fwd = up.cross(Vector3.RIGHT)
	fwd = fwd.normalized()
	var right: Vector3 = fwd.cross(up).normalized()
	chamber.global_basis = Basis(right, up, fwd)
	chamber.global_position = pos_surf

	# Interconectar destinos de teletransporte
	chamber.destino_nucleo = engine
	engine.destino_superficie = chamber
