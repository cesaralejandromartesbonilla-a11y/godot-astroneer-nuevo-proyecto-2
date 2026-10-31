extends Control

const Guardado := preload("res://scripts/sistema/guardado.gd")

@onready var panel_slots: Control    = $PanelSlots
@onready var panel_opciones: Control = $PanelOpciones
@onready var btn_nuevo: Button       = $PanelPrincipal/VBox/BtnNuevo
@onready var btn_continuar: Button   = $PanelPrincipal/VBox/BtnContinuar
@onready var btn_opciones: Button    = $PanelPrincipal/VBox/BtnOpciones
@onready var btn_salir: Button       = $PanelPrincipal/VBox/BtnSalir

# Controles de Opciones
@onready var opt_pantalla: OptionButton = $PanelOpciones/VBoxOpciones/HBoxPantalla/OptPantalla
@onready var opt_res: OptionButton      = $PanelOpciones/VBoxOpciones/HBoxResolucion/OptRes
@onready var opt_lod: OptionButton      = $PanelOpciones/VBoxOpciones/HBoxLOD/OptLOD
@onready var chk_vsync: CheckBox        = $PanelOpciones/VBoxOpciones/HBoxVSync/ChkVsync
@onready var slider_vol: HSlider        = $PanelOpciones/VBoxOpciones/HBoxVolumen/SliderVol
@onready var btn_guardar_opt: Button    = $PanelOpciones/VBoxOpciones/HBoxBotones/BtnGuardarOpciones
@onready var btn_volver_opt: Button     = $PanelOpciones/VBoxOpciones/HBoxBotones/BtnVolverOpciones

var _labels_slot: Array[Label]   = []
var _botones_slot: Array[Button] = []


func _ready() -> void:
	btn_nuevo.pressed.connect(_on_nuevo)
	btn_continuar.pressed.connect(_on_continuar)
	btn_opciones.pressed.connect(_on_opciones)
	btn_salir.pressed.connect(_on_salir)

	btn_guardar_opt.pressed.connect(_on_guardar_opciones)
	btn_volver_opt.pressed.connect(func(): panel_opciones.visible = false)

	panel_slots.visible = false
	panel_opciones.visible = false

	_inicializar_controles_opciones()
	_construir_slots()
	_actualizar_continuar()


func _inicializar_controles_opciones() -> void:
	# Pantalla
	opt_pantalla.clear()
	opt_pantalla.add_item("Ventana", 0)
	opt_pantalla.add_item("Pantalla Completa", 1)
	opt_pantalla.add_item("Sin Bordes", 2)

	# Resolución
	opt_res.clear()
	opt_res.add_item("1280 x 720", 0)
	opt_res.add_item("1600 x 900", 1)
	opt_res.add_item("1920 x 1080", 2)

	# Calidad Terreno (LOD)
	opt_lod.clear()
	opt_lod.add_item("Baja (32m)", 0)
	opt_lod.add_item("Media (48m)", 1)
	opt_lod.add_item("Alta (64m)", 2)


func _cargar_valores_opciones() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm == null:
		return

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


func _on_opciones() -> void:
	panel_slots.visible = false
	_cargar_valores_opciones()
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

	panel_opciones.visible = false


func _construir_slots() -> void:
	var vbox: VBoxContainer = $PanelSlots/VBoxSlots
	for i in Guardado.SLOTS:
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 12)

		var lbl := Label.new()
		lbl.custom_minimum_size = Vector2(380, 0)
		fila.add_child(lbl)
		_labels_slot.append(lbl)

		var btn := Button.new()
		btn.text = "Cargar"
		btn.pressed.connect(_cargar_slot.bind(i))
		fila.add_child(btn)
		_botones_slot.append(btn)

		vbox.add_child(fila)

	var btn_cerrar := Button.new()
	btn_cerrar.text = "Volver"
	btn_cerrar.pressed.connect(func(): panel_slots.visible = false)
	vbox.add_child(btn_cerrar)


func _actualizar_continuar() -> void:
	var alguno := false
	for i in Guardado.SLOTS:
		if Guardado.existe(i):
			alguno = true
			break
	btn_continuar.disabled = not alguno


func _refrescar_slots() -> void:
	for i in Guardado.SLOTS:
		var inf := Guardado.info(i)
		if inf.is_empty():
			_labels_slot[i].text = "Slot %d — vacío" % (i + 1)
		else:
			_labels_slot[i].text = "Slot %d — %s — %d bytes" % [i + 1, inf["fecha"], inf["bytes"]]
		_botones_slot[i].disabled = inf.is_empty()


func _on_nuevo() -> void:
	Global.slot_a_cargar = -1
	get_tree().change_scene_to_file("res://escenas/test_2.tscn")


func _on_continuar() -> void:
	panel_opciones.visible = false
	_refrescar_slots()
	panel_slots.visible = true


func _on_salir() -> void:
	get_tree().quit()


func _cargar_slot(slot: int) -> void:
	if not Guardado.existe(slot):
		return
	Global.slot_a_cargar = slot
	get_tree().change_scene_to_file("res://escenas/test_2.tscn")
