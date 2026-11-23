extends Node

# ==============================================================================
# AUTOLOAD: GameManager
# Gestiona economía (Monedas de Rayo), mejoras acumulables entre niveles
# (nivel_vida, multiplicador_velocidad, bonus_danio), guardado en disco
# (user://savegame.save), checkpoints, temporizador, HUD y PantallaMuerte.
# ==============================================================================

signal monedas_cambiadas(cantidad: int)
signal vida_cambiada(actual: int, maxima: int)
signal tiempo_cambiado(tiempo_restante: float)
signal tiempo_agregado(segundos: float)
signal mejoras_cambiadas(mejoras: Dictionary)
signal checkpoint_guardado(escena: String, posicion: Vector2)
signal jugador_murio(motivo: String)
signal pausa_cambiada(en_pausa: bool)
signal archivos_recuperados_cambiados(recuperados: bool)

const SAVE_PATH: String = "user://savegame.save"
const ESCENA_NIVEL_1: String = "res://Escenas/escena_01.tscn"
const ESCENA_MENU_PRINCIPAL: String = "res://Escenas/UI/MenuPrincipal.tscn"
const ESCENA_HUD: String = "res://Escenas/HUD.tscn"
const ESCENA_PANTALLA_MUERTE: String = "res://Escenas/PantallaMuerte.tscn"

# Estadísticas base del jugador y balance por nivel de mejora (máx. 3 niveles)
const VIDA_BASE: int = 100
const VELOCIDAD_BASE: float = 220.0
const DANIO_BASE: int = 25

const NIVEL_MAX_MEJORA: int = 3
const BONUS_VIDA_POR_NIVEL: int = 25         # +25 HP máx. por nivel (100 -> 125 -> 150 -> 175)
const BONUS_VELOCIDAD_POR_NIVEL: float = 0.15 # +15% velocidad horizontal por nivel (sin alterar salto)
const BONUS_DANIO_POR_NIVEL: int = 15        # +15 daño por nivel (25 -> 40 -> 55 -> 70)

const COSTOS_VIDA: Array[int] = [3, 5, 7]
const COSTOS_VELOCIDAD: Array[int] = [3, 5, 7]
const COSTOS_DANIO: Array[int] = [4, 6, 8]

const TIEMPO_NIVEL_DEFAULT: float = 50.0

var tiempo_inicial_nivel: float = 50.0

# Estado persistente de la partida activa (conservado entre niveles y checkpoints)
var monedas_rayo: int = 0
var nivel_vida: int = 0
var nivel_velocidad: int = 0
var multiplicador_velocidad: float = 1.0
var nivel_danio: int = 0
var bonus_danio: int = 0

var checkpoint_escena: String = ""
var checkpoint_posicion: Vector2 = Vector2.ZERO
var tiene_checkpoint: bool = false
var mejoras: Dictionary = {
	"jugger_nog": false,
	"stamin_up": false,
	"double_tap": false,
}

# Estado temporal de la sesión en curso
var vida_actual: int = VIDA_BASE
var tiempo_restante: float = 50.0
var temporizador_activo: bool = false
var jugador_muerto: bool = false
var en_pausa: bool = false
var archivos_recuperados: bool = false
var cinematica_insercion_vista: bool = false

var _usar_posicion_pendiente: bool = false
var _posicion_pendiente_respawn: Vector2 = Vector2.ZERO
var _escena_actual_id: int = -1
var _modales_abiertos: int = 0
var _hud_escena_cache: PackedScene = null
var _muerte_escena_cache: PackedScene = null
var _volumen_ducking_actual_db: float = 0.0
var indice_muerte_actual: int = 0
var _audio_muerte_jugador: AudioStreamPlayer = null
var _audio_sfx_moneda: AudioStreamPlayer = null
var _cache_sfx_monedas: Dictionary = {}

