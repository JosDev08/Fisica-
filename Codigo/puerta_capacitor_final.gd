extends Node2D

# ==============================================================================
# PUZZLE 3 — PUERTA FINAL HACIA ESCENA 3 (EQUILIBRIO DE CARGA Q = C · V)
# Escena: res://Escenas/escena_02.tscn -> Transición a res://Escenas/escena_03.tscn
# - PanelContainer oscuro casi sólido (alfa ~0.95) en CanvasLayer (layer = 10).
# - Cero superposición de textos: oculta todos los Labels flotantes del mundo.
# - Barra superior compacta: OBJETIVO: 120.0 µC vs ACTUAL: [valor] µC + ProgressBar.
# - Diagrama de circuito interactivo en tiempo real (Line2D + ColorRect) con
#   fuente V, capacitor C y cerrojo de la compuerta, flujo de energía animado
#   y operación corta debajo sin párrafos largos que regalen la respuesta.
# - Auditoría de teclas: [W/S] o [1]/[2] o Arriba/Abajo ajustan C,
#   [A/D] o Izquierda/Derecha ajustan V, Enter/Space confirman/activan, E/Esc cierran.
# ==============================================================================

const OPCIONES_C: Array[float] = [5.0, 10.0, 12.0, 15.0, 20.0]
const OPCIONES_V: Array[float] = [2.0, 4.0, 6.0, 8.0, 10.0, 12.0]
const ESCENA_SIGUIENTE: String = "res://Escenas/escena_03.tscn"

var carga_meta: float = 120.0
var carga_max_barra: float = 180.0
var indice_c: int = 1
var indice_v: int = 2
var puerta_abierta: bool = false
var jugador_cerca: bool = false
var panel_abierto: bool = false
var area_terminal_ref: Area2D = null
var _tecla_e_prev: bool = false
var fase_energia: float = 0.0

# Nodos del mundo
var cuerpo_puerta: StaticBody2D
var colision_puerta: CollisionShape2D
var sprite_puerta: Sprite2D
var cable_puerta: Line2D
var label_prompt: Label
var label_estado_puerta: Label
var area_portal_salida: Area2D

# Nodos de UI (CanvasLayer layer = 10)
var canvas_ui: CanvasLayer
var panel_contenedor: PanelContainer
var lbl_hud_estado: Label
var barra_q: ProgressBar
var lienzo_circuito: Control
var linea_cable_sup: Line2D
var linea_cable_inf: Line2D
var lbl_bloque_fuente: Label
var lbl_bloque_cap: Label
var lbl_placas_signos: Label
var nodo_cerrojo: ColorRect
var lbl_bloque_cerrojo: Label
var pulsos_energia: Array[ColorRect] = []
var lbl_formula: Label
var lbl_c_val: Label
var lbl_v_val: Label
var btn_confirmar: Button
var btn_avanzar_escena3: Button

func _ready() -> void:
	randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_asegurar_input_interactuar()
	_construir_escena_mundo()
	_construir_interfaz_ui()
	generar_nuevo_puzzle()

