class_name FloraPeligrosa
extends Node3D

# FloraPeligrosa (Fase 7):
# Especie vegetal hostil alienígena.
# Si el jugador se acerca a menos de 4.5m, emite esporas tóxicas que drenan oxígeno.
# Si el jugador excava bajo sus raíces (desestabilizando su soporte), la planta
# se marchita y suelta una muestra de investigación biológica valiosa.

const PIEDRA_SCENE := preload("res://escenas/planeta/piedra_investigacion.tscn")

@export var dano_o2_por_segundo: float = 12.0
@export var bytes_recompensa: int = 350

var _jugador_en_rango: Node3D = null
var _neutralizada: bool = false
var _tiempo_pulso: float = 0.0
var _tiempo_vida: float = 0.0
var _suelo_confirmado: bool = false

@onready var tallo_mesh: MeshInstance3D = get_node_or_null("Tallo")
@onready var bulbo_mesh: MeshInstance3D = get_node_or_null("Bulbo")
@onready var luz_toxica: OmniLight3D = get_node_or_null("LuzToxica")
@onready var area_esporas: Area3D = get_node_or_null("AreaEsporas")
@onready var raycast_suelo: RayCast3D = get_node_or_null("RayCastSuelo")

var _mat_bulbo: StandardMaterial3D = null
var _mat_tallo: StandardMaterial3D = null


func _ready() -> void:
	add_to_group("flora_peligrosa")
	_crear_materiales()
	if area_esporas:
		area_esporas.body_entered.connect(_on_body_entered)
		area_esporas.body_exited.connect(_on_body_exited)
	if raycast_suelo:
		raycast_suelo.collision_mask = 1
		raycast_suelo.enabled = true


func _crear_materiales() -> void:
	# Material del tallo: vegetal alienígena oscuro con vetas verdosas
	_mat_tallo = StandardMaterial3D.new()
	_mat_tallo.albedo_color = Color(0.12, 0.25, 0.18)
	_mat_tallo.roughness = 0.7
	_mat_tallo.emission_enabled = true
	_mat_tallo.emission = Color(0.05, 0.2, 0.1)
	_mat_tallo.emission_energy_multiplier = 0.8
	if tallo_mesh:
		tallo_mesh.material_override = _mat_tallo

	# Material del bulbo: espora púrpura/carmesí bio-luminiscente visible a distancia
	_mat_bulbo = StandardMaterial3D.new()
	_mat_bulbo.albedo_color = Color(0.7, 0.1, 0.45)
	_mat_bulbo.roughness = 0.35
	_mat_bulbo.emission_enabled = true
	_mat_bulbo.emission = Color(0.9, 0.15, 0.5)
	_mat_bulbo.emission_energy_multiplier = 1.8
	if bulbo_mesh:
		bulbo_mesh.material_override = _mat_bulbo

	if luz_toxica:
		luz_toxica.visible = true
		luz_toxica.light_color = Color(1.0, 0.2, 0.5)
		luz_toxica.light_energy = 1.2
		luz_toxica.omni_range = 8.0


func _physics_process(delta: float) -> void:
	if _neutralizada:
		return

	_tiempo_vida += delta
	_tiempo_pulso += delta * (6.0 if _jugador_en_rango else 2.0)

	# 1. Verificación segura del suelo:
	# Esperar a que el meshing del terreno termine y el raycast confirme suelo al menos una vez
	if raycast_suelo:
		if not _suelo_confirmado:
			if raycast_suelo.is_colliding():
				_suelo_confirmado = true
		else:
			# Solo tras haber confirmado suelo y pasado el tiempo inicial, verificar si se excavó
			if _tiempo_vida > 2.0 and not raycast_suelo.is_colliding():
				_neutralizar()
				return

	# 2. Pulsación visual constante del bulbo (incluso en reposo para ser detectable)
	var factor_pulso := sin(_tiempo_pulso)
	var escala_pulso := 1.0 + factor_pulso * (0.18 if _jugador_en_rango else 0.08)
	if bulbo_mesh:
		bulbo_mesh.scale = Vector3.ONE * escala_pulso

	# 3. Comportamiento ante presencia del jugador
	if _jugador_en_rango:
		if _mat_bulbo:
			_mat_bulbo.emission = Color(1.0, 0.1, 0.15)
			_mat_bulbo.emission_energy_multiplier = 3.0 + factor_pulso * 1.5
		if luz_toxica:
			luz_toxica.light_energy = 2.5 + factor_pulso * 1.2
			luz_toxica.light_color = Color(1.0, 0.1, 0.2)

		# Drenar oxígeno del jugador
		if "stats" in _jugador_en_rango:
			var stats = _jugador_en_rango.stats
			stats.consume_oxygen(dano_o2_por_segundo, delta)
	else:
		if _mat_bulbo:
			_mat_bulbo.emission = Color(0.9, 0.15, 0.5)
			_mat_bulbo.emission_energy_multiplier = 1.5 + factor_pulso * 0.4
		if luz_toxica:
			luz_toxica.light_energy = 1.0 + factor_pulso * 0.3
			luz_toxica.light_color = Color(1.0, 0.2, 0.5)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_jugador_en_rango = body
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("mostrar_notificacion"):
			hud.mostrar_notificacion("¡PELIGRO! Esporas tóxicas — drena oxígeno")


func _on_body_exited(body: Node3D) -> void:
	if body == _jugador_en_rango:
		_jugador_en_rango = null


func _neutralizar() -> void:
	_neutralizada = true

	# Dejar caer muestra de investigación
	var muestra = PIEDRA_SCENE.instantiate()
	muestra.bytes_valor = bytes_recompensa
	muestra.freeze = true
	get_tree().current_scene.add_child(muestra)
	muestra.global_position = global_position + global_transform.basis.y * 0.8

	AudioJuego.reproducir_recoger()
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("mostrar_notificacion"):
		hud.mostrar_notificacion("¡Flora tóxica desenterrada! Muestra obtenida (+350 Bytes)")

	queue_free()
