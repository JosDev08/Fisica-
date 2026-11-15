extends CanvasLayer
## Panel de control: minijuego de la Ley de Ohm con V = I × R (solo números enteros).
## Incluye Tarjeta de Nota Técnica previa, HUD compacto OBJETIVO vs ACTUAL con ProgressBar,
## esquema visual animado en tiempo real y controles de teclado/ratón sin robo de foco.

signal circuito_correcto
signal cerrado

@export var voltaje_objetivo: int = 24
@export var objetivo_aleatorio: bool = false
@export var corriente_min: int = 1
@export var corriente_max: int = 10
@export var resistencia_min: int = 1
@export var resistencia_max: int = 20

const COLOR_CIAN := Color(0.35, 0.85, 1.0)
const COLOR_VERDE := Color(0.35, 1.0, 0.45)
const COLOR_ROJO := Color(1.0, 0.35, 0.35)
const COLOR_AMARILLO := Color(1.0, 0.9, 0.45)
const COLOR_FONDO := Color(0.04, 0.08, 0.14, 0.96)

var _panel_nota: PanelContainer
var _panel_puzzle: PanelContainer
var _slider_i: HSlider
var _slider_r: HSlider
var _lbl_i: Label
var _lbl_r: Label
var _lbl_hud_objetivo: Label
var _lbl_hud_actual: Label
var _barra_progreso: ProgressBar
var _lbl_estado: Label

# Nodos del esquema visual del circuito
var _cable_loop: Line2D
var _zigzag_r: Line2D
var _bloque_i: ColorRect
var _lbl_bloque_i: Label
var _bloque_r: ColorRect
var _lbl_bloque_r: Label
var _bloque_puerta: ColorRect
var _lbl_bloque_puerta: Label
var _pulsos: Array[ColorRect] = []
var _fase_pulsos: float = 0.0
var _ruta_pulsos: Array[Vector2] = [
	Vector2(85, 30),
	Vector2(495, 30),
	Vector2(495, 126),
	Vector2(85, 126)
]

func _ready() -> void:
	randomize()
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construir_interfaz()
	generar_nuevo_puzzle()
	hide()

func generar_nuevo_puzzle() -> void:
	# Generación inversa: sortear primero valores válidos dentro del rango y paso (1) de los sliders
	var i_ganador: int = randi_range(maxi(2, corriente_min), corriente_max)
	var r_ganador: int = randi_range(maxi(2, resistencia_min), resistencia_max)
	voltaje_objetivo = i_ganador * r_ganador

	# Verificar con un bucle while que los valores iniciales nunca empiecen ya resueltos
	var i_ini: int = randi_range(corriente_min, corriente_max)
	var r_ini: int = randi_range(resistencia_min, resistencia_max)
	while (i_ini * r_ini) == voltaje_objetivo:
		i_ini = randi_range(corriente_min, corriente_max)
		r_ini = randi_range(resistencia_min, resistencia_max)

	if _slider_i:
		_slider_i.value = i_ini
	if _slider_r:
		_slider_r.value = r_ini
	if _barra_progreso:
		_barra_progreso.max_value = float(voltaje_objetivo) * 1.5
	_actualizar()

func _ocultar_textos_mundo(ocultar: bool) -> void:
	for n in get_tree().get_nodes_in_group("texto_mundo_flotante"):
		if n is CanvasItem:
			n.modulate.a = 0.0 if ocultar else 1.0

func abrir() -> void:
	var i: int = int(_slider_i.value) if _slider_i else corriente_min
	var r: int = int(_slider_r.value) if _slider_r else resistencia_min
	while (i * r) == voltaje_objetivo:
		i = randi_range(corriente_min, corriente_max)
		r = randi_range(resistencia_min, resistencia_max)
	_slider_i.value = i
	_slider_r.value = r
	_lbl_estado.text = ""
	_panel_nota.visible = true
	_panel_puzzle.visible = false
	_ocultar_textos_mundo(true)
	_actualizar()
	show()
	get_tree().paused = true

func _mostrar_nota() -> void:
	_panel_nota.visible = true
	_panel_puzzle.visible = false

func _pasar_a_puzzle() -> void:
	_panel_nota.visible = false
	_panel_puzzle.visible = true
	_actualizar()

func cerrar() -> void:
	hide()
	_panel_nota.visible = false
	_panel_puzzle.visible = false
	_ocultar_textos_mundo(false)
	get_tree().paused = false
	cerrado.emit()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if _panel_nota.visible:
			if kc in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E]:
				get_viewport().set_input_as_handled()
				_pasar_a_puzzle()
			elif kc == KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				cerrar()
		elif _panel_puzzle.visible:
			if kc in [KEY_ESCAPE, KEY_E]:
				get_viewport().set_input_as_handled()
				cerrar()
			elif kc in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				get_viewport().set_input_as_handled()
				_on_verificar()
			elif kc in [KEY_Q, KEY_DOWN]:
				_slider_i.value = clampf(_slider_i.value - 1.0, corriente_min, corriente_max)
				get_viewport().set_input_as_handled()
			elif kc in [KEY_W, KEY_UP]:
				_slider_i.value = clampf(_slider_i.value + 1.0, corriente_min, corriente_max)
				get_viewport().set_input_as_handled()
			elif kc in [KEY_A, KEY_LEFT]:
				_slider_r.value = clampf(_slider_r.value - 1.0, resistencia_min, resistencia_max)
				get_viewport().set_input_as_handled()
			elif kc in [KEY_D, KEY_RIGHT]:
				_slider_r.value = clampf(_slider_r.value + 1.0, resistencia_min, resistencia_max)
				get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not visible or not _panel_puzzle or not _panel_puzzle.visible:
		return
	var i_val: float = _slider_i.value if _slider_i else 1.0
	var v_val: int = _voltaje()
	var exacto: bool = (v_val == voltaje_objetivo)
	_fase_pulsos = fmod(_fase_pulsos + delta * (0.12 + i_val * 0.045), 1.0)
	var col_p := COLOR_VERDE if exacto else (COLOR_ROJO if v_val > voltaje_objetivo else COLOR_AMARILLO)
	for idx in range(_pulsos.size()):
		var p := _pulsos[idx]
		p.color = col_p
		var t := fmod(_fase_pulsos + float(idx) / float(_pulsos.size()), 1.0)
		p.position = _punto_en_lazo(t) - Vector2(4, 4)

func _punto_en_lazo(t: float) -> Vector2:
	var dist := t * 1012.0
	if dist < 410.0:
		return _ruta_pulsos[0].lerp(_ruta_pulsos[1], dist / 410.0)
	elif dist < 506.0:
		return _ruta_pulsos[1].lerp(_ruta_pulsos[2], (dist - 410.0) / 96.0)
	elif dist < 916.0:
		return _ruta_pulsos[2].lerp(_ruta_pulsos[3], (dist - 506.0) / 410.0)
	else:
		return _ruta_pulsos[3].lerp(_ruta_pulsos[0], (dist - 916.0) / 96.0)

func _generar_objetivo() -> void:
	var opciones: Array[int] = []
	for v in range(12, 61):
		if _contar_soluciones(v) >= 2:
			opciones.append(v)
	if not opciones.is_empty():
		voltaje_objetivo = opciones.pick_random()

func _contar_soluciones(voltaje: int) -> int:
	var total: int = 0
	for i in range(corriente_min, corriente_max + 1):
		for r in range(resistencia_min, resistencia_max + 1):
			if i * r == voltaje:
				total += 1
	return total

func _voltaje() -> int:
	return int(_slider_i.value) * int(_slider_r.value)

func _actualizar() -> void:
	if _slider_i == null or _slider_r == null:
		return
	var i_val: int = int(_slider_i.value)
	var r_val: int = int(_slider_r.value)
	var voltaje: int = _voltaje()
	var exacto: bool = (voltaje == voltaje_objetivo)

	_lbl_i.text = "%d A" % i_val
	_lbl_r.text = "%d Ω" % r_val
	_lbl_hud_objetivo.text = "OBJETIVO: %d V" % voltaje_objetivo
	_lbl_hud_actual.text = "ACTUAL: %d V %s" % [voltaje, "(¡LISTO!)" if exacto else ""]

	var col_estado: Color = COLOR_VERDE if exacto else (COLOR_ROJO if voltaje > voltaje_objetivo else COLOR_AMARILLO)
	_lbl_hud_actual.add_theme_color_override("font_color", col_estado)

	_barra_progreso.max_value = float(voltaje_objetivo) * 1.5
	_barra_progreso.value = clampf(float(voltaje), 0.0, _barra_progreso.max_value)
	var fill_sb := StyleBoxFlat.new()
	fill_sb.set_corner_radius_all(4)
	fill_sb.bg_color = col_estado
	_barra_progreso.add_theme_stylebox_override("fill", fill_sb)

	if _cable_loop:
		_cable_loop.default_color = col_estado
		_cable_loop.width = 2.0 + clampf(float(i_val) / float(corriente_max), 0.0, 1.0) * 3.0
		_zigzag_r.width = 1.8 + (float(r_val) / float(resistencia_max)) * 2.8
		_lbl_bloque_i.text = "CORRIENTE\nI = %d A" % i_val
		_lbl_bloque_r.text = "R = %d Ω" % r_val
		_bloque_puerta.color = Color(0.1, 0.42, 0.24) if exacto else Color(0.14, 0.18, 0.26)
		_lbl_bloque_puerta.text = "🔓 CERROJO (%d / %d V)" % [voltaje, voltaje_objetivo]

