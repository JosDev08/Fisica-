extends Node2D

# ==============================================================================
# PUZZLE 1 — PUENTE DE CARGA (CAPACITORES EN SERIE / PARALELO)
# Escena: res://Escenas/escena_02.tscn
# - PanelContainer oscuro casi sólido (alfa ~0.95) en CanvasLayer (layer = 10).
# - Cero superposición de textos: oculta todos los Labels flotantes del mundo.
# - Barra superior compacta: OBJETIVO: 18.0 µF vs ACTUAL: [valor] µF + ProgressBar.
# - Diagrama de circuito interactivo en tiempo real (Line2D + ColorRect) con
#   fuente, C1 = 6 µF, C2 = 12 µF y puente, flujo de energía animado y operación corta.
# - Auditoría de teclas: [1]/[2] o Flechas Izq/Der (A/D) alternan Serie/Paralelo,
#   Enter/Space confirman/activan el puente, E/Esc cierran el panel.
# ==============================================================================

const C1_VAL: float = 6.0
const C2_VAL: float = 12.0
const META_CEQ: float = 18.0

var en_paralelo: bool = false # Inicia en Serie: (6×12)/(6+12) = 4.0 µF
var puente_activo: bool = false
var jugador_cerca: bool = false
var panel_abierto: bool = false
var area_terminal_ref: Area2D = null
var _tecla_e_prev: bool = false

# Nodos del mundo
var cuerpo_puente: StaticBody2D
var colision_puente: CollisionShape2D
var sprite_puente: Sprite2D
var cable_linea: Line2D
var label_prompt: Label
var label_estado_mundo: Label

# Nodos de UI (CanvasLayer layer = 10)
var canvas_ui: CanvasLayer
var panel_contenedor: PanelContainer
var lbl_hud_estado: Label
var barra_carga: ProgressBar
var lienzo_circuito: Control
var linea_principal_izq: Line2D
var linea_principal_der: Line2D
var linea_rama_sup: Line2D
var linea_rama_inf: Line2D
var nodo_union_izq: ColorRect
var nodo_union_der: ColorRect
var nodo_fuente: ColorRect
var nodo_puente: ColorRect
var bloque_c1: Control
var bloque_c2: Control
var pulsos_energia: Array[ColorRect] = []
var fase_energia: float = 0.0
var btn_serie: Button
var btn_paralelo: Button
var btn_confirmar: Button
var btn_cerrar: Button
var lbl_formula: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_asegurar_input_interactuar()
	_construir_escena_mundo()
	_construir_interfaz_ui()
	_actualizar_calculo_y_estado(true)

func _asegurar_input_interactuar() -> void:
	if not InputMap.has_action("interactuar"):
		InputMap.add_action("interactuar")
	var tiene_e := false
	for ev in InputMap.action_get_events("interactuar"):
		if ev is InputEventKey and ev.physical_keycode == KEY_E:
			tiene_e = true
			break
	if not tiene_e:
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_E
		InputMap.action_add_event("interactuar", ev)

