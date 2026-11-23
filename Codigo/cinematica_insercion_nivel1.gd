extends Node2D

# ==============================================================================
# CINEMÁTICA DE INSERCIÓN EN HELICÓPTERO — NIVEL 1 (res://Escenas/escena_01.tscn)
# Orden exacto al cargar escena_01.tscn por primera vez:
# 1) Oculta y bloquea temporalmente al Jugador y pausa el temporizador del HUD,
#    manteniendo la Camera2D enfocada en la zona de inicio.
# 2) El helicóptero entra desde arriba-izquierda (spawn + (-380, -260)) y
#    desciende suavemente durante 1.4 s hasta flotar sobre el inicio (0, -65).
# 3) El soldado aparece y cae suavemente al suelo inicial (Capa 5 Suelo) mientras
#    el helicóptero inclina el morro y se eleva para retirarse en 1.2 s.
# 4) Apenas aterriza el soldado y el helicóptero comienza a elevarse, se abre
#    automáticamente NotaCientifico (abrir_nota()).
# 5) Al cerrar NotaCientifico ("ENTENDIDO / INICIAR MISIÓN"), se reanuda el
#    juego, se reactivan los controles del Jugador y arranca el temporizador.
# - No se repite si el jugador muere y reaparece en un checkpoint.
# ==============================================================================

const TEX_HELICOPTERO := "res://assets/nivel_1/helicoptero_insercion.svg"
const DURACION_DESCENSO: float = 1.4
const DURACION_RETIRADA: float = 1.2
const OFFSET_ENTRADA := Vector2(-380.0, -260.0)
const OFFSET_FLOTACION := Vector2(0.0, -65.0)
const OFFSET_SALIDA := Vector2(450.0, -260.0)
const ALTURA_SOLTADO_SOLDADO: float = 54.0
const GRAVEDAD_CAIDA: float = 780.0

var _cinematica_activa: bool = false
var _modal_registrado: bool = false
var _caida_soldado_activa: bool = false
var _nota_lanzada: bool = false
var _controles_restaurados: bool = false

var _spawn_pos: Vector2 = Vector2.ZERO
var _cam_offset_original: Vector2 = Vector2.ZERO
var _vel_caida: float = 0.0
var _tiempo_caida: float = 0.0
var _fase_helice: float = 0.0
var _velocidad_helice: float = 44.0

var _jugador: CharacterBody2D = null
var _cam: Camera2D = null
var _nota_cientifico: Node = null
var _helicoptero: Node2D = null
var _helice_principal: Node2D = null
var _helice_cola: Node2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("cinematica_insercion")

	_jugador = _buscar_jugador()
	_nota_cientifico = _buscar_nota_cientifico()

	# Solo ejecutar la cinemática la primera vez que se carga escena_01.tscn
	# (no repetir al reaparecer en checkpoint tras morir)
	if GameManager.cinematica_insercion_vista:
		_cinematica_activa = false
		return

	if _jugador == null:
		GameManager.cinematica_insercion_vista = true
		if _nota_cientifico != null and _nota_cientifico.has_method("abrir_nota"):
			_nota_cientifico.call_deferred("abrir_nota")
		return

	GameManager.cinematica_insercion_vista = true
	_iniciar_cinematica()


func esta_activa() -> bool:
	return _cinematica_activa


func _process(delta: float) -> void:
	# Mantener las hélices girando con suavidad incluso mientras NotaCientifico pausa el árbol
	if is_instance_valid(_helicoptero):
		_fase_helice += delta * _velocidad_helice
		if is_instance_valid(_helice_principal):
			_helice_principal.scale.x = 0.16 + 0.84 * absf(cos(_fase_helice))
		if is_instance_valid(_helice_cola):
			_helice_cola.rotation += delta * (_velocidad_helice * 0.92)


func _physics_process(delta: float) -> void:
	if not _caida_soldado_activa or _jugador == null:
		return
	if get_tree().paused:
		return

	_tiempo_caida += delta
	_vel_caida = minf(_vel_caida + GRAVEDAD_CAIDA * delta, 460.0)
	var colision := _jugador.move_and_collide(Vector2(0.0, _vel_caida * delta))

	# Mantener la Camera2D estable enfocada en la zona de inicio durante la caída
	if is_instance_valid(_cam):
		_cam.offset = _cam_offset_original + Vector2(0.0, _spawn_pos.y - _jugador.global_position.y)

	if colision != null or _jugador.global_position.y >= _spawn_pos.y or _tiempo_caida >= 0.85:
		if colision == null:
			_jugador.global_position.y = _spawn_pos.y
		_al_aterrizar_soldado()