const BUS_MUSICA := "Musica"
const BUS_VOCES := "Voces"
const BUS_SFX := "SFX"
const DUCKING_MUSICA_ACTIVO_DB: float = -18.0
const DUCKING_MUSICA_NORMAL_DB: float = 0.0
const RUTAS_AUDIO_MUERTE: Array[String] = [
	"res://assets/audio/muerte_soldado_1.mp3",
	"res://assets/audio/muerte_soldado_2.mp3",
]
const RUTAS_AUDIO_MUERTE_WAV: Array[String] = [
	"res://assets/audio/muerte_soldado_1.wav",
	"res://assets/audio/muerte_soldado_2.wav",
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	configurar_buses_audio()
	_configurar_audio_muerte_jugador()
	_configurar_audio_sfx_moneda()
	cargar_partida()


func _process(delta: float) -> void:
	var tree := get_tree()
	if tree == null:
		return

	var escena := tree.current_scene
	if escena != null and escena.get_instance_id() != _escena_actual_id:
		_escena_actual_id = escena.get_instance_id()
		_al_cambiar_escena(escena)

	_actualizar_audio_ducking(delta)

	if temporizador_activo and not tree.paused and not jugador_muerto and _modales_abiertos <= 0:
		tiempo_restante = maxf(0.0, tiempo_restante - delta)
		tiempo_cambiado.emit(tiempo_restante)
		if tiempo_restante <= 0.0:
			activar_muerte_jugador("¡SE ACABÓ EL TIEMPO!")


# ==============================================================================
# BUSES DE AUDIO, ECUALIZACIÓN Y ATENUACIÓN AUTOMÁTICA (AUDIO DUCKING)
# ==============================================================================
func configurar_buses_audio() -> void:
	# 1. Bus "Musica": EQ6 cálido (recorta estridentes y da espacio en 1-2 kHz a voces) + LowPass 9000 Hz
	var idx_musica: int = AudioServer.get_bus_index(BUS_MUSICA)
	if idx_musica == -1:
		idx_musica = AudioServer.bus_count
		AudioServer.add_bus(idx_musica)
		AudioServer.set_bus_name(idx_musica, BUS_MUSICA)
		AudioServer.set_bus_send(idx_musica, "Master")
		AudioServer.set_bus_volume_db(idx_musica, DUCKING_MUSICA_NORMAL_DB)

		var eq := AudioEffectEQ6.new()
		eq.set_band_gain_db(0, -1.0) # 32 Hz
		eq.set_band_gain_db(1, 0.8)  # 100 Hz (calidez)
		eq.set_band_gain_db(2, 0.0)  # 320 Hz
		eq.set_band_gain_db(3, -2.5) # 1000 Hz (espacio limpio para las voces)
		eq.set_band_gain_db(4, -1.5) # 3200 Hz
		eq.set_band_gain_db(5, -5.5) # 10000 Hz (suavizar agudos estridentes)
		AudioServer.add_bus_effect(idx_musica, eq)

		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 9000.0
		lp.resonance = 0.5
		AudioServer.add_bus_effect(idx_musica, lp)

	# 2. Bus "Voces": Compresor suave (-14 dB, ratio 3.0) para claridad y presencia del científico
	var idx_voces: int = AudioServer.get_bus_index(BUS_VOCES)
	if idx_voces == -1:
		idx_voces = AudioServer.bus_count
		AudioServer.add_bus(idx_voces)
		AudioServer.set_bus_name(idx_voces, BUS_VOCES)
		AudioServer.set_bus_send(idx_voces, "Master")
		AudioServer.set_bus_volume_db(idx_voces, 0.0)

		var comp := AudioEffectCompressor.new()
		comp.threshold = -14.0
		comp.ratio = 3.0
		comp.attack_us = 200.0
		comp.release_ms = 180.0
		comp.gain = 1.5
		AudioServer.add_bus_effect(idx_voces, comp)

	# 3. Bus "SFX": Canal limpio para disparos y alarmas (-2.0 dB)
	var idx_sfx: int = AudioServer.get_bus_index(BUS_SFX)
	if idx_sfx == -1:
		idx_sfx = AudioServer.bus_count
		AudioServer.add_bus(idx_sfx)
		AudioServer.set_bus_name(idx_sfx, BUS_SFX)
		AudioServer.set_bus_send(idx_sfx, "Master")
		AudioServer.set_bus_volume_db(idx_sfx, -2.0)


func _actualizar_audio_ducking(delta: float) -> void:
	var idx_musica: int = AudioServer.get_bus_index(BUS_MUSICA)
	if idx_musica == -1:
		return

	var voz_activa: bool = false
	for nodo in get_tree().get_nodes_in_group("voces_cientifico"):
		if is_instance_valid(nodo) and nodo is AudioStreamPlayer:
			if (nodo as AudioStreamPlayer).is_playing():
				voz_activa = true
				break

	var objetivo_db: float = DUCKING_MUSICA_ACTIVO_DB if voz_activa else DUCKING_MUSICA_NORMAL_DB
	var velocidad: float = 8.5 if voz_activa else 3.5
	_volumen_ducking_actual_db = lerpf(_volumen_ducking_actual_db, objetivo_db, clampf(delta * velocidad, 0.0, 1.0))
	if absf(_volumen_ducking_actual_db - objetivo_db) < 0.05:
		_volumen_ducking_actual_db = objetivo_db
	AudioServer.set_bus_volume_db(idx_musica, _volumen_ducking_actual_db)


# ==============================================================================
# GESTIÓN DE PARTIDAS Y GUARDADO EN DISCO (user://savegame.save)
# ==============================================================================
func existe_partida_guardada() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var datos := _leer_datos_disco()
	if datos.is_empty():
		return false
	var escena_guardada: String = str(datos.get("checkpoint_escena", ""))
	var ck_valido: bool = bool(datos.get("tiene_checkpoint", false))
	return ck_valido and not escena_guardada.is_empty() and ResourceLoader.exists(escena_guardada)


func guardar_partida() -> void:
	_sincronizar_diccionario_mejoras()
	var datos := {
		"monedas_rayo": monedas_rayo,
		"nivel_vida": nivel_vida,
		"nivel_velocidad": nivel_velocidad,
		"multiplicador_velocidad": multiplicador_velocidad,
		"nivel_danio": nivel_danio,
		"bonus_danio": bonus_danio,
		"checkpoint_escena": checkpoint_escena,
		"checkpoint_x": checkpoint_posicion.x,
		"checkpoint_y": checkpoint_posicion.y,
		"tiene_checkpoint": tiene_checkpoint,
		"mejoras": mejoras.duplicate(),
	}
	var archivo := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if archivo == null:
		push_warning("GameManager: No se pudo guardar en %s (error %d)" % [SAVE_PATH, FileAccess.get_open_error()])
		return
	archivo.store_string(JSON.stringify(datos, "\t"))
	archivo.close()


func cargar_partida() -> bool:
	var datos := _leer_datos_disco()
	if datos.is_empty():
		return false

	monedas_rayo = maxi(0, int(datos.get("monedas_rayo", 0)))
	checkpoint_escena = str(datos.get("checkpoint_escena", ""))
	checkpoint_posicion = Vector2(
		float(datos.get("checkpoint_x", 0.0)),
		float(datos.get("checkpoint_y", 0.0))
	)
	tiene_checkpoint = bool(datos.get("tiene_checkpoint", false)) and not checkpoint_escena.is_empty()

	if datos.has("nivel_vida"):
		nivel_vida = clampi(int(datos.get("nivel_vida", 0)), 0, NIVEL_MAX_MEJORA)
	else:
		var m_raw = datos.get("mejoras", {})
		nivel_vida = 1 if (m_raw is Dictionary and bool(m_raw.get("jugger_nog", false))) else 0

	if datos.has("nivel_velocidad"):
		nivel_velocidad = clampi(int(datos.get("nivel_velocidad", 0)), 0, NIVEL_MAX_MEJORA)
	else:
		var m_raw2 = datos.get("mejoras", {})
		nivel_velocidad = 1 if (m_raw2 is Dictionary and bool(m_raw2.get("stamin_up", false))) else 0

	if datos.has("nivel_danio"):
		nivel_danio = clampi(int(datos.get("nivel_danio", 0)), 0, NIVEL_MAX_MEJORA)
	else:
		var m_raw3 = datos.get("mejoras", {})
		nivel_danio = 1 if (m_raw3 is Dictionary and bool(m_raw3.get("double_tap", false))) else 0

	_recalcular_derivados()
	vida_actual = obtener_vida_maxima()
	return true


func _leer_datos_disco() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var archivo := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if archivo == null:
		return {}
	var texto := archivo.get_as_text()
	archivo.close()
	if texto.strip_edges().is_empty():
		return {}
	var json := JSON.new()
	if json.parse(texto) != OK:
		return {}
	if json.data is Dictionary:
		return json.data
	return {}


func nueva_partida(cambiar_escena: bool = true) -> String:
	monedas_rayo = 0
	nivel_vida = 0
	nivel_velocidad = 0
	nivel_danio = 0
	_recalcular_derivados()

	checkpoint_escena = ESCENA_NIVEL_1
	checkpoint_posicion = Vector2.ZERO
	tiene_checkpoint = true
	vida_actual = obtener_vida_maxima()
	tiempo_restante = tiempo_inicial_nivel
	temporizador_activo = false
	jugador_muerto = false
	en_pausa = false
	archivos_recuperados = false
	cinematica_insercion_vista = false
	_modales_abiertos = 0
	_usar_posicion_pendiente = false
	_posicion_pendiente_respawn = Vector2.ZERO

	guardar_partida()
	archivos_recuperados_cambiados.emit(false)
	monedas_cambiadas.emit(monedas_rayo)
	mejoras_cambiadas.emit(mejoras.duplicate())
	vida_cambiada.emit(vida_actual, obtener_vida_maxima())

	get_tree().paused = false
	if cambiar_escena:
		if ResourceLoader.exists(ESCENA_NIVEL_1):
			get_tree().change_scene_to_file(ESCENA_NIVEL_1)
		else:
			push_error("GameManager: No se encontró Nivel 1 en " + ESCENA_NIVEL_1)
	return ESCENA_NIVEL_1


func continuar_partida(cambiar_escena: bool = true) -> String:
	if not cargar_partida() or not tiene_checkpoint or not ResourceLoader.exists(checkpoint_escena):
		return nueva_partida(cambiar_escena)

	jugador_muerto = false
	en_pausa = false
	_modales_abiertos = 0
	vida_actual = obtener_vida_maxima()
	tiempo_restante = tiempo_inicial_nivel
	_usar_posicion_pendiente = (checkpoint_posicion != Vector2.ZERO)
	_posicion_pendiente_respawn = checkpoint_posicion

	monedas_cambiadas.emit(monedas_rayo)
	mejoras_cambiadas.emit(mejoras.duplicate())
	vida_cambiada.emit(vida_actual, obtener_vida_maxima())

	get_tree().paused = false
	if cambiar_escena:
		get_tree().change_scene_to_file(checkpoint_escena)
	return checkpoint_escena


func reaparecer_en_checkpoint() -> void:
	jugador_muerto = false
	en_pausa = false
	_modales_abiertos = 0
	vida_actual = obtener_vida_maxima()
	tiempo_restante = tiempo_inicial_nivel
	get_tree().paused = false
	reiniciar_zonas_muerte()

	var escena_destino := checkpoint_escena
	if escena_destino.is_empty() or not ResourceLoader.exists(escena_destino):
		if get_tree().current_scene != null and not get_tree().current_scene.scene_file_path.is_empty():
			escena_destino = get_tree().current_scene.scene_file_path
		else:
			escena_destino = ESCENA_NIVEL_1

	_usar_posicion_pendiente = tiene_checkpoint and (checkpoint_posicion != Vector2.ZERO)
	_posicion_pendiente_respawn = checkpoint_posicion

	_escena_actual_id = -1
	get_tree().change_scene_to_file(escena_destino)


func reiniciar_zonas_muerte() -> void:
	for zona in get_tree().get_nodes_in_group("zonas_muerte"):
		if is_instance_valid(zona):
			if zona.has_method("reiniciar"):
				zona.reiniciar()
			elif "activada" in zona:
				zona.activada = false


func volver_al_menu_principal() -> void:
	temporizador_activo = false
	jugador_muerto = false
	en_pausa = false
	_modales_abiertos = 0
	pausa_cambiada.emit(false)
	get_tree().paused = false
	if ResourceLoader.exists(ESCENA_MENU_PRINCIPAL):
		get_tree().change_scene_to_file(ESCENA_MENU_PRINCIPAL)


# ==============================================================================
# CHECKPOINTS AUTOMÁTICOS (INICIO DE NIVEL, INTERMEDIOS Y META FINAL)
# ==============================================================================
func registrar_checkpoint(escena_path: String, posicion: Vector2, notificar: bool = true) -> void:
	if escena_path.is_empty():
		return
	checkpoint_escena = escena_path
	checkpoint_posicion = posicion
	tiene_checkpoint = true
	guardar_partida()
	if notificar:
		checkpoint_guardado.emit(checkpoint_escena, checkpoint_posicion)


func completar_meta_nivel(escena_siguiente: String = "", posicion_meta: Vector2 = Vector2.ZERO) -> void:
	if not escena_siguiente.is_empty() and ResourceLoader.exists(escena_siguiente):
		registrar_checkpoint(escena_siguiente, Vector2.ZERO, true)
	else:
		var escena_actual := ""
		if get_tree().current_scene != null:
			escena_actual = get_tree().current_scene.scene_file_path
		if not escena_actual.is_empty():
			registrar_checkpoint(escena_actual, posicion_meta, true)
		else:
			guardar_partida()


# ==============================================================================
# ECONOMÍA DE MONEDAS DE RAYO Y MEJORAS ACUMULABLES
# ==============================================================================
func sumar_monedas(cantidad: int = 1) -> void:
	if cantidad == 0:
		return
	monedas_rayo = maxi(0, monedas_rayo + cantidad)
	guardar_partida()
	monedas_cambiadas.emit(monedas_rayo)


func iniciar_temporizador(segundos: float = -1.0) -> void:
	var tiempo_obj: float = tiempo_inicial_nivel if segundos <= 0.0 else segundos
	tiempo_restante = maxf(1.0, tiempo_obj)
	temporizador_activo = true
	tiempo_cambiado.emit(tiempo_restante)


func agregar_tiempo(segundos: float = 10.0) -> void:
	if segundos <= 0.0:
		return
	tiempo_restante += segundos
	tiempo_agregado.emit(segundos)
	tiempo_cambiado.emit(tiempo_restante)


func obtener_vida_maxima() -> int:
	return VIDA_BASE + (nivel_vida * BONUS_VIDA_POR_NIVEL)


func obtener_velocidad_jugador() -> float:
	return VELOCIDAD_BASE * multiplicador_velocidad


func obtener_danio_disparo() -> int:
	return DANIO_BASE + bonus_danio


func tiene_mejora(id_mejora: String) -> bool:
	match id_mejora:
		"vida", "jugger_nog":
			return nivel_vida > 0
		"velocidad", "stamin_up":
			return nivel_velocidad > 0
		"danio", "double_tap":
			return nivel_danio > 0
		_:
			return false


func obtener_nivel_mejora(id_mejora: String) -> int:
	match id_mejora:
		"vida", "jugger_nog":
			return nivel_vida
		"velocidad", "stamin_up":
			return nivel_velocidad
		"danio", "double_tap":
			return nivel_danio
		_:
			return 0


func obtener_costo_siguiente(id_mejora: String) -> int:
	var nv := obtener_nivel_mejora(id_mejora)
	if nv >= NIVEL_MAX_MEJORA:
		return -1
	match id_mejora:
		"vida", "jugger_nog":
			return COSTOS_VIDA[nv]
		"velocidad", "stamin_up":
			return COSTOS_VELOCIDAD[nv]
		"danio", "double_tap":
			return COSTOS_DANIO[nv]
		_:
			return -1


func obtener_catalogo_mejoras() -> Array[Dictionary]:
	return [
		{
			"id": "vida",
			"nombre": "Blindaje Vital",
			"subtitulo": "Más Vida y Curación",
			"descripcion": "+%d Vida Máx. por nivel y curación completa inmediata. (Actual: %d HP)" % [
				BONUS_VIDA_POR_NIVEL, obtener_vida_maxima()
			],
			"nivel": nivel_vida,
			"nivel_max": NIVEL_MAX_MEJORA,
			"costo": obtener_costo_siguiente("vida"),
			"color": Color(0.92, 0.25, 0.34),
			"icono": "res://assets/objetos/icono_jugger_nog.svg",
		},
		{
			"id": "velocidad",
			"nombre": "Propulsores Ligeros",
			"subtitulo": "Más Velocidad (+15%/nv)",
			"descripcion": "Aumenta la velocidad horizontal +15%% por nivel sin alterar el salto. (Actual: %.0f%%)" % [
				multiplicador_velocidad * 100.0
			],
			"nivel": nivel_velocidad,
			"nivel_max": NIVEL_MAX_MEJORA,
			"costo": obtener_costo_siguiente("velocidad"),
			"color": Color(0.97, 0.78, 0.22),
			"icono": "res://assets/objetos/icono_stamin_up.svg",
		},
		{
			"id": "danio",
			"nombre": "Sobrecarga de Munición",
			"subtitulo": "Más Daño de Disparo",
			"descripcion": "+%d daño extra para ProyectilJugador contra enemigos. (Actual: %d DMG)" % [
				BONUS_DANIO_POR_NIVEL, obtener_danio_disparo()
			],
			"nivel": nivel_danio,
			"nivel_max": NIVEL_MAX_MEJORA,
			"costo": obtener_costo_siguiente("danio"),
			"color": Color(1.0, 0.48, 0.16),
			"icono": "res://assets/objetos/icono_double_tap.svg",
		},
	]


func comprar_mejora(id_mejora: String) -> Dictionary:
	var id_norm := _normalizar_id_mejora(id_mejora)
	if id_norm.is_empty():
		return {"ok": false, "mensaje": "Mejora desconocida."}

	var nivel_actual := obtener_nivel_mejora(id_norm)
	if nivel_actual >= NIVEL_MAX_MEJORA:
		return {"ok": false, "mensaje": "Esta mejora ya alcanzó su nivel máximo (Nv. %d/%d)." % [NIVEL_MAX_MEJORA, NIVEL_MAX_MEJORA]}

	var costo := obtener_costo_siguiente(id_norm)
	if monedas_rayo < costo:
		return {"ok": false, "mensaje": "Te faltan %d Monedas de Rayo para esta mejora." % (costo - monedas_rayo)}

	monedas_rayo -= costo
	var curar_total := false
	var nombre_mostrar := ""

	match id_norm:
		"vida":
			nivel_vida += 1
			curar_total = true
			nombre_mostrar = "Blindaje Vital Nv.%d" % nivel_vida
		"velocidad":
			nivel_velocidad += 1
			nombre_mostrar = "Propulsores Ligeros Nv.%d" % nivel_velocidad
		"danio":
			nivel_danio += 1
			nombre_mostrar = "Sobrecarga de Munición Nv.%d" % nivel_danio

	_recalcular_derivados()
	if curar_total:
		vida_actual = obtener_vida_maxima()

	guardar_partida()
	monedas_cambiadas.emit(monedas_rayo)
	mejoras_cambiadas.emit(mejoras.duplicate())
	aplicar_mejoras_a_jugador(curar_total)

	return {"ok": true, "mensaje": "¡%s adquirido y aplicado!" % nombre_mostrar}


func aplicar_mejoras_a_jugador(curar_al_maximo: bool = false) -> void:
	var jugador := obtener_jugador_actual()
	if jugador != null and jugador.has_method("sincronizar_con_game_manager"):
		jugador.sincronizar_con_game_manager(curar_al_maximo)
	else:
		var max_hp := obtener_vida_maxima()
		if curar_al_maximo:
			vida_actual = max_hp
		vida_cambiada.emit(vida_actual, max_hp)


func actualizar_vida(actual: int, maxima: int) -> void:
	vida_actual = clampi(actual, 0, maxima)
	vida_cambiada.emit(vida_actual, maxima)


func activar_muerte_jugador(motivo: String = "HAS CAÍDO") -> void:
	if jugador_muerto:
		return
	jugador_muerto = true
	temporizador_activo = false
	en_pausa = false

	_reproducir_sonido_muerte_alternado()

	var jugador := obtener_jugador_actual()
	if jugador != null and jugador.has_method("forzar_estado_muerto"):
		jugador.forzar_estado_muerto()

	vida_cambiada.emit(0, obtener_vida_maxima())
	jugador_murio.emit(motivo)


func _configurar_audio_muerte_jugador() -> void:
	if _audio_muerte_jugador != null and is_instance_valid(_audio_muerte_jugador):
		return
	_audio_muerte_jugador = AudioStreamPlayer.new()
	_audio_muerte_jugador.name = "AudioMuerteJugador"
	_audio_muerte_jugador.process_mode = Node.PROCESS_MODE_ALWAYS
	_audio_muerte_jugador.bus = BUS_SFX if AudioServer.get_bus_index(BUS_SFX) != -1 else "Master"
	add_child(_audio_muerte_jugador)


func _reproducir_sonido_muerte_alternado() -> void:
	_configurar_audio_muerte_jugador()
	if _audio_muerte_jugador == null:
		return

	var idx: int = indice_muerte_actual % 2
	indice_muerte_actual = (indice_muerte_actual + 1) % 2

	var ruta_elegida: String = ""
	if existe_audio_seguro(RUTAS_AUDIO_MUERTE[idx]):
		ruta_elegida = RUTAS_AUDIO_MUERTE[idx]
	elif existe_audio_seguro(RUTAS_AUDIO_MUERTE_WAV[idx]):
		ruta_elegida = RUTAS_AUDIO_MUERTE_WAV[idx]

	if ruta_elegida.is_empty():
		return

	var stream := cargar_audio_seguro(ruta_elegida)
	if stream == null:
		return

	# Efecto de un solo disparo: asegurar que el bucle esté desactivado
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = false
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED

	_audio_muerte_jugador.process_mode = Node.PROCESS_MODE_ALWAYS
	_audio_muerte_jugador.bus = BUS_SFX if AudioServer.get_bus_index(BUS_SFX) != -1 else "Master"
	_audio_muerte_jugador.stop()
	_audio_muerte_jugador.stream = stream
	_audio_muerte_jugador.play(0.0)


func _configurar_audio_sfx_moneda() -> void:
	if _audio_sfx_moneda != null and is_instance_valid(_audio_sfx_moneda):
		return
	_audio_sfx_moneda = AudioStreamPlayer.new()
	_audio_sfx_moneda.name = "AudioSfxMoneda"
	_audio_sfx_moneda.process_mode = Node.PROCESS_MODE_ALWAYS
	_audio_sfx_moneda.max_polyphony = 4
	_audio_sfx_moneda.bus = BUS_SFX if AudioServer.get_bus_index(BUS_SFX) != -1 else "Master"
	add_child(_audio_sfx_moneda)


func reproducir_sfx_moneda(ruta: String) -> void:
	if ruta.is_empty():
		return
	_configurar_audio_sfx_moneda()
	if _audio_sfx_moneda == null:
		return

	var stream: AudioStream = _cache_sfx_monedas.get(ruta, null) as AudioStream
	if stream == null:
		if not existe_audio_seguro(ruta):
			return
		stream = cargar_audio_seguro(ruta)
		if stream == null:
			return
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = false
		elif stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = false
		elif stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
		_cache_sfx_monedas[ruta] = stream

	_audio_sfx_moneda.bus = BUS_SFX if AudioServer.get_bus_index(BUS_SFX) != -1 else "Master"
	_audio_sfx_moneda.stream = stream
	_audio_sfx_moneda.play(0.0)


func registrar_modal_abierto(abierto: bool) -> void:
	if abierto:
		_modales_abiertos += 1
	else:
		_modales_abiertos = maxi(0, _modales_abiertos - 1)


func hay_modal_interactivo_abierto() -> bool:
	return _modales_abiertos > 0


func marcar_archivos_recuperados(estado: bool) -> void:
	archivos_recuperados = estado
	var escena := get_tree().current_scene if get_tree() != null else null
	if escena != null:
		escena.set_meta("archivos_recuperados", estado)
	archivos_recuperados_cambiados.emit(estado)


func tiene_archivos_recuperados() -> bool:
	if archivos_recuperados:
		return true
	var escena := get_tree().current_scene if get_tree() != null else null
	if escena != null and escena.has_meta("archivos_recuperados"):
		return bool(escena.get_meta("archivos_recuperados"))
	return false


func existe_audio_seguro(ruta: String) -> bool:
	if ruta.is_empty():
		return false
	return ResourceLoader.exists(ruta) or FileAccess.file_exists(ruta)


func cargar_audio_seguro(ruta: String) -> AudioStream:
	if ruta.is_empty():
		return null
	if ResourceLoader.exists(ruta):
		var recurso := ResourceLoader.load(ruta)
		if recurso is AudioStream:
			return recurso as AudioStream
	if FileAccess.file_exists(ruta):
		var ruta_lower := ruta.to_lower()
		if ruta_lower.ends_with(".wav"):
			return AudioStreamWAV.load_from_file(ruta)
		if ruta_lower.ends_with(".mp3"):
			var bytes := FileAccess.get_file_as_bytes(ruta)
			if not bytes.is_empty():
				var stream_mp3 := AudioStreamMP3.new()
				stream_mp3.data = bytes
				return stream_mp3
	return null


func establecer_pausa(pausar: bool) -> void:
	if jugador_muerto:
		return
	en_pausa = pausar
	get_tree().paused = pausar
	pausa_cambiada.emit(en_pausa)


func obtener_jugador_actual() -> Node2D:
	var jugadores := get_tree().get_nodes_in_group("jugador")
	for nodo in jugadores:
		if is_instance_valid(nodo) and nodo is Node2D:
			return nodo as Node2D
	return null


func obtener_nombre_nivel(escena_path: String) -> String:
	var nombre := escena_path.get_file().get_basename().to_lower()
	match nombre:
		"escena_01":
			return "Nivel 1 — Electrostática"
		"escena_02":
			return "Nivel 2 — Capacitores"
		"escena_03":
			return "Nivel 3 — Electromagnetismo"
		"escena_4":
			return "Nivel 4 — Extracción Final"
		_:
			if escena_path.is_empty():
				return "Sin Checkpoint"
			return escena_path.get_file().get_basename()


# ==============================================================================
# CONFIGURACIÓN AUTOMÁTICA AL ENTRAR EN CADA ESCENA DE NIVEL
# ==============================================================================
func _al_cambiar_escena(escena: Node) -> void:
	var ruta := escena.scene_file_path
	if _es_escena_menu(ruta):
		temporizador_activo = false
		jugador_muerto = false
		en_pausa = false
		_modales_abiertos = 0
		get_tree().paused = false
		return

	call_deferred("_configurar_escena_juego", escena)


func _configurar_escena_juego(escena: Node) -> void:
	if not is_instance_valid(escena) or get_tree().current_scene != escena:
		return

	var ruta := escena.scene_file_path
	if _es_escena_menu(ruta):
		return

	jugador_muerto = false
	en_pausa = false
	_modales_abiertos = 0
	get_tree().paused = false
	_recalcular_derivados()

	# En Nivel 3 los archivos clasificados deben recuperarse del estante antes de salir
	if ruta.get_file().to_lower() == "escena_03.tscn":
		marcar_archivos_recuperados(false)

	# 1. Posicionar jugador en checkpoint y aplicar mejoras activas automáticamente
	var jugador := obtener_jugador_actual()
	if jugador != null:
		if _usar_posicion_pendiente and _posicion_pendiente_respawn != Vector2.ZERO:
			jugador.global_position = _posicion_pendiente_respawn
			if jugador is CharacterBody2D:
				(jugador as CharacterBody2D).velocity = Vector2.ZERO
			_usar_posicion_pendiente = false
		elif not ruta.is_empty():
			if (not tiene_checkpoint) or checkpoint_escena != ruta or checkpoint_posicion == Vector2.ZERO:
				registrar_checkpoint(ruta, jugador.global_position, true)

		if jugador.has_method("sincronizar_con_game_manager"):
			jugador.sincronizar_con_game_manager(true)
	elif not ruta.is_empty() and ((not tiene_checkpoint) or checkpoint_escena != ruta):
		registrar_checkpoint(ruta, Vector2.ZERO, false)

	# 2. Reiniciar zonas de muerte y garantizar HUD + PantallaMuerte
	reiniciar_zonas_muerte()
	_asegurar_ui_de_nivel(escena)

	# 3. Iniciar cuenta regresiva del nivel y emitir estado inicial a la UI
	iniciar_temporizador(tiempo_inicial_nivel)
	monedas_cambiadas.emit(monedas_rayo)
	mejoras_cambiadas.emit(mejoras.duplicate())
	vida_cambiada.emit(vida_actual, obtener_vida_maxima())

	# 4. Respetar cualquier NotaCientifico obligatoria que se haya abierto al iniciar el nivel
	for nota in get_tree().get_nodes_in_group("nota_cientifico"):
		if is_instance_valid(nota) and nota.has_method("esta_abierta") and nota.esta_abierta():
			_modales_abiertos = maxi(_modales_abiertos, 1)
			get_tree().paused = true
			break

	# 5. Respetar cualquier cinemática de inserción inicial activa (mantiene el HUD pausado sin congelar la animación)
	for cine in get_tree().get_nodes_in_group("cinematica_insercion"):
		if is_instance_valid(cine) and cine.has_method("esta_activa") and cine.esta_activa():
			temporizador_activo = false
			_modales_abiertos = maxi(_modales_abiertos, 1)
			break


func _asegurar_ui_de_nivel(escena: Node) -> void:
	if get_tree().get_nodes_in_group("hud_juego").is_empty():
		if _hud_escena_cache == null and ResourceLoader.exists(ESCENA_HUD):
			_hud_escena_cache = load(ESCENA_HUD) as PackedScene
		if _hud_escena_cache != null:
			var hud_inst := _hud_escena_cache.instantiate()
			escena.add_child(hud_inst)

	if get_tree().get_nodes_in_group("pantalla_muerte").is_empty():
		if _muerte_escena_cache == null and ResourceLoader.exists(ESCENA_PANTALLA_MUERTE):
			_muerte_escena_cache = load(ESCENA_PANTALLA_MUERTE) as PackedScene
		if _muerte_escena_cache != null:
			var muerte_inst := _muerte_escena_cache.instantiate()
			escena.add_child(muerte_inst)


func _es_escena_menu(ruta: String) -> bool:
	if ruta.is_empty():
		return false
	var archivo := ruta.get_file().to_lower()
	return archivo == "menuprincipal.tscn" or archivo == "pantalladerrota.tscn"


func _recalcular_derivados() -> void:
	multiplicador_velocidad = 1.0 + (float(nivel_velocidad) * BONUS_VELOCIDAD_POR_NIVEL)
	bonus_danio = nivel_danio * BONUS_DANIO_POR_NIVEL
	_sincronizar_diccionario_mejoras()


func _sincronizar_diccionario_mejoras() -> void:
	mejoras = {
		"jugger_nog": nivel_vida > 0,
		"stamin_up": nivel_velocidad > 0,
		"double_tap": nivel_danio > 0,
	}


func _normalizar_id_mejora(id_mejora: String) -> String:
	match id_mejora:
		"vida", "jugger_nog":
			return "vida"
		"velocidad", "stamin_up":
			return "velocidad"
		"danio", "double_tap":
			return "danio"
		_:
			return ""
