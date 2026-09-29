extends CanvasLayer
## Panel de control: minijuego de la Ley de Ohm con V = I × R (solo números enteros).
## El jugador ajusta la corriente (I) y la resistencia (R); el voltaje resultante
## es V = I × R y debe coincidir con el voltaje objetivo.
## Se construye por código y pausa el juego mientras está abierto.

signal circuito_correcto
signal cerrado

@export var voltaje_objetivo: int = 24
## Si es true, el voltaje objetivo se elige al azar (siempre alcanzable).
@export var objetivo_aleatorio: bool = false
@export var corriente_min: int = 1
@export var corriente_max: int = 10
@export var resistencia_min: int = 1
@export var resistencia_max: int = 20

const COLOR_CIAN := Color(0.35, 0.85, 1.0)
const COLOR_VERDE := Color(0.35, 1.0, 0.45)
const COLOR_ROJO := Color(1.0, 0.35, 0.35)
const COLOR_AMARILLO := Color(1.0, 0.9, 0.45)
const COLOR_FONDO := Color(0.05, 0.1, 0.17, 0.97)

var _slider_i: HSlider
var _slider_r: HSlider
var _lbl_i: Label
var _lbl_r: Label
var _lbl_voltaje: Label
var _lbl_estado: Label


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS  # funciona aunque el juego esté en pausa
	if objetivo_aleatorio:
		_generar_objetivo()
	_construir_interfaz()
	hide()


func abrir() -> void:
	# Posición inicial aleatoria de los deslizadores (nunca ya resuelta)
	var i: int = corriente_min
	var r: int = resistencia_min
	for intento in 30:
		i = randi_range(corriente_min, corriente_max)
		r = randi_range(resistencia_min, resistencia_max)
		if i * r != voltaje_objetivo:
			break
	_slider_i.value = i
	_slider_r.value = r
	_lbl_estado.text = ""
	_actualizar()
	show()
	get_tree().paused = true
	_slider_i.grab_focus()


func cerrar() -> void:
	hide()
	get_tree().paused = false
	cerrado.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cerrar()


# ---------------------------------------------------------------- objetivo aleatorio

func _generar_objetivo() -> void:
	var opciones: Array[int] = []
	for v in range(12, 61):
		if _contar_soluciones(v) >= 2:
			opciones.append(v)
	if not opciones.is_empty():
		voltaje_objetivo = opciones.pick_random()
	print("Voltaje objetivo de la puerta: %d V" % voltaje_objetivo)


## Cuántos pares (I, R) enteros dentro de los rangos dan ese voltaje.
func _contar_soluciones(voltaje: int) -> int:
	var total: int = 0
	for i in range(corriente_min, corriente_max + 1):
		for r in range(resistencia_min, resistencia_max + 1):
			if i * r == voltaje:
				total += 1
	return total


# ---------------------------------------------------------------- lógica

func _voltaje() -> int:
	return int(_slider_i.value) * int(_slider_r.value)   # V = I × R


func _actualizar() -> void:
	if _slider_i == null or _slider_r == null:
		return
	var voltaje: int = _voltaje()
	_lbl_i.text = "%d A" % int(_slider_i.value)
	_lbl_r.text = "%d Ω" % int(_slider_r.value)
	_lbl_voltaje.text = "VOLTAJE RESULTANTE: %d V" % voltaje
	var color: Color = COLOR_VERDE if voltaje == voltaje_objetivo else COLOR_AMARILLO
	_lbl_voltaje.add_theme_color_override("font_color", color)


func _on_slider_cambiado(_valor: float) -> void:
	_actualizar()


func _on_verificar() -> void:
	var voltaje: int = _voltaje()
	if voltaje == voltaje_objetivo:
		print("Circuito correcto: %d V" % voltaje)
		cerrar()                    # primero se cierra (y se quita la pausa)...
		circuito_correcto.emit()    # ...y luego se avisa para abrir la puerta
	else:
		_lbl_estado.text = "Voltaje incorrecto (%d V). Ajusta I y R para obtener %d V." % [voltaje, voltaje_objetivo]
		_lbl_estado.add_theme_color_override("font_color", COLOR_ROJO)


# ---------------------------------------------------------------- interfaz