func _on_slider_cambiado(_valor: float) -> void:
	_actualizar()

func _on_verificar() -> void:
	var voltaje: int = _voltaje()
	if voltaje == voltaje_objetivo:
		cerrar()
		circuito_correcto.emit()
	else:
		_lbl_estado.text = "Tensión actual: %d V (Se requieren exactamente %d V)." % [voltaje, voltaje_objetivo]
		_lbl_estado.add_theme_color_override("font_color", COLOR_ROJO)

func _construir_interfaz() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0.01, 0.03, 0.06, 0.72)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fondo)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var centro := CenterContainer.new()
	centro.mouse_filter = Control.MOUSE_FILTER_PASS
	fondo.add_child(centro)
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# ==========================================================================
	# 1. TARJETA DE NOTA TÉCNICA PREVIA (CONOCIMIENTOS PREVIOS)
	# ==========================================================================
	_panel_nota = PanelContainer.new()
	_panel_nota.custom_minimum_size = Vector2(540, 0)
	_panel_nota.focus_mode = Control.FOCUS_NONE
	_panel_nota.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_nota.add_theme_stylebox_override("panel", _caja(COLOR_FONDO, COLOR_CIAN, 3, 10, 22))
	_panel_nota.visible = false
	centro.add_child(_panel_nota)

	var vbox_nota := VBoxContainer.new()
	vbox_nota.add_theme_constant_override("separation", 12)
	_panel_nota.add_child(vbox_nota)

	var lbl_tn := Label.new()
	lbl_tn.text = "NOTA TÉCNICA: CONCEPTOS CLAVE"
	lbl_tn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_tn.add_theme_font_size_override("font_size", 18)
	lbl_tn.add_theme_color_override("font_color", COLOR_CIAN)
	vbox_nota.add_child(lbl_tn)

	var lbl_mag := Label.new()
	lbl_mag.text = "Magnitud: Voltaje o Tensión Eléctrica (Ley de Ohm)"
	lbl_mag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_mag.add_theme_font_size_override("font_size", 15)
	lbl_mag.add_theme_color_override("font_color", COLOR_AMARILLO)
	vbox_nota.add_child(lbl_mag)

	var caja_f := PanelContainer.new()
	caja_f.add_theme_stylebox_override("panel", _caja(Color(0.02, 0.05, 0.09, 0.95), Color(0.2, 0.55, 0.75), 2, 6, 10))
	vbox_nota.add_child(caja_f)

	var lbl_f := Label.new()
	lbl_f.text = "V = I × R"
	lbl_f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_f.add_theme_font_size_override("font_size", 22)
	lbl_f.add_theme_color_override("font_color", COLOR_VERDE)
	caja_f.add_child(lbl_f)

	var lbl_exp := Label.new()
	lbl_exp.text = "• I (Corriente, A): Flujo de carga; R (Resistencia, Ω): Oposición del circuito.\n• Su producto genera el voltaje V (Voltios) que energiza la cerradura."
	lbl_exp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_exp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_exp.add_theme_font_size_override("font_size", 13)
	vbox_nota.add_child(lbl_exp)

	var btn_cont := Button.new()
	btn_cont.text = "[ ENTENDIDO / CONTINUAR ]  (Enter / Espacio / E)"
	btn_cont.custom_minimum_size = Vector2(0, 42)
	btn_cont.focus_mode = Control.FOCUS_NONE
	_estilizar_boton(btn_cont, COLOR_VERDE)
	btn_cont.pressed.connect(_pasar_a_puzzle)
	vbox_nota.add_child(btn_cont)

	# ==========================================================================
	# 2. PANEL PRINCIPAL DEL PUZZLE
	# ==========================================================================
	_panel_puzzle = PanelContainer.new()
	_panel_puzzle.custom_minimum_size = Vector2(620, 0)
	_panel_puzzle.focus_mode = Control.FOCUS_NONE
	_panel_puzzle.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_puzzle.add_theme_stylebox_override("panel", _caja(COLOR_FONDO, COLOR_CIAN, 3, 10, 18))
	_panel_puzzle.visible = false
	centro.add_child(_panel_puzzle)

	var caja := VBoxContainer.new()
	caja.mouse_filter = Control.MOUSE_FILTER_PASS
	caja.add_theme_constant_override("separation", 10)
	_panel_puzzle.add_child(caja)

	# Barra de título con botón Nota y botón X
	var barra := HBoxContainer.new()
	barra.add_theme_constant_override("separation", 8)
	caja.add_child(barra)

	var btn_nota := Button.new()
	btn_nota.text = "[?] Nota"
	btn_nota.focus_mode = Control.FOCUS_NONE
	_estilizar_boton(btn_nota, COLOR_CIAN)
	btn_nota.pressed.connect(_mostrar_nota)
	barra.add_child(btn_nota)

	var titulo := Label.new()
	titulo.text = "COMPUERTA DE OHM — CONTROL I × R"
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 16)
	titulo.add_theme_color_override("font_color", COLOR_CIAN)
	barra.add_child(titulo)

	var btn_x := Button.new()
	btn_x.text = "[X] Esc"
	btn_x.focus_mode = Control.FOCUS_NONE
	_estilizar_boton(btn_x, COLOR_ROJO)
	btn_x.pressed.connect(cerrar)
	barra.add_child(btn_x)

	# HUD Superior: OBJETIVO vs ACTUAL + ProgressBar
	var caja_hud := PanelContainer.new()
	caja_hud.add_theme_stylebox_override("panel", _caja(Color(0.02, 0.04, 0.08, 0.95), Color(0.2, 0.45, 0.65), 2, 6, 10))
	caja.add_child(caja_hud)

	var vbox_hud := VBoxContainer.new()
	vbox_hud.add_theme_constant_override("separation", 6)
	caja_hud.add_child(vbox_hud)

	var hbox_hud := HBoxContainer.new()
	vbox_hud.add_child(hbox_hud)

	_lbl_hud_objetivo = Label.new()
	_lbl_hud_objetivo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_hud_objetivo.add_theme_font_size_override("font_size", 15)
	_lbl_hud_objetivo.add_theme_color_override("font_color", COLOR_AMARILLO)
	hbox_hud.add_child(_lbl_hud_objetivo)

	_lbl_hud_actual = Label.new()
	_lbl_hud_actual.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_hud_actual.add_theme_font_size_override("font_size", 15)
	hbox_hud.add_child(_lbl_hud_actual)

	_barra_progreso = ProgressBar.new()
	_barra_progreso.custom_minimum_size = Vector2(0, 16)
	_barra_progreso.min_value = 0.0
	_barra_progreso.show_percentage = false
	_barra_progreso.focus_mode = Control.FOCUS_NONE
	vbox_hud.add_child(_barra_progreso)

	# Esquema visual del circuito dentro del panel
	var caja_esq := Panel.new()
	caja_esq.custom_minimum_size = Vector2(580, 156)
	caja_esq.focus_mode = Control.FOCUS_NONE
	caja_esq.add_theme_stylebox_override("panel", _caja(Color(0.02, 0.04, 0.07, 0.98), Color(0.18, 0.35, 0.52), 2, 8, 0))
	caja.add_child(caja_esq)

	_cable_loop = Line2D.new()
	_cable_loop.width = 3.0
	_cable_loop.points = PackedVector2Array([
		Vector2(85, 30), Vector2(495, 30),
		Vector2(495, 126), Vector2(85, 126), Vector2(85, 30)
	])
	caja_esq.add_child(_cable_loop)

	_pulsos.clear()
	for idx in range(8):
		var p := ColorRect.new()
		p.size = Vector2(8, 8)
		caja_esq.add_child(p)
		_pulsos.append(p)

	_bloque_i = ColorRect.new()
	_bloque_i.position = Vector2(32, 48)
	_bloque_i.size = Vector2(106, 60)
	_bloque_i.color = Color(0.1, 0.25, 0.45)
	caja_esq.add_child(_bloque_i)

	_lbl_bloque_i = Label.new()
	_lbl_bloque_i.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lbl_bloque_i.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_bloque_i.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_bloque_i.add_theme_font_size_override("font_size", 12)
	_bloque_i.add_child(_lbl_bloque_i)

	_bloque_r = ColorRect.new()
	_bloque_r.position = Vector2(442, 48)
	_bloque_r.size = Vector2(106, 60)
	_bloque_r.color = Color(0.26, 0.16, 0.12)
	caja_esq.add_child(_bloque_r)

	_zigzag_r = Line2D.new()
	_zigzag_r.width = 2.5
	_zigzag_r.default_color = Color(1.0, 0.72, 0.3)
	_zigzag_r.points = PackedVector2Array([
		Vector2(12, 42), Vector2(26, 34), Vector2(40, 48),
		Vector2(54, 34), Vector2(68, 48), Vector2(82, 34), Vector2(94, 42)
	])
	_bloque_r.add_child(_zigzag_r)

	_lbl_bloque_r = Label.new()
	_lbl_bloque_r.position = Vector2(0, 6)
	_lbl_bloque_r.size = Vector2(106, 22)
	_lbl_bloque_r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_bloque_r.add_theme_font_size_override("font_size", 13)
	_bloque_r.add_child(_lbl_bloque_r)

	_bloque_puerta = ColorRect.new()
	_bloque_puerta.position = Vector2(195, 106)
	_bloque_puerta.size = Vector2(190, 36)
	_bloque_puerta.color = Color(0.14, 0.18, 0.26)
	caja_esq.add_child(_bloque_puerta)

	_lbl_bloque_puerta = Label.new()
	_lbl_bloque_puerta.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lbl_bloque_puerta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_bloque_puerta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_bloque_puerta.add_theme_font_size_override("font_size", 12)
	_bloque_puerta.add_child(_lbl_bloque_puerta)

	# Controles interactivos (Sliders + botones paso a paso sin foco)
	var fila_i: Array = _crear_fila(caja, "CORRIENTE (I):", corriente_min, corriente_max, Color(0.3, 0.6, 1.0), "◀ [Q/↓]", "[W/↑] ▶")
	_slider_i = fila_i[0]
	_lbl_i = fila_i[1]
	var fila_r: Array = _crear_fila(caja, "RESISTENCIA (R):", resistencia_min, resistencia_max, Color(1.0, 0.55, 0.35), "◀ [A/←]", "[D/→] ▶")
	_slider_r = fila_r[0]
	_lbl_r = fila_r[1]

	_lbl_estado = Label.new()
	_lbl_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_estado.add_theme_font_size_override("font_size", 12)
	caja.add_child(_lbl_estado)

	# Botones de acción
	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 16)
	caja.add_child(botones)

	var btn_ok := Button.new()
	btn_ok.text = "ENERGIZAR COMPUERTA [Enter / Espacio]"
	btn_ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_ok.custom_minimum_size = Vector2(0, 40)
	btn_ok.focus_mode = Control.FOCUS_NONE
	_estilizar_boton(btn_ok, COLOR_VERDE)
	btn_ok.pressed.connect(_on_verificar)
	botones.add_child(btn_ok)

	var btn_salir := Button.new()
	btn_salir.text = "CERRAR [E / Esc]"
	btn_salir.custom_minimum_size = Vector2(150, 40)
	btn_salir.focus_mode = Control.FOCUS_NONE
	_estilizar_boton(btn_salir, COLOR_ROJO)
	btn_salir.pressed.connect(cerrar)
	botones.add_child(btn_salir)