func generar_nuevo_puzzle() -> void:
	# Generación inversa: sortear primero C y V ganadores dentro de los límites de los controles
	var idx_c_ganador: int = randi_range(0, OPCIONES_C.size() - 1)
	var idx_v_ganador: int = randi_range(1, OPCIONES_V.size() - 1)
	carga_meta = OPCIONES_C[idx_c_ganador] * OPCIONES_V[idx_v_ganador]
	carga_max_barra = carga_meta * 1.5

	# Verificar con un bucle while que los controles nunca empiecen ya resueltos
	indice_c = randi_range(0, OPCIONES_C.size() - 1)
	indice_v = randi_range(0, OPCIONES_V.size() - 1)
	while is_equal_approx(_calcular_q(), carga_meta):
		indice_c = randi_range(0, OPCIONES_C.size() - 1)
		indice_v = randi_range(0, OPCIONES_V.size() - 1)

	if barra_q:
		barra_q.max_value = carga_max_barra
	_actualizar_circuito_carga()

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
	# 1. Cable entre terminal (-72, -32) y la compuerta (0, -64)
	cable_puerta = Line2D.new()
	cable_puerta.width = 5.0
	cable_puerta.default_color = Color(0.9, 0.25, 0.3, 0.9)
	cable_puerta.points = PackedVector2Array([
		Vector2(-72, -16),
		Vector2(-72, -4),
		Vector2(0, -4),
		Vector2(0, -64)
	])
	cable_puerta.z_index = -1
	add_child(cable_puerta)

	# 2. Compuerta física en Capa 5 Suelo (collision_layer = 16)
	cuerpo_puerta = StaticBody2D.new()
	cuerpo_puerta.name = "CompuertaCapacitor"
	cuerpo_puerta.position = Vector2(0, -64)
	cuerpo_puerta.collision_layer = 16 # Capa 5: Suelo
	cuerpo_puerta.collision_mask = 0
	add_child(cuerpo_puerta)

	colision_puerta = CollisionShape2D.new()
	var rect_puerta := RectangleShape2D.new()
	rect_puerta.size = Vector2(48, 128)
	colision_puerta.shape = rect_puerta
	cuerpo_puerta.add_child(colision_puerta)

	sprite_puerta = Sprite2D.new()
	var tex_puerta := load("res://assets/nivel_2/puerta_capacitor.svg") as Texture2D
	if tex_puerta:
		sprite_puerta.texture = tex_puerta
	cuerpo_puerta.add_child(sprite_puerta)

	# 3. Terminal del Circuito Final a la izquierda de la puerta (-72, -32)
	var area_terminal := Area2D.new()
	area_terminal_ref = area_terminal
	area_terminal.name = "TerminalPuertaFinal"
	area_terminal.position = Vector2(-72, -32)
	area_terminal.monitoring = true
	area_terminal.monitorable = true
	area_terminal.collision_layer = 0
	area_terminal.collision_mask = 1 # Capa 1: Jugador
	add_child(area_terminal)

	var col_term := CollisionShape2D.new()
	var rect_term := RectangleShape2D.new()
	rect_term.size = Vector2(120, 120)
	col_term.shape = rect_term
	area_terminal.add_child(col_term)

	var sprite_term := Sprite2D.new()
	var tex_term := load("res://assets/nivel_2/terminal_capacitor.svg") as Texture2D
	if tex_term:
		sprite_term.texture = tex_term
	area_terminal.add_child(sprite_term)

	var btn_mundo := Button.new()
	btn_mundo.flat = true
	btn_mundo.position = Vector2(-36, -36)
	btn_mundo.size = Vector2(120, 96)
	btn_mundo.focus_mode = Control.FOCUS_NONE
	btn_mundo.pressed.connect(_abrir_panel)
	area_terminal.add_child(btn_mundo)

	label_prompt = Label.new()
	label_prompt.text = "[E] Interactuar"
	label_prompt.position = Vector2(-80, -68)
	label_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_prompt.add_theme_font_size_override("font_size", 13)
	label_prompt.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	label_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label_prompt.add_theme_constant_override("outline_size", 3)
	label_prompt.visible = false
	label_prompt.add_to_group("texto_mundo_nivel2")
	area_terminal.add_child(label_prompt)

	label_estado_puerta = Label.new()
	label_estado_puerta.text = "🔒 Puerta Bloqueada (60.0 µC / 120.0 µC)"
	label_estado_puerta.position = Vector2(-130, -148)
	label_estado_puerta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_estado_puerta.add_theme_font_size_override("font_size", 11)
	label_estado_puerta.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	label_estado_puerta.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label_estado_puerta.add_theme_constant_override("outline_size", 3)
	label_estado_puerta.add_to_group("texto_mundo_nivel2")
	add_child(label_estado_puerta)

	# 4. Portal de transición hacia Escena 3 al cruzar la puerta abierta
	area_portal_salida = Area2D.new()
	area_portal_salida.position = Vector2(24, -48)
	area_portal_salida.collision_layer = 0
	area_portal_salida.collision_mask = 1
	add_child(area_portal_salida)

	var col_portal := CollisionShape2D.new()
	var rect_portal := RectangleShape2D.new()
	rect_portal.size = Vector2(48, 110)
	col_portal.shape = rect_portal
	area_portal_salida.add_child(col_portal)

	area_terminal.body_entered.connect(_on_body_entered)
	area_terminal.body_exited.connect(_on_body_exited)
	area_portal_salida.body_entered.connect(_on_portal_salida_entered)

func _crear_estilo_boton(activo: bool, color_activo: Color) -> StyleBoxFlat:
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
	st.set_content_margin_all(6)
	return st

