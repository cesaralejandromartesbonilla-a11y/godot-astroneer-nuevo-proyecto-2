extends CanvasLayer

# HUD (F2): barras de oxÃ­geno/energÃ­a + contador de tethers. Escucha las
# seÃ±ales de PlayerStats â€” no toca los valores directamente.

var _player: Node3D
var _cat: Node

@onready var o2_bar: ProgressBar       = $Control/VBox/O2Row/O2Bar
@onready var power_bar: ProgressBar    = $Control/VBox/PowerRow/PowerBar
@onready var tethers_label: Label      = $Control/VBox/TethersLabel
@onready var beacon_label: Label       = $Control/BeaconLabel
@onready var notificacion_label: Label = $Control/NotificacionLabel
@onready var fade_rect: ColorRect      = $FadeRect
@onready var label_muerte: Label       = $FadeRect/LabelMuerte

var _notif_tween: Tween = null


func _ready() -> void:
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	_cat = get_tree().get_first_node_in_group("catalogo")
	if _player:
		var stats = _player.stats
		stats.oxygen_changed.connect(_on_o2)
		stats.power_changed.connect(_on_power)
		_on_o2(stats.oxygen, stats.oxygen_max)
		_on_power(stats.power, stats.power_max)
	# Asegurar que el fade empiece invisible
	if fade_rect:
		fade_rect.modulate.a = 0.0
		fade_rect.visible = false
	if beacon_label:
		beacon_label.visible = false
	if notificacion_label:
		notificacion_label.modulate.a = 0.0


func _process(_delta: float) -> void:
	if _player == null:
		return
	var bytes := 0
	if _cat:
		bytes = _cat.bytes
	var info_tool := ""
	if _player.get("is_tool_active"):
		var tt = _player.get("terrain_tool")
		if tt:
			var modo_str = ["EXCAVAR", "RELLENAR", "APLANAR"][tt.get("modo_actual")]
			info_tool = " | Herramienta: %s (%d%% Sedimento) [E/R]" % [modo_str, int(tt.get("sedimento"))]
		else:
			info_tool = " | Herramienta Activa [E]"
	tethers_label.text = ("Tethers: %d [T]  Paneles: %d [P]  Bytes: %d [F]" % [
		_player.placeables.get("tether", 0),
		_player.placeables.get("panel_solar", 0),
		bytes
	]) + info_tool
	# Actualizar indicador de baliza de muerte mÃ¡s cercana
	_actualizar_baliza()


# â”€â”€â”€ Baliza de Muerte â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _actualizar_baliza() -> void:
	var balizas = get_tree().get_nodes_in_group("death_beacons")
	if balizas.is_empty() or _player == null:
		if beacon_label:
			beacon_label.visible = false
		return
	# Buscar la mÃ¡s cercana
	var mas_cercana: Node3D = null
	var dist_min := INF
	for b in balizas:
		var d = _player.global_position.distance_to(b.global_position)
		if d < dist_min:
			dist_min = d
			mas_cercana = b
	if mas_cercana and beacon_label:
		beacon_label.visible = true
		beacon_label.text = "â—† BALIZA DE RESCATE: %.0f m" % dist_min
	else:
		if beacon_label:
			beacon_label.visible = false


# â”€â”€â”€ Notificaciones â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func mostrar_notificacion(texto: String) -> void:
	if notificacion_label == null:
		return
	notificacion_label.text = texto
	notificacion_label.modulate.a = 1.0
	# Cancelar tween anterior si existÃ­a
	if _notif_tween and _notif_tween.is_valid():
		_notif_tween.kill()
	_notif_tween = create_tween()
	_notif_tween.tween_interval(4.0)
	_notif_tween.tween_property(notificacion_label, "modulate:a", 0.0, 1.0)


# â”€â”€â”€ Fade de Muerte â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func mostrar_fade_muerte() -> void:
	if fade_rect == null:
		return
	fade_rect.visible = true
	if label_muerte:
		label_muerte.text = "TE QUEDASTE SIN OXÃGENO...\nRespawnando en la cÃ¡psula"
	var tw = create_tween()
	tw.tween_property(fade_rect, "modulate:a", 1.0, 1.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished


func ocultar_fade() -> void:
	if fade_rect == null:
		return
	var tw = create_tween()
	tw.tween_property(fade_rect, "modulate:a", 0.0, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	fade_rect.visible = false


func _on_o2(value: float, max_value: float) -> void:
	o2_bar.max_value = max_value
	o2_bar.value = value


func _on_power(value: float, max_value: float) -> void:
	power_bar.max_value = max_value
	power_bar.value = value