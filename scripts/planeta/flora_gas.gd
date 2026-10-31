class_name FloraGas
extends Node3D

# FloraGas (Fase 8):
# Planta alienígena emisora de nubes de gas tóxico y esporas asfixiantes.
# Cuando el jugador ingresa a su radio perimetral (<6.5m), empieza a expulsar
# nubes de gas denso que drenan oxígeno a ritmo acelerado (26 O2/s).
# Se neutraliza excavando sus raíces con la Herramienta de Terreno.

const RECOMPENSA_SCENE := preload("res://escenas/planeta/piedra_investigacion.tscn")
const ORGANICO_SCENE := preload("res://escenas/planeta/ore_organico.tscn")

@export var radio_gas: float = 6.5
@export var dano_oxigeno_por_seg: float = 26.0
@export var bytes_recompensa: int = 420

var _neutralizada: bool = false
var _tiempo_vida: float = 0.0
var _suelo_confirmado: bool = false
var _tiempo_pulso: float = 0.0
var _jugador_en_gas: Node3D = null

@onready var bulbo_gas: MeshInstance3D = get_node_or_null("BulboGas")
@onready var luz_gas: OmniLight3D = get_node_or_null("LuzGas")
@onready var niebla_mesh: MeshInstance3D = get_node_or_null("NieblaGas")
@onready var area_gas: Area3D = get_node_or_null("AreaGas")
@onready var raycast_suelo: RayCast3D = get_node_or_null("RayCastSuelo")

var _mat_bulbo: StandardMaterial3D = null
var _mat_niebla: StandardMaterial3D = null


func _ready() -> void:
	add_to_group("flora_peligrosa")
	_crear_materiales()
	if area_gas:
		area_gas.body_entered.connect(_on_body_entered)
		area_gas.body_exited.connect(_on_body_exited)
	if raycast_suelo:
		raycast_suelo.collision_mask = 1
		raycast_suelo.enabled = true
		raycast_suelo.position = Vector3(0.0, 0.15, 0.0)
		raycast_suelo.target_position = Vector3(0.0, -0.6, 0.0)
		for c in find_children("*", "CollisionObject3D", true, false):
			raycast_suelo.add_exception(c)


func _crear_materiales() -> void:
	# Bulbo amarillo verdoso bio-químico
	_mat_bulbo = StandardMaterial3D.new()
	_mat_bulbo.albedo_color = Color(0.65, 0.75, 0.1)
	_mat_bulbo.roughness = 0.4
	_mat_bulbo.emission_enabled = true
	_mat_bulbo.emission = Color(0.7, 0.85, 0.1)
	_mat_bulbo.emission_energy_multiplier = 1.4
	if bulbo_gas:
		bulbo_gas.material_override = _mat_bulbo

	# Niebla semi-translúcida
	_mat_niebla = StandardMaterial3D.new()
	_mat_niebla.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_niebla.albedo_color = Color(0.7, 0.85, 0.15, 0.25)
	_mat_niebla.emission_enabled = true
	_mat_niebla.emission = Color(0.5, 0.75, 0.1)
	_mat_niebla.emission_energy_multiplier = 0.6
	_mat_niebla.cull_mode = BaseMaterial3D.CULL_DISABLED
	if niebla_mesh:
		niebla_mesh.material_override = _mat_niebla
		niebla_mesh.visible = false

	if luz_gas:
		luz_gas.light_color = Color(0.75, 0.9, 0.1)
		luz_gas.light_energy = 0.8
		luz_gas.omni_range = radio_gas + 2.0


func _physics_process(delta: float) -> void:
	if _neutralizada:
		return

	_tiempo_vida += delta
	_tiempo_pulso += delta * (8.0 if _jugador_en_gas else 2.5)

	# 1. Comprobación de raíces
	if raycast_suelo:
		if not _suelo_confirmado:
			if raycast_suelo.is_colliding():
				_suelo_confirmado = true
		else:
			if _tiempo_vida > 0.5 and not raycast_suelo.is_colliding():
				_neutralizar()
				return

	# 2. Pulsación visual y expansión de gas
	var pulso := sin(_tiempo_pulso)
	if bulbo_gas:
		var esc := 1.0 + pulso * (0.22 if _jugador_en_gas else 0.07)
		bulbo_gas.scale = Vector3.ONE * esc

	if _jugador_en_gas:
		if niebla_mesh:
			niebla_mesh.visible = true
			niebla_mesh.scale = Vector3.ONE * (1.0 + pulso * 0.12)
		if luz_gas:
			luz_gas.light_energy = 2.2 + pulso * 1.0

		# Drenaje activo de oxígeno del jugador
		if "stats" in _jugador_en_gas and _jugador_en_gas.stats != null:
			_jugador_en_gas.stats.consume_oxygen(dano_oxigeno_por_seg, delta)
	else:
		if niebla_mesh:
			niebla_mesh.visible = false
		if luz_gas:
			luz_gas.light_energy = 0.8 + pulso * 0.2


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_jugador_en_gas = body
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("mostrar_notificacion"):
			hud.mostrar_notificacion("¡GAS TOXICO DENSO! Drenaje critico de oxigeno")


func _on_body_exited(body: Node3D) -> void:
	if body == _jugador_en_gas:
		_jugador_en_gas = null


func recibir_excavacion(pos_excavacion: Vector3, radio_excavacion: float) -> void:
	if _neutralizada:
		return
	if global_position.distance_to(pos_excavacion) <= radio_excavacion + 2.0:
		_neutralizar()


func neutralizar() -> void:
	_neutralizar()


func _neutralizar() -> void:
	if _neutralizada:
		return
	_neutralizada = true

	# Suelta una muestra de investigación y materia orgánica
	var muestra := RECOMPENSA_SCENE.instantiate()
	muestra.set("bytes_valor", bytes_recompensa)
	muestra.set("freeze", true)
	get_tree().current_scene.add_child(muestra)
	muestra.global_position = global_position + global_transform.basis.y * 0.8

	var org: RigidBody3D = ORGANICO_SCENE.instantiate() as RigidBody3D
	if org:
		org.recurso_id = 24
		get_tree().current_scene.add_child(org)
		org.global_position = global_position + global_transform.basis.y * 1.3
		if org.has_method("set_physics_state"):
			org.set_physics_state(true)

	AudioJuego.reproducir_recoger()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("mostrar_notificacion"):
		hud.mostrar_notificacion("¡Emisora de gas desenterrada! (+%d Bytes + Organico)" % bytes_recompensa)

	queue_free()
