extends CharacterBody2D

@export var speed: float = 80.0
@export var shoot_distance: float = 180.0
@export var damage: int = 20
@export var vida_maxima: int = 90

var vida_actual: int = 90
var esta_muerto: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_cooldown: Timer = $attack_coldown

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
			if not is_instance_valid(player):
				current_state = State.IDLE
				animated_sprite.play("idle")
				velocity.x = 0

			elif player.esta_muerto:
				player = null
				current_state = State.IDLE
				animated_sprite.play("idle")
				velocity.x = 0

			else:
				var distance = abs(player.global_position.x - global_position.x)

				if distance <= shoot_distance:
					velocity.x = 0

					if attack_cooldown.is_stopped():
						current_state = State.ATTACK
						attack_player()
					else:
						animated_sprite.play("idle")
				else:
					chase_player()

		State.ATTACK:
			velocity.x = 0

	move_and_slide()


func _on_detection_area_body_entered(body: Node2D):
	if body.is_in_group("jugador"):
		player = body as CharacterBody2D

		if current_state == State.IDLE:
			current_state = State.TRANSFORM
			play_transform()


func _on_detection_area_body_exited(body: Node2D):
	if body == player:
		player = null

		if current_state == State.CHASE:
			current_state = State.IDLE
			velocity.x = 0
			animated_sprite.play("idle")


func play_transform():
	animated_sprite.play("transformation")
	await animated_sprite.animation_finished

	if current_state == State.TRANSFORM:
		if is_instance_valid(player) and not player.esta_muerto:
			current_state = State.CHASE
			animated_sprite.play("walk")
		else:
			current_state = State.IDLE
			animated_sprite.play("idle")


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


func attack_player():
	velocity.x = 0
	animated_sprite.flip_h = player.global_position.x < global_position.x
	animated_sprite.play("attack")

	await animated_sprite.animation_finished

	if esta_muerto:
		return

	if is_instance_valid(player):
		if not player.esta_muerto:
			var distance = abs(player.global_position.x - global_position.x)

			if distance <= shoot_distance:
				player.recibir_danio(damage)

	attack_cooldown.start()

	if is_instance_valid(player) and not player.esta_muerto:
		current_state = State.CHASE
		animated_sprite.play("walk")
	else:
		current_state = State.IDLE
		animated_sprite.play("idle")
