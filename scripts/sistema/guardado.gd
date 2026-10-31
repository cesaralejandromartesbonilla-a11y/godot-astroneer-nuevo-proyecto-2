extends RefCounted

# Guardado por slots (JSON) + terreno por slot (SQLite propio).
# Uso: const Guardado = preload("res://scripts/sistema/guardado.gd")

const SLOTS := 3


static func ruta_json(slot: int) -> String:
	return "user://slot_%d.json" % slot


static func ruta_db(slot: int) -> String:
	return "user://slot_%d.db" % slot


## Db de terreno por planeta y slot (F5)
static func ruta_db_planeta(slot: int, planeta_id: int) -> String:
	return "user://slot_%d_p%d.db" % [slot, planeta_id]


static func existe(slot: int) -> bool:
	return FileAccess.file_exists(ruta_json(slot))


static func guardar(slot: int, datos: Dictionary) -> bool:
	datos["fecha"] = Time.get_datetime_string_from_system().replace("T", " ")
	var f := FileAccess.open(ruta_json(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(datos, "\t"))
	return true


static func leer(slot: int) -> Dictionary:
	if not existe(slot):
		return {}
	var f := FileAccess.open(ruta_json(slot), FileAccess.READ)
	if f == null:
		return {}
	var res = JSON.parse_string(f.get_as_text())
	return res if res is Dictionary else {}


static func info(slot: int) -> Dictionary:
	var d := leer(slot)
	if d.is_empty():
		return {}
	return {
		"fecha": d.get("fecha", "?"),
		"bytes": int(d.get("catalogo", {}).get("bytes", 0)),
		"seed": int(d.get("seed", 0)),
	}


static func borrar(slot: int) -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if existe(slot):
		dir.remove(ruta_json(slot).get_file())
	var prefijo := "slot_%d_p" % slot
	for f in dir.get_files():
		if f.begins_with(prefijo):
			dir.remove(f)
