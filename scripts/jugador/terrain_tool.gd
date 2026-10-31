extends Node3D

# TerrainTool (Fase 2 de la Mochila):
# Herramienta de deformacion diegetica que se enfunda en el lateral de la mochila.
# Cuenta con 3 modos (Excavar, Rellenar, Aplanar) y un Canister volumetrico de sedimento.

signal modo_cambiado(nuevo_modo: int)
signal sedimento_cambiado(actual: float, maximo: float)
signal augment_cambiado(nuevo_augment: int)

enum Modo {
	EXCAVAR = 0,
	RELLENAR = 1,
	APLANAR = 2
}

enum Augment {
	NINGUNO = 0,
	AMPLIO = 1,
	PRECISION = 2,
	IMPULSO = 3
}

const NOMBRES_AUGMENT := {
	Augment.NINGUNO: "ESTANDAR",
	Augment.AMPLIO: "AUGMENT: AMPLIO (1.75x)",
	Augment.PRECISION: "AUGMENT: PRECISION (0.5x)",
	Augment.IMPULSO: "AUGMENT: IMPULSO (2x)"
}

const COLORES_MODO := {
	Modo.EXCAVAR: Color(1.0, 0.45, 0.05),   # Naranja/Ambar Astroneer
	Modo.RELLENAR: Color(0.2, 0.9, 0.25),   # Verde esmeralda
	Modo.APLANAR: Color(0.15, 0.75, 1.0)    # Cian / Azul electrico
}

const NOMBRES_MODO := {
	Modo.EXCAVAR: "EXCAVAR",
	Modo.RELLENAR: "RELLENAR",
	Modo.APLANAR: "APLANAR"
}

var modo_actual: int = Modo.EXCAVAR
var augment_actual: int = Augment.NINGUNO
var sedimento: float = 25.0
var sedimento_max: float = 100.0

var esta_activa: bool = false
var _tween_desenfunde: Tween = null

# Posiciones locales relativas a Visuals
const POS_ENFUNDADA := Vector3(0.48, 0.18, 0.58)
const ROT_ENFUNDADA := Vector3(-0.2618, 0.2618, -0.1745)

const POS_MANO := Vector3(0.38, 0.05, -0.45)
const ROT_MANO := Vector3(-0.0873, 3.0543, 0.0)

@onready var canister_nivel: MeshInstance3D = $Canister/CanisterNivel
@onready var luz_modo: OmniLight3D = $Punta/LuzModo
@onready var gema_modo: MeshInstance3D = $Punta/GemaModo
@onready var display_modo: Label3D = $Display/HoloModo
@onready var display_sedimento: Label3D = $Display/HoloSedimento

var _mat_gema: StandardMaterial3D
var _mat_canister: StandardMaterial3D


func _ready() -> void:
	_crear_materiales()
	transform.origin = POS_ENFUNDADA
	rotation = ROT_ENFUNDADA
	actualizar_interfaz_modo()
	actualizar_canister()


func _crear_materiales() -> void:
	_mat_gema = StandardMaterial3D.new()
	_mat_gema.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if gema_modo:
		gema_modo.material_override = _mat_gema

	_mat_canister = StandardMaterial3D.new()
	_mat_canister.albedo_color = Color(0.45, 0.32, 0.2, 1.0)
	_mat_canister.roughness = 0.9
	if canister_nivel:
		canister_nivel.material_override = _mat_canister


func ciclar_modo() -> void:
	modo_actual = (modo_actual + 1) % 3
	actualizar_interfaz_modo()
	modo_cambiado.emit(modo_actual)


func set_modo(nuevo: int) -> void:
	modo_actual = clamp(nuevo, 0, 2)
	actualizar_interfaz_modo()
	modo_cambiado.emit(modo_actual)


func ciclar_augment() -> void:
	augment_actual = (augment_actual + 1) % 4
	augment_cambiado.emit(augment_actual)
	actualizar_interfaz_modo()
	AudioJuego.reproducir_recoger()
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("mostrar_notificacion"):
		hud.mostrar_notificacion("Herramienta: %s [G]" % NOMBRES_AUGMENT[augment_actual])


func get_multiplicador_radio() -> float:
	match augment_actual:
		Augment.AMPLIO: return 1.75
		Augment.PRECISION: return 0.5
		_: return 1.0


func get_multiplicador_impulso() -> float:
	match augment_actual:
		Augment.IMPULSO: return 2.0
		_: return 1.0


func actualizar_interfaz_modo() -> void:
	var col: Color = COLORES_MODO.get(modo_actual, Color.WHITE)
	var nom: String = NOMBRES_MODO.get(modo_actual, "MODO")

	if _mat_gema:
		_mat_gema.albedo_color = col

	if luz_modo:
		luz_modo.light_color = col

	if display_modo:
		var aug_str := ""
		if augment_actual != Augment.NINGUNO:
			aug_str = "\n" + ["", "AMPLIO", "PRECIS.", "IMPULSO"][augment_actual]
		display_modo.text = nom + aug_str
		display_modo.modulate = col


func actualizar_canister() -> void:
	var ratio = clamp(sedimento / sedimento_max, 0.0, 1.0)
	if canister_nivel:
		canister_nivel.scale.y = max(ratio, 0.01)
		canister_nivel.position.y = -0.11 * (1.0 - ratio)

	if display_sedimento:
		display_sedimento.text = "%d%%" % int(ratio * 100.0)

	sedimento_cambiado.emit(sedimento, sedimento_max)


func agregar_sedimento(cantidad: float) -> bool:
	if sedimento >= sedimento_max:
		return false
	sedimento = min(sedimento + cantidad, sedimento_max)
	actualizar_canister()
	return true


func consumir_sedimento(cantidad: float) -> bool:
	if sedimento < cantidad:
		return false
	sedimento = max(sedimento - cantidad, 0.0)
	actualizar_canister()
	return true


func set_activa(activa: bool) -> void:
	esta_activa = activa
	if _tween_desenfunde and _tween_desenfunde.is_valid():
		_tween_desenfunde.kill()

	_tween_desenfunde = create_tween()
	_tween_desenfunde.set_parallel(true)
	_tween_desenfunde.set_trans(Tween.TRANS_BACK)
	_tween_desenfunde.set_ease(Tween.EASE_OUT)

	var target_pos = POS_MANO if esta_activa else POS_ENFUNDADA
	var target_rot = ROT_MANO if esta_activa else ROT_ENFUNDADA
	var dur = 0.3 if esta_activa else 0.25

	_tween_desenfunde.tween_property(self, "position", target_pos, dur)
	_tween_desenfunde.tween_property(self, "rotation", target_rot, dur)
