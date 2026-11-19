extends CharacterBody2D
@export var speed: float = 80.0
@export var vida_maxima: int = 75

var vida_actual: int = 75
var esta_muerto: bool = false

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
	add_to_group("enemigo")
	collision_layer = 2 # Capa 2: Enemigo
	collision_mask = 16 # Capa 5: Suelo
	vida_actual = vida_maxima
	esta_muerto = false
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
		morir()


func morir() -> void:
	if esta_muerto:
		return
	esta_muerto = true
	player = null
	current_state = State.IDLE
	velocity = Vector2.ZERO
	set_physics_process(false)

	if attack_cooldown != null:
		attack_cooldown.stop()

	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	_desactivar_colisiones_y_areas()

	var anim_muerte := _buscar_animacion_muerte()
	if animated_sprite != null and not anim_muerte.is_empty():
		animated_sprite.sprite_frames.set_animation_loop(anim_muerte, false)
		if not animated_sprite.animation_finished.is_connected(_on_muerte_animation_finished):
			animated_sprite.animation_finished.connect(_on_muerte_animation_finished, CONNECT_ONE_SHOT)
		animated_sprite.play(anim_muerte)

	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(self) and not is_queued_for_deletion():
		queue_free()


func _on_muerte_animation_finished() -> void:
	if esta_muerto and is_instance_valid(self) and not is_queued_for_deletion():
		queue_free()


func _buscar_animacion_muerte() -> StringName:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return &""
	for nombre in [&"death", &"morir", &"muerte", &"die"]:
		if animated_sprite.sprite_frames.has_animation(nombre):
			return nombre
	return &""


func _desactivar_colisiones_y_areas() -> void:
	var col_cuerpo := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col_cuerpo != null:
		col_cuerpo.set_deferred("disabled", true)
	for area in [detection_area, attack_area]:
		if area != null:
			area.set_deferred("monitoring", false)
			area.set_deferred("monitorable", false)
			area.set_deferred("collision_layer", 0)
			area.set_deferred("collision_mask", 0)
			for hijo in area.get_children():
				if hijo is CollisionShape2D:
					(hijo as CollisionShape2D).set_deferred("disabled", true)


func _physics_process(delta):
	if esta_muerto:
		velocity = Vector2.ZERO
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
	if esta_muerto:
		return
	if body.is_in_group("jugador"):
		player = body as CharacterBody2D

		if current_state == State.IDLE:
			current_state = State.TRANSFORM
			play_transform()


func _on_detection_area_body_exited(body: Node2D):
	if esta_muerto:
		return
	if body == player:
		player = null

		if current_state == State.CHASE:
			current_state = State.IDLE
			velocity = Vector2.ZERO
			animated_sprite.play("idle")


func play_transform():
	if esta_muerto:
		return
	animated_sprite.play("transformation")
	await animated_sprite.animation_finished

	if esta_muerto:
		return

	if current_state == State.TRANSFORM:
		if is_instance_valid(player) and not player.esta_muerto:
			current_state = State.CHASE
			animated_sprite.play("walk")
		else:
			current_state = State.IDLE
			animated_sprite.play("idle")


func chase_player():
	if esta_muerto or not is_instance_valid(player):
		return
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
	if esta_muerto:
		return
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
