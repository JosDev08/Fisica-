extends Area2D

# ==============================================================================
# PROYECTIL ENERGÉTICO DEL JUGADOR (res://Escenas/ProyectilJugador.tscn)
# Area2D con collision_mask = 18 (Capa 2: Enemigo + Capa 5: Suelo).
# Lee el daño directamente desde GameManager.obtener_danio_disparo().
# ==============================================================================

@export var velocidad: float = 580.0
@export var tiempo_vida: float = 1.6

@onready var sprite: Sprite2D = $Sprite2D
@onready var estela: Line2D = $Estela

var direccion: Vector2 = Vector2.RIGHT
var danio: int = 25
var _impactado: bool = false
var _vida_restante: float = 1.6


func _ready() -> void:
	collision_layer = 0
	collision_mask = 18 # Capa 2 (Enemigo = 2) + Capa 5 (Suelo = 16)
	monitoring = true
	monitorable = false
	_vida_restante = tiempo_vida

	# Leer el daño actual directamente desde GameManager
	danio = GameManager.obtener_danio_disparo()

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	_aplicar_estilo_visual()


func configurar(nueva_direccion: Vector2, danio_personalizado: int = -1) -> void:
	if nueva_direccion.length_squared() > 0.001:
		direccion = nueva_direccion.normalized()
	else:
		direccion = Vector2.RIGHT

	danio = danio_personalizado if danio_personalizado > 0 else GameManager.obtener_danio_disparo()
	_aplicar_estilo_visual()


func _aplicar_estilo_visual() -> void:
	var tiene_sobrecarga: bool = GameManager.bonus_danio > 0
	if sprite != null:
		sprite.flip_h = direccion.x < 0.0
		sprite.modulate = Color(1.0, 0.72, 0.30, 1.0) if tiene_sobrecarga else Color(0.55, 0.96, 1.0, 1.0)
	if estela != null:
		var dir_atras: float = -1.0 if direccion.x >= 0.0 else 1.0
		estela.points = PackedVector2Array([
			Vector2.ZERO,
			Vector2(dir_atras * 18.0, 0.0),
		])
		estela.default_color = Color(1.0, 0.52, 0.18, 0.85) if tiene_sobrecarga else Color(0.22, 0.88, 1.0, 0.82)


func _physics_process(delta: float) -> void:
	if _impactado:
		return
	global_position += direccion * velocidad * delta
	_vida_restante -= delta
	if _vida_restante <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _impactado or body == null or not is_instance_valid(body):
		return
	if body.is_in_group("jugador"):
		return
	# Ignorar cadáveres de enemigos que ya murieron en el mismo frame
	if "esta_muerto" in body and bool(body.get("esta_muerto")):
		return

	_impactado = true
	set_deferred("monitoring", false)

	var danio_actual: int = GameManager.obtener_danio_disparo()
	if body.has_method("recibir_danio"):
		body.recibir_danio(danio_actual)
	elif body.has_method("take_damage"):
		body.take_damage(danio_actual)

	_crear_destello_impacto()
	queue_free()


func _crear_destello_impacto() -> void:
	var escena := get_tree().current_scene
	if escena == null:
		return
	var destello := ColorRect.new()
	var tiene_dt := GameManager.bonus_danio > 0
	destello.size = Vector2(12, 12)
	destello.global_position = global_position - Vector2(6, 6)
	destello.color = Color(1.0, 0.75, 0.25, 0.95) if tiene_dt else Color(0.45, 0.98, 1.0, 0.95)
	destello.z_index = 40
	destello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	escena.add_child(destello)

	var tw := destello.create_tween()
	tw.tween_property(destello, "scale", Vector2(1.8, 1.8), 0.12)
	tw.parallel().tween_property(destello, "modulate:a", 0.0, 0.12)
	tw.tween_callback(destello.queue_free)
