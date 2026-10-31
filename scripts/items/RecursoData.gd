extends Resource
class_name RecursoData

# Identificador numérico — debe coincidir con el type_id del voxel en el generador
@export var id: int = 0
@export var nombre: String = "Recurso"
@export var color_albedo: Color = Color(1, 1, 1)
# Escena del item que se spawnea al minar este recurso
@export var escena_item: PackedScene
