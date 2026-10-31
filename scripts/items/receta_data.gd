class_name RecetaData
extends Resource

# Receta de fabricación (F3). Una por archivo .tres en recursos/.

@export var id: String = ""            # "tethers", "panel_solar", ...
@export var nombre: String = ""
# { recurso_id: cantidad } — se consumen de los slots de la mochila
@export var inputs: Dictionary = {}
# Si la salida es un colocable: clave en player.placeables ("tether", "panel_solar")
@export var colocable: String = ""
@export var salida_cantidad: int = 1
# Si la salida es una mejora permanente:
@export var mejora_o2_max := 0
@export var mejora_power_max := 0
# Bytes necesarios para desbloquearla (una sola vez; luego fabricable libre)
@export var coste_bytes := 0
