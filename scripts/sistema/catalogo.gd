extends Node

# Catálogo de investigación (F3): bytes + recetas desbloqueadas.
# Datos con señales (disciplina multiplayer §6.2). Persistirá en F6.

signal bytes_changed(total: int)

var bytes := 0
var desbloqueadas: Array[String] = ["tethers"]


func sumar_bytes(n: int) -> void:
	bytes += n
	bytes_changed.emit(bytes)


func esta_desbloqueada(id: String) -> bool:
	return id in desbloqueadas


## Desbloquea si hay bytes suficientes (una sola vez por receta).
func intentar_desbloquear(id: String, coste: int) -> bool:
	if esta_desbloqueada(id):
		return true
	if bytes < coste:
		return false
	bytes -= coste
	bytes_changed.emit(bytes)
	desbloqueadas.append(id)
	return true
