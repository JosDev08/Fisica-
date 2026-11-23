extends CharacterBody2D

# ==============================================================================
# JUGADOR (Capa 1: Jugador, collision_mask = 16: Suelo)
# Conserva movimiento original (mov. izquierda, mov. derecha, Saltar) e integra
# mejoras de GameManager y disparo energético (clic izquierdo o teclas J / Z).
# ==============================================================================

const SPEED_BASE: float = 220.0
const JUMP_VELOCITY: float = -450.0
const VIDA_MAXIMA_BASE: int = 100
const CADENCIA_DISPARO: float = 0.25
const ESCENA_PROYECTIL: PackedScene = preload("res://Escenas/ProyectilJugador.tscn")
const SFX_DISPARO: AudioStream = preload("res://assets/audio/sfx_disparo.wav")

var vida_maxima: int = VIDA_MAXIMA_BASE
var vida_actual: int = VIDA_MAXIMA_BASE
var esta_muerto: bool = false
var direccion_mirada: int = 1
var _cooldown_disparo: float = 0.0
var _tiempo_flash_danio: float = 0.0

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var punto_disparo: Marker2D = get_node_or_null("PuntoDisparo")
@onready var audio_disparo: AudioStreamPlayer = get_node_or_null("AudioDisparo") as AudioStreamPlayer


func _ready() -> void:
	collision_layer = 1 # Capa 1: Jugador
	collision_mask = 16 # Capa 5: Suelo
	if not is_in_group("jugador"):
		add_to_group("jugador")

	if animated_sprite_2d != null:
		animated_sprite_2d.flip_h = false
		direccion_mirada = 1

	# Garantizar Camera2D únicamente si la escena del nivel no incluyó una propia
	if get_node_or_null("Camera2D") == null:
		var cam := Camera2D.new()
		cam.name = "Camera2D"
		cam.position = Vector2(-2, 6)
		cam.zoom = Vector2(2, 2)
		cam.position_smoothing_enabled = true
		add_child(cam)

	if punto_disparo == null:
		punto_disparo = Marker2D.new()
		punto_disparo.name = "PuntoDisparo"
		punto_disparo.position = Vector2(26, 24)
		add_child(punto_disparo)

	GameManager.configurar_buses_audio()
	if audio_disparo == null:
		audio_disparo = AudioStreamPlayer.new()
		audio_disparo.name = "AudioDisparo"
		add_child(audio_disparo)
	if audio_disparo.stream == null:
		audio_disparo.stream = SFX_DISPARO
	audio_disparo.bus = &"SFX"
	audio_disparo.max_polyphony = 4

	sincronizar_con_game_manager(true)


func sincronizar_con_game_manager(curar_al_maximo: bool = false) -> void:
	var nueva_maxima: int = GameManager.obtener_vida_maxima()
	var incremento: int = maxi(0, nueva_maxima - vida_maxima)
	vida_maxima = nueva_maxima

	if curar_al_maximo:
		vida_actual = vida_maxima
	else:
		vida_actual = clampi(vida_actual + incremento, 0, vida_maxima)

	GameManager.actualizar_vida(vida_actual, vida_maxima)


func recibir_danio(cantidad: int) -> void:
	if esta_muerto or cantidad <= 0:
		return

	vida_actual = maxi(vida_actual - cantidad, 0)
	GameManager.actualizar_vida(vida_actual, vida_maxima)
	_tiempo_flash_danio = 0.16

	if vida_actual <= 0:
		morir("SIN VIDA")


func morir(motivo: String = "HAS CAÍDO") -> void:
	if esta_muerto:
		return
	esta_muerto = true
	vida_actual = 0
	velocity.x = 0.0
	if animated_sprite_2d != null:
		animated_sprite_2d.modulate = Color.WHITE
		animated_sprite_2d.play("muerte")
	GameManager.actualizar_vida(0, vida_maxima)
	GameManager.activar_muerte_jugador(motivo)


func forzar_estado_muerto() -> void:
	if esta_muerto:
		return
	esta_muerto = true
	vida_actual = 0
	velocity.x = 0.0
	if animated_sprite_2d != null:
		animated_sprite_2d.modulate = Color.WHITE
		animated_sprite_2d.play("muerte")


