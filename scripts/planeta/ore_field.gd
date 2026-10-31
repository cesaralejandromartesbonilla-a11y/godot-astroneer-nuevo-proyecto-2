class_name OreField
extends RefCounted

# Campo de vetas de UN planeta (F5: parametrizado por cuerpo planetario).
# Única fuente de verdad del minado Y de la textura 3D del shader.
#
# config: { ore_id: {"band": Vector2(prof_min, prof_max), "wl": float} }
# (profundidad radial negativa bajo la superficie; orden de prioridad = band.min
# ascendente, es decir, las capas más profundas ganan).

const NOISE_THRESHOLD := 0.70
const DEFAULT_RESOLUTION := 64

var radio := 250.0
var bounds_pos := Vector3(-512, -512, -512)
var bounds_size := Vector3(1024, 1152, 1024)

# Config por defecto (Terra): cobre/hierro/litio
var config := {
	2: {"band": Vector2(-40, -5), "wl": 90.0},
	3: {"band": Vector2(-80, -40), "wl": 100.0},
	4: {"band": Vector2(-300, -80), "wl": 130.0},
}

var _ruidos: Dictionary = {}  # ore_id -> FastNoiseLite


func setup(base_seed: int, planeta_radio: float = 250.0, cfg: Dictionary = {},
		p_bounds_pos: Vector3 = Vector3(-512, -512, -512),
		p_bounds_size: Vector3 = Vector3(1024, 1152, 1024)) -> void:
	radio = planeta_radio
	bounds_pos = p_bounds_pos
	bounds_size = p_bounds_size
	if not cfg.is_empty():
		config = cfg
	_ruidos.clear()
	var idx := 0
	for ore_id in config:
		var n := FastNoiseLite.new()
		n.seed = base_seed + 10 + int(ore_id) * 7 + idx
		n.frequency = 1.0 / float(config[ore_id]["wl"])
		n.fractal_octaves = 2
		_ruidos[ore_id] = n
		idx += 1


## Ids ordenados por prioridad (capa más profunda primero)
func _ids_por_prioridad() -> Array:
	var ids := config.keys()
	ids.sort_custom(func(a, b): return config[a]["band"].x < config[b]["band"].x)
	return ids


func depth_at(pos: Vector3, centro: Vector3 = Vector3.ZERO) -> float:
	return (pos - centro).length() - radio


## Devuelve el type_id del mineral en esa posición (0 = nada).
func get_ore_id(pos: Vector3, centro: Vector3 = Vector3.ZERO) -> int:
	var d := depth_at(pos, centro)
	for ore_id in _ids_por_prioridad():
		var band: Vector2 = config[ore_id]["band"]
		if d > band.x and d <= band.y:
			if _n01(_ruidos[ore_id], pos) > NOISE_THRESHOLD:
				return int(ore_id)
			return 0
	return 0


## Señal n01 (0..1) de un mineral concreto en una posición.
func get_ore_signal(pos: Vector3, ore_id: int) -> float:
	if not _ruidos.has(ore_id):
		return 0.0
	return _n01(_ruidos[ore_id], pos)


static func _n01(n: FastNoiseLite, pos: Vector3) -> float:
	return (n.get_noise_3d(pos.x, pos.y, pos.z) + 1.0) * 0.5


## Textura 3D para el shader (R/G/B = minerales por prioridad de banda).
## Se construye por slices con PackedByteArray directo.
func build_texture_3d(resolution: int = DEFAULT_RESOLUTION) -> ImageTexture3D:
	var n := maxi(4, resolution)
	var ids := _ids_por_prioridad()
	var canal := {}  # ore_id -> índice de canal 0/1/2
	for i in mini(3, ids.size()):
		canal[ids[i]] = i

	var slices: Array[Image] = []
	slices.resize(n)
	var inv_n := 1.0 / float(n)
	var step := bounds_size * inv_n

	for z in n:
		var wz: float = bounds_pos.z + (float(z) + 0.5) * step.z
		var buf := PackedByteArray()
		buf.resize(n * n * 3)
		var idx := 0
		for y in n:
			var wy: float = bounds_pos.y + (float(y) + 0.5) * step.y
			for x in n:
				var wx: float = bounds_pos.x + (float(x) + 0.5) * step.x
				var world := Vector3(wx, wy, wz)
				var d := (world - _centro_bounds()).length() - radio
				var rgb := [0, 0, 0]
				for ore_id in ids:
					if not canal.has(ore_id):
						continue
					var band: Vector2 = config[ore_id]["band"]
					if d > band.x and d <= band.y:
						var v := _oreness_byte(_n01(_ruidos[ore_id], world))
						rgb[canal[ore_id]] = v
						break
				buf[idx] = rgb[0]
				buf[idx + 1] = rgb[1]
				buf[idx + 2] = rgb[2]
				idx += 3
		slices[z] = Image.create_from_data(n, n, false, Image.FORMAT_RGB8, buf)

	var tex := ImageTexture3D.new()
	var err: Error = tex.create(Image.FORMAT_RGB8, n, n, n, false, slices)
	if err != OK:
		return null
	return tex


## El campo se evalúa en coords LOCALES al planeta (bounds relativos),
## así que el centro efectivo para la profundidad es el centro de la caja.
func _centro_bounds() -> Vector3:
	return bounds_pos + bounds_size * 0.5


## smoothstep(0.72, 0.78, n01) escalado a byte; mismo criterio que el shader (>0.55)
static func _oreness_byte(n01: float) -> int:
	var t := clampf((n01 - 0.72) / (0.78 - 0.72), 0.0, 1.0)
	return int((t * t * (3.0 - 2.0 * t)) * 255.0)
