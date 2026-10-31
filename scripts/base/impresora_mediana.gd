extends ImpresoraBase


func _configurar_recetas() -> void:
	nivel_impresora = "IMPRESORA MEDIANA"

	var mesh_plat_g := BoxMesh.new()
	mesh_plat_g.size = Vector3(1.8, 0.25, 1.2)

	var mesh_fund := BoxMesh.new()
	mesh_fund.size = Vector3(1.5, 0.9, 1.1)

	var mesh_cent := CylinderMesh.new()
	mesh_cent.top_radius = 0.8
	mesh_cent.bottom_radius = 0.8
	mesh_cent.height = 0.9

	var mesh_cam := BoxMesh.new()
	mesh_cam.size = Vector3(1.4, 0.9, 1.0)

	var mesh_imp_g := BoxMesh.new()
	mesh_imp_g.size = Vector3(2.2, 1.4, 1.8)

	_recetas = [
		{
			"id": "plataforma_grande",
			"nombre": "Plataforma Grande",
			"inputs": {21: 2},
			"escena": preload("res://escenas/planeta/plataforma_mediana.tscn"),
			"tiempo": 8.0,
			"consumo": 2.0,
			"preview_mesh": mesh_plat_g
		},
		{
			"id": "fundicion",
			"nombre": "Horno / Fundición",
			"inputs": {20: 1, 21: 2},
			"escena": preload("res://escenas/planeta/fundicion.tscn"),
			"tiempo": 10.0,
			"consumo": 2.5,
			"preview_mesh": mesh_fund
		},
		{
			"id": "centrifugadora",
			"nombre": "Centrifugadora de Suelo",
			"inputs": {20: 2, 21: 1},
			"escena": preload("res://escenas/planeta/centrifugadora.tscn"),
			"tiempo": 10.0,
			"consumo": 2.5,
			"preview_mesh": mesh_cent
		},
		{
			"id": "camara_investigacion",
			"nombre": "Cámara de Investigación",
			"inputs": {20: 2, 21: 1},
			"escena": preload("res://escenas/planeta/camara_investigacion.tscn"),
			"tiempo": 10.0,
			"consumo": 2.5,
			"preview_mesh": mesh_cam
		},
		{
			"id": "impresora_grande",
			"nombre": "Impresora Grande",
			"inputs": {20: 3},
			"escena": preload("res://escenas/planeta/impresora_grande.tscn"),
			"tiempo": 12.0,
			"consumo": 3.0,
			"preview_mesh": mesh_imp_g
		}
	]
