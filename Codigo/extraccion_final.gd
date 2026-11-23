extends Area2D

# ==============================================================================
# PUNTO DE EXTRACCIÓN FINAL — CINEMÁTICA DE DESPEGUE (Escena_4.tscn)
# - Area2D con monitoring = true y collision_mask = 1 (Capa 1: Jugador).
# - Al entrar el Jugador (una sola vez con extraccion_iniciada):
#   1) Desactiva movimiento/disparo del Jugador y lo oculta (aborda helicóptero).
#   2) Anima el helicóptero inclinando el morro y despegando hacia arriba y a la
#      derecha durante 1.8 segundos mientras la cámara lo observa.
#   3) Pausa el juego (get_tree().paused = true) y muestra PantallaVictoria con
#      fade-in suave y fanfarria de victoria.
# ==============================================================================

const ESCENA_VICTORIA := "res://Escenas/UI/PantallaVictoria.tscn"
const DURACION_DESPEGUE: float = 1.8

var extraccion_iniciada: bool = false
var _fase_helice: float = 0.0
var _velocidad_helice: float = 28.0
var _modal_cinematica_activo: bool = false

@onready var helicoptero: Node2D = get_node_or_null("HelicopteroExtraccion") as Node2D
@onready var helice_principal: Node2D = get_node_or_null("HelicopteroExtraccion/HelicePrincipal") as Node2D
@onready var helice_cola: Node2D = get_node_or_null("HelicopteroExtraccion/HeliceCola") as Node2D
@onready var luz_meta: PointLight2D = get_node_or_null("LuzPortalMeta") as PointLight2D
@onready var aviso_meta: Label = get_node_or_null("AvisoMeta") as Label


func _ready() -> void:
	monitoring = true
	monitorable = true
	collision_layer = 0
	collision_mask = 1 # Capa 1: Jugador

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	# Animación continua de hélices (acelera durante el despegue)
	_fase_helice += delta * _velocidad_helice
	if helice_principal != null:
		helice_principal.scale.x = 0.18 + 0.82 * absf(cos(_fase_helice))
	if helice_cola != null:
		helice_cola.rotation += delta * (_velocidad_helice * 0.9)

	# Ligero vaivén en reposo antes del abordaje
	if not extraccion_iniciada and monitoring:
		for b in get_overlapping_bodies():
			if _es_jugador(b):
				_iniciar_cinematica_extraccion(b as Node2D)
				break


func _es_jugador(body: Node) -> bool:
	if body == null:
		return false
	if body.is_in_group("jugador") or body.name == "Jugador" or body.name == "CharacterBody2D":
		return true
	if body is CollisionObject2D:
		return (((body as CollisionObject2D).collision_layer & 1) != 0)
	return false


func _on_body_entered(body: Node2D) -> void:
	if extraccion_iniciada:
		return
	if _es_jugador(body):
		_iniciar_cinematica_extraccion(body)


func _iniciar_cinematica_extraccion(jugador: Node2D) -> void:
	if extraccion_iniciada:
		return
	extraccion_iniciada = true

	# 1. Detener temporizador y bloquear movimiento/disparo del Jugador
	GameManager.temporizador_activo = false
	if not _modal_cinematica_activo:
		_modal_cinematica_activo = true
		GameManager.registrar_modal_abierto(true)

	if jugador != null:
		if jugador is CharacterBody2D:
			(jugador as CharacterBody2D).velocity = Vector2.ZERO
		jugador.set_physics_process(false)
		jugador.set_process(false)
		jugador.set_process_unhandled_input(false)
		if jugador is CollisionObject2D:
			(jugador as CollisionObject2D).set_deferred("collision_layer", 0)
		jugador.visible = false

	# Guardar progreso de finalización
	GameManager.completar_meta_nivel("", global_position)

	if aviso_meta != null:
		aviso_meta.text = "¡ABORDANDO! DESPEGUE EN CURSO..."
		aviso_meta.modulate = Color(0.35, 1.0, 0.62, 1.0)

	# 2. Acelerar hélices y animar el despegue del helicóptero durante 1.8 s
	_velocidad_helice = 58.0
	var tw := create_tween()
	tw.set_parallel(true)

	if helicoptero != null:
		# Inclinar ligeramente el morro hacia la derecha mientras asciende
		tw.tween_property(helicoptero, "rotation_degrees", 10.5, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		# Elevarse suavemente hacia arriba y a la derecha durante 1.8 segundos
		var destino_vuelo: Vector2 = helicoptero.position + Vector2(360.0, -250.0)
		tw.tween_property(helicoptero, "position", destino_vuelo, DURACION_DESPEGUE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	if luz_meta != null:
		tw.tween_property(luz_meta, "energy", 0.35, DURACION_DESPEGUE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	if aviso_meta != null:
		tw.tween_property(aviso_meta, "modulate:a", 0.0, 0.75).set_delay(0.35)

	# La cámara observa suavemente el ascenso del helicóptero
	if jugador != null:
		var cam := jugador.get_node_or_null("Camera2D") as Camera2D
		if cam != null:
			tw.tween_property(cam, "offset", Vector2(95.0, -75.0), DURACION_DESPEGUE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tw.chain().tween_callback(_finalizar_despegue_y_mostrar_victoria)


func _finalizar_despegue_y_mostrar_victoria() -> void:
	if _modal_cinematica_activo:
		_modal_cinematica_activo = false
		GameManager.registrar_modal_abierto(false)

	get_tree().paused = true

	var pantalla_victoria := _obtener_o_instanciar_victoria()
	if pantalla_victoria != null and pantalla_victoria.has_method("mostrar_victoria"):
		pantalla_victoria.mostrar_victoria()


func _obtener_o_instanciar_victoria() -> Node:
	var padre := get_parent()
	if padre != null:
		var nodo := padre.get_node_or_null("PantallaVictoria")
		if nodo != null:
			return nodo

	for n in get_tree().get_nodes_in_group("pantalla_victoria"):
		if is_instance_valid(n):
			return n

	if ResourceLoader.exists(ESCENA_VICTORIA):
		var escena_v := load(ESCENA_VICTORIA) as PackedScene
		if escena_v != null and get_tree().current_scene != null:
			var inst := escena_v.instantiate()
			get_tree().current_scene.add_child(inst)
			return inst
	return null
