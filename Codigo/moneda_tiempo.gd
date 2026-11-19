extends Area2D

# ==============================================================================
# MONEDA CRONÓMETRO / TIEMPO (res://Escenas/MonedaTiempo.tscn)
# Area2D con collision_mask = 1 (Capa 1: Jugador).
# Al recogerla suma +10 segundos al temporizador activo mostrando "+10s".
# ==============================================================================

@export var segundos_extra: float = 10.0

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
	_tiempo += delta * 4.6
	sprite.position.y = _y_inicial_sprite + sin(_tiempo) * 3.0
	var pulso: float = 0.90 + 0.10 * sin(_tiempo * 2.0)
	sprite.modulate = Color(pulso, 1.0, 1.0, 1.0)


func _on_body_entered(body: Node2D) -> void:
	if _recogida or body == null:
		return
	if not (body.is_in_group("jugador") or body.name == "Jugador" or body.name == "CharacterBody2D"):
		return

	_recogida = true
	colision.set_deferred("disabled", true)
	set_deferred("monitoring", false)

	GameManager.agregar_tiempo(segundos_extra)
	_mostrar_texto_flotante("+%ds" % int(round(segundos_extra)), Color(0.32, 0.98, 1.0))

	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.45, 1.45), 0.14)
	tw.parallel().tween_property(sprite, "modulate:a", 0.0, 0.14)
	tw.tween_callback(queue_free)


func _mostrar_texto_flotante(texto: String, color: Color) -> void:
	var padre := get_tree().current_scene
	if padre == null:
		return
	var lbl := Label.new()
	lbl.text = texto
	lbl.global_position = global_position + Vector2(-22.0, -36.0)
	lbl.z_index = 50
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 5)
	padre.add_child(lbl)

	var tw := lbl.create_tween()
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y - 40.0, 0.78).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.78)
	tw.tween_callback(lbl.queue_free)
