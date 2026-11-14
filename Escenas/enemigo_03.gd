extends CharacterBody2D
@export var speed: float = 80.0
@export var shoot_distance: float = 180.0
@export var bullet_scene: PackedScene

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $Detection_area
@onready var attack_cooldown: Timer = $attack_coldown
@onready var shoot_point: Marker2D = $PuntoDisparo

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
					current_state = State.ATTACK
					shoot_at_player()
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
	var direction_x = sign(difference_x)

	velocity.x = direction_x * speed
	animated_sprite.flip_h = direction_x < 0

	if animated_sprite.animation != "walk":
		animated_sprite.play("walk")


func shoot_at_player():
	if not is_instance_valid(player):
		current_state = State.IDLE
		return

	animated_sprite.flip_h = player.global_position.x < global_position.x
	animated_sprite.play("attack")

	await animated_sprite.animation_finished

	if not is_instance_valid(player) or player.esta_muerto:
		current_state = State.IDLE
		animated_sprite.play("idle")
		return

	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)

	bullet.global_position = shoot_point.global_position

	var direction = sign(player.global_position.x - shoot_point.global_position.x)
	bullet.configurar(Vector2(direction, 0))

	attack_cooldown.start()

	await attack_cooldown.timeout

	if is_instance_valid(player) and not player.esta_muerto:
		current_state = State.CHASE
		animated_sprite.play("walk")
	else:
		current_state = State.IDLE
		animated_sprite.play("idle")