func _construir_interfaz() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.6)
	add_child(fondo)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var centro := CenterContainer.new()
	fondo.add_child(centro)
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	panel.add_theme_stylebox_override("panel", _caja(COLOR_FONDO, COLOR_CIAN, 3, 8, 18))
	centro.add_child(panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 14)
	panel.add_child(caja)

	# Barra de título con botón X
	var barra := HBoxContainer.new()
	caja.add_child(barra)
	var titulo := Label.new()
	titulo.text = "PANEL DE CONTROL: SECTOR A - PUENTE DE ENERGÍA"
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_color_override("font_color", COLOR_CIAN)
	barra.add_child(titulo)
	var btn_x := Button.new()
	btn_x.text = "X"
	btn_x.flat = true
	btn_x.pressed.connect(cerrar)
	barra.add_child(btn_x)

	# Objetivo
	var objetivo := Label.new()
	objetivo.text = "OBJETIVO: Ajustar voltaje a %d V" % voltaje_objetivo
	objetivo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objetivo.add_theme_font_size_override("font_size", 22)
	objetivo.add_theme_color_override("font_color", COLOR_AMARILLO)
	caja.add_child(objetivo)

	# Deslizadores
	var fila_i: Array = _crear_fila(caja, "CORRIENTE (I):", corriente_min, corriente_max, Color(0.3, 0.6, 1.0))
	_slider_i = fila_i[0]
	_lbl_i = fila_i[1]
	var fila_r: Array = _crear_fila(caja, "RESISTENCIA (R):", resistencia_min, resistencia_max, Color(1.0, 0.35, 0.35))
	_slider_r = fila_r[0]
	_lbl_r = fila_r[1]

	# Caja de fórmula y resultado
	var caja_formula := PanelContainer.new()
	caja_formula.add_theme_stylebox_override("panel", _caja(Color(0.03, 0.07, 0.11), Color(0.2, 0.45, 0.6), 2, 6, 14))
	caja.add_child(caja_formula)
	var vbox_formula := VBoxContainer.new()
	vbox_formula.add_theme_constant_override("separation", 8)
	caja_formula.add_child(vbox_formula)

	var formula := Label.new()
	formula.text = "FÓRMULA: V = I × R"
	formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	formula.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	vbox_formula.add_child(formula)

	_lbl_voltaje = Label.new()
	_lbl_voltaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_voltaje.add_theme_font_size_override("font_size", 30)
	vbox_formula.add_child(_lbl_voltaje)

	# Mensaje de estado
	_lbl_estado = Label.new()
	_lbl_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(_lbl_estado)

	# Botones
	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 24)
	caja.add_child(botones)

	var btn_ok := Button.new()
	btn_ok.text = "VERIFICAR CIRCUITO"
	btn_ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_ok.custom_minimum_size = Vector2(0, 44)
	_estilizar_boton(btn_ok, COLOR_VERDE)
	btn_ok.pressed.connect(_on_verificar)
	botones.add_child(btn_ok)

	var btn_salir := Button.new()
	btn_salir.text = "SALIR"
	btn_salir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_salir.custom_minimum_size = Vector2(0, 44)
	_estilizar_boton(btn_salir, COLOR_ROJO)
	btn_salir.pressed.connect(cerrar)
	botones.add_child(btn_salir)


func _crear_fila(padre: Control, nombre: String, minimo: int, maximo: int, color: Color) -> Array:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 14)
	padre.add_child(fila)

	var etiqueta := Label.new()
	etiqueta.text = nombre
	etiqueta.custom_minimum_size = Vector2(170, 0)
	fila.add_child(etiqueta)

	var slider := HSlider.new()
	slider.min_value = minimo
	slider.max_value = maximo
	slider.step = 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(240, 24)
	_estilizar_slider(slider, color)
	slider.value_changed.connect(_on_slider_cambiado)
	fila.add_child(slider)

	var valor := Label.new()
	valor.custom_minimum_size = Vector2(70, 0)
	valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	valor.add_theme_color_override("font_color", color.lightened(0.3))
	fila.add_child(valor)

	return [slider, valor]


func _estilizar_slider(slider: HSlider, color: Color) -> void:
	var pista := StyleBoxFlat.new()
	pista.bg_color = Color(0.1, 0.15, 0.22)
	pista.set_corner_radius_all(4)
	pista.content_margin_top = 4
	pista.content_margin_bottom = 4
	var relleno := StyleBoxFlat.new()
	relleno.bg_color = color
	relleno.set_corner_radius_all(4)
	relleno.content_margin_top = 4
	relleno.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", pista)
	slider.add_theme_stylebox_override("grabber_area", relleno)
	slider.add_theme_stylebox_override("grabber_area_highlight", relleno)


func _estilizar_boton(boton: Button, color: Color) -> void:
	for estado in ["normal", "hover", "pressed", "focus"]:
		var fondo: Color = color.darkened(0.8) if estado == "normal" else color.darkened(0.6)
		boton.add_theme_stylebox_override(estado, _caja(fondo, color, 2, 6, 8))
	boton.add_theme_color_override("font_color", color.lightened(0.4))
	boton.add_theme_color_override("font_hover_color", Color.WHITE)
	boton.add_theme_color_override("font_pressed_color", Color.WHITE)


func _caja(fondo: Color, borde: Color, grosor: int, radio: int, margen: int) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fondo
	estilo.border_color = borde
	estilo.set_border_width_all(grosor)
	estilo.set_corner_radius_all(radio)
	estilo.set_content_margin_all(margen)
	return estilo
