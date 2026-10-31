extends CanvasLayer

# MenuTeleport (Fase 7):
# Interfaz de Red de Portales Gravitacionales.
# Al interactuar con una Cámara de Portal activada o un Núcleo Planetario,
# despliega un mapa holográfico de nodos celestiales que permite al jugador
# elegir a qué sector del planeta (superficie o núcleo) o sistema planetario viajar.

@onready var panel: PanelContainer = $Panel
@onready var subtitulo: Label = $Panel/VBox/Subtitulo
@onready var destinos_list: VBoxContainer = $Panel/VBox/Scroll/DestinosList
@onready var boton_cerrar: Button = $Panel/VBox/BotonCerrar

var _origen: Node3D = null
var _abierto: bool = false


func _ready() -> void:
	visible = false
	if boton_cerrar:
		boton_cerrar.pressed.connect(cerrar)


func _unhandled_input(event: InputEvent) -> void:
	if not _abierto:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("press_tab"):
		cerrar()
		get_viewport().set_input_as_handled()


func abrir_red(nodo_origen: Node3D) -> void:
	if _abierto:
		return
	_origen = nodo_origen
	_abierto = true
	visible = true
	Global.ui_abierta += 1
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_refrescar_destinos()


func cerrar() -> void:
	if not _abierto:
		return
	_abierto = false
	visible = false
	Global.ui_abierta = maxi(0, Global.ui_abierta - 1)
	_origen = null


func _refrescar_destinos() -> void:
	for c in destinos_list.get_children():
		c.queue_free()

	var player = get_tree().get_first_node_in_group("player")
	if player == null or _origen == null:
		return

	# Identificar planeta actual
	var planeta_actual: Node3D = _obtener_planeta_de(_origen)
	var nombre_planeta: String = str(planeta_actual.get("nombre")) if planeta_actual else "Planeta"
	subtitulo.text = "PLANETA ACTUAL: %s — SELECCIONE DESTINO" % nombre_planeta.to_upper()

	# Recolectar todos los nodos de portal disponibles en la escena
	var chambers := get_tree().get_nodes_in_group("gateways")
	var engines := get_tree().get_nodes_in_group("gateway_engines")

	# 1. Monolitos de superficie (Gateway Chambers)
	for ch in chambers:
		if not is_instance_valid(ch):
			continue
		var plan: Node3D = _obtener_planeta_de(ch)
		var p_nom: String = str(plan.get("nombre")) if plan else "Superficie"
		var es_aqui: bool = (_origen == ch) or (_origen.global_position.distance_to(ch.global_position) < 8.0)
		var activo: bool = bool(ch.get("activado")) if "activado" in ch else false

		_crear_fila_destino(
			"🏛️ %s — Cámara de Portal" % p_nom,
			"Superficie exterior" + (" [ACTIVO]" if activo else " [REQUIERE ENERGÍA]"),
			Color(0.2, 0.85, 1.0) if activo else Color(0.6, 0.65, 0.75),
			ch,
			es_aqui,
			activo or es_aqui
		)

	# 2. Núcleos planetarios (Gateway Engines)
	for eng in engines:
		if not is_instance_valid(eng):
			continue
		var plan: Node3D = _obtener_planeta_de(eng)
		var p_nom: String = str(plan.get("nombre")) if plan else "Núcleo"
		var es_aqui: bool = (_origen == eng) or (_origen.global_position.distance_to(eng.global_position) < 8.0)
		var activo: bool = bool(eng.get("activado")) if "activado" in eng else false
		var recurso_nom: String = str(eng.get("nombre_recurso")) if "nombre_recurso" in eng else "Mineral"

		_crear_fila_destino(
			"🌀 %s — Núcleo Planetario" % p_nom,
			"Centro geométrico" + (" [DESPIERTO]" if activo else " [REQUIERE %s]" % recurso_nom.to_upper()),
			Color(0.7, 0.3, 1.0) if activo else Color(0.8, 0.6, 0.3),
			eng,
			es_aqui,
			true # El núcleo siempre es accesible desde su cámara de portal
		)


func _crear_fila_destino(titulo: String, desc: String, color_tag: Color, destino_nodo: Node3D, es_aqui: bool, habilitado: bool) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 12)

	var info_box := VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lbl_tit := Label.new()
	lbl_tit.text = titulo
	lbl_tit.modulate = color_tag
	info_box.add_child(lbl_tit)

	var lbl_desc := Label.new()
	lbl_desc.text = desc
	lbl_desc.modulate = Color(0.75, 0.8, 0.85, 0.8)
	info_box.add_child(lbl_desc)

	hbox.add_child(info_box)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(160, 38)
	if es_aqui:
		btn.text = "Ubicación Actual"
		btn.disabled = true
	elif not habilitado:
		btn.text = "Inactivo"
		btn.disabled = true
	else:
		btn.text = "Teletransportar"
		btn.pressed.connect(_viajar_a.bind(destino_nodo, titulo))

	hbox.add_child(btn)
	destinos_list.add_child(hbox)


func _viajar_a(destino: Node3D, nombre_destino: String) -> void:
	cerrar()
	var player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null or not is_instance_valid(destino):
		return

	var loading = get_node_or_null("/root/Loading")
	if loading and loading.has_method("show_message"):
		loading.show_message("TELETRANSPORTANDO A %s..." % nombre_destino)

	player.set_physics_process(false)
	AudioJuego.reproducir_recoger()

	# Determinar vector 'up' del destino
	var up_dest: Vector3 = destino.global_transform.basis.y
	if up_dest.length_squared() < 0.5:
		var planeta = _obtener_planeta_de(destino)
		if planeta:
			up_dest = (destino.global_position - planeta.global_position).normalized()
		else:
			up_dest = Vector3.UP
	player.global_position = destino.global_position + up_dest * 2.2
	player.up_direction = up_dest
	player.velocity = Vector3.ZERO
	if player.has_method("update_gravity_source"):
		player.update_gravity_source()
	if player.has_method("align_up_with_planet"):
		player.align_up_with_planet(up_dest)

	var dn := get_tree().get_first_node_in_group("day_night")
	if dn and dn.has_method("snap_atmosfera"):
		dn.snap_atmosfera(player.global_position)

	await get_tree().create_timer(0.6).timeout
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)

	if loading and loading.has_method("hide_screen"):
		loading.hide_screen()

	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("mostrar_notificacion"):
		hud.mostrar_notificacion("Salto completado: %s" % nombre_destino)


func _obtener_planeta_de(nodo: Node3D) -> Node3D:
	var curr: Node = nodo
	while curr:
		if curr.is_in_group("planetas") or curr.is_in_group("cuerpos"):
			return curr as Node3D
		curr = curr.get_parent()

	# Búsqueda por proximidad si no es hijo directo
	var planetas = get_tree().get_nodes_in_group("planetas")
	var mejor: Node3D = null
	var d_min := INF
	for p in planetas:
		var d = nodo.global_position.distance_to(p.global_position)
		if d < d_min:
			d_min = d
			mejor = p
	return mejor
