extends Node2D

# ==============================================================================
# PUZZLE 2 — PLATAFORMA ELEVADORA POR ENERGÍA ALMACENADA (U = ½ · C · V²)
# Escena: res://Escenas/escena_02.tscn
# - PanelContainer oscuro casi sólido (alfa ~0.95) en CanvasLayer (layer = 10).
# - Cero superposición de textos: oculta todos los Labels flotantes del mundo.
# - Barra superior compacta: OBJETIVO: 144.0 J vs ACTUAL: [valor] J + ProgressBar.
# - Diagrama de circuito interactivo en tiempo real (Line2D + ColorRect) con
#   fuente V, capacitor con dieléctrico dinámico (C = κ · C0) y elevador.
# - Auditoría de teclas: [1]/[2]/[3] eligen dieléctrico, Flechas Izq/Der (A/D)
#   ajustan V, Enter/Space confirman/activan, E/Esc cierran el panel.
# ==============================================================================

const C0_BASE: float = 2.0
const ENERGIA_META: float = 144.0
const NOMBRES_DIELECTRICO: Array[String] = [
	"AIRE (κ=1)",
	"VIDRIO (κ=2)",
	"CERÁMICA (κ=4)"
]
const CONSTANTES_K: Array[float] = [1.0, 2.0, 4.0]
const COLORES_DIELECTRICO: Array[Color] = [
	Color(0.35, 0.78, 1.0),
	Color(0.55, 0.92, 0.75),
	Color(1.0, 0.78, 0.3)
]

var indice_dielectrico: int = 0 # Inicia en Aire (κ = 1 -> C = 2.0 F)
var voltaje: float = 4.0        # Inicia en 4 V -> U = 0.5 * 2 * 16 = 16.0 J
var elevador_activo: bool = false
var jugador_cerca: bool = false
var panel_abierto: bool = false
var area_terminal_ref: Area2D = null
var _tecla_e_prev: bool = false
var tiempo_movimiento: float = 0.0
var fase_energia: float = 0.0

# Coordenadas del elevador en el mundo (suelo bajo y=128, plataforma alta y=-48)
const ELEVADOR_X: float = 1344.0
const ELEVADOR_Y_BAJO: float = 122.0
const ELEVADOR_Y_ALTO: float = -52.0

# Nodos del mundo
var cuerpo_elevador: AnimatableBody2D
var sprite_elevador: Sprite2D
var cuerpo_barrera: StaticBody2D
var colision_barrera: CollisionShape2D
var linea_barrera: Line2D
var cable_energia: Line2D
var label_prompt: Label
var label_estado_mundo: Label

