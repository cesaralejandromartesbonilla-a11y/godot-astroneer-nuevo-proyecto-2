extends CanvasLayer

# Consola de desarrollo (estilo Minecraft), tecla ` (press_bar, junto al 1).
# Extensible: añadir comandos en _ejecutar().

const ITEMS := {
	"cobre": {"id": 2, "escena": "res://escenas/planeta/ore_copper.tscn"},
	"hierro": {"id": 3, "escena": "res://escenas/planeta/ore_iron.tscn"},
	"litio": {"id": 4, "escena": "res://escenas/planeta/ore_lithium.tscn"},
	"titanio": {"id": 5, "escena": "res://escenas/planeta/ore_titanio.tscn"},
	"criolita": {"id": 6, "escena": "res://escenas/planeta/ore_criolita.tscn"},
	"cuarzo": {"id": 23, "escena": "res://escenas/planeta/ore_cuarzo.tscn"},
	"lingote_cobre": {"id": 12, "escena": "res://escenas/planeta/ingot_copper.tscn"},
	"lingote_hierro": {"id": 13, "escena": "res://escenas/planeta/ingot_iron.tscn"},
	"lingote_litio": {"id": 14, "escena": "res://escenas/planeta/ingot_litio.tscn"},
	"piedra": {"id": 0, "escena": "res://escenas/planeta/piedra_investigacion.tscn"},
	"organico": {"id": 24, "escena": "res://escenas/planeta/ore_organico.tscn"},
	"materia_organica": {"id": 24, "escena": "res://escenas/planeta/ore_organico.tscn"},
}
const COLOCABLES := {
	"tether": "tether", "tethers": "tether",
	"panel": "panel_solar", "panel_solar": "panel_solar",
	"rover": "rover",
}

var _historial: Array[String] = []

@onready var entrada: LineEdit = $Panel/VBox/Entrada
@onready var registro: Label = $Panel/VBox/Registro


func _ready() -> void:
	visible = false
	entrada.text_submitted.connect(_on_entrada_text_submitted)
	_log("Consola — 'help' para ver comandos")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("press_bar"):
		_alternar()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("press_escape"):
		_alternar()
		get_viewport().set_input_as_handled()


func _alternar() -> void:
	visible = not visible
	if visible:
		Global.ui_abierta += 1
		entrada.grab_focus()
	else:
		Global.ui_abierta = maxi(0, Global.ui_abierta - 1)
		entrada.release_focus()


func _on_entrada_text_submitted(texto: String) -> void:
	entrada.clear()
	_ejecutar(texto)


func _ejecutar(texto: String) -> void:
	_log("> " + texto)
	var partes := texto.strip_edges().split(" ", false)
	if partes.is_empty():
		return
	var cmd: String = partes[0].to_lower().trim_prefix("/")
	match cmd:
		"help", "ayuda":
			_log("give <nombre> [n] — cobre/hierro/litio/titanio/criolita/cuarzo/lingote_*/piedra/tether/panel/rover")
			_log("bytes <n> — suma bytes de investigación")
			_log("o2 | energia — recargar al máximo")
			_log("time <dia|noche> — hora del sol")
			_log("tp <x> <y> <z> — teletransporte")
			_log("pos | seed | kill | limpiar")
		"give":
			_give(partes)
		"bytes":
			var cat := get_tree().get_first_node_in_group("catalogo")
			if cat and partes.size() >= 2:
				cat.sumar_bytes(int(partes[1]))
				_log("bytes: %d" % cat.bytes)
		"o2", "energia":
			var s = _stats()
			if s:
				s.reset()
				_log("O2 y energía al máximo")
		"time", "hora":
			_hora(partes)
		"tp":
			_tp(partes)
		"pos":
			var p := _player()
			if p:
				_log("pos: %s" % str(p.global_position.round()))
		"seed":
			_log("seed: %d" % Global.world_seed)
		"kill":
			var s = _stats()
			if s:
				s.consume_oxygen(999.0, 1.0)
		"limpiar":
			_historial.clear()
			_actualizar_registro()
		_:
			_log("Comando desconocido: %s (help)" % cmd)


func _give(partes: Array) -> void:
	if partes.size() < 2:
		_log("uso: give <nombre> [cantidad]")
		return
	var nombre: String = partes[1].to_lower()
	var cantidad := 1
	if partes.size() >= 3:
		cantidad = maxi(1, int(partes[2]))
	var player := _player()
	if player == null:
		return

	if COLOCABLES.has(nombre):
		var clave: String = COLOCABLES[nombre]
		player.placeables[clave] = player.placeables.get(clave, 0) + cantidad
		_log("+%d %s" % [cantidad, clave])
		return

	if not ITEMS.has(nombre):
		_log("item desconocido: %s" % nombre)
		return
	var def: Dictionary = ITEMS[nombre]
	for i in cantidad:
		var item: RigidBody3D = load(def["escena"]).instantiate()
		item.recurso_id = def["id"]
		get_tree().current_scene.add_child(item)
		item.set_physics_state(false)
		# primero intentar mochila; si llena, a los pies
		var colocado := false
		for c in player.visuals.get_children():
			if c.is_in_group("slots") and c.stored_item == null:
				c.equip_item(item)
				colocado = true
				break
		if not colocado:
			item.set_physics_state(true)
			item.global_position = player.global_position + Vector3.UP * 1.5
	_log("give %s x%d" % [nombre, cantidad])


func _hora(partes: Array) -> void:
	var dn := get_tree().get_first_node_in_group("day_night")
	if dn == null:
		return
	var cual := "dia"
	if partes.size() >= 2:
		cual = partes[1]
	dn.phase = 0.25 if cual.begins_with("di") or cual == "day" else 0.75
	dn._apply_sun()
	_log("hora: %s" % ("día" if dn.is_day() else "noche"))


func _tp(partes: Array) -> void:
	if partes.size() < 4:
		_log("uso: tp x y z")
		return
	var p := _player()
	if p:
		p.global_position = Vector3(float(partes[1]), float(partes[2]), float(partes[3]))
		p.velocity = Vector3.ZERO
		_log("tp ok")


func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player")


func _stats():
	var p := _player()
	return p.stats if p else null


func _log(txt: String) -> void:
	_historial.append(txt)
	# Máximo 7 líneas visibles: más desborda el panel y tapa la barra de entrada
	if _historial.size() > 7:
		_historial = _historial.slice(_historial.size() - 7)
	_actualizar_registro()


func _actualizar_registro() -> void:
	registro.text = "\n".join(_historial)
