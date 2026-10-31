extends CanvasLayer

@onready var label_velocidad: Label = $PanelInfo/VBox/LabelVelocidad
@onready var label_estado: Label = $PanelInfo/VBox/LabelEstado
@onready var bar_boost: ProgressBar = $PanelInfo/VBox/BarBoost
@onready var prompt_aterrizaje: Label = $PromptAterrizaje
@onready var reticula: Control = $Reticula

func _ready() -> void:
	visible = false

func mostrar(activar: bool) -> void:
	visible = activar

func actualizar_datos(vel: float, boost_pct: float, estado_txt: String, puede_aterrizar: bool) -> void:
	if not visible:
		return
	if label_velocidad:
		label_velocidad.text = "VELOCIDAD: %d u/s" % int(vel)
	if label_estado:
		label_estado.text = "ESTADO: %s" % estado_txt
	if bar_boost:
		bar_boost.value = boost_pct * 100.0
	if prompt_aterrizaje:
		prompt_aterrizaje.visible = puede_aterrizar
