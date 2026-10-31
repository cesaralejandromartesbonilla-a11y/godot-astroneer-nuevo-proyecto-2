extends ModuloBase

# Plataforma Mediana (Tier 2):
# Provee 4 ranuras universales para módulos o almacenamiento.
# Conecta automáticamente su cable de energía con la red de la base.

@onready var slot1: Area3D = $Slots/Slot1
@onready var slot2: Area3D = $Slots/Slot2
@onready var slot3: Area3D = $Slots/Slot3
@onready var slot4: Area3D = $Slots/Slot4


func _ready() -> void:
	add_to_group("plataformas")
	add_to_group("modulo_base")
