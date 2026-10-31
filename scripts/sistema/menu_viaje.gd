extends CanvasLayer

# Mapa de viaje (F5), tecla M. Solo montado en la lanzadera: lista los
# planetas y salta (fundido con Loading) a la órbita del elegido.

@onready var filas: VBoxContainer = $Panel/VBox/Filas
@onready var estado: Label = $Panel/VBox/Estado


func _ready() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("press_m"):
		if visible:
			cerrar()
		elif Global.ui_abierta == 0:
			abrir()
		get_viewport().set_input_as_handled()


func abrir() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or player.en_vehiculo == null or not player.en_vehiculo.is_in_group("vehiculos"):
		return
	if not player.en_vehiculo.get_script().resource_path.begins_with("res://scripts/vehiculo/shuttle"):
		return
	visible = true
	Global.ui_abierta += 1
	_refrescar(player.en_vehiculo)


func cerrar() -> void:
	visible = false
	Global.ui_abierta = maxi(0, Global.ui_abierta - 1)


func _refrescar(shuttle: Node3D) -> void:
	for c in filas.get_children():
		c.queue_free()
	for p in get_tree().get_nodes_in_group("cuerpos"):
		var btn := Button.new()
		var dist: float = shuttle.global_position.distance_to(p.global_position)
		btn.text = "%s — %d recursos — a %.0f u" % [p.nombre, p.ore_catalog.size(), dist]
		if dist < p.radio * 1.5:
			btn.text += "  (aquí)"
			btn.disabled = true
		btn.pressed.connect(_viajar.bind(shuttle, p))
		filas.add_child(btn)
	estado.text = "Elige destino (el salto es un fundido)"


func _viajar(shuttle: Node3D, destino: Node3D) -> void:
	cerrar()
	var loading := get_node_or_null("/root/Loading")
	if loading:
		loading.show_message("Viajando a %s..." % destino.nombre)
	await get_tree().create_timer(0.6).timeout
	shuttle.viajar_a(destino)
	await get_tree().create_timer(1.2).timeout
	if loading:
		loading.hide_screen()
