extends StaticBody2D
## Puerta bloqueada (reja con candado) que se abre resolviendo el ejercicio
## de la Ley de Ohm. Todo en un solo nodo: puerta + zona de interacción + panel.
##
## El origen del nodo es el CENTRO-ABAJO de la puerta: colócala apoyada en el suelo.
## panel_ohm.gd debe estar en la MISMA carpeta que este script.

signal abierta

@export var ancho: float = 64.0
@export var alto: float = 160.0
## Distancia extra a cada lado de la puerta desde la que el jugador puede interactuar.
@export var alcance: float = 90.0
## true = el voltaje objetivo cambia en cada partida.
@export var objetivo_aleatorio: bool = true
## Solo se usa si objetivo_aleatorio es false.
@export var voltaje_objetivo: int = 24
@export var texto_aviso: String = "[E] Panel de control"
@export var duracion_candado: float = 0.6
@export var duracion_reja: float = 1.0

const FILAS: int = 8
const COLUMNAS: int = 3

var esta_abierta: bool = false
var jugador_en_rango: bool = false
var apertura: float = 0.0: set = _set_apertura      # 0 = cerrada, 1 = abierta
var desbloqueo: float = 0.0: set = _set_desbloqueo  # 0 = candado cerrado, 1 = abierto

var _forma: CollisionShape2D
var _zona: Area2D
var _aviso: Label
var _panel: CanvasLayer
var _tween: Tween
var _tecla_e_prev: bool = false


func _ready() -> void:
	_asegurar_accion()
	_crear_colision()
	_crear_zona()
	_crear_aviso()
	_crear_panel()


func _process(_delta: float) -> void:
	if esta_abierta:
		return
	var detectado := false
	if _zona and _zona.monitoring:
		for body in _zona.get_overlapping_bodies():
			if body is CharacterBody2D or body.name == "Jugador" or body.name == "CharacterBody2D":
				detectado = true
				break
	if detectado != jugador_en_rango:
		jugador_en_rango = detectado
	if _aviso:
		_aviso.visible = jugador_en_rango and (_panel == null or not _panel.visible)
	var e_actual := Input.is_physical_key_pressed(KEY_E) or Input.is_key_pressed(KEY_E)
	if e_actual and not _tecla_e_prev and jugador_en_rango and not esta_abierta and _panel and not _panel.visible:
		_panel.abrir()
	_tecla_e_prev = e_actual


func _unhandled_input(event: InputEvent) -> void:
	if not jugador_en_rango or esta_abierta or not _panel or _panel.visible:
		return
	var es_tecla_e := false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E or event.keycode == KEY_E:
			es_tecla_e = true
	if es_tecla_e or event.is_action_pressed("interactuar"):
		_tecla_e_prev = true
		get_viewport().set_input_as_handled()
		_panel.abrir()


# ---------------------------------------------------------------- preparación

func _asegurar_accion() -> void:
	if InputMap.has_action("interactuar"):
		return
	InputMap.add_action("interactuar")
	var tecla := InputEventKey.new()
	tecla.physical_keycode = KEY_E
	InputMap.action_add_event("interactuar", tecla)


func _crear_colision() -> void:
	var rect := RectangleShape2D.new()
	rect.size = Vector2(ancho, alto)
	_forma = CollisionShape2D.new()
	_forma.shape = rect
	_forma.position = Vector2(0.0, -alto / 2.0)
	add_child(_forma)


func _crear_zona() -> void:
	_zona = Area2D.new()
	_zona.monitoring = true
	_zona.monitorable = true
	_zona.collision_layer = 0
	_zona.collision_mask = 1 # Capa 1: Jugador
	var rect := RectangleShape2D.new()
	rect.size = Vector2(ancho + alcance * 2.0, alto)
	var forma := CollisionShape2D.new()
	forma.shape = rect
	forma.position = Vector2(0.0, -alto / 2.0)
	_zona.add_child(forma)
	add_child(_zona)
	_zona.body_entered.connect(_on_body_entered)
	_zona.body_exited.connect(_on_body_exited)
	_zona.input_pickable = true
	_zona.input_event.connect(_on_zona_input_event)


func _on_zona_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not esta_abierta and _panel:
			_panel.abrir()


func _crear_aviso() -> void:
	_aviso = Label.new()
	_aviso.text = texto_aviso
	_aviso.position = Vector2(-90.0, -alto - 36.0)
	_aviso.custom_minimum_size = Vector2(180.0, 0.0)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aviso.z_index = 20
	_aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	_aviso.add_theme_constant_override("outline_size", 6)
	_aviso.add_to_group("texto_mundo_flotante")
	_aviso.hide()
	add_child(_aviso)


