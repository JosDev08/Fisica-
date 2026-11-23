extends Area2D

# ==============================================================================
# MONEDA DE RAYO COLECCIONABLE (res://Escenas/MonedaRayo.tscn)
# Area2D con monitoring = true y collision_mask = 1 (Capa 1: Jugador).
# Suma +1 moneda en GameManager, reproduce un destello visual y hace queue_free().
# ==============================================================================

@export var valor: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var colision: CollisionShape2D = $CollisionShape2D

var _recogida: bool = false
var _tiempo: float = 0.0
var _y_inicial_sprite: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 # Capa 1: Jugador
	monitoring = true
	monitorable = true
	_tiempo = randf() * TAU
	if sprite != null:
		_y_inicial_sprite = sprite.position.y
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _recogida or sprite == null:
		return
	_tiempo += delta * 4.2
	sprite.position.y = _y_inicial_sprite + sin(_tiempo) * 3.0
	var brillo: float = 0.92 + 0.08 * sin(_tiempo * 1.8)
	sprite.modulate = Color(brillo, brillo, 1.0, 1.0)


func _on_body_entered(body: Node2D) -> void:
	if _recogida or body == null:
		return
	var es_jugador: bool = body.is_in_group("jugador") or body.name == "Jugador" or body.name == "CharacterBody2D"
	if not es_jugador and body is CollisionObject2D:
		es_jugador = (((body as CollisionObject2D).collision_layer & 1) != 0)
	if not es_jugador:
		return

	_recogida = true
	colision.set_deferred("disabled", true)
	set_deferred("monitoring", false)

	GameManager.sumar_monedas(valor)
	GameManager.reproducir_sfx_moneda("res://assets/audio/sfx_moneda_rayo.wav")
	_crear_efecto_destello()
	_mostrar_texto_flotante("+%d ⚡" % valor, Color(1.0, 0.88, 0.28))

	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.14)
	tw.parallel().tween_property(sprite, "modulate:a", 0.0, 0.14)
	tw.tween_callback(queue_free)


func _crear_efecto_destello() -> void:
	var escena := get_tree().current_scene
	if escena == null:
		return

	# Destello central dorado/cian + 4 chispas pixel art en diagonal
	var flash := ColorRect.new()
	flash.size = Vector2(16, 16)
	flash.global_position = global_position - Vector2(8, 8)
	flash.color = Color(1.0, 0.95, 0.55, 0.95)
	flash.z_index = 45
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	escena.add_child(flash)

	var tw_f := flash.create_tween()
	tw_f.tween_property(flash, "scale", Vector2(2.0, 2.0), 0.16)
	tw_f.parallel().tween_property(flash, "modulate:a", 0.0, 0.16)
	tw_f.tween_callback(flash.queue_free)

	var dirs: Array[Vector2] = [
		Vector2(-1, -1), Vector2(1, -1),
		Vector2(-1, 1), Vector2(1, 1),
	]
	for d in dirs:
		var chispa := ColorRect.new()
		chispa.size = Vector2(5, 5)
		chispa.global_position = global_position - Vector2(2.5, 2.5)
		chispa.color = Color(0.35, 0.92, 1.0, 1.0)
		chispa.z_index = 46
		chispa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		escena.add_child(chispa)

		var tw_c := chispa.create_tween()
		tw_c.tween_property(chispa, "global_position", chispa.global_position + d * 20.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_c.parallel().tween_property(chispa, "modulate:a", 0.0, 0.24)
		tw_c.tween_callback(chispa.queue_free)


func _mostrar_texto_flotante(texto: String, color: Color) -> void:
	var padre := get_tree().current_scene
	if padre == null:
		return
	var lbl := Label.new()
	lbl.text = texto
	lbl.global_position = global_position + Vector2(-24.0, -34.0)
	lbl.z_index = 50
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	padre.add_child(lbl)

	var tw := lbl.create_tween()
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y - 34.0, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.65)
	tw.tween_callback(lbl.queue_free)