func _construir_escena_mundo() -> void:
	# 1. Cable conductor visual entre la terminal y el puente retráctil
	cable_linea = Line2D.new()
	cable_linea.width = 6.0
	cable_linea.points = PackedVector2Array([
		Vector2(-96, -12),
		Vector2(-96, 8),
		Vector2(-64, 8),
		Vector2(400, 8)
	])
	cable_linea.default_color = Color(0.85, 0.2, 0.25, 0.85)
	cable_linea.z_index = -1
	add_child(cable_linea)

	# 2. Puente Retráctil en Capa 5 Suelo (collision_layer = 16)
	cuerpo_puente = StaticBody2D.new()
	cuerpo_puente.name = "PuenteRetractil"
	cuerpo_puente.position = Vector2(168, 10)
	cuerpo_puente.collision_layer = 16 # Capa 5: Suelo
	cuerpo_puente.collision_mask = 0
	add_child(cuerpo_puente)

	colision_puente = CollisionShape2D.new()
	var rect_puente := RectangleShape2D.new()
	rect_puente.size = Vector2(464, 20)
	colision_puente.shape = rect_puente
	colision_puente.disabled = true
	cuerpo_puente.add_child(colision_puente)

	sprite_puente = Sprite2D.new()
	var tex_puente := load("res://assets/nivel_2/puente_electrico.svg") as Texture2D
	if tex_puente:
		sprite_puente.texture = tex_puente
	cuerpo_puente.add_child(sprite_puente)

	# 3. Terminal interactiva (Area2D) junto al borde izquierdo del abismo
	var area_terminal := Area2D.new()
	area_terminal_ref = area_terminal
	area_terminal.name = "TerminalPuente"
	area_terminal.position = Vector2(-96, -32)
	area_terminal.monitoring = true
	area_terminal.monitorable = true
	area_terminal.collision_layer = 0
	area_terminal.collision_mask = 1 # Capa 1: Jugador
	add_child(area_terminal)

	var col_terminal := CollisionShape2D.new()
	var shape_term := RectangleShape2D.new()
	shape_term.size = Vector2(120, 120)
	col_terminal.shape = shape_term
	area_terminal.add_child(col_terminal)

	var sprite_terminal := Sprite2D.new()
	var tex_term := load("res://assets/nivel_2/terminal_capacitor.svg") as Texture2D
	if tex_term:
		sprite_terminal.texture = tex_term
	area_terminal.add_child(sprite_terminal)

	var btn_mundo := Button.new()
	btn_mundo.flat = true
	btn_mundo.position = Vector2(-32, -32)
	btn_mundo.size = Vector2(64, 64)
	btn_mundo.focus_mode = Control.FOCUS_NONE
	btn_mundo.pressed.connect(_abrir_panel)
	area_terminal.add_child(btn_mundo)

	label_prompt = Label.new()
	label_prompt.text = "[E] Interactuar"
	label_prompt.position = Vector2(-80, -62)
	label_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_prompt.add_theme_font_size_override("font_size", 13)
	label_prompt.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	label_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label_prompt.add_theme_constant_override("outline_size", 3)
	label_prompt.visible = false
	label_prompt.add_to_group("texto_mundo_nivel2")
	area_terminal.add_child(label_prompt)

	label_estado_mundo = Label.new()
	label_estado_mundo.text = "Puente Retraído (4.0 µF / 18.0 µF)"
	label_estado_mundo.position = Vector2(40, -28)
	label_estado_mundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_estado_mundo.add_theme_font_size_override("font_size", 11)
	label_estado_mundo.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	label_estado_mundo.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label_estado_mundo.add_theme_constant_override("outline_size", 3)
	label_estado_mundo.add_to_group("texto_mundo_nivel2")
	add_child(label_estado_mundo)

	area_terminal.body_entered.connect(_on_body_entered)
	area_terminal.body_exited.connect(_on_body_exited)

func _crear_estilo_boton_switch(activo: bool, color_activo: Color) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	if activo:
		st.bg_color = color_activo.darkened(0.62)
		st.border_color = color_activo
		st.set_border_width_all(2)
	else:
		st.bg_color = Color(0.09, 0.13, 0.2, 0.95)
		st.border_color = Color(0.28, 0.36, 0.48, 0.85)
		st.set_border_width_all(1)
	st.set_corner_radius_all(6)
	st.set_content_margin_all(8)
	return st

func _crear_bloque_capacitor(etiqueta: String, valor_txt: String, color_acento: Color) -> Control:
	var raiz := Control.new()
	raiz.custom_minimum_size = Vector2(104, 56)
	raiz.size = Vector2(104, 56)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var caja := ColorRect.new()
	caja.position = Vector2(0, 0)
	caja.size = Vector2(104, 56)
	caja.color = Color(0.08, 0.13, 0.22, 0.98)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(caja)

	var borde_sup := ColorRect.new()
	borde_sup.position = Vector2(0, 0)
	borde_sup.size = Vector2(104, 3)
	borde_sup.color = color_acento
	borde_sup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(borde_sup)

	var borde_inf := ColorRect.new()
	borde_inf.position = Vector2(0, 53)
	borde_inf.size = Vector2(104, 3)
	borde_inf.color = color_acento
	borde_inf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(borde_inf)

	var terminal_izq := ColorRect.new()
	terminal_izq.position = Vector2(0, 26)
	terminal_izq.size = Vector2(12, 4)
	terminal_izq.color = color_acento
	terminal_izq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(terminal_izq)

	var placa_izq := ColorRect.new()
	placa_izq.position = Vector2(12, 10)
	placa_izq.size = Vector2(4, 36)
	placa_izq.color = Color(0.88, 0.96, 1.0)
	placa_izq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(placa_izq)

	var dielectrico := ColorRect.new()
	dielectrico.position = Vector2(17, 13)
	dielectrico.size = Vector2(6, 30)
	dielectrico.color = Color(color_acento.r, color_acento.g, color_acento.b, 0.45)
	dielectrico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(dielectrico)

	var placa_der := ColorRect.new()
	placa_der.position = Vector2(24, 10)
	placa_der.size = Vector2(4, 36)
	placa_der.color = Color(0.88, 0.96, 1.0)
	placa_der.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(placa_der)

	var lbl := Label.new()
	lbl.position = Vector2(32, 6)
	lbl.size = Vector2(68, 44)
	lbl.text = "%s = %s" % [etiqueta, valor_txt]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	raiz.add_child(lbl)

	return raiz

