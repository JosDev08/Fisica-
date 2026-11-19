extends Node

# ==============================================================================
# AUTOLOAD: GameManager
# Gestiona guardado en disco (user://savegame.save), Monedas de Rayo,
# Checkpoints automáticos (inicio y meta de nivel), 3 Mejoras de partida,
# Temporizador competitivo, HUD global y Pantalla de Muerte.
# ==============================================================================

signal monedas_cambiadas(cantidad: int)
signal vida_cambiada(actual: int, maxima: int)
signal tiempo_cambiado(tiempo_restante: float)
signal tiempo_agregado(segundos: float)
signal mejoras_cambiadas(mejoras: Dictionary)
signal checkpoint_guardado(escena: String, posicion: Vector2)
signal jugador_murio(motivo: String)
signal pausa_cambiada(en_pausa: bool)

const SAVE_PATH: String = "user://savegame.save"
const ESCENA_NIVEL_1: String = "res://Escenas/escena_01.tscn"
const ESCENA_MENU_PRINCIPAL: String = "res://Escenas/UI/MenuPrincipal.tscn"
const ESCENA_HUD: String = "res://Escenas/HUD.tscn"
const ESCENA_PANTALLA_MUERTE: String = "res://Escenas/PantallaMuerte.tscn"

# Estadísticas base del jugador y balance de mejoras de partida
const VIDA_BASE: int = 100
const VELOCIDAD_BASE: float = 220.0
const DANIO_BASE: int = 25

const BONUS_VIDA_JUGGER_NOG: int = 50       # 100 -> 150 HP + curación total
const BONUS_VELOCIDAD_STAMIN_UP: float = 65.0 # 220 -> 285 px/s (~+30%)
const BONUS_DANIO_DOUBLE_TAP: int = 20      # 25 -> 45 daño por disparo

const COSTO_JUGGER_NOG: int = 4
const COSTO_STAMIN_UP: int = 3
const COSTO_DOUBLE_TAP: int = 5

const TIEMPO_NIVEL_DEFAULT: float = 120.0

# Estado persistente de la partida activa
var monedas_rayo: int = 0
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
var tiempo_restante: float = TIEMPO_NIVEL_DEFAULT
var temporizador_activo: bool = false
var jugador_muerto: bool = false
var en_pausa: bool = false

var _usar_posicion_pendiente: bool = false
var _posicion_pendiente_respawn: Vector2 = Vector2.ZERO
var _escena_actual_id: int = -1
var _modales_abiertos: int = 0
var _hud_escena_cache: PackedScene = null
var _muerte_escena_cache: PackedScene = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cargar_partida()