func _construir_interfaz_ui() -> void:
	canvas_ui = CanvasLayer.new()
	canvas_ui.layer = 10
	canvas_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas_ui.visible = false
	add_child(canvas_ui)

	var fondo := ColorRect.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.01, 0.02, 0.05, 0.72)
	fondo.mouse_filter = Control.MOUSE_FILTER_PASS
	canvas_ui.add_child(fondo)

	# PanelContainer oscuro casi sólido (alfa ~0.95)
	panel_contenedor = PanelContainer.new()
	panel_contenedor.custom_minimum_size = Vector2(590, 396)
	panel_contenedor.set_anchors_preset(Control.PRESET_CENTER)
	panel_contenedor.offset_left = -295
	panel_contenedor.offset_top = -198
	panel_contenedor.offset_right = 295
	panel_contenedor.offset_bottom = 198
	panel_contenedor.mouse_filter = Control.MOUSE_FILTER_STOP
	panel_contenedor.focus_mode = Control.FOCUS_NONE
	var style_win := StyleBoxFlat.new()
	style_win.bg_color = Color(0.05, 0.08, 0.14, 0.95)
	style_win.border_color = Color(0.25, 0.9, 0.65)
	style_win.set_border_width_all(3)
	style_win.set_corner_radius_all(10)
	style_win.set_content_margin_all(16)
	panel_contenedor.add_theme_stylebox_override("panel", style_win)
	canvas_ui.add_child(panel_contenedor)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_theme_constant_override("separation", 8)
	panel_contenedor.add_child(vbox)

	# Barra superior compacta: OBJETIVO vs ACTUAL
	lbl_hud_estado = Label.new()
	lbl_hud_estado.text = "OBJETIVO: 120.0 µC   vs   ACTUAL: 60.0 µC"
	lbl_hud_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_hud_estado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_hud_estado.add_theme_font_size_override("font_size", 18)
	vbox.add_child(lbl_hud_estado)

	barra_q = ProgressBar.new()
	barra_q.min_value = 0.0
	barra_q.max_value = 240.0
	barra_q.custom_minimum_size = Vector2(540, 18)
	barra_q.show_percentage = false
	barra_q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra_q.focus_mode = Control.FOCUS_NONE
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.08, 0.12, 0.18, 0.95)
	sb_bg.set_corner_radius_all(5)
	barra_q.add_theme_stylebox_override("background", sb_bg)
	vbox.add_child(barra_q)

	# Diagrama de circuito interactivo en tiempo real (Line2D + ColorRect)
	lienzo_circuito = Control.new()
	lienzo_circuito.custom_minimum_size = Vector2(550, 152)
	lienzo_circuito.size = Vector2(550, 152)
	lienzo_circuito.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(lienzo_circuito)

	var fondo_diag := ColorRect.new()
	fondo_diag.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo_diag.color = Color(0.03, 0.05, 0.09, 0.98)
	fondo_diag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo_circuito.add_child(fondo_diag)

	linea_cable_sup = Line2D.new()
	linea_cable_sup.width = 4.0
	linea_cable_sup.points = PackedVector2Array([
		Vector2(82, 52), Vector2(195, 52),
		Vector2(355, 52), Vector2(455, 52)
	])
	lienzo_circuito.add_child(linea_cable_sup)

	linea_cable_inf = Line2D.new()
	linea_cable_inf.width = 4.0
	linea_cable_inf.points = PackedVector2Array([
		Vector2(455, 100), Vector2(82, 100)
	])
	lienzo_circuito.add_child(linea_cable_inf)

	var nodo_fuente := ColorRect.new()
	nodo_fuente.position = Vector2(18, 40)
	nodo_fuente.size = Vector2(68, 72)
	nodo_fuente.color = Color(0.11, 0.2, 0.34, 1.0)
	nodo_fuente.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo_circuito.add_child(nodo_fuente)

	lbl_bloque_fuente = Label.new()
	lbl_bloque_fuente.position = Vector2(18, 42)
	lbl_bloque_fuente.size = Vector2(68, 68)
	lbl_bloque_fuente.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_bloque_fuente.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_bloque_fuente.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_bloque_fuente.add_theme_font_size_override("font_size", 11)
	lbl_bloque_fuente.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	lienzo_circuito.add_child(lbl_bloque_fuente)

	var caja_cap := ColorRect.new()
	caja_cap.position = Vector2(195, 20)
	caja_cap.size = Vector2(160, 112)
	caja_cap.color = Color(0.08, 0.13, 0.22, 0.98)
	caja_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo_circuito.add_child(caja_cap)

	var placa_izq := ColorRect.new()
	placa_izq.position = Vector2(215, 32)
	placa_izq.size = Vector2(6, 56)
	placa_izq.color = Color(0.35, 0.9, 1.0)
	placa_izq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo_circuito.add_child(placa_izq)

	var dielectrico := ColorRect.new()
	dielectrico.position = Vector2(223, 36)
	dielectrico.size = Vector2(14, 48)
	dielectrico.color = Color(0.25, 0.85, 0.65, 0.45)
	dielectrico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo_circuito.add_child(dielectrico)

	var placa_der := ColorRect.new()
	placa_der.position = Vector2(239, 32)
	placa_der.size = Vector2(6, 56)
	placa_der.color = Color(0.35, 0.9, 1.0)
	placa_der.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo_circuito.add_child(placa_der)

	lbl_bloque_cap = Label.new()
	lbl_bloque_cap.position = Vector2(250, 26)
	lbl_bloque_cap.size = Vector2(100, 62)
	lbl_bloque_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_bloque_cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_bloque_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_bloque_cap.add_theme_font_size_override("font_size", 12)
	lienzo_circuito.add_child(lbl_bloque_cap)

	lbl_placas_signos = Label.new()
	lbl_placas_signos.position = Vector2(202, 92)
	lbl_placas_signos.size = Vector2(146, 34)
	lbl_placas_signos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_placas_signos.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_placas_signos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_placas_signos.add_theme_font_size_override("font_size", 11)
	lbl_placas_signos.add_theme_color_override("font_color", Color(0.55, 0.92, 1.0))
	lienzo_circuito.add_child(lbl_placas_signos)

	nodo_cerrojo = ColorRect.new()
	nodo_cerrojo.position = Vector2(455, 40)
	nodo_cerrojo.size = Vector2(76, 72)
	nodo_cerrojo.color = Color(0.14, 0.2, 0.3, 1.0)
	nodo_cerrojo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo_circuito.add_child(nodo_cerrojo)

	lbl_bloque_cerrojo = Label.new()
	lbl_bloque_cerrojo.position = Vector2(455, 42)
	lbl_bloque_cerrojo.size = Vector2(76, 68)
	lbl_bloque_cerrojo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_bloque_cerrojo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_bloque_cerrojo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_bloque_cerrojo.add_theme_font_size_override("font_size", 10)
	lienzo_circuito.add_child(lbl_bloque_cerrojo)

	for i in range(6):
		var p := ColorRect.new()
		p.size = Vector2(8, 8)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lienzo_circuito.add_child(p)
		pulsos_energia.append(p)

	# Operación corta debajo del diagrama
	lbl_formula = Label.new()
	lbl_formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_formula.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_formula.add_theme_font_size_override("font_size", 15)
	vbox.add_child(lbl_formula)

	# Controles de C y V
	var hb_cv := HBoxContainer.new()
	hb_cv.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_cv.add_theme_constant_override("separation", 8)
	vbox.add_child(hb_cv)

	var btn_c_menos := Button.new()
	btn_c_menos.text = "◀ -C [1 / S]"
	btn_c_menos.custom_minimum_size = Vector2(92, 34)
	btn_c_menos.focus_mode = Control.FOCUS_NONE
	btn_c_menos.pressed.connect(func():
		indice_c = max(0, indice_c - 1)
		_actualizar_circuito_carga()
	)
	hb_cv.add_child(btn_c_menos)

	lbl_c_val = Label.new()
	lbl_c_val.custom_minimum_size = Vector2(82, 34)
	lbl_c_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_c_val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_c_val.add_theme_font_size_override("font_size", 14)
	lbl_c_val.add_theme_color_override("font_color", Color(0.35, 0.9, 1.0))
	hb_cv.add_child(lbl_c_val)

	var btn_c_mas := Button.new()
	btn_c_mas.text = "[2 / W] +C ▶"
	btn_c_mas.custom_minimum_size = Vector2(92, 34)
	btn_c_mas.focus_mode = Control.FOCUS_NONE
	btn_c_mas.pressed.connect(func():
		indice_c = min(OPCIONES_C.size() - 1, indice_c + 1)
		_actualizar_circuito_carga()
	)
	hb_cv.add_child(btn_c_mas)

	var btn_v_menos := Button.new()
	btn_v_menos.text = "◀ -V [A / Izq]"
	btn_v_menos.custom_minimum_size = Vector2(96, 34)
	btn_v_menos.focus_mode = Control.FOCUS_NONE
	btn_v_menos.pressed.connect(func():
		indice_v = max(0, indice_v - 1)
		_actualizar_circuito_carga()
	)
	hb_cv.add_child(btn_v_menos)

	lbl_v_val = Label.new()
	lbl_v_val.custom_minimum_size = Vector2(76, 34)
	lbl_v_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_v_val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_v_val.add_theme_font_size_override("font_size", 14)
	lbl_v_val.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	hb_cv.add_child(lbl_v_val)

	var btn_v_mas := Button.new()
	btn_v_mas.text = "[D / Der] +V ▶"
	btn_v_mas.custom_minimum_size = Vector2(96, 34)
	btn_v_mas.focus_mode = Control.FOCUS_NONE
	btn_v_mas.pressed.connect(func():
		indice_v = min(OPCIONES_V.size() - 1, indice_v + 1)
		_actualizar_circuito_carga()
	)
	hb_cv.add_child(btn_v_mas)

	# Botones de Confirmar, Avanzar y Cerrar
	var hb_acc := HBoxContainer.new()
	hb_acc.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_acc.add_theme_constant_override("separation", 10)
	vbox.add_child(hb_acc)

	btn_confirmar = Button.new()
	btn_confirmar.text = "CONFIRMAR [Enter / Space]"
	btn_confirmar.custom_minimum_size = Vector2(180, 36)
	btn_confirmar.focus_mode = Control.FOCUS_NONE
	btn_confirmar.pressed.connect(_cerrar_panel)
	hb_acc.add_child(btn_confirmar)

	btn_avanzar_escena3 = Button.new()
	btn_avanzar_escena3.text = "IR A ESCENA 3 ▶"
	btn_avanzar_escena3.custom_minimum_size = Vector2(150, 36)
	btn_avanzar_escena3.focus_mode = Control.FOCUS_NONE
	btn_avanzar_escena3.disabled = true
	btn_avanzar_escena3.pressed.connect(_ir_a_escena_3)
	hb_acc.add_child(btn_avanzar_escena3)

	var btn_cerrar := Button.new()
	btn_cerrar.text = "✕ [E / Esc]"
	btn_cerrar.custom_minimum_size = Vector2(80, 36)
	btn_cerrar.focus_mode = Control.FOCUS_NONE
	btn_cerrar.pressed.connect(_cerrar_panel)
	hb_acc.add_child(btn_cerrar)