func _construir_interfaz_ui() -> void:
	canvas_ui = CanvasLayer.new()
	canvas_ui.layer = 10
	canvas_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas_ui.visible = false
	add_child(canvas_ui)

	var fondo_oscuro := ColorRect.new()
	fondo_oscuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo_oscuro.color = Color(0.01, 0.02, 0.05, 0.72)
	fondo_oscuro.mouse_filter = Control.MOUSE_FILTER_PASS
	canvas_ui.add_child(fondo_oscuro)

	# PanelContainer oscuro casi sólido (alfa ~0.95)
	panel_contenedor = PanelContainer.new()
	panel_contenedor.custom_minimum_size = Vector2(580, 368)
	panel_contenedor.set_anchors_preset(Control.PRESET_CENTER)
	panel_contenedor.offset_left = -290
	panel_contenedor.offset_top = -184
	panel_contenedor.offset_right = 290
	panel_contenedor.offset_bottom = 184
	panel_contenedor.mouse_filter = Control.MOUSE_FILTER_STOP
	panel_contenedor.focus_mode = Control.FOCUS_NONE
	var style_win := StyleBoxFlat.new()
	style_win.bg_color = Color(0.05, 0.08, 0.14, 0.95)
	style_win.border_color = Color(0.25, 0.85, 1.0)
	style_win.set_border_width_all(3)
	style_win.set_corner_radius_all(10)
	style_win.set_content_margin_all(16)
	panel_contenedor.add_theme_stylebox_override("panel", style_win)
	canvas_ui.add_child(panel_contenedor)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_theme_constant_override("separation", 10)
	panel_contenedor.add_child(vbox)

	# Barra superior compacta: OBJETIVO vs ACTUAL
	lbl_hud_estado = Label.new()
	lbl_hud_estado.text = "OBJETIVO: 18.0 µF   vs   ACTUAL: 4.0 µF"
	lbl_hud_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_hud_estado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_hud_estado.add_theme_font_size_override("font_size", 18)
	vbox.add_child(lbl_hud_estado)

	# ProgressBar dinámica (ámbar/rojo si insuficiente, verde neón al alcanzar objetivo)
	barra_carga = ProgressBar.new()
	barra_carga.min_value = 0.0
	barra_carga.max_value = META_CEQ
	barra_carga.custom_minimum_size = Vector2(520, 18)
	barra_carga.show_percentage = false
	barra_carga.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra_carga.focus_mode = Control.FOCUS_NONE
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.08, 0.12, 0.18, 0.95)
	sb_bg.set_corner_radius_all(5)
	barra_carga.add_theme_stylebox_override("background", sb_bg)
	vbox.add_child(barra_carga)

	# Diagrama de circuito interactivo (Line2D + ColorRect)
	lienzo_circuito = Control.new()
	lienzo_circuito.custom_minimum_size = Vector2(540, 184)
	lienzo_circuito.size = Vector2(540, 184)
	lienzo_circuito.mouse_filter = Control.MOUSE_FILTER_STOP
	lienzo_circuito.focus_mode = Control.FOCUS_NONE
	lienzo_circuito.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			en_paralelo = not en_paralelo
			_actualizar_calculo_y_estado(false)
	)
	vbox.add_child(lienzo_circuito)

	var fondo_diag := ColorRect.new()
	fondo_diag.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo_diag.color = Color(0.03, 0.05, 0.09, 0.98)
	fondo_diag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo_circuito.add_child(fondo_diag)

	nodo_fuente = ColorRect.new()
	nodo_fuente.position = Vector2(14, 66)
	nodo_fuente.size = Vector2(54, 52)
	nodo_fuente.color = Color(0.11, 0.2, 0.34, 1.0)
	nodo_fuente.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo_circuito.add_child(nodo_fuente)

	var borde_fuente := ColorRect.new()
	borde_fuente.position = Vector2(14, 66)
	borde_fuente.size = Vector2(54, 3)
	borde_fuente.color = Color(0.35, 0.88, 1.0)
	borde_fuente.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo_circuito.add_child(borde_fuente)

	var lbl_fuente := Label.new()
	lbl_fuente.position = Vector2(14, 68)
	lbl_fuente.size = Vector2(54, 48)
	lbl_fuente.text = "FUENTE\n+ 12 V -"
	lbl_fuente.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_fuente.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_fuente.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_fuente.add_theme_font_size_override("font_size", 10)
	lbl_fuente.add_theme_color_override("font_color", Color(0.45, 0.92, 1.0))
	lienzo_circuito.add_child(lbl_fuente)

	nodo_puente = ColorRect.new()
	nodo_puente.position = Vector2(468, 66)
	nodo_puente.size = Vector2(58, 52)
	nodo_puente.color = Color(0.12, 0.2, 0.32, 1.0)
	nodo_puente.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo_circuito.add_child(nodo_puente)

	var lbl_carga := Label.new()
	lbl_carga.position = Vector2(468, 68)
	lbl_carga.size = Vector2(58, 48)
	lbl_carga.text = "PUENTE\n18.0 µF"
	lbl_carga.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_carga.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_carga.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_carga.add_theme_font_size_override("font_size", 10)
	lbl_carga.add_theme_color_override("font_color", Color(0.95, 0.9, 0.45))
	lienzo_circuito.add_child(lbl_carga)

	linea_principal_izq = Line2D.new()
	linea_principal_izq.width = 4.0
	lienzo_circuito.add_child(linea_principal_izq)

	linea_principal_der = Line2D.new()
	linea_principal_der.width = 4.0
	lienzo_circuito.add_child(linea_principal_der)

	linea_rama_sup = Line2D.new()
	linea_rama_sup.width = 4.0
	lienzo_circuito.add_child(linea_rama_sup)

	linea_rama_inf = Line2D.new()
	linea_rama_inf.width = 4.0
	lienzo_circuito.add_child(linea_rama_inf)

	nodo_union_izq = ColorRect.new()
	nodo_union_izq.size = Vector2(10, 10)
	nodo_union_izq.position = Vector2(115, 87)
	nodo_union_izq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo_circuito.add_child(nodo_union_izq)

	nodo_union_der = ColorRect.new()
	nodo_union_der.size = Vector2(10, 10)
	nodo_union_der.position = Vector2(411, 87)
	nodo_union_der.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo_circuito.add_child(nodo_union_der)

	bloque_c1 = _crear_bloque_capacitor("C1", "6 µF", Color(0.3, 0.85, 1.0))
	lienzo_circuito.add_child(bloque_c1)

	bloque_c2 = _crear_bloque_capacitor("C2", "12 µF", Color(0.45, 0.95, 0.65))
	lienzo_circuito.add_child(bloque_c2)

	for i in range(6):
		var pulso := ColorRect.new()
		pulso.size = Vector2(8, 8)
		pulso.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lienzo_circuito.add_child(pulso)
		pulsos_energia.append(pulso)

	# Operación corta debajo del diagrama
	lbl_formula = Label.new()
	lbl_formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_formula.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_formula.add_theme_font_size_override("font_size", 15)
	vbox.add_child(lbl_formula)

	# Botonera interactiva con todos los atajos visibles y sin bloqueo de foco
	var hb_switch := HBoxContainer.new()
	hb_switch.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_switch.mouse_filter = Control.MOUSE_FILTER_PASS
	hb_switch.add_theme_constant_override("separation", 10)
	vbox.add_child(hb_switch)

	btn_serie = Button.new()
	btn_serie.text = "[ SERIE ]  [1 / ◀]"
	btn_serie.custom_minimum_size = Vector2(150, 38)
	btn_serie.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_serie.focus_mode = Control.FOCUS_NONE
	btn_serie.pressed.connect(func():
		en_paralelo = false
		_actualizar_calculo_y_estado(false)
	)
	hb_switch.add_child(btn_serie)

	btn_paralelo = Button.new()
	btn_paralelo.text = "[ PARALELO ]  [2 / ▶]"
	btn_paralelo.custom_minimum_size = Vector2(160, 38)
	btn_paralelo.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_paralelo.focus_mode = Control.FOCUS_NONE
	btn_paralelo.pressed.connect(func():
		en_paralelo = true
		_actualizar_calculo_y_estado(false)
	)
	hb_switch.add_child(btn_paralelo)

	btn_confirmar = Button.new()
	btn_confirmar.text = "ACTIVAR [Enter / Space]"
	btn_confirmar.custom_minimum_size = Vector2(154, 38)
	btn_confirmar.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_confirmar.focus_mode = Control.FOCUS_NONE
	btn_confirmar.pressed.connect(_confirmar_y_cerrar)
	hb_switch.add_child(btn_confirmar)

	btn_cerrar = Button.new()
	btn_cerrar.text = "✕ [E / Esc]"
	btn_cerrar.custom_minimum_size = Vector2(74, 38)
	btn_cerrar.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_cerrar.focus_mode = Control.FOCUS_NONE
	btn_cerrar.pressed.connect(_cerrar_panel)
	hb_switch.add_child(btn_cerrar)