func _process(delta: float) -> void:
	var tree := get_tree()
	if tree == null:
		return

	var escena := tree.current_scene
	if escena != null and escena.get_instance_id() != _escena_actual_id:
		_escena_actual_id = escena.get_instance_id()
		_al_cambiar_escena(escena)

	if temporizador_activo and not tree.paused and not jugador_muerto and _modales_abiertos <= 0:
		tiempo_restante = maxf(0.0, tiempo_restante - delta)
		tiempo_cambiado.emit(tiempo_restante)
		if tiempo_restante <= 0.0:
			activar_muerte_jugador("¡SE ACABÓ EL TIEMPO!")


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
	var datos := {
		"monedas_rayo": monedas_rayo,
		"checkpoint_escena": checkpoint_escena,
		"checkpoint_x": checkpoint_posicion.x,
		"checkpoint_y": checkpoint_posicion.y,
		"tiene_checkpoint": tiene_checkpoint,
		"mejoras": {
			"jugger_nog": bool(mejoras.get("jugger_nog", false)),
			"stamin_up": bool(mejoras.get("stamin_up", false)),
			"double_tap": bool(mejoras.get("double_tap", false)),
		},
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

	var m_raw = datos.get("mejoras", {})
	if m_raw is Dictionary:
		mejoras["jugger_nog"] = bool(m_raw.get("jugger_nog", false))
		mejoras["stamin_up"] = bool(m_raw.get("stamin_up", false))
		mejoras["double_tap"] = bool(m_raw.get("double_tap", false))
	else:
		_reiniciar_diccionario_mejoras()

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


func nueva_partida() -> void:
	monedas_rayo = 0
	_reiniciar_diccionario_mejoras()
	checkpoint_escena = ESCENA_NIVEL_1
	checkpoint_posicion = Vector2.ZERO
	tiene_checkpoint = true
	vida_actual = obtener_vida_maxima()
	tiempo_restante = TIEMPO_NIVEL_DEFAULT
	temporizador_activo = false
	jugador_muerto = false
	en_pausa = false
	_modales_abiertos = 0
	_usar_posicion_pendiente = false
	_posicion_pendiente_respawn = Vector2.ZERO

	guardar_partida()
	monedas_cambiadas.emit(monedas_rayo)
	mejoras_cambiadas.emit(mejoras.duplicate())
	vida_cambiada.emit(vida_actual, obtener_vida_maxima())

	get_tree().paused = false
	if ResourceLoader.exists(ESCENA_NIVEL_1):
		get_tree().change_scene_to_file(ESCENA_NIVEL_1)
	else:
		push_error("GameManager: No se encontró Nivel 1 en " + ESCENA_NIVEL_1)


func continuar_partida() -> void:
	if not cargar_partida() or not tiene_checkpoint or not ResourceLoader.exists(checkpoint_escena):
		nueva_partida()
		return

	jugador_muerto = false
	en_pausa = false
	_modales_abiertos = 0
	vida_actual = obtener_vida_maxima()
	_usar_posicion_pendiente = (checkpoint_posicion != Vector2.ZERO)
	_posicion_pendiente_respawn = checkpoint_posicion

	monedas_cambiadas.emit(monedas_rayo)
	mejoras_cambiadas.emit(mejoras.duplicate())
	vida_cambiada.emit(vida_actual, obtener_vida_maxima())

	get_tree().paused = false
	get_tree().change_scene_to_file(checkpoint_escena)


func reaparecer_en_checkpoint() -> void:
	jugador_muerto = false
	en_pausa = false
	_modales_abiertos = 0
	vida_actual = obtener_vida_maxima()
	tiempo_restante = TIEMPO_NIVEL_DEFAULT

	var escena_destino := checkpoint_escena
	if escena_destino.is_empty() or not ResourceLoader.exists(escena_destino):
		if get_tree().current_scene != null and not get_tree().current_scene.scene_file_path.is_empty():
			escena_destino = get_tree().current_scene.scene_file_path
		else:
			escena_destino = ESCENA_NIVEL_1

	_usar_posicion_pendiente = (checkpoint_posicion != Vector2.ZERO)
	_posicion_pendiente_respawn = checkpoint_posicion

	get_tree().paused = false
	_escena_actual_id = -1
	get_tree().change_scene_to_file(escena_destino)


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
# MONEDAS, TEMPORIZADOR Y MEJORAS BALANCEADAS DE PARTIDA
# ==============================================================================
func sumar_monedas(cantidad: int = 1) -> void:
	if cantidad == 0:
		return
	monedas_rayo = maxi(0, monedas_rayo + cantidad)
	guardar_partida()
	monedas_cambiadas.emit(monedas_rayo)


func iniciar_temporizador(segundos: float = TIEMPO_NIVEL_DEFAULT) -> void:
	tiempo_restante = maxf(1.0, segundos)
	temporizador_activo = true
	tiempo_cambiado.emit(tiempo_restante)


func agregar_tiempo(segundos: float = 10.0) -> void:
	if segundos <= 0.0:
		return
	tiempo_restante += segundos
	tiempo_agregado.emit(segundos)
	tiempo_cambiado.emit(tiempo_restante)


func obtener_vida_maxima() -> int:
	return VIDA_BASE + (BONUS_VIDA_JUGGER_NOG if bool(mejoras.get("jugger_nog", false)) else 0)


func obtener_velocidad_jugador() -> float:
	return VELOCIDAD_BASE + (BONUS_VELOCIDAD_STAMIN_UP if bool(mejoras.get("stamin_up", false)) else 0.0)


func obtener_danio_disparo() -> int:
	return DANIO_BASE + (BONUS_DANIO_DOUBLE_TAP if bool(mejoras.get("double_tap", false)) else 0)


func tiene_mejora(id_mejora: String) -> bool:
	return bool(mejoras.get(id_mejora, false))


func obtener_catalogo_mejoras() -> Array[Dictionary]:
	return [
		{
			"id": "jugger_nog",
			"nombre": "Jugger-Nog",
			"subtitulo": "Más Vida / Sanación",
			"descripcion": "+%d Vida Máxima (%d HP) y sanación completa inmediata." % [BONUS_VIDA_JUGGER_NOG, VIDA_BASE + BONUS_VIDA_JUGGER_NOG],
			"costo": COSTO_JUGGER_NOG,
			"color": Color(0.92, 0.25, 0.32),
			"icono": "res://assets/objetos/icono_jugger_nog.svg",
		},
		{
			"id": "stamin_up",
			"nombre": "Stamin-Up",
			"subtitulo": "Correr Más Rápido",
			"descripcion": "Aumenta la velocidad de %.0f a %.0f px/s para vencer el reloj." % [VELOCIDAD_BASE, VELOCIDAD_BASE + BONUS_VELOCIDAD_STAMIN_UP],
			"costo": COSTO_STAMIN_UP,
			"color": Color(0.97, 0.78, 0.22),
			"icono": "res://assets/objetos/icono_stamin_up.svg",
		},
		{
			"id": "double_tap",
			"nombre": "Double Tap",
			"subtitulo": "Más Daño",
			"descripcion": "Eleva el daño de tus disparos energéticos de %d a %d." % [DANIO_BASE, DANIO_BASE + BONUS_DANIO_DOUBLE_TAP],
			"costo": COSTO_DOUBLE_TAP,
			"color": Color(1.0, 0.48, 0.16),
			"icono": "res://assets/objetos/icono_double_tap.svg",
		},
	]


func comprar_mejora(id_mejora: String) -> Dictionary:
	var info := _buscar_info_mejora(id_mejora)
	if info.is_empty():
		return {"ok": false, "mensaje": "Mejora desconocida."}

	if tiene_mejora(id_mejora):
		return {"ok": false, "mensaje": "%s ya está equipado en esta partida." % info["nombre"]}

	var costo: int = int(info["costo"])
	if monedas_rayo < costo:
		return {"ok": false, "mensaje": "Te faltan %d Monedas de Rayo para %s." % [costo - monedas_rayo, info["nombre"]]}

	monedas_rayo -= costo
	mejoras[id_mejora] = true

	if id_mejora == "jugger_nog":
		vida_actual = obtener_vida_maxima()

	guardar_partida()
	monedas_cambiadas.emit(monedas_rayo)
	mejoras_cambiadas.emit(mejoras.duplicate())
	aplicar_mejoras_a_jugador(id_mejora == "jugger_nog")

	return {"ok": true, "mensaje": "¡%s equipado para toda la partida!" % info["nombre"]}


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

	var jugador := obtener_jugador_actual()
	if jugador != null and jugador.has_method("forzar_estado_muerto"):
		jugador.forzar_estado_muerto()

	vida_cambiada.emit(0, obtener_vida_maxima())
	jugador_murio.emit(motivo)


func registrar_modal_abierto(abierto: bool) -> void:
	if abierto:
		_modales_abiertos += 1
	else:
		_modales_abiertos = maxi(0, _modales_abiertos - 1)


func hay_modal_interactivo_abierto() -> bool:
	return _modales_abiertos > 0


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

	# 1. Posicionar jugador si corresponde a un respawn/continuar en checkpoint
	var jugador := obtener_jugador_actual()
	if jugador != null:
		if _usar_posicion_pendiente and _posicion_pendiente_respawn != Vector2.ZERO:
			jugador.global_position = _posicion_pendiente_respawn
			if jugador is CharacterBody2D:
				(jugador as CharacterBody2D).velocity = Vector2.ZERO
			_usar_posicion_pendiente = false
		elif not ruta.is_empty():
			# Guardado automático al iniciar un nivel nuevo o sin posición fija todavía
			if (not tiene_checkpoint) or checkpoint_escena != ruta or checkpoint_posicion == Vector2.ZERO:
				registrar_checkpoint(ruta, jugador.global_position, true)

		if jugador.has_method("sincronizar_con_game_manager"):
			jugador.sincronizar_con_game_manager(true)
	elif not ruta.is_empty() and ((not tiene_checkpoint) or checkpoint_escena != ruta):
		registrar_checkpoint(ruta, Vector2.ZERO, false)

	# 2. Garantizar HUD y Pantalla de Muerte presentes en cualquier escena de juego
	_asegurar_ui_de_nivel(escena)

	# 3. Iniciar cuenta regresiva del nivel y emitir estado inicial a la UI
	iniciar_temporizador(TIEMPO_NIVEL_DEFAULT)
	monedas_cambiadas.emit(monedas_rayo)
	mejoras_cambiadas.emit(mejoras.duplicate())
	vida_cambiada.emit(vida_actual, obtener_vida_maxima())


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


func _reiniciar_diccionario_mejoras() -> void:
	mejoras = {
		"jugger_nog": false,
		"stamin_up": false,
		"double_tap": false,
	}


func _buscar_info_mejora(id_mejora: String) -> Dictionary:
	for item in obtener_catalogo_mejoras():
		if item["id"] == id_mejora:
			return item
	return {}
