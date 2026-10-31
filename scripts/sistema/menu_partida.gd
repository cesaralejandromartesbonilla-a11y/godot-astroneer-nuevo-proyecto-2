extends CanvasLayer

# Menú de partida (Escape): 3 slots de guardado con Guardar/Cargar/Borrar,
# configuración de video/audio/LOD, botón de Menú Principal y autoguardado periódico.

const Guardado := preload("res://scripts/sistema/guardado.gd")

var _labels: Array[Label] = []
var _botones_cargar: Array[Button] = []
var _botones_borrar: Array[Button] = []

@onready var panel_partida: Control  = $Panel
@onready var panel_opciones: Control = $PanelOpciones
@onready var btn_opciones: Button    = $Panel/VBox/HBoxAcciones/BtnOpciones
@onready var btn_menu_prin: Button   = $Panel/VBox/HBoxAcciones/BtnMenuPrincipal
@onready var timer_autosave: Timer   = $TimerAutosave

# Controles de Opciones
@onready var opt_pantalla: OptionButton = $PanelOpciones/VBoxOpciones/HBoxPantalla/OptPantalla
@onready var opt_res: OptionButton      = $PanelOpciones/VBoxOpciones/HBoxResolucion/OptRes
@onready var opt_lod: OptionButton      = $PanelOpciones/VBoxOpciones/HBoxLOD/OptLOD
@onready var chk_vsync: CheckBox        = $PanelOpciones/VBoxOpciones/HBoxVSync/ChkVsync
@onready var slider_vol: HSlider        = $PanelOpciones/VBoxOpciones/HBoxVolumen/SliderVol
@onready var btn_guardar_opt: Button    = $PanelOpciones/VBoxOpciones/HBoxBotones/BtnGuardarOpciones
@onready var btn_volver_opt: Button     = $PanelOpciones/VBoxOpciones/HBoxBotones/BtnVolverOpciones


func _ready() -> void:
	visible = false
	panel_partida.visible = true
	panel_opciones.visible = false

	btn_opciones.pressed.connect(_on_abrir_opciones)
	btn_menu_prin.pressed.connect(_on_volver_menu_principal)
	btn_guardar_opt.pressed.connect(_on_guardar_opciones)
	btn_volver_opt.pressed.connect(_on_cerrar_opciones)

	timer_autosave.timeout.connect(_on_autosave_timer)

	_inicializar_controles_opciones()
	_construir_filas()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("press_escape"):
		if panel_opciones.visible:
			_on_cerrar_opciones()
		elif visible:
			cerrar()
		elif Global.ui_abierta == 0:
			abrir()
		get_viewport().set_input_as_handled()


func abrir() -> void:
	visible = true
	panel_partida.visible = true
	panel_opciones.visible = false
	Global.ui_abierta += 1
	_refrescar()


func cerrar() -> void:
	visible = false
	panel_opciones.visible = false
	Global.ui_abierta = maxi(0, Global.ui_abierta - 1)


func _construir_filas() -> void:
	var cont: VBoxContainer = $Panel/VBox/Slots
	for i in Guardado.SLOTS:
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 8)

		var lbl := Label.new()
		lbl.custom_minimum_size = Vector2(360, 0)
		fila.add_child(lbl)
		_labels.append(lbl)

		var b_guardar := Button.new()
		b_guardar.text = "Guardar"
		b_guardar.pressed.connect(_guardar_en.bind(i))
		fila.add_child(b_guardar)

		var b_cargar := Button.new()
		b_cargar.text = "Cargar"
		b_cargar.pressed.connect(_cargar_en.bind(i))
		fila.add_child(b_cargar)
		_botones_cargar.append(b_cargar)

		var b_borrar := Button.new()
		b_borrar.text = "Borrar"
		b_borrar.pressed.connect(_borrar_en.bind(i))
		fila.add_child(b_borrar)
		_botones_borrar.append(b_borrar)

		cont.add_child(fila)


func _refrescar() -> void:
	for i in Guardado.SLOTS:
		var inf := Guardado.info(i)
		if inf.is_empty():
			_labels[i].text = "Slot %d — vacío" % (i + 1)
		else:
			_labels[i].text = "Slot %d — %s — %d bytes" % [i + 1, inf["fecha"], inf["bytes"]]
		var hay := not inf.is_empty()
		_botones_cargar[i].disabled = not hay
		_botones_borrar[i].disabled = not hay


func _guardar_en(slot: int) -> void:
	# Dbs de terreno por planeta al slot (copian la sesión actual si hace falta)
	for planeta in get_tree().get_nodes_in_group("cuerpos"):
		planeta.asignar_db(Guardado.ruta_db_planeta(slot, planeta.planeta_id))
	Global.slot_actual = slot
	var ok := Guardado.guardar(slot, _capturar_estado())
	_log_ui("Slot %d %s" % [slot + 1, "guardado (sobrescrito)" if ok else "ERROR al guardar"])
	_refrescar()