func _crear_fila(padre: Control, nombre: String, minimo: int, maximo: int, color: Color, txt_menos: String, txt_mas: String) -> Array:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	padre.add_child(fila)

	var etiqueta := Label.new()
	etiqueta.text = nombre
	etiqueta.custom_minimum_size = Vector2(135, 0)
	etiqueta.add_theme_font_size_override("font_size", 13)
	fila.add_child(etiqueta)

	var slider := HSlider.new()
	slider.min_value = minimo
	slider.max_value = maximo
	slider.step = 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(160, 24)
	slider.focus_mode = Control.FOCUS_NONE
	_estilizar_slider(slider, color)
	slider.value_changed.connect(_on_slider_cambiado)

	var btn_menos := Button.new()
	btn_menos.text = txt_menos
	btn_menos.custom_minimum_size = Vector2(76, 32)
	btn_menos.focus_mode = Control.FOCUS_NONE
	btn_menos.pressed.connect(func(): slider.value = clampf(slider.value - 1.0, minimo, maximo))
	fila.add_child(btn_menos)

	fila.add_child(slider)

	var btn_mas := Button.new()
	btn_mas.text = txt_mas
	btn_mas.custom_minimum_size = Vector2(76, 32)
	btn_mas.focus_mode = Control.FOCUS_NONE
	btn_mas.pressed.connect(func(): slider.value = clampf(slider.value + 1.0, minimo, maximo))
	fila.add_child(btn_mas)

	var valor := Label.new()
	valor.custom_minimum_size = Vector2(65, 0)
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
