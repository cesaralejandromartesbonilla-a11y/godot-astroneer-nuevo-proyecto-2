extends Node

var estado: int = 1  # 1 = a pie, 0 = en vehiculo

# Seed autoritativa del mundo (F1): misma seed => mismo planeta.
var world_seed: int = 20260816

# UI abierta (consola/menus): el juego ignora el input mientras > 0
var ui_abierta: int = 0

# Slot a cargar en el proximo arranque de escena (-1 = partida nueva)
var slot_a_cargar: int = -1

# Slot de la sesion actual (-1 = nueva sin guardar; cambia al guardar/cargar)
var slot_actual: int = -1


func cambia_estado() -> void:
	estado = 0 if estado == 1 else 1
