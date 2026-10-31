extends Node

# AudioJuego (autoload) — Fase 6.
# Provee audio de ambiente cósmico continuo y efectos de feedback procedurales:
# excavar, recoger materiales, e impresión de módulos.
# Todo generado algorítmicamente sin dependencias de assets externos.

var _jugador_ambiente: AudioStreamPlayer
var _jugador_excavar: AudioStreamPlayer
var _jugador_recoger: AudioStreamPlayer
var _jugador_imprimir: AudioStreamPlayer

const SAMPLE_RATE := 22050
const AMPLITUDE   := 0.18


func _ready() -> void:
	_jugador_excavar  = _crear_jugador_sfx()
	_jugador_recoger  = _crear_jugador_sfx()
	_jugador_imprimir = _crear_jugador_sfx()
	_iniciar_ambiente()


func _crear_jugador_sfx() -> AudioStreamPlayer:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = SAMPLE_RATE
	gen.buffer_length = 0.08
	var p := AudioStreamPlayer.new()
	p.stream = gen
	p.volume_db = -8.0
	p.bus = "Master"
	add_child(p)
	return p


func _iniciar_ambiente() -> void:
	_jugador_ambiente = AudioStreamPlayer.new()
	_jugador_ambiente.name = "AmbienteEspacial"
	_jugador_ambiente.volume_db = -18.0
	_jugador_ambiente.bus = "Master"

	var duracion := 6.0
	var num_frames := int(SAMPLE_RATE * duracion)
	var data := PackedByteArray()
	data.resize(num_frames * 4) # 16 bits estéreo = 4 bytes por frame

	var amp_viento := 2200.0
	var amp_drone := 1600.0
	for i in num_frames:
		var t := float(i) / SAMPLE_RATE
		# Viento espacial suave modulado
		var mod := sin(TAU * 0.166 * t) * 0.5 + 0.5
		var viento_l := sin(TAU * 68.0 * t) * sin(TAU * 112.0 * t) * amp_viento * mod
		var viento_r := cos(TAU * 72.0 * t) * sin(TAU * 124.0 * t) * amp_viento * mod
		# Drone cósmico armónico
		var drone := (sin(TAU * 55.0 * t) + sin(TAU * 110.0 * t) * 0.35) * amp_drone
		var sl := int(clampf(viento_l + drone, -32000.0, 32000.0))
		var sr := int(clampf(viento_r + drone, -32000.0, 32000.0))

		var offset := i * 4
		data.encode_s16(offset, sl)
		data.encode_s16(offset + 2, sr)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = true
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = num_frames

	_jugador_ambiente.stream = stream
	add_child(_jugador_ambiente)
	_jugador_ambiente.play()


func reproducir_excavar() -> void:
	if _jugador_excavar.playing:
		return
	_jugador_excavar.play()
	_llenar_tono(_jugador_excavar, 110.0, 0.05, true)


func reproducir_recoger() -> void:
	_jugador_recoger.play()
	_llenar_tono(_jugador_recoger, 880.0, 0.04, false)


func reproducir_imprimir() -> void:
	_jugador_imprimir.play()
	_llenar_tono_doble(_jugador_imprimir, 660.0, 880.0, 0.05)


# --- Helpers de generación procedural de tonos ---

func _llenar_tono(jugador: AudioStreamPlayer, hz: float, duracion: float, ruido: bool) -> void:
	var pb = jugador.get_stream_playback()
	if pb == null:
		return
	var muestras := int(SAMPLE_RATE * duracion)
	var frames_disponibles: int = pb.get_frames_available()
	muestras = mini(muestras, frames_disponibles)
	for i in muestras:
		var t := float(i) / SAMPLE_RATE
		var env := 1.0 - (t / duracion)
		var val := sin(TAU * hz * t) * AMPLITUDE * env
		if ruido:
			val += randf_range(-0.03, 0.03) * env
		pb.push_frame(Vector2(val, val))


func _llenar_tono_doble(jugador: AudioStreamPlayer, hz1: float, hz2: float, duracion: float) -> void:
	var pb = jugador.get_stream_playback()
	if pb == null:
		return
	var muestras := int(SAMPLE_RATE * duracion)
	var frames_disponibles: int = pb.get_frames_available()
	muestras = mini(muestras, frames_disponibles)
	var mitad := muestras / 2
	for i in muestras:
		var t := float(i) / SAMPLE_RATE
		var env := 1.0 - (t / duracion)
		var hz := hz1 if i < mitad else hz2
		var val := sin(TAU * hz * t) * AMPLITUDE * env
		pb.push_frame(Vector2(val, val))
