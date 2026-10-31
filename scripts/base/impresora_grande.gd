extends ImpresoraBase


func _configurar_recetas() -> void:
	nivel_impresora = "IMPRESORA GRANDE"

	var mesh_rover := BoxMesh.new()
	mesh_rover.size = Vector3(2.5, 1.2, 1.8)

	var mesh_shuttle := CylinderMesh.new()
	mesh_shuttle.top_radius = 0.3
	mesh_shuttle.bottom_radius = 1.2
	mesh_shuttle.height = 3.5

	var mesh_plat_ex := BoxMesh.new()
	mesh_plat_ex.size = Vector3(3.2, 0.4, 2.4)

	_recetas = [
		{
			"id": "rover",
			"nombre": "Rover Terrestre",
			"inputs": {12: 2, 13: 1},
			"escena": preload("res://escenas/vehiculo/rover.tscn"),
			"tiempo": 14.0,
			"consumo": 3.5,
			"preview_mesh": mesh_rover
		},
		{
			"id": "shuttle",
			"nombre": "Lanzadera Espacial",
			"inputs": {12: 4, 13: 2},
			"escena": preload("res://escenas/vehiculo/shuttle.tscn"),
			"tiempo": 18.0,
			"consumo": 4.0,
			"preview_mesh": mesh_shuttle
		},
		{
			"id": "plataforma_extra_grande",
			"nombre": "Plataforma Extra Grande",
			"inputs": {21: 3, 3: 1},
			"escena": preload("res://escenas/planeta/plataforma_mediana.tscn"),
			"tiempo": 12.0,
			"consumo": 3.0,
			"preview_mesh": mesh_plat_ex
		}
	]