func _cargar_en(slot: int) -> void:
	if not Guardado.existe(slot):
		return
	cerrar()
	Global.slot_a_cargar = slot
	get_tree().change_scene_to_file("res://escenas/test_2.tscn")


func _borrar_en(slot: int) -> void:
	Guardado.borrar(slot)
	_log_ui("Slot %d borrado" % (slot + 1))
	_refrescar()


func _log_ui(txt: String) -> void:
	$Panel/VBox/Estado.text = txt


func _capturar_estado() -> Dictionary:
	var player := get_tree().get_first_node_in_group("player")
	var datos := {
		"seed": Global.world_seed,
		"colocados": [],
	}
	if player:
		var s = player.stats
		var p: Vector3 = player.global_position
		datos["player"] = {
			"pos": [p.x, p.y, p.z],
			"o2max": s.oxygen_max, "pwmax": s.power_max,
			"o2": s.oxygen, "pw": s.power,
			"placeables": player.placeables.duplicate(),
		}
	var cat := get_tree().get_first_node_in_group("catalogo")
	if cat:
		datos["catalogo"] = {
			"bytes": cat.bytes,
			"desbloqueadas": cat.desbloqueadas.duplicate(),
		}
	for obj in get_tree().get_nodes_in_group("colocados"):
		var q: Vector3 = obj.global_position
		var r: Vector3 = obj.global_rotation
		datos["colocados"].append({
			"tipo": obj.get_meta("tipo", "?"),
			"pos": [q.x, q.y, q.z],
			"rot": [r.x, r.y, r.z],
		})
	return datos


# --- Opciones ---

func _inicializar_controles_opciones() -> void:
	opt_pantalla.clear()
	opt_pantalla.add_item("Ventana", 0)
	opt_pantalla.add_item("Pantalla Completa", 1)
	opt_pantalla.add_item("Sin Bordes", 2)

	opt_res.clear()
	opt_res.add_item("1280 x 720", 0)
	opt_res.add_item("1600 x 900", 1)
	opt_res.add_item("1920 x 1080", 2)

	opt_lod.clear()
	opt_lod.add_item("Baja (32m)", 0)
	opt_lod.add_item("Media (48m)", 1)
	opt_lod.add_item("Alta (64m)", 2)


func _on_abrir_opciones() -> void:
	panel_partida.visible = false
	var sm = get_node_or_null("/root/SaveManager")
	if sm:
		var modo: int = int(sm.config_get("video", "window_mode", 0))
		opt_pantalla.selected = clamp(modo, 0, 2)

		var w: int = int(sm.config_get("video", "res_w", 1280))
		match w:
			1920: opt_res.selected = 2
			1600: opt_res.selected = 1
			_: opt_res.selected = 0

		var lod: float = float(sm.config_get("video", "lod_distance", 48.0))
		if lod <= 32.0:
			opt_lod.selected = 0
		elif lod >= 64.0:
			opt_lod.selected = 2
		else:
			opt_lod.selected = 1

		chk_vsync.button_pressed = bool(sm.config_get("video", "vsync", true))
		slider_vol.value = float(sm.config_get("audio", "master_volume", 0.8)) * 100.0

	panel_opciones.visible = true


func _on_guardar_opciones() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm:
		sm.config_set("video", "window_mode", opt_pantalla.selected)
		var res_w := 1280
		var res_h := 720
		match opt_res.selected:
			1:
				res_w = 1600
				res_h = 900
			2:
				res_w = 1920
				res_h = 1080
		sm.config_set("video", "res_w", res_w)
		sm.config_set("video", "res_h", res_h)

		var lod_dist := 48.0
		match opt_lod.selected:
			0: lod_dist = 32.0
			1: lod_dist = 48.0
			2: lod_dist = 64.0
		sm.config_set("video", "lod_distance", lod_dist)

		sm.config_set("video", "vsync", chk_vsync.button_pressed)
		sm.config_set("audio", "master_volume", slider_vol.value / 100.0)
		sm.config_save()
		sm.aplicar_config()

	_on_cerrar_opciones()


func _on_cerrar_opciones() -> void:
	panel_opciones.visible = false
	panel_partida.visible = true


func _on_volver_menu_principal() -> void:
	cerrar()
	Global.slot_actual = -1
	Global.slot_a_cargar = -1
	get_tree().change_scene_to_file("res://escenas/ui/menu_principal.tscn")


# --- Autoguardado (Fase 6) ---

func _on_autosave_timer() -> void:
	if Global.slot_actual >= 0 and Guardado.existe(Global.slot_actual):
		_guardar_en(Global.slot_actual)
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("mostrar_notificacion"):
			hud.mostrar_notificacion("Partida autoguardada (Slot %d)" % (Global.slot_actual + 1))
