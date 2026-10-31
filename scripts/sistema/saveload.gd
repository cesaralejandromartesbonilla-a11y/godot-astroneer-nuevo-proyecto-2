extends Node

# SaveManager (autoload) — Fase 6.
# Gestiona la configuración (config.cfg), ajustes de pantalla, audio, LOD
# y delega guardado/carga por slots a guardado.gd.

const Guardado := preload("res://scripts/sistema/guardado.gd")

var config := ConfigFile.new()
var file_config := "user://config.cfg"


func _ready() -> void:
	_cargar_config()
	aplicar_config()


# --- Configuración (config.cfg) ---

func _cargar_config() -> void:
	if config.load(file_config) != OK:
		config = ConfigFile.new()
		_inicializar_defaults()


func _inicializar_defaults() -> void:
	if not config.has_section("video"):
		config.set_value("video", "window_mode", 0) # 0: Ventana, 1: Pantalla completa, 2: Sin bordes
		config.set_value("video", "res_w", 1280)
		config.set_value("video", "res_h", 720)
		config.set_value("video", "vsync", true)
		config.set_value("video", "lod_distance", 48.0) # 32.0: Baja, 48.0: Media, 64.0: Alta
	if not config.has_section("audio"):
		config.set_value("audio", "master_volume", 0.8)
	config_save()


func config_save() -> void:
	config.save(file_config)


func config_get(seccion: String, clave: String, defecto: Variant) -> Variant:
	return config.get_value(seccion, clave, defecto)


func config_set(seccion: String, clave: String, valor: Variant) -> void:
	config.set_value(seccion, clave, valor)


func aplicar_config() -> void:
	# 1. Modo de pantalla y resolución
	var modo: int = int(config_get("video", "window_mode", 0))
	match modo:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var w: int = int(config_get("video", "res_w", 1280))
			var h: int = int(config_get("video", "res_h", 720))
			DisplayServer.window_set_size(Vector2i(w, h))
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

	# 2. V-Sync
	var vsync: bool = bool(config_get("video", "vsync", true))
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)

	# 3. Audio Master
	var vol: float = float(config_get("audio", "master_volume", 0.8))
	var bus_idx: int = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		if vol <= 0.01:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(vol))


# --- Utilidades de slot (delegadas a guardado.gd) ---

func slot_existe(slot: int) -> bool:
	return Guardado.existe(slot)


func slot_info(slot: int) -> Dictionary:
	return Guardado.info(slot)


func slot_borrar(slot: int) -> void:
	Guardado.borrar(slot)
