class_name PlayerStats
extends RefCounted

# Estado de supervivencia del jugador (F2). Datos puros separados de los nodos
# (disciplina multiplayer §6.2 del ROADMAP): el HUD escucha las señales y nadie
# más modifica estos valores directamente.

signal oxygen_changed(value: float, max_value: float)
signal power_changed(value: float, max_value: float)
signal died

# --- Balance (afinar jugando; ROADMAP F2) ---
const O2_REPLENISH_RATE := 25.0   # por segundo dentro de la red de oxígeno
const O2_DRAIN_RATE := 1.1        # por segundo fuera de la red (~90 s de autonomía)
const POWER_REGEN_DAY := 1.0      # por segundo de día (panel de mochila v1)
const DIG_COST := 2.0             # por clic de excavar/rellenar

var oxygen_max := 100.0
var power_max := 100.0
var oxygen := 100.0
var power := 100.0


func replenish_oxygen(rate: float, delta: float) -> void:
	_set_oxygen(clampf(oxygen + rate * delta, 0.0, oxygen_max))


func consume_oxygen(rate: float, delta: float) -> void:
	_set_oxygen(clampf(oxygen - rate * delta, 0.0, oxygen_max))


func replenish_power(rate: float, delta: float) -> void:
	_set_power(clampf(power + rate * delta, 0.0, power_max))


## Devuelve false si no hay energía suficiente (la acción no se ejecuta).
func consume_power(amount: float) -> bool:
	if power < amount:
		return false
	_set_power(power - amount)
	return true


func reset() -> void:
	oxygen = oxygen_max
	power = power_max
	oxygen_changed.emit(oxygen, oxygen_max)
	power_changed.emit(power, power_max)


## Mejoras permanentes fabricadas (F3): tanque de O2 / batería.
func mejorar_o2_max(n: float) -> void:
	oxygen_max += n
	oxygen = oxygen_max
	oxygen_changed.emit(oxygen, oxygen_max)


func mejorar_power_max(n: float) -> void:
	power_max += n
	power = power_max
	power_changed.emit(power, power_max)


func _set_oxygen(v: float) -> void:
	if v == oxygen:
		return
	oxygen = v
	oxygen_changed.emit(oxygen, oxygen_max)
	if oxygen <= 0.0:
		died.emit()


func _set_power(v: float) -> void:
	if v == power:
		return
	power = v
	power_changed.emit(power, power_max)
