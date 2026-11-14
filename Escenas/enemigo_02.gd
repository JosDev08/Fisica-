extends CharacterBody2D
@export var speed: float = 80.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $Detection_area
@onready var attack_area: Area2D = $Attack_area
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
	animated_sprite.play("idle")


func _physics_process(delta):
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
						animated_sprite.play("idle")
				else:
					chase_player()
			else:
				current_state = State.IDLE
				animated_sprite.play("idle")

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
			velocity = Vector2.ZERO
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
	animated_sprite.play("attack")

	await animated_sprite.animation_finished

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
