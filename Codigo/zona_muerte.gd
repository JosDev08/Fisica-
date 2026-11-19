extends Area2D

# ==============================================================================
# ZONA DE MUERTE (res://Escenas/ZonaMuerte.tscn)
# Area2D con collision_mask = 1 (Capa 1: Jugador) para colocar debajo de
# abismos o vacíos. Al entrar el jugador, dispara la muerte y la PantallaMuerte.
# ==============================================================================

@export var mensaje_muerte: String = "HAS CAÍDO AL VACÍO"
@export var tamano_zona: Vector2 = Vector2(800.0, 64.0):
	set(valor):
		tamano_zona = valor
		_actualizar_forma()


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 # Capa 1: Jugador
	monitoring = true
	monitorable = true
	_actualizar_forma()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _actualizar_forma() -> void:
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col != null and col.shape is RectangleShape2D:
		var rect := col.shape.duplicate() as RectangleShape2D
		rect.size = tamano_zona
		col.shape = rect


func _on_body_entered(body: Node2D) -> void:
	if body == null:
		return
	if body.is_in_group("jugador") or body.name == "Jugador" or body.name == "CharacterBody2D":
		if body.has_method("morir"):
			body.morir(mensaje_muerte)
		else:
			GameManager.activar_muerte_jugador(mensaje_muerte)
