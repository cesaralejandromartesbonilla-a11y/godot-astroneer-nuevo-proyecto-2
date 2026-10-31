extends ImpresoraBase


func _configurar_recetas() -> void:
	nivel_impresora = "IMPRESORA PEQUEÑA"

	var mesh_plat := BoxMesh.new()
	mesh_plat.size = Vector3(1.2, 0.2, 0.8)

	var mesh_alm := BoxMesh.new()
	mesh_alm.size = Vector3(0.7, 0.5, 0.3)

	var mesh_imp_m := BoxMesh.new()
	mesh_imp_m.size = Vector3(1.4, 0.8, 1.0)

	var mesh_panel := BoxMesh.new()
	mesh_panel.size = Vector3(0.6, 0.1, 0.6)

	_recetas = [
		{
			"id": "plataforma_mediana",
			"nombre": "Plataforma Mediana",
			"inputs": {21: 1},
			"escena": preload("res://escenas/planeta/plataforma_mediana.tscn"),
			"tiempo": 6.0,
			"consumo": 1.5,
			"preview_mesh": mesh_plat
		},
		{
			"id": "almacenamiento_mediano",
			"nombre": "Almacenamiento Mediano",
			"inputs": {21: 2},
			"escena": preload("res://escenas/planeta/almacenamiento_mediano.tscn"),
			"tiempo": 6.0,
			"consumo": 1.5,
			"preview_mesh": mesh_alm
		},
		{
			"id": "impresora_mediana",
			"nombre": "Impresora Mediana",
			"inputs": {20: 2},
			"escena": preload("res://escenas/planeta/impresora_mediana.tscn"),
			"tiempo": 8.0,
			"consumo": 2.0,
			"preview_mesh": mesh_imp_m
		},
		{
			"id": "panel_solar",
			"nombre": "Panel Solar",
			"inputs": {2: 1},
			"escena": preload("res://escenas/planeta/panel_solar.tscn"),
			"tiempo": 5.0,
			"consumo": 1.2,
			"preview_mesh": mesh_panel
		}
	]
