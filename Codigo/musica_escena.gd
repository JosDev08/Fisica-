extends AudioStreamPlayer

# ==============================================================================
# REPRODUCTOR DE MÚSICA EN BUCLE POR ESCENA
# - Opera siempre en bus = "Musica" con process_mode = PROCESS_MODE_ALWAYS.
# - Habilita bucle nativo (.mp3 / .wav / .ogg) y respaldo por señal finished.
# ==============================================================================

@export var ruta_pista_respaldo: String = ""


func _ready() -> void:
	GameManager.configurar_buses_audio()
	process_mode = Node.PROCESS_MODE_ALWAYS
	bus = &"Musica"
	autoplay = true

	if stream == null and not ruta_pista_respaldo.is_empty():
		stream = GameManager.cargar_audio_seguro(ruta_pista_respaldo)

	_habilitar_bucle_en_stream()

	if not finished.is_connected(_on_finished):
		finished.connect(_on_finished)

	if stream != null and not playing:
		play()


func _habilitar_bucle_en_stream() -> void:
	if stream == null:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		if wav.loop_end <= 0 and not wav.data.is_empty():
			var bytes_por_muestra: int = 2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1
			var canales: int = 2 if wav.stereo else 1
			wav.loop_end = int(wav.data.size() / (bytes_por_muestra * canales))


func _on_finished() -> void:
	if stream != null and is_inside_tree():
		play()