func _iniciar_cinematica() -> void:
	_cinematica_activa = true
	_spawn_pos = _jugador.global_position
	_cam = _jugador.get_node_or_null("Camera2D") as Camera2D
	if _cam != null:
		_cam_offset_original = _cam.offset

	# 1. Ocultar y desactivar controles del Jugador, manteniendo el temporizador pausado
	_jugador.velocity = Vector2.ZERO
	_jugador.visible = false
	_jugador.set_physics_process(false)
	_jugador.set_process(false)
	_jugador.set_process_unhandled_input(false)
	_jugador.collision_layer = 0

	GameManager.temporizador_activo = false
	if not _modal_registrado:
		_modal_registrado = true
		GameManager.registrar_modal_abierto(true)

	# 2. Instanciar helicóptero fuera de pantalla (arriba-izquierda respecto al spawn)
	_crear_helicoptero()
	if _helicoptero == null:
		_abrir_nota_cientifico()
		return

	_helicoptero.global_position = _spawn_pos + OFFSET_ENTRADA
	_helicoptero.rotation_degrees = 8.0

	# 3. Descenso suave durante 1.4 s hasta flotar sobre el punto de inicio
	var destino_flotacion := _spawn_pos + OFFSET_FLOTACION
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_helicoptero, "global_position", destino_flotacion, DURACION_DESCENSO).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var tw_inclinacion := create_tween()
	tw_inclinacion.tween_property(_helicoptero, "rotation_degrees", -4.5, DURACION_DESCENSO * 0.62).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_inclinacion.tween_property(_helicoptero, "rotation_degrees", 0.0, DURACION_DESCENSO * 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tw.chain().tween_callback(_al_llegar_punto_despliegue)


func _al_llegar_punto_despliegue() -> void:
	if not is_instance_valid(_jugador):
		_abrir_nota_cientifico()
		return

	# Hacer visible al soldado saliendo del helicóptero para caer suavemente al suelo
	_jugador.global_position = _spawn_pos + Vector2(0.0, -ALTURA_SOLTADO_SOLDADO)
	if is_instance_valid(_cam):
		_cam.offset = _cam_offset_original + Vector2(0.0, _spawn_pos.y - _jugador.global_position.y)
	_jugador.visible = true
	_jugador.velocity = Vector2.ZERO

	var anim := _jugador.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim != null:
		anim.flip_h = false
		if anim.sprite_frames != null and anim.sprite_frames.has_animation(&"Saltar"):
			anim.play(&"Saltar")

	_vel_caida = 45.0
	_tiempo_caida = 0.0
	_caida_soldado_activa = true

	# Iniciar la inclinación y retirada del helicóptero tras un breve instante de despliegue
	_iniciar_retirada_helicoptero()


func _iniciar_retirada_helicoptero() -> void:
	if not is_instance_valid(_helicoptero):
		return

	_velocidad_helice = 58.0
	var destino_salida := _helicoptero.global_position + OFFSET_SALIDA

	var tw := create_tween()
	# Permite que el helicóptero termine de salir de pantalla limpiamente incluso al abrirse NotaCientifico
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_interval(0.16)
	tw.tween_property(_helicoptero, "rotation_degrees", 11.5, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var tw_vuelo := create_tween()
	tw_vuelo.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw_vuelo.tween_interval(0.16)
	tw_vuelo.tween_property(_helicoptero, "global_position", destino_salida, DURACION_RETIRADA).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw_vuelo.tween_callback(_limpiar_helicoptero)


func _al_aterrizar_soldado() -> void:
	_caida_soldado_activa = false

	if is_instance_valid(_cam):
		_cam.offset = _cam_offset_original

	if is_instance_valid(_jugador):
		_jugador.velocity = Vector2.ZERO
		_jugador.collision_layer = 1 # Capa 1: Jugador
		var anim := _jugador.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if anim != null and anim.sprite_frames != null and anim.sprite_frames.has_animation(&"Reposo"):
			anim.play(&"Reposo")

	# Breve instante (~0.22 s) para apreciar el aterrizaje y el ascenso inicial del helicóptero
	var timer := get_tree().create_timer(0.22, true)
	timer.timeout.connect(_abrir_nota_cientifico, CONNECT_ONE_SHOT)


func _abrir_nota_cientifico() -> void:
	if _nota_lanzada:
		return
	_nota_lanzada = true
	_cinematica_activa = false

	# Liberar el bloqueo modal propio de la cinemática antes de ceder el control a NotaCientifico
	if _modal_registrado:
		_modal_registrado = false
		GameManager.registrar_modal_abierto(false)

	if is_instance_valid(_nota_cientifico) and _nota_cientifico.has_method("abrir_nota"):
		if _nota_cientifico.has_signal("transmision_cerrada") and not _nota_cientifico.transmision_cerrada.is_connected(_al_cerrar_nota):
			_nota_cientifico.transmision_cerrada.connect(_al_cerrar_nota, CONNECT_ONE_SHOT)
		_nota_cientifico.abrir_nota()
	else:
		_al_cerrar_nota()


func _al_cerrar_nota() -> void:
	if _controles_restaurados:
		return
	_controles_restaurados = true

	if is_instance_valid(_cam):
		_cam.offset = _cam_offset_original

	if is_instance_valid(_jugador):
		_jugador.visible = true
		_jugador.collision_layer = 1 # Capa 1: Jugador
		_jugador.velocity = Vector2.ZERO
		_jugador.set_physics_process(true)
		_jugador.set_process(true)
		_jugador.set_process_unhandled_input(true)

	get_tree().paused = false
	GameManager.iniciar_temporizador(GameManager.tiempo_inicial_nivel)


func _crear_helicoptero() -> void:
	_helicoptero = Node2D.new()
	_helicoptero.name = "HelicopteroInsercion"
	_helicoptero.z_index = 25
	add_child(_helicoptero)

	var sprite := Sprite2D.new()
	sprite.name = "SpriteHelicoptero"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(TEX_HELICOPTERO):
		sprite.texture = load(TEX_HELICOPTERO) as Texture2D
	_helicoptero.add_child(sprite)

	# Rotor principal animado (ubicado en el mástil superior del SVG)
	_helice_principal = Node2D.new()
	_helice_principal.name = "HelicePrincipal"
	_helice_principal.position = Vector2(4.0, -38.0)
	_helicoptero.add_child(_helice_principal)

	var pala_principal := Polygon2D.new()
	pala_principal.color = Color(0.78, 0.96, 1.0, 0.85)
	pala_principal.polygon = PackedVector2Array([
		Vector2(-86.0, -2.5),
		Vector2(86.0, -2.5),
		Vector2(86.0, 2.5),
		Vector2(-86.0, 2.5),
	])
	_helice_principal.add_child(pala_principal)

	var nucleo_rotor := Polygon2D.new()
	nucleo_rotor.color = Color(1.0, 0.84, 0.0, 1.0)
	nucleo_rotor.polygon = PackedVector2Array([
		Vector2(-6.0, -3.5),
		Vector2(6.0, -3.5),
		Vector2(6.0, 3.5),
		Vector2(-6.0, 3.5),
	])
	_helice_principal.add_child(nucleo_rotor)

	# Rotor de cola animado (ubicado en el cubo trasero del SVG)
	_helice_cola = Node2D.new()
	_helice_cola.name = "HeliceCola"
	_helice_cola.position = Vector2(-80.0, -14.0)
	_helicoptero.add_child(_helice_cola)

	var pala_cola_a := Polygon2D.new()
	pala_cola_a.color = Color(0.82, 0.96, 1.0, 0.9)
	pala_cola_a.polygon = PackedVector2Array([
		Vector2(-2.0, -14.0),
		Vector2(2.0, -14.0),
		Vector2(2.0, 14.0),
		Vector2(-2.0, 14.0),
	])
	_helice_cola.add_child(pala_cola_a)

	var pala_cola_b := Polygon2D.new()
	pala_cola_b.color = Color(0.82, 0.96, 1.0, 0.72)
	pala_cola_b.polygon = PackedVector2Array([
		Vector2(-14.0, -2.0),
		Vector2(14.0, -2.0),
		Vector2(14.0, 2.0),
		Vector2(-14.0, 2.0),
	])
	_helice_cola.add_child(pala_cola_b)


func _limpiar_helicoptero() -> void:
	if is_instance_valid(_helicoptero):
		_helicoptero.queue_free()
	_helicoptero = null
	_helice_principal = null
	_helice_cola = null


func _buscar_jugador() -> CharacterBody2D:
	var padre := get_parent()
	if padre != null:
		var por_nombre := padre.get_node_or_null("CharacterBody2D")
		if por_nombre is CharacterBody2D:
			return por_nombre as CharacterBody2D
	var en_grupo := get_tree().get_first_node_in_group("jugador")
	if en_grupo is CharacterBody2D:
		return en_grupo as CharacterBody2D
	return null


func _buscar_nota_cientifico() -> Node:
	var padre := get_parent()
	if padre != null:
		var por_nombre := padre.get_node_or_null("NotaCientifico")
		if por_nombre != null:
			return por_nombre
	return get_tree().get_first_node_in_group("nota_cientifico")