func _calcular_ceq() -> float:
	if en_paralelo:
		return C1_VAL + C2_VAL
	else:
		return (C1_VAL * C2_VAL) / (C1_VAL + C2_VAL)

func _ocultar_textos_mundo(ocultar: bool) -> void:
	if get_tree():
		for n in get_tree().get_nodes_in_group("texto_mundo_nivel2"):
			if n is CanvasItem:
				if ocultar:
					n.visible = false
				else:
					if n == label_prompt:
						n.visible = jugador_cerca
					elif n.name != "PromptInteractuar":
						n.visible = true
	if label_prompt:
		label_prompt.visible = jugador_cerca and not ocultar
	if label_estado_mundo:
		label_estado_mundo.visible = not ocultar

func _congelar_jugador(congelar: bool) -> void:
	if not get_tree():
		return
	var root := get_tree().current_scene
	if not root:
		return
	for child in root.get_children():
		if child is CharacterBody2D:
			child.set_physics_process(not congelar)

func _actualizar_calculo_y_estado(instantaneo: bool) -> void:
	var ceq: float = _calcular_ceq()
	puente_activo = is_equal_approx(ceq, META_CEQ)

	if lbl_hud_estado:
		var col_estado := Color(0.2, 1.0, 0.55) if puente_activo else Color(1.0, 0.68, 0.25)
		lbl_hud_estado.text = "OBJETIVO: 18.0 µF   vs   ACTUAL: %.1f µF" % ceq
		lbl_hud_estado.add_theme_color_override("font_color", col_estado)

		barra_carga.value = ceq
		var sb_fill := StyleBoxFlat.new()
		sb_fill.bg_color = Color(0.18, 0.98, 0.52) if puente_activo else Color(0.95, 0.55, 0.2)
		sb_fill.set_corner_radius_all(5)
		barra_carga.add_theme_stylebox_override("fill", sb_fill)

		btn_serie.add_theme_stylebox_override("normal", _crear_estilo_boton_switch(not en_paralelo, Color(1.0, 0.72, 0.25)))
		btn_serie.add_theme_stylebox_override("hover", _crear_estilo_boton_switch(not en_paralelo, Color(1.0, 0.82, 0.35)))
		btn_serie.add_theme_stylebox_override("pressed", _crear_estilo_boton_switch(not en_paralelo, Color(1.0, 0.72, 0.25)))
		btn_serie.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4) if not en_paralelo else Color(0.6, 0.7, 0.8))

		btn_paralelo.add_theme_stylebox_override("normal", _crear_estilo_boton_switch(en_paralelo, Color(0.2, 0.98, 0.55)))
		btn_paralelo.add_theme_stylebox_override("hover", _crear_estilo_boton_switch(en_paralelo, Color(0.35, 1.0, 0.68)))
		btn_paralelo.add_theme_stylebox_override("pressed", _crear_estilo_boton_switch(en_paralelo, Color(0.2, 0.98, 0.55)))
		btn_paralelo.add_theme_color_override("font_color", Color(0.3, 1.0, 0.62) if en_paralelo else Color(0.6, 0.7, 0.8))

		btn_confirmar.add_theme_stylebox_override("normal", _crear_estilo_boton_switch(puente_activo, Color(0.25, 0.95, 0.6)))
		btn_confirmar.add_theme_stylebox_override("hover", _crear_estilo_boton_switch(true, Color(0.35, 1.0, 0.7)))

		var col_cable := Color(0.2, 0.98, 0.55, 1.0) if en_paralelo else Color(0.98, 0.65, 0.22, 0.92)
		linea_principal_izq.default_color = col_cable
		linea_principal_der.default_color = col_cable
		linea_rama_sup.default_color = col_cable
		linea_rama_inf.default_color = col_cable
		nodo_union_izq.color = col_cable
		nodo_union_der.color = col_cable
		nodo_puente.color = Color(0.1, 0.32, 0.22, 1.0) if puente_activo else Color(0.24, 0.14, 0.14, 1.0)

		if en_paralelo:
			bloque_c1.position = Vector2(216, 16)
			bloque_c2.position = Vector2(216, 112)
			nodo_union_izq.visible = true
			nodo_union_der.visible = true
			linea_rama_inf.visible = true

			linea_principal_izq.points = PackedVector2Array([Vector2(68, 92), Vector2(120, 92)])
			linea_principal_der.points = PackedVector2Array([Vector2(416, 92), Vector2(468, 92)])
			linea_rama_sup.points = PackedVector2Array([
				Vector2(120, 92), Vector2(120, 44), Vector2(216, 44),
				Vector2(320, 44), Vector2(416, 44), Vector2(416, 92)
			])
			linea_rama_inf.points = PackedVector2Array([
				Vector2(120, 92), Vector2(120, 140), Vector2(216, 140),
				Vector2(320, 140), Vector2(416, 140), Vector2(416, 92)
			])

			lbl_formula.text = "6 + 12 = 18.0 µF"
			lbl_formula.add_theme_color_override("font_color", Color(0.25, 1.0, 0.58))
		else:
			bloque_c1.position = Vector2(136, 64)
			bloque_c2.position = Vector2(292, 64)
			nodo_union_izq.visible = false
			nodo_union_der.visible = false
			linea_rama_inf.visible = false

			linea_principal_izq.points = PackedVector2Array([Vector2(68, 92), Vector2(136, 92)])
			linea_rama_sup.points = PackedVector2Array([Vector2(240, 92), Vector2(292, 92)])
			linea_principal_der.points = PackedVector2Array([Vector2(396, 92), Vector2(468, 92)])

			lbl_formula.text = "(6×12)/(6+12) = 4.0 µF"
			lbl_formula.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))

	# Actualizar puente físico en Capa 5 Suelo y cables en el mundo
	colision_puente.set_deferred("disabled", not puente_activo)
	if puente_activo:
		cable_linea.default_color = Color(0.2, 0.95, 0.55, 1.0)
		label_estado_mundo.text = "⚡ PUENTE ENERGIZADO (18.0 µF)"
		label_estado_mundo.add_theme_color_override("font_color", Color(0.25, 1.0, 0.55))
		if instantaneo:
			sprite_puente.scale = Vector2(1.0, 1.0)
			sprite_puente.modulate = Color(1, 1, 1, 1)
		else:
			var tw := create_tween()
			tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_property(sprite_puente, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(sprite_puente, "modulate", Color(1, 1, 1, 1), 0.25)
	else:
		cable_linea.default_color = Color(0.85, 0.2, 0.25, 0.85)
		label_estado_mundo.text = "Puente Retraído (%.1f µF / 18.0 µF)" % ceq
		label_estado_mundo.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		if instantaneo:
			sprite_puente.scale = Vector2(0.05, 1.0)
			sprite_puente.modulate = Color(1, 0.4, 0.4, 0.35)
		else:
			var tw := create_tween()
			tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_property(sprite_puente, "scale", Vector2(0.05, 1.0), 0.25)
			tw.parallel().tween_property(sprite_puente, "modulate", Color(1, 0.4, 0.4, 0.35), 0.25)

func _animar_flujo_circuito(delta: float) -> void:
	if not panel_abierto or panel_contenedor == null or not panel_contenedor.is_visible_in_tree():
		return
	var velocidad := 1.15 if en_paralelo else 0.42
	fase_energia = fmod(fase_energia + delta * velocidad, 1.0)
	var col_pulso := Color(0.4, 1.0, 0.72, 0.95) if en_paralelo else Color(1.0, 0.78, 0.3, 0.85)

	for i in range(pulsos_energia.size()):
		var p := pulsos_energia[i]
		p.color = col_pulso
		var t := fmod(fase_energia + float(i) / float(pulsos_energia.size()), 1.0)
		if en_paralelo:
			var y_rama := 44.0 if (i % 2 == 0) else 140.0
			var x_pos := lerpf(70.0, 464.0, t)
			var y_pos := 92.0
			if x_pos >= 120.0 and x_pos <= 416.0:
				y_pos = y_rama
			p.position = Vector2(x_pos - 4.0, y_pos - 4.0)
		else:
			var x_pos := lerpf(70.0, 464.0, t)
			p.position = Vector2(x_pos - 4.0, 92.0 - 4.0)

func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D or body.is_in_group("jugador") or body.name == "CharacterBody2D":
		jugador_cerca = true
		if not panel_abierto:
			label_prompt.visible = true

func _on_body_exited(body: Node) -> void:
	if body is CharacterBody2D or body.is_in_group("jugador") or body.name == "CharacterBody2D":
		jugador_cerca = false
		label_prompt.visible = false

func _process(delta: float) -> void:
	if area_terminal_ref and area_terminal_ref.monitoring:
		var detectado := false
		for b in area_terminal_ref.get_overlapping_bodies():
			if b is CharacterBody2D or b.is_in_group("jugador"):
				detectado = true
				break
		jugador_cerca = detectado
		if not panel_abierto and label_prompt:
			label_prompt.visible = jugador_cerca

	_animar_flujo_circuito(delta)

	var e_actual: bool = Input.is_physical_key_pressed(KEY_E) or Input.is_key_pressed(KEY_E)
	if e_actual and not _tecla_e_prev:
		if panel_abierto and panel_contenedor and panel_contenedor.is_visible_in_tree():
			_cerrar_panel()
		elif jugador_cerca and not panel_abierto:
			_abrir_panel()
	_tecla_e_prev = e_actual

func _abrir_panel() -> void:
	panel_abierto = true
	canvas_ui.visible = true
	_ocultar_textos_mundo(true)
	_congelar_jugador(true)
	get_tree().paused = true
	if get_viewport():
		get_viewport().gui_release_focus()
	_actualizar_calculo_y_estado(true)

func _confirmar_y_cerrar() -> void:
	_actualizar_calculo_y_estado(false)
	_cerrar_panel()

func _cerrar_panel() -> void:
	panel_abierto = false
	canvas_ui.visible = false
	if get_viewport():
		get_viewport().gui_release_focus()
	get_tree().paused = false
	_congelar_jugador(false)
	_ocultar_textos_mundo(false)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var kc: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode

	if panel_abierto and panel_contenedor != null and panel_contenedor.is_visible_in_tree():
		match kc:
			KEY_1, KEY_KP_1:
				en_paralelo = false
				_actualizar_calculo_y_estado(false)
				get_viewport().set_input_as_handled()
			KEY_2, KEY_KP_2:
				en_paralelo = true
				_actualizar_calculo_y_estado(false)
				get_viewport().set_input_as_handled()
			KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D:
				en_paralelo = not en_paralelo
				_actualizar_calculo_y_estado(false)
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_confirmar_y_cerrar()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE, KEY_E:
				_tecla_e_prev = true
				_cerrar_panel()
				get_viewport().set_input_as_handled()
	elif not panel_abierto and jugador_cerca and kc == KEY_E:
		_tecla_e_prev = true
		_abrir_panel()
		get_viewport().set_input_as_handled()
