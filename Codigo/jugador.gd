extends CharacterBody2D

const SPEED = 220.0
const JUMP_VELOCITY = -450.0
const VIDA_MAXIMA = 100

var vida_actual = VIDA_MAXIMA
var esta_muerto = false

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


func recibir_danio(cantidad: int):
	if esta_muerto:
		return

	vida_actual -= cantidad
	vida_actual = max(vida_actual, 0)

	print("Vida del jugador: ", vida_actual)

	if vida_actual <= 0:
		esta_muerto = true
		velocity.x = 0
		animated_sprite_2d.play("muerte")
		print("El jugador ha muerto")


func _physics_process(delta: float) -> void:

	if esta_muerto:
		if not is_on_floor():
			velocity.y += get_gravity().y * delta

		velocity.x = 0
		move_and_slide()
		return

	# Gravedad
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Salto
	if Input.is_action_just_pressed("Saltar") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movimiento
	var direction := Input.get_axis("mov. izquierda", "mov. derecha")

	if direction > 0:
		animated_sprite_2d.flip_h = false
	elif direction < 0:
		animated_sprite_2d.flip_h = true

	if is_on_floor():
		if direction == 0:
			animated_sprite_2d.play("Reposo")
		else:
			animated_sprite_2d.play("Correr")
	else:
		animated_sprite_2d.play("Saltar")

	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	