func _calcular_q() -> float:
	return OPCIONES_C[indice_c] * OPCIONES_V[indice_v]

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
	if label_estado_puerta:
		label_estado_puerta.visible = not ocultar

func _congelar_jugador(congelar: bool) -> void:
	if not get_tree():
		return
	var root := get_tree().current_scene
	if not root:
		return
	for child in root.get_children():
		if child is CharacterBody2D:
			child.set_physics_process(not congelar)

func _actualizar_circuito_carga() -> void:
	var c: float = OPCIONES_C[indice_c]
	var v: float = OPCIONES_V[indice_v]
	var q: float = _calcular_q()
	puerta_abierta = is_equal_approx(q, carga_meta)

	if lbl_hud_estado:
		var col_hud: Color
		if puerta_abierta:
			col_hud = Color(0.2, 1.0, 0.55)
		elif q < carga_meta:
			col_hud = Color(1.0, 0.68, 0.25)
		else:
			col_hud = Color(1.0, 0.38, 0.38)

		lbl_hud_estado.text = "OBJETIVO: %.1f µC   vs   ACTUAL: %.1f µC" % [carga_meta, q]
		lbl_hud_estado.add_theme_color_override("font_color", col_hud)

		barra_q.max_value = carga_max_barra
		barra_q.value = clampf(q, 0.0, carga_max_barra)
		var sb_fill := StyleBoxFlat.new()
		sb_fill.bg_color = col_hud
		sb_fill.set_corner_radius_all(5)
		barra_q.add_theme_stylebox_override("fill", sb_fill)

		lbl_c_val.text = "C = %.0f µF" % c
		lbl_v_val.text = "V = %.0f V" % v
		lbl_bloque_fuente.text = "FUENTE\n%.0f V" % v
		lbl_bloque_cap.text = "CAPACITOR\nC = %.0f µF" % c

		var num_signos: int = clampi(int(round(q / max(carga_meta / 4.0, 10.0))), 1, 6)
		lbl_placas_signos.text = "[+%s | -%s]" % ["+".repeat(num_signos), "-".repeat(num_signos)]

		lbl_bloque_cerrojo.text = "PUERTA\n%s" % ("ABIERTA" if puerta_abierta else "%.1f µC" % carga_meta)
		lbl_bloque_cerrojo.add_theme_color_override("font_color", col_hud)
		nodo_cerrojo.color = Color(0.1, 0.32, 0.22, 1.0) if puerta_abierta else Color(0.24, 0.14, 0.14, 1.0)

		linea_cable_sup.default_color = col_hud
		linea_cable_inf.default_color = col_hud

		lbl_formula.text = "Q = C × V = %.0f µF × %.0f V = %.1f µC" % [c, v, q]
		lbl_formula.add_theme_color_override("font_color", col_hud)

		btn_avanzar_escena3.disabled = not puerta_abierta
		btn_confirmar.add_theme_stylebox_override("normal", _crear_estilo_boton(puerta_abierta, Color(0.25, 0.95, 0.6)))

	# Actualizar compuerta física en el mundo
	colision_puerta.set_deferred("disabled", puerta_abierta)
	if puerta_abierta:
		cable_puerta.default_color = Color(0.2, 0.95, 0.55, 1.0)
		label_estado_puerta.text = "🔓 PUERTA ABIERTA (%.1f µC)" % carga_meta
		label_estado_puerta.add_theme_color_override("font_color", Color(0.25, 1.0, 0.55))
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(sprite_puerta, "position", Vector2(0, -110), 0.4)
		tw.parallel().tween_property(sprite_puerta, "modulate", Color(0.4, 1.0, 0.7, 0.45), 0.4)
	else:
		cable_puerta.default_color = Color(0.9, 0.25, 0.3, 0.9)
		label_estado_puerta.text = "🔒 Puerta Bloqueada (%.1f µC / %.1f µC)" % [q, carga_meta]
		label_estado_puerta.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		sprite_puerta.position = Vector2.ZERO
		sprite_puerta.modulate = Color(1, 1, 1, 1)

