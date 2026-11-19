extends Area2D

# ==============================================================================
# ZONA DE MUERTE (res://Escenas/ZonaMuerte.tscn)
# Area2D con monitoring = true y collision_mask = 3 (Capa 1: Jugador + Capa 2: Enemigo).
# - Enemigos (Capa 2): eliminados con queue_free() sin afectar al jugador.
# - Jugador (Capa 1): bandera `activada` para disparar la muerte una sola vez.
# ==============================================================================

@export var mensaje_muerte: String = "HAS CAÍDO AL VACÍO"
@export var tamano_zona: Vector2 = Vector2(800.0, 64.0):
	set(valor):
		tamano_zona = valor
		if is_inside_tree():
			_actualizar_forma()

var activada: bool = false


func _ready() -> void:
	add_to_group("zonas_muerte")
	collision_layer = 0
	collision_mask = 3 # Capa 1 (Jugador = 1) + Capa 2 (Enemigo = 2)
	monitoring = true
	monitorable = true
	activada = false
	_actualizar_forma()

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func reiniciar() -> void:
	activada = false
	monitoring = true


func _actualizar_forma() -> void:
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null:
		return
	var rect := RectangleShape2D.new()
	rect.size = tamano_zona
	col.shape = rect


func _physics_process(_delta: float) -> void:
	if not monitoring:
		return
	for body in get_overlapping_bodies():
		if body is Node2D:
			_procesar_cuerpo(body as Node2D)


func _on_body_entered(body: Node2D) -> void:
	_procesar_cuerpo(body)


func _procesar_cuerpo(body: Node2D) -> void:
	if body == null or not is_instance_valid(body):
		return

	# 1. Capa 1: Jugador
	var es_jugador: bool = body.is_in_group("jugador") or body.name == "Jugador" or body.name == "CharacterBody2D"
	if not es_jugador and body is CollisionObject2D:
		es_jugador = (((body as CollisionObject2D).collision_layer & 1) != 0)

	if es_jugador:
		if activada:
			return
		activada = true
		if body.has_method("morir"):
			body.morir(mensaje_muerte)
		else:
			GameManager.activar_muerte_jugador(mensaje_muerte)
		return

	# 2. Capa 2: Enemigo -> eliminar limpiamente sin matar al jugador
	var es_enemigo: bool = body.is_in_group("enemigo")
	if not es_enemigo and body is CollisionObject2D:
		es_enemigo = (((body as CollisionObject2D).collision_layer & 2) != 0)

	if es_enemigo:
		body.queue_free()