func _unhandled_input(event: InputEvent) -> void:
	if esta_muerto or get_tree().paused or GameManager.hay_modal_interactivo_abierto():
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			intentar_disparar()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var ev_k := event as InputEventKey
		if ev_k.pressed and not ev_k.echo:
			var kc: int = ev_k.physical_keycode if ev_k.physical_keycode != 0 else ev_k.keycode
			if kc == KEY_J or kc == KEY_Z:
				intentar_disparar()
				get_viewport().set_input_as_handled()


func intentar_disparar() -> void:
	if esta_muerto or _cooldown_disparo > 0.0:
		return
	if get_tree().paused or GameManager.hay_modal_interactivo_abierto():
		return

	_cooldown_disparo = CADENCIA_DISPARO
	var escena := get_tree().current_scene
	if escena == null:
		return

	var proyectil := ESCENA_PROYECTIL.instantiate()
	escena.add_child(proyectil)

	var offset_x: float = 26.0 * float(direccion_mirada)
	var offset_y: float = punto_disparo.position.y if punto_disparo != null else 24.0
	var origen_global: Vector2 = global_position + Vector2(offset_x, offset_y)
	proyectil.global_position = origen_global

	var danio_actual: int = GameManager.obtener_danio_disparo()
	if proyectil.has_method("configurar"):
		proyectil.configurar(Vector2(float(direccion_mirada), 0.0), danio_actual)

	_mostrar_destello_canon(origen_global)
	_reproducir_sonido_disparo()


func _reproducir_sonido_disparo() -> void:
	if audio_disparo == null:
		return
	if audio_disparo.stream == null:
		audio_disparo.stream = SFX_DISPARO
	audio_disparo.bus = &"SFX"
	audio_disparo.pitch_scale = randf_range(0.95, 1.05)
	audio_disparo.play()


func _mostrar_destello_canon(pos_global: Vector2) -> void:
	var escena := get_tree().current_scene
	if escena == null:
		return
	var destello := ColorRect.new()
	var tiene_dt: bool = GameManager.tiene_mejora("double_tap")
	destello.size = Vector2(10, 10)
	destello.global_position = pos_global - Vector2(5, 5)
	destello.color = Color(1.0, 0.78, 0.25, 0.95) if tiene_dt else Color(0.45, 0.96, 1.0, 0.95)
	destello.z_index = 20
	destello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	escena.add_child(destello)

	var tw := destello.create_tween()
	tw.tween_property(destello, "scale", Vector2(1.6, 1.6), 0.09)
	tw.parallel().tween_property(destello, "modulate:a", 0.0, 0.09)
	tw.tween_callback(destello.queue_free)


func _physics_process(delta: float) -> void:
	if _cooldown_disparo > 0.0:
		_cooldown_disparo = maxf(0.0, _cooldown_disparo - delta)

	if _tiempo_flash_danio > 0.0:
		_tiempo_flash_danio = maxf(0.0, _tiempo_flash_danio - delta)
		if animated_sprite_2d != null:
			animated_sprite_2d.modulate = Color(1.0, 0.35, 0.35, 1.0) if _tiempo_flash_danio > 0.0 else Color.WHITE

	if esta_muerto:
		if not is_on_floor():
			velocity.y += get_gravity().y * delta
		velocity.x = 0.0
		move_and_slide()
		return

	# Gravedad
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Salto
	if Input.is_action_just_pressed("Saltar") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movimiento (velocidad leída dinámicamente desde GameManager para Stamin-Up)
	var velocidad_actual: float = GameManager.obtener_velocidad_jugador()
	var direction: float = Input.get_axis("mov. izquierda", "mov. derecha")

	if direction > 0.0:
		direccion_mirada = 1
		animated_sprite_2d.flip_h = false
	elif direction < 0.0:
		direccion_mirada = -1
		animated_sprite_2d.flip_h = true

	if is_on_floor():
		if direction == 0.0:
			animated_sprite_2d.play("Reposo")
		else:
			animated_sprite_2d.play("Correr")
	else:
		animated_sprite_2d.play("Saltar")

	if direction != 0.0:
		velocity.x = direction * velocidad_actual
	else:
		velocity.x = move_toward(velocity.x, 0.0, velocidad_actual)

	# Disparo continuo manteniendo teclas físicas J o Z (bloqueado si hay modal abierto)
	if not get_tree().paused and not GameManager.hay_modal_interactivo_abierto():
		if (Input.is_physical_key_pressed(KEY_J) or Input.is_physical_key_pressed(KEY_Z)) and _cooldown_disparo <= 0.0:
			intentar_disparar()

	move_and_slide()