func _animar_flujo_circuito(delta: float) -> void:
	if not panel_abierto or panel_contenedor == null or not panel_contenedor.is_visible_in_tree():
		return
	var velocidad := 1.15 if puerta_abierta else 0.4
	fase_energia = fmod(fase_energia + delta * velocidad, 1.0)
	var col_pulso := Color(0.4, 1.0, 0.72, 0.95) if puerta_abierta else Color(1.0, 0.78, 0.3, 0.85)

	for i in range(pulsos_energia.size()):
		var p := pulsos_energia[i]
		p.color = col_pulso
		var t := fmod(fase_energia + float(i) / float(pulsos_energia.size()), 1.0)
		var x_pos := lerpf(86.0, 450.0, t)
		var y_pos := 52.0 if (i % 2 == 0) else 100.0
		p.position = Vector2(x_pos - 4.0, y_pos - 4.0)

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

func _on_portal_salida_entered(body: Node) -> void:
	if puerta_abierta and (body is CharacterBody2D or body.is_in_group("jugador") or body.name == "CharacterBody2D"):
		_ir_a_escena_3()

func _ir_a_escena_3() -> void:
	panel_abierto = false
	if get_viewport():
		get_viewport().gui_release_focus()
	get_tree().paused = false
	_congelar_jugador(false)
	if ResourceLoader.exists(ESCENA_SIGUIENTE):
		get_tree().change_scene_to_file(ESCENA_SIGUIENTE)