# Nodos de UI (CanvasLayer layer = 10)
var canvas_ui: CanvasLayer
var panel_contenedor: PanelContainer
var lbl_hud_estado: Label
var barra_energia: ProgressBar
var lienzo_circuito: Control
var linea_cable_sup: Line2D
var linea_cable_inf: Line2D
var rect_dielectrico: ColorRect
var lbl_bloque_fuente: Label
var lbl_bloque_cap: Label
var lbl_bloque_motor: Label
var nodo_motor: ColorRect
var pulsos_energia: Array[ColorRect] = []
var lbl_formula: Label
var botones_dielectrico: Array[Button] = []
var lbl_v_actual: Label
var btn_confirmar: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_asegurar_input_interactuar()
	_construir_escena_mundo()
	_construir_interfaz_ui()
	_actualizar_estado_energia()

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
	# 1. Riel vertical y cable de energía desde la terminal (x=1275, y=96) al elevador (x=1344)
	var riel_guia := Line2D.new()
	riel_guia.width = 4.0
	riel_guia.default_color = Color(0.2, 0.3, 0.45, 0.7)
	riel_guia.points = PackedVector2Array([
		Vector2(ELEVADOR_X, ELEVADOR_Y_BAJO + 10),
		Vector2(ELEVADOR_X, ELEVADOR_Y_ALTO - 8)
	])
	riel_guia.z_index = -2
	add_child(riel_guia)

	cable_energia = Line2D.new()
	cable_energia.width = 5.0
	cable_energia.default_color = Color(0.85, 0.25, 0.25, 0.85)
	cable_energia.points = PackedVector2Array([
		Vector2(1275, 118),
		Vector2(ELEVADOR_X, 118),
		Vector2(ELEVADOR_X, ELEVADOR_Y_ALTO)
	])
	cable_energia.z_index = -1
	add_child(cable_energia)

	# 2. Plataforma Elevadora (AnimatableBody2D en Capa 5 Suelo: collision_layer = 16)
	cuerpo_elevador = AnimatableBody2D.new()
	cuerpo_elevador.name = "PlataformaElevadora"
	cuerpo_elevador.position = Vector2(ELEVADOR_X, ELEVADOR_Y_BAJO)
	cuerpo_elevador.collision_layer = 16 # Capa 5: Suelo
	cuerpo_elevador.collision_mask = 0
	cuerpo_elevador.sync_to_physics = true
	add_child(cuerpo_elevador)

	var col_elev := CollisionShape2D.new()
	var rect_elev := RectangleShape2D.new()
	rect_elev.size = Vector2(92, 18)
	col_elev.shape = rect_elev
	cuerpo_elevador.add_child(col_elev)

	sprite_elevador = Sprite2D.new()
	var tex_elev := load("res://assets/nivel_2/plataforma_elevadora.svg") as Texture2D
	if tex_elev:
		sprite_elevador.texture = tex_elev
	cuerpo_elevador.add_child(sprite_elevador)

	# 3. Barrera dieléctrica inferior en x = 1396
	cuerpo_barrera = StaticBody2D.new()
	cuerpo_barrera.name = "BarreraDielectrica"
	cuerpo_barrera.position = Vector2(1396, 42)
	cuerpo_barrera.collision_layer = 16 # Capa 5: Suelo
	cuerpo_barrera.collision_mask = 0
	add_child(cuerpo_barrera)

	colision_barrera = CollisionShape2D.new()
	var rect_barrera := RectangleShape2D.new()
	rect_barrera.size = Vector2(16, 168)
	colision_barrera.shape = rect_barrera
	cuerpo_barrera.add_child(colision_barrera)

	linea_barrera = Line2D.new()
	linea_barrera.width = 8.0
	linea_barrera.default_color = Color(1.0, 0.25, 0.35, 0.85)
	linea_barrera.points = PackedVector2Array([Vector2(0, -84), Vector2(0, 84)])
	cuerpo_barrera.add_child(linea_barrera)

	# 4. Terminal Interactiva (Area2D) en el piso inferior (x = 1275, y = 96)
	var area_terminal := Area2D.new()
	area_terminal_ref = area_terminal
	area_terminal.name = "TerminalElevador"
	area_terminal.position = Vector2(1275, 96)
	area_terminal.monitoring = true
	area_terminal.monitorable = true
	area_terminal.collision_layer = 0
	area_terminal.collision_mask = 1 # Capa 1: Jugador
	add_child(area_terminal)

	var col_term := CollisionShape2D.new()
	var shape_term := RectangleShape2D.new()
	shape_term.size = Vector2(120, 120)
	col_term.shape = shape_term
	area_terminal.add_child(col_term)

	var sprite_term := Sprite2D.new()
	var tex_term := load("res://assets/nivel_2/terminal_capacitor.svg") as Texture2D
	if tex_term:
		sprite_term.texture = tex_term
	area_terminal.add_child(sprite_term)

	var btn_mundo := Button.new()
	btn_mundo.flat = true
	btn_mundo.position = Vector2(-32, -32)
	btn_mundo.size = Vector2(64, 64)
	btn_mundo.focus_mode = Control.FOCUS_NONE
	btn_mundo.pressed.connect(_abrir_panel)
	area_terminal.add_child(btn_mundo)

	label_prompt = Label.new()
	label_prompt.text = "[E] Interactuar"
	label_prompt.position = Vector2(-80, -60)
	label_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_prompt.add_theme_font_size_override("font_size", 13)
	label_prompt.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	label_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label_prompt.add_theme_constant_override("outline_size", 3)
	label_prompt.visible = false
	label_prompt.add_to_group("texto_mundo_nivel2")
	area_terminal.add_child(label_prompt)

	label_estado_mundo = Label.new()
	label_estado_mundo.text = "Elevador Detenido (16.0 J / 144.0 J)"
	label_estado_mundo.position = Vector2(1210, 14)
	label_estado_mundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_estado_mundo.add_theme_font_size_override("font_size", 11)
	label_estado_mundo.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	label_estado_mundo.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label_estado_mundo.add_theme_constant_override("outline_size", 3)
	label_estado_mundo.add_to_group("texto_mundo_nivel2")
	add_child(label_estado_mundo)

	area_terminal.body_entered.connect(_on_body_entered)
	area_terminal.body_exited.connect(_on_body_exited)

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
	style_win.border_color = Color(0.96, 0.68, 0.18)
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
	lbl_hud_estado.text = "OBJETIVO: 144.0 J   vs   ACTUAL: 16.0 J"
	lbl_hud_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_hud_estado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_hud_estado.add_theme_font_size_override("font_size", 18)
	vbox.add_child(lbl_hud_estado)

	barra_energia = ProgressBar.new()
	barra_energia.min_value = 0.0
	barra_energia.max_value = 200.0
	barra_energia.custom_minimum_size = Vector2(540, 18)
	barra_energia.show_percentage = false
	barra_energia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra_energia.focus_mode = Control.FOCUS_NONE
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.08, 0.12, 0.18, 0.95)
	sb_bg.set_corner_radius_all(5)
	barra_energia.add_theme_stylebox_override("background", sb_bg)
	vbox.add_child(barra_energia)

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
		Vector2(82, 52), Vector2(215, 52),
		Vector2(335, 52), Vector2(455, 52)
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

	# Bloque visual del capacitor con placas y dieléctrico
	var caja_cap := ColorRect.new()
	caja_cap.position = Vector2(205, 22)
	caja_cap.size = Vector2(140, 108)
	caja_cap.color = Color(0.08, 0.13, 0.22, 0.98)
	caja_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo_circuito.add_child(caja_cap)

	var placa_izq := ColorRect.new()
	placa_izq.position = Vector2(222, 34)
	placa_izq.size = Vector2(6, 56)
	placa_izq.color = Color(0.9, 0.96, 1.0)
	placa_izq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo_circuito.add_child(placa_izq)

	rect_dielectrico = ColorRect.new()
	rect_dielectrico.position = Vector2(230, 38)
	rect_dielectrico.size = Vector2(18, 48)
	rect_dielectrico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo_circuito.add_child(rect_dielectrico)

	var placa_der := ColorRect.new()
	placa_der.position = Vector2(250, 34)
	placa_der.size = Vector2(6, 56)
	placa_der.color = Color(0.9, 0.96, 1.0)
	placa_der.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo_circuito.add_child(placa_der)

	lbl_bloque_cap = Label.new()
	lbl_bloque_cap.position = Vector2(260, 28)
	lbl_bloque_cap.size = Vector2(80, 96)
	lbl_bloque_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_bloque_cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_bloque_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_bloque_cap.add_theme_font_size_override("font_size", 11)
	lienzo_circuito.add_child(lbl_bloque_cap)

	nodo_motor = ColorRect.new()
	nodo_motor.position = Vector2(455, 40)
	nodo_motor.size = Vector2(76, 72)
	nodo_motor.color = Color(0.14, 0.2, 0.3, 1.0)
	nodo_motor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo_circuito.add_child(nodo_motor)

	lbl_bloque_motor = Label.new()
	lbl_bloque_motor.position = Vector2(455, 42)
	lbl_bloque_motor.size = Vector2(76, 68)
	lbl_bloque_motor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_bloque_motor.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_bloque_motor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_bloque_motor.add_theme_font_size_override("font_size", 10)
	lienzo_circuito.add_child(lbl_bloque_motor)

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
	lbl_formula.add_theme_font_size_override("font_size", 14)
	vbox.add_child(lbl_formula)

	# Selector visual de Dieléctrico ([1], [2], [3])
	var hb_diel := HBoxContainer.new()
	hb_diel.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_diel.add_theme_constant_override("separation", 8)
	vbox.add_child(hb_diel)

	botones_dielectrico.clear()
	for i in range(NOMBRES_DIELECTRICO.size()):
		var btn := Button.new()
		btn.text = "[%d] %s → %.0f F" % [i + 1, NOMBRES_DIELECTRICO[i], CONSTANTES_K[i] * C0_BASE]
		btn.custom_minimum_size = Vector2(174, 34)
		btn.focus_mode = Control.FOCUS_NONE
		var idx := i
		btn.pressed.connect(func():
			indice_dielectrico = idx
			_actualizar_estado_energia()
		)
		hb_diel.add_child(btn)
		botones_dielectrico.append(btn)

	# Controles de Voltaje y Confirmar/Cerrar
	var hb_ctrl := HBoxContainer.new()
	hb_ctrl.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_ctrl.add_theme_constant_override("separation", 8)
	vbox.add_child(hb_ctrl)

	var btn_v_menos := Button.new()
	btn_v_menos.text = "◀ -2 V [A / Izq]"
	btn_v_menos.custom_minimum_size = Vector2(124, 36)
	btn_v_menos.focus_mode = Control.FOCUS_NONE
	btn_v_menos.pressed.connect(func():
		voltaje = max(0.0, voltaje - 2.0)
		_actualizar_estado_energia()
	)
	hb_ctrl.add_child(btn_v_menos)

	lbl_v_actual = Label.new()
	lbl_v_actual.custom_minimum_size = Vector2(88, 36)
	lbl_v_actual.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_v_actual.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_v_actual.add_theme_font_size_override("font_size", 16)
	lbl_v_actual.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	hb_ctrl.add_child(lbl_v_actual)

	var btn_v_mas := Button.new()
	btn_v_mas.text = "[D / Der] +2 V ▶"
	btn_v_mas.custom_minimum_size = Vector2(124, 36)
	btn_v_mas.focus_mode = Control.FOCUS_NONE
	btn_v_mas.pressed.connect(func():
		voltaje = min(10.0, voltaje + 2.0)
		_actualizar_estado_energia()
	)
	hb_ctrl.add_child(btn_v_mas)

	btn_confirmar = Button.new()
	btn_confirmar.text = "ACTIVAR [Enter / Space]"
	btn_confirmar.custom_minimum_size = Vector2(142, 36)
	btn_confirmar.focus_mode = Control.FOCUS_NONE
	btn_confirmar.pressed.connect(_cerrar_panel)
	hb_ctrl.add_child(btn_confirmar)

	var btn_cerrar := Button.new()
	btn_cerrar.text = "✕ [E / Esc]"
	btn_cerrar.custom_minimum_size = Vector2(68, 36)
	btn_cerrar.focus_mode = Control.FOCUS_NONE
	btn_cerrar.pressed.connect(_cerrar_panel)
	hb_ctrl.add_child(btn_cerrar)

