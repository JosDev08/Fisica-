extends CharacterBody2D
# Velocidad de movimiento del enemigo
@export var speed: float = 100.0
@export var vida_maxima: int = 75

var vida_actual: int = 75
var esta_muerto: bool = false

# Referencias a los nodos
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $Detection_area
@onready var attack_area: Area2D = $Attack_area
@onready var attack_cooldown: Timer = $attack_coldown

# Estados del enemigo
enum State {
	IDLE,
	TRANSFORM,
	CHASE,
	ATTACK
}

var current_state = State.IDLE
var player: CharacterBody2D = null


func _ready():
	vida_actual = vida_maxima
	animated_sprite.play("idle")


func recibir_danio(cantidad: int) -> void:
	if esta_muerto or cantidad <= 0:
		return
	vida_actual = maxi(vida_actual - cantidad, 0)
	if animated_sprite != null:
		var tw := create_tween()
		animated_sprite.modulate = Color(1.0, 0.35, 0.35, 1.0)
		tw.tween_property(animated_sprite, "modulate", Color.WHITE, 0.14)
	if vida_actual <= 0:
		_morir()


func _morir() -> void:
	if esta_muerto:
		return
	esta_muerto = true
	velocity = Vector2.ZERO
	set_collision_layer_value(2, false)
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col != null:
		col.set_deferred("disabled", true)
	if detection_area != null:
		detection_area.set_deferred("monitoring", false)
	if attack_area != null:
		attack_area.set_deferred("monitoring", false)
	if animated_sprite != null and animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
		await animated_sprite.animation_finished
	queue_free()


func _physics_process(delta):
	if esta_muerto:
		return
	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	match current_state:

		State.IDLE:
			velocity.x = 0

		State.TRANSFORM:
			velocity.x = 0

		State.CHASE:
			if is_instance_valid(player):
				if player.esta_muerto:
					player = null
					current_state = State.IDLE
					velocity.x = 0
					animated_sprite.play("idle")

				elif attack_area.overlaps_body(player):
					velocity.x = 0

					if attack_cooldown.is_stopped():
						current_state = State.ATTACK
						attack_player()
				else:
					chase_player()
			else:
				current_state = State.IDLE
				animated_sprite.play("idle")

		State.ATTACK:
			velocity.x = 0

	move_and_slide()


# Cuando el jugador entra en el área de detección
func _on_detection_area_body_entered(body: Node2D):
	if body.is_in_group("jugador"):
		player = body as CharacterBody2D

		if current_state == State.IDLE:
			current_state = State.TRANSFORM
			play_transform()


# Cuando el jugador sale del área de detección
func _on_detection_area_body_exited(body: Node2D):
	if body == player:
		player = null

		if current_state == State.CHASE:
			current_state = State.IDLE
			velocity = Vector2.ZERO
			animated_sprite.play("idle")


# Reproducir la animación de transformación
func play_transform():
	animated_sprite.play("transformation")

	await animated_sprite.animation_finished

	if current_state == State.TRANSFORM:
		if is_instance_valid(player):
			current_state = State.CHASE
			animated_sprite.play("walk")
		else:
			current_state = State.IDLE
			animated_sprite.play("idle")


# Perseguir al jugador
func chase_player():
	var difference_x = player.global_position.x - global_position.x

	if abs(difference_x) < 10:
		velocity.x = 0
		animated_sprite.play("idle")
		return

	var direction_x = sign(difference_x)

	velocity.x = direction_x * speed
	animated_sprite.flip_h = direction_x < 0

	if animated_sprite.animation != "walk":
		animated_sprite.play("walk")
	# Ejecutar ataque del enemigo
func attack_player():
	velocity.x = 0
	animated_sprite.play("attack")

	await animated_sprite.animation_finished

	if esta_muerto:
		return

	if is_instance_valid(player):
		if not player.esta_muerto and attack_area.overlaps_body(player):
			player.recibir_danio(20)

	attack_cooldown.start()

	if is_instance_valid(player) and not player.esta_muerto:
		current_state = State.CHASE

		if attack_area.overlaps_body(player):
			animated_sprite.play("idle")
		else:
			animated_sprite.play("walk")
	else:
		current_state = State.IDLE
		animated_sprite.play("idle")