func _abrir_panel() -> void:
	panel_abierto = true
	canvas_ui.visible = true
	_ocultar_textos_mundo(true)
	_congelar_jugador(true)
	get_tree().paused = true
	if get_viewport():
		get_viewport().gui_release_focus()
	_actualizar_circuito_carga()

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
			KEY_1, KEY_KP_1, KEY_S, KEY_DOWN:
				indice_c = max(0, indice_c - 1)
				_actualizar_circuito_carga()
				get_viewport().set_input_as_handled()
			KEY_2, KEY_KP_2, KEY_W, KEY_UP:
				indice_c = min(OPCIONES_C.size() - 1, indice_c + 1)
				_actualizar_circuito_carga()
				get_viewport().set_input_as_handled()
			KEY_A, KEY_LEFT:
				indice_v = max(0, indice_v - 1)
				_actualizar_circuito_carga()
				get_viewport().set_input_as_handled()
			KEY_D, KEY_RIGHT:
				indice_v = min(OPCIONES_V.size() - 1, indice_v + 1)
				_actualizar_circuito_carga()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_cerrar_panel()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE, KEY_E:
				_tecla_e_prev = true
				_cerrar_panel()
				get_viewport().set_input_as_handled()
	elif not panel_abierto and jugador_cerca and kc == KEY_E:
		_tecla_e_prev = true
		_abrir_panel()
		get_viewport().set_input_as_handled()