func _crear_panel() -> void:
	var carpeta: String = (get_script() as Script).resource_path.get_base_dir()
	var script_panel := load(carpeta.path_join("panel_ohm.gd")) as Script
	if script_panel == null:
		push_error("PuertaOhm: no se encontró panel_ohm.gd en " + carpeta)
		return
	_panel = CanvasLayer.new()
	_panel.set_script(script_panel)
	_panel.objetivo_aleatorio = objetivo_aleatorio
	_panel.voltaje_objetivo = voltaje_objetivo
	add_child(_panel)
	_panel.circuito_correcto.connect(_on_circuito_correcto)


# ---------------------------------------------------------------- eventos

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and not esta_abierta:
		jugador_en_rango = true
		_aviso.show()


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		jugador_en_rango = false
		_aviso.hide()


func _on_circuito_correcto() -> void:
	abrir()


func abrir() -> void:
	if esta_abierta:
		return
	esta_abierta = true
	_aviso.hide()
	print("Puerta: circuito correcto, abriendo")
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "desbloqueo", 1.0, duracion_candado)
	_tween.tween_property(self, "apertura", 1.0, duracion_reja) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func() -> void: abierta.emit())


func _set_apertura(valor: float) -> void:
	apertura = clampf(valor, 0.0, 1.0)
	# Cuando la reja ya casi está recogida, se puede pasar.
	if _forma and apertura > 0.7 and not _forma.disabled:
		_forma.set_deferred("disabled", true)
	queue_redraw()


func _set_desbloqueo(valor: float) -> void:
	desbloqueo = clampf(valor, 0.0, 1.0)
	queue_redraw()


# ---------------------------------------------------------------- dibujo

func _draw() -> void:
	var x0: float = -ancho / 2.0
	var y_top: float = -alto
	var acero := Color(0.16, 0.2, 0.27)
	var neon := Color(0.3, 0.85, 1.0)
	var barra := Color(0.58, 0.63, 0.7)

	draw_rect(Rect2(x0, y_top, ancho, alto), Color(0.03, 0.05, 0.08, 0.75))

	# Reja en X (se comprime hacia arriba al abrirse, como un acordeón)
	var area_top: float = y_top + 10.0
	var area_h: float = alto - 10.0
	var cel_h: float = area_h / FILAS * (1.0 - apertura * 0.92)
	var cel_w: float = (ancho - 16.0) / COLUMNAS
	var bx: float = x0 + 8.0
	for f in FILAS:
		var y: float = area_top + f * cel_h
		for c in COLUMNAS:
			var x: float = bx + c * cel_w
			draw_line(Vector2(x, y), Vector2(x + cel_w, y + cel_h), barra, 2.0)
			draw_line(Vector2(x + cel_w, y), Vector2(x, y + cel_h), barra, 2.0)
	var y_fin: float = area_top + FILAS * cel_h
	for c in COLUMNAS + 1:
		draw_line(Vector2(bx + c * cel_w, area_top), Vector2(bx + c * cel_w, y_fin), barra, 3.0)
	draw_rect(Rect2(bx - 2.0, y_fin - 2.0, COLUMNAS * cel_w + 4.0, 4.0), barra)

	# Marco metálico con borde de neón
	draw_rect(Rect2(x0, y_top, 8.0, alto), acero)
	draw_rect(Rect2(x0 + ancho - 8.0, y_top, 8.0, alto), acero)
	draw_rect(Rect2(x0, y_top, ancho, 10.0), acero)
	draw_line(Vector2(x0 + 8.0, y_top + 10.0), Vector2(x0 + ancho - 8.0, y_top + 10.0), neon, 2.0)
	draw_line(Vector2(x0 + 8.0, y_top + 10.0), Vector2(x0 + 8.0, 0.0), neon, 2.0)
	draw_line(Vector2(x0 + ancho - 8.0, y_top + 10.0), Vector2(x0 + ancho - 8.0, 0.0), neon, 2.0)

	# Luz de estado: roja -> verde
	var led: Color = Color(1.0, 0.25, 0.25).lerp(Color(0.3, 1.0, 0.4), desbloqueo)
	draw_rect(Rect2(x0 + ancho - 6.0, y_top + alto * 0.45, 4.0, 10.0), led)

	# Candado (se abre y se desvanece cuando la reja empieza a subir)
	var alfa: float = 1.0 - clampf(apertura * 4.0, 0.0, 1.0)
	if alfa > 0.0:
		var cy: float = area_top + (FILAS * cel_h) / 2.0
		var cuerpo: Color = Color(0.8, 0.82, 0.86).lerp(Color(0.5, 0.95, 0.6), desbloqueo)
		cuerpo.a = alfa
		var alza: float = 5.0 * desbloqueo
		draw_arc(Vector2(0.0, cy - 7.0 - alza), 6.0, PI, TAU, 16, Color(0.85, 0.87, 0.9, alfa), 3.0)
		draw_rect(Rect2(-9.0, cy - 7.0, 18.0, 15.0), cuerpo)
		draw_circle(Vector2(0.0, cy), 2.0, Color(0.1, 0.1, 0.14, alfa))
