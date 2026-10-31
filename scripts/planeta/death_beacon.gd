extends Area3D

# Baliza de Muerte (Death Beacon):
# Guarda los items perdidos por el jugador al morir por O2.
# Emite un pilar de luz vertical visible en el horizonte y devuelve los items al acercarse.

var stored_items: Array[Node3D] = []
var _tiempo: float = 0.0

@onready var columna_luz: MeshInstance3D = $ColumnaLuz
@onready var luz: OmniLight3D = $OmniLight3D


func _ready() -> void:
	add_to_group("death_beacons")
	body_entered.connect(_on_body_entered)


func agregar_item(item: Node3D) -> void:
	stored_items.append(item)
	if item.get_parent():
		item.get_parent().remove_child(item)
	add_child(item)
	item.position = Vector3(randf_range(-0.5, 0.5), 0.3, randf_range(-0.5, 0.5))
	item.visible = false # Ocultar mientras están dentro de la baliza


func _physics_process(delta: float) -> void:
	_tiempo += delta
	# Pulsación de luz de baliza
	if luz:
		luz.light_energy = 2.0 + sin(_tiempo * 4.0) * 1.0
	if columna_luz:
		columna_luz.rotate_y(0.5 * delta)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		recuperar_equipo(body)


func recuperar_equipo(player: Node3D) -> void:
	var slots: Array[Node] = []
	var visuals = player.get_node_or_null("Visuals")
	if visuals:
		for c in visuals.get_children():
			if c.is_in_group("slots") and c.stored_item == null:
				slots.append(c)

	var devueltos := 0
	for item in stored_items:
		if not is_instance_valid(item):
			continue
		item.visible = true
		if slots.size() > 0:
			var slot = slots.pop_front()
			slot.equip_item(item)
			devueltos += 1
		else:
			# Si no caben en la mochila, soltarlos en el suelo con física
			remove_child(item)
			get_tree().current_scene.add_child(item)
			item.global_position = global_position + Vector3.UP * 1.0 + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
			if item.has_method("set_physics_state"):
				item.set_physics_state(true)
			devueltos += 1

	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("mostrar_notificacion"):
		hud.mostrar_notificacion("¡Equipo recuperado de la Baliza de Rescate! (%d items)" % devueltos)

	queue_free()
