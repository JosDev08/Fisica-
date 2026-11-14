extends Area2D
@export var speed: float = 350.0
@export var damage: int = 20

var direction: Vector2 = Vector2.RIGHT


func _ready():
	body_entered.connect(_on_body_entered)


func configurar(nueva_direccion: Vector2):
	direction = nueva_direccion.normalized()


func _physics_process(delta):
	global_position += direction * speed * delta


func _on_body_entered(body: Node2D):
	if body.is_in_group("jugador"):
		if body.has_method("recibir_danio"):
			body.recibir_danio(damage)

		queue_free()