func _calcular_c() -> float:
	return CONSTANTES_K[indice_dielectrico] * C0_BASE

func _calcular_u() -> float:
	var c := _calcular_c()
	return 0.5 * c * voltaje * voltaje

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

func _actualizar_estado_energia() -> void:
	var k := CONSTANTES_K[indice_dielectrico]
	var c := _calcular_c()
	var u := _calcular_u()
	elevador_activo = (u >= ENERGIA_META and u <= 200.0)

	if lbl_hud_estado:
		var col_hud := Color(0.2, 1.0, 0.55) if elevador_activo else Color(1.0, 0.68, 0.25)
		lbl_hud_estado.text = "OBJETIVO: 144.0 J   vs   ACTUAL: %.1f J" % u
		lbl_hud_estado.add_theme_color_override("font_color", col_hud)

		barra_energia.value = min(u, 200.0)
		var sb_fill := StyleBoxFlat.new()
		sb_fill.bg_color = Color(0.18, 0.98, 0.52) if elevador_activo else Color(0.95, 0.55, 0.2)
		sb_fill.set_corner_radius_all(5)
		barra_energia.add_theme_stylebox_override("fill", sb_fill)

		lbl_v_actual.text = "V = %.0f V" % voltaje
		lbl_bloque_fuente.text = "FUENTE\n%.0f V" % voltaje
		lbl_bloque_cap.text = "C = %.0f F\n(κ = %.0f)" % [c, k]
		lbl_bloque_motor.text = "ELEVADOR\n%s" % ("ACTIVO" if elevador_activo else "144.0 J")
		lbl_bloque_motor.add_theme_color_override("font_color", Color(0.25, 1.0, 0.58) if elevador_activo else Color(1.0, 0.72, 0.35))
		nodo_motor.color = Color(0.1, 0.32, 0.22, 1.0) if elevador_activo else Color(0.24, 0.14, 0.14, 1.0)

		var col_diel := COLORES_DIELECTRICO[indice_dielectrico]
		rect_dielectrico.color = Color(col_diel.r, col_diel.g, col_diel.b, 0.75)

		var col_cable := Color(0.2, 0.98, 0.55, 1.0) if elevador_activo else Color(0.98, 0.65, 0.22, 0.92)
		linea_cable_sup.default_color = col_cable
		linea_cable_inf.default_color = col_cable

		lbl_formula.text = "U = ½ · C · V² = 0.5 × %.0f × (%.0f)² = %.1f J" % [c, voltaje, u]
		lbl_formula.add_theme_color_override("font_color", col_hud)

		for i in range(botones_dielectrico.size()):
			var b := botones_dielectrico[i]
			var act := (i == indice_dielectrico)
			b.add_theme_stylebox_override("normal", _crear_estilo_boton(act, COLORES_DIELECTRICO[i]))
			b.add_theme_stylebox_override("hover", _crear_estilo_boton(act, COLORES_DIELECTRICO[i].lightened(0.15)))
			b.add_theme_stylebox_override("pressed", _crear_estilo_boton(act, COLORES_DIELECTRICO[i]))

		btn_confirmar.add_theme_stylebox_override("normal", _crear_estilo_boton(elevador_activo, Color(0.25, 0.95, 0.6)))

	# Actualizar barrera y cables en el mundo
	colision_barrera.set_deferred("disabled", elevador_activo)
	linea_barrera.visible = not elevador_activo
	if elevador_activo:
		cable_energia.default_color = Color(0.2, 0.95, 0.55, 1.0)
		sprite_elevador.modulate = Color(1.0, 1.0, 1.0, 1.0)
		label_estado_mundo.text = "⚡ ELEVADOR ACTIVO (%.1f J)" % u
		label_estado_mundo.add_theme_color_override("font_color", Color(0.25, 1.0, 0.55))
	else:
		cable_energia.default_color = Color(0.85, 0.25, 0.25, 0.85)
		sprite_elevador.modulate = Color(0.65, 0.65, 0.75, 1.0)
		label_estado_mundo.text = "Elevador Detenido (%.1f J / 144.0 J)" % u
		label_estado_mundo.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))

