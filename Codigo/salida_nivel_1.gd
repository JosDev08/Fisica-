extends Node2D

# ==============================================================================
# SALIDA DEL NIVEL 1 HACIA EL NIVEL 2 (res://Escenas/escena_02.tscn)
# Conecta la PuertaOhm final del Nivel 1 (x = 2227, y = 112) para que al
# completarse y abrirse (o al cruzar el umbral), muestre una tarjeta limpia
# y cargue res://Escenas/escena_02.tscn.
# ==============================================================================

const ESCENA_NIVEL_2 := "res://Escenas/escena_02.tscn"
const POS_PUERTA_FINAL := Vector2(2227, 112)

var puerta_abierta: bool = false
var transicion_iniciada: bool = false
var cuenta_regresiva: float = 4.0

var area_meta: Area2D
var lbl_indicador_puerta: Label
var ui_layer: CanvasLayer
var panel_resumen: PanelContainer
var lbl_contador: Label

func _ready() -> void:
	_configurar_puerta_ohm()
	_crear_zona_meta()
	_crear_ui_educativa()

func _configurar_puerta_ohm() -> void:
	var puerta := get_parent().get_node_or_null("PuertaOhm")
	if not puerta:
		return

	if puerta is StaticBody2D:
		puerta.collision_layer = 16
		puerta.collision_mask = 1

	if puerta.has_signal("abierta"):
		puerta.connect("abierta", Callable(self, "_on_puerta_ohm_abierta"))

func _crear_zona_meta() -> void:
	lbl_indicador_puerta = Label.new()
	lbl_indicador_puerta.text = "SALIDA AL NIVEL 2\n[E] Compuerta de Ohm"
	lbl_indicador_puerta.position = POS_PUERTA_FINAL + Vector2(-135, -145)
	lbl_indicador_puerta.size = Vector2(270, 42)
	lbl_indicador_puerta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_indicador_puerta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_indicador_puerta.add_theme_font_size_override("font_size", 12)
	lbl_indicador_puerta.add_theme_color_override("font_color", Color(0.4, 0.95, 1.0))
	lbl_indicador_puerta.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_indicador_puerta.add_theme_constant_override("outline_size", 4)
	lbl_indicador_puerta.add_to_group("texto_mundo_flotante")
	add_child(lbl_indicador_puerta)

	area_meta = Area2D.new()
	area_meta.name = "MetaNivel1"
	area_meta.position = POS_PUERTA_FINAL + Vector2(0, -48)
	area_meta.monitoring = true
	area_meta.monitorable = true
	area_meta.collision_layer = 0
	area_meta.collision_mask = 1 # Capa 1: Jugador
	add_child(area_meta)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(110, 120)
	col.shape = rect
	area_meta.add_child(col)

	area_meta.body_entered.connect(_on_meta_body_entered)

func _crear_ui_educativa() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(centro)

	panel_resumen = PanelContainer.new()
	panel_resumen.custom_minimum_size = Vector2(540, 0)
	panel_resumen.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.08, 0.14, 0.96)
	sb.border_color = Color(0.35, 1.0, 0.55)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(20)
	panel_resumen.add_theme_stylebox_override("panel", sb)
	panel_resumen.visible = false
	centro.add_child(panel_resumen)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel_resumen.add_child(vbox)

	var titulo := Label.new()
	titulo.text = "¡NIVEL 1 COMPLETADO!"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 18)
	titulo.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55))
	vbox.add_child(titulo)

	var resumen := Label.new()
	resumen.text = "• Ley de Coulomb: F = k · |q₁·q₂| / r²  (Atracción ↑ entre signos opuestos)\n• Ley de Ohm: I = V / R  |  V = I × R  (Control de corriente y tensión)"
	resumen.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resumen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resumen.add_theme_font_size_override("font_size", 14)
	vbox.add_child(resumen)

	lbl_contador = Label.new()
	lbl_contador.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_contador.add_theme_font_size_override("font_size", 14)
	lbl_contador.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	vbox.add_child(lbl_contador)

	var btn_continuar := Button.new()
	btn_continuar.text = "[ CONTINUAR AL NIVEL 2 ]  (Enter / Espacio / E)"
	btn_continuar.custom_minimum_size = Vector2(0, 40)
	btn_continuar.focus_mode = Control.FOCUS_NONE
	btn_continuar.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_continuar.pressed.connect(_cargar_nivel_2)
	vbox.add_child(btn_continuar)

func _on_puerta_ohm_abierta() -> void:
	puerta_abierta = true
	lbl_indicador_puerta.text = "¡COMPUERTA ABIERTA!\nAvanza hacia el Nivel 2"
	lbl_indicador_puerta.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	_iniciar_resumen_y_transicion()

func _on_meta_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and puerta_abierta and not transicion_iniciada:
		_iniciar_resumen_y_transicion()

func _iniciar_resumen_y_transicion() -> void:
	if transicion_iniciada:
		return
	transicion_iniciada = true
	for n in get_tree().get_nodes_in_group("texto_mundo_flotante"):
		if n is CanvasItem:
			n.modulate.a = 0.0
	panel_resumen.visible = true
	lbl_contador.text = "Avanzando a Nivel 2 en %.1f s..." % cuenta_regresiva

func _input(event: InputEvent) -> void:
	if not transicion_iniciada:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if kc in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E]:
			get_viewport().set_input_as_handled()
			_cargar_nivel_2()

func _process(delta: float) -> void:
	if area_meta and area_meta.monitoring and puerta_abierta and not transicion_iniciada:
		for body in area_meta.get_overlapping_bodies():
			if body is CharacterBody2D or body.name == "Jugador" or body.name == "CharacterBody2D":
				_iniciar_resumen_y_transicion()
				break
	if not transicion_iniciada:
		return
	cuenta_regresiva -= delta
	if cuenta_regresiva > 0.0:
		lbl_contador.text = "Avanzando a Nivel 2 en %.1f s..." % cuenta_regresiva
	else:
		_cargar_nivel_2()

func _cargar_nivel_2() -> void:
	get_tree().paused = false
	if ResourceLoader.exists(ESCENA_NIVEL_2):
		get_tree().change_scene_to_file(ESCENA_NIVEL_2)