func _animar_flujo_circuito(delta: float) -> void:
	if not panel_abierto or panel_contenedor == null or not panel_contenedor.is_visible_in_tree():
		return
	var velocidad := 1.15 if elevador_activo else 0.38
	fase_energia = fmod(fase_energia + delta * velocidad, 1.0)
	var col_pulso := Color(0.4, 1.0, 0.72, 0.95) if elevador_activo else Color(1.0, 0.78, 0.3, 0.85)

	for i in range(pulsos_energia.size()):
		var p := pulsos_energia[i]
		p.color = col_pulso
		var t := fmod(fase_energia + float(i) / float(pulsos_energia.size()), 1.0)
		var x_pos := lerpf(86.0, 450.0, t)
		var y_pos := 52.0 if (i % 2 == 0) else 100.0
		p.position = Vector2(x_pos - 4.0, y_pos - 4.0)

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if elevador_activo:
		tiempo_movimiento += delta * 1.35
		var factor: float = clamp(0.5 - 0.65 * cos(tiempo_movimiento), 0.0, 1.0)
		var nuevo_y: float = lerpf(ELEVADOR_Y_BAJO, ELEVADOR_Y_ALTO, factor)
		cuerpo_elevador.position = Vector2(ELEVADOR_X, nuevo_y)
	else:
		cuerpo_elevador.position = cuerpo_elevador.position.move_toward(Vector2(ELEVADOR_X, ELEVADOR_Y_BAJO), 120.0 * delta)

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
	_actualizar_estado_energia()

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
				indice_dielectrico = 0
				_actualizar_estado_energia()
				get_viewport().set_input_as_handled()
			KEY_2, KEY_KP_2:
				indice_dielectrico = 1
				_actualizar_estado_energia()
				get_viewport().set_input_as_handled()
			KEY_3, KEY_KP_3:
				indice_dielectrico = 2
				_actualizar_estado_energia()
				get_viewport().set_input_as_handled()
			KEY_A, KEY_LEFT:
				voltaje = max(0.0, voltaje - 2.0)
				_actualizar_estado_energia()
				get_viewport().set_input_as_handled()
			KEY_D, KEY_RIGHT:
				voltaje = min(10.0, voltaje + 2.0)
				_actualizar_estado_energia()
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
