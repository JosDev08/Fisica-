extends Node2D

# ==============================================================================
# PUZZLE 1 (NIVEL 1): ELECTROSTÁTICA — LEY DE COULOMB (ATRACCIÓN Y REPULSIÓN)
# F = k * |q1 * q2| / r^2
# Esfera cargada positivamente (q2 = +6 uC) bloquea el paso en x = 240, y = 0.
# El jugador cambia la polaridad (+ o -) y magnitud del emisor superior (q1)
# para observar Repulsión (+ con +) o Atracción (- con +) y despejar el camino.
# ==============================================================================

const POS_TERMINAL := Vector2(130, -32)
const POS_EMISOR := Vector2(240, -195)
const POS_ESFERA_SUELO := Vector2(240, -44)
const POS_ESFERA_ELEVADA := Vector2(240, -142)

# Constantes físicas didácticas (intactas)
const K_COULOMB := 9.0 # N * m^2 / uC^2 (escala didáctica 9x10^9)
const Q_ESFERA := 6.0 # +6 uC (carga positiva fija en el obstáculo)
const DISTANCIA_R := 1.5 # m
const FUERZA_PESO_UMBRAL := 100.0 # N requeridos hacia arriba para levantar la esfera
const FUERZA_MAXIMA := 144.0 # N con |q1| = 6 uC

# Estado del emisor controlado por el jugador:
# polaridad_emisor: +1 (Positiva -> Repulsión), -1 (Negativa -> Atracción), 0 (Apagado)
var polaridad_emisor: int = 1
var opciones_carga: Array[float] = [2.0, 4.0, 6.0] # uC
var indice_carga: int = 2 # Inicia en 6.0 uC con polaridad (+) mostrando repulsión
var despejado: bool = false
var jugador_cerca: bool = false
var jugador_ref: Node2D = null
var area_terminal: Area2D = null
var _tecla_e_prev: bool = false
var tiempo_anim: float = 0.0
var _actualizando_ui: bool = false

# Nodos del mundo
var esfera_body: StaticBody2D
var esfera_col: CollisionShape2D
var esfera_sprite: Sprite2D
var lbl_esfera_mundo: Label
var emisor_sprite: Sprite2D
var lbl_emisor_mundo: Label
var lbl_prompt: Label
var lbl_estado_mundo: Label

# Nodos de UI (CanvasLayer layer = 10)
var ui_layer: CanvasLayer
var fondo_oscuro: ColorRect
var panel_nota: PanelContainer
var panel_puzzle: PanelContainer

# Controles HUD y simulación dentro del panel_puzzle
var lbl_hud_objetivo: Label
var lbl_hud_actual: Label
var barra_progreso: ProgressBar
var btn_pol_pos: Button
var btn_pol_neg: Button
var btn_pol_off: Button
var slider_q: HSlider
var lbl_valor_q: Label

# Nodos del esquema visual interactivo
var rect_emisor_vis: ColorRect
var lbl_emisor_vis: Label
var rect_esfera_vis: ColorRect
var lbl_esfera_vis: Label
var lineas_campo_vis: Array[Line2D] = []
var pulsos_campo_vis: Array[ColorRect] = []
var barra_vector_vis: ColorRect
var lbl_vector_vis: Label

func _ready() -> void:
	_crear_emisor_y_terminal()
	_crear_esfera_obstaculo()
	_crear_ui()
	_actualizar_estado()

func _crear_emisor_y_terminal() -> void:
	# 1. Emisor Electrostático Superior
	var nodo_emisor := Node2D.new()
	nodo_emisor.position = POS_EMISOR
	add_child(nodo_emisor)

	emisor_sprite = Sprite2D.new()
	var tex_emisor := load("res://assets/nivel_1/emisor_polaridad.svg") as Texture2D
	if tex_emisor:
		emisor_sprite.texture = tex_emisor
	nodo_emisor.add_child(emisor_sprite)

	lbl_emisor_mundo = Label.new()
	lbl_emisor_mundo.position = Vector2(-95, -42)
	lbl_emisor_mundo.size = Vector2(190, 36)
	lbl_emisor_mundo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_emisor_mundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_emisor_mundo.add_theme_font_size_override("font_size", 12)
	lbl_emisor_mundo.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_emisor_mundo.add_theme_constant_override("outline_size", 4)
	lbl_emisor_mundo.add_to_group("texto_mundo_flotante")
	nodo_emisor.add_child(lbl_emisor_mundo)

	# 2. Terminal interactivo (Area2D)
	area_terminal = Area2D.new()
	area_terminal.name = "TerminalCoulomb"
	area_terminal.position = POS_TERMINAL
	area_terminal.monitoring = true
	area_terminal.monitorable = true
	area_terminal.collision_layer = 0
	area_terminal.collision_mask = 1 # Capa 1: Jugador
	area_terminal.input_pickable = true
	add_child(area_terminal)

	var col_area := CollisionShape2D.new()
	var rect_area := RectangleShape2D.new()
	rect_area.size = Vector2(120, 120)
	col_area.shape = rect_area
	area_terminal.add_child(col_area)

	var spr_term := Sprite2D.new()
	var tex_term := load("res://assets/nivel_1/tablero_electrico.svg") as Texture2D
	if tex_term:
		spr_term.texture = tex_term
	area_terminal.add_child(spr_term)

	lbl_prompt = Label.new()
	lbl_prompt.text = "[E] Interactuar"
	lbl_prompt.position = Vector2(-95, -62)
	lbl_prompt.size = Vector2(190, 24)
	lbl_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_prompt.add_theme_font_size_override("font_size", 13)
	lbl_prompt.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	lbl_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_prompt.add_theme_constant_override("outline_size", 4)
	lbl_prompt.visible = false
	lbl_prompt.add_to_group("texto_mundo_flotante")
	area_terminal.add_child(lbl_prompt)

	lbl_estado_mundo = Label.new()
	lbl_estado_mundo.position = Vector2(POS_ESFERA_SUELO.x - 125, POS_EMISOR.y - 68)
	lbl_estado_mundo.size = Vector2(250, 24)
	lbl_estado_mundo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_estado_mundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_estado_mundo.add_theme_font_size_override("font_size", 12)
	lbl_estado_mundo.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_estado_mundo.add_theme_constant_override("outline_size", 4)
	lbl_estado_mundo.add_to_group("texto_mundo_flotante")
	add_child(lbl_estado_mundo)

	area_terminal.body_entered.connect(_on_body_entered)
	area_terminal.body_exited.connect(_on_body_exited)
	area_terminal.input_event.connect(_on_area_input_event)

func _crear_esfera_obstaculo() -> void:
	esfera_body = StaticBody2D.new()
	esfera_body.name = "EsferaCargada"
	esfera_body.position = POS_ESFERA_SUELO
	esfera_body.collision_layer = 16 # Capa 5: Suelo
	esfera_body.collision_mask = 1   # Capa 1: Jugador
	add_child(esfera_body)

	esfera_col = CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 40.0
	esfera_col.shape = shape
	esfera_body.add_child(esfera_col)

	esfera_sprite = Sprite2D.new()
	var tex_esf := load("res://assets/nivel_1/esfera_cargada.svg") as Texture2D
	if tex_esf:
		esfera_sprite.texture = tex_esf
	esfera_body.add_child(esfera_sprite)

	lbl_esfera_mundo = Label.new()
	lbl_esfera_mundo.text = "q₂ = +6 µC"
	lbl_esfera_mundo.position = Vector2(-65, 42)
	lbl_esfera_mundo.size = Vector2(130, 22)
	lbl_esfera_mundo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_esfera_mundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_esfera_mundo.add_theme_font_size_override("font_size", 12)
	lbl_esfera_mundo.add_theme_color_override("font_color", Color(1.0, 0.75, 0.75))
	lbl_esfera_mundo.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_esfera_mundo.add_theme_constant_override("outline_size", 4)
	lbl_esfera_mundo.add_to_group("texto_mundo_flotante")
	esfera_body.add_child(lbl_esfera_mundo)

func _crear_estilo_panel(col_fondo: Color, col_borde: Color, radio: int = 10, margen: int = 18) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col_fondo
	sb.border_color = col_borde
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(radio)
	sb.content_margin_left = margen
	sb.content_margin_right = margen
	sb.content_margin_top = margen - 4
	sb.content_margin_bottom = margen - 4
	return sb

func _crear_estilo_boton(col_fondo: Color, col_borde: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col_fondo
	sb.border_color = col_borde
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

func _crear_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)

	fondo_oscuro = ColorRect.new()
	fondo_oscuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo_oscuro.color = Color(0.01, 0.03, 0.06, 0.72)
	fondo_oscuro.mouse_filter = Control.MOUSE_FILTER_STOP
	fondo_oscuro.visible = false
	ui_layer.add_child(fondo_oscuro)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_PASS
	fondo_oscuro.add_child(centro)

	# ==========================================================================
	# 1. TARJETA DE NOTA TÉCNICA PREVIA (CONOCIMIENTOS PREVIOS)
	# ==========================================================================
	panel_nota = PanelContainer.new()
	panel_nota.custom_minimum_size = Vector2(540, 0)
	panel_nota.focus_mode = Control.FOCUS_NONE
	panel_nota.mouse_filter = Control.MOUSE_FILTER_STOP
	panel_nota.add_theme_stylebox_override("panel", _crear_estilo_panel(Color(0.04, 0.08, 0.14, 0.96), Color(0.3, 0.85, 1.0), 10, 22))
	panel_nota.visible = false
	centro.add_child(panel_nota)

	var vbox_nota := VBoxContainer.new()
	vbox_nota.add_theme_constant_override("separation", 12)
	vbox_nota.mouse_filter = Control.MOUSE_FILTER_PASS
	panel_nota.add_child(vbox_nota)

	var lbl_titulo_nota := Label.new()
	lbl_titulo_nota.text = "NOTA TÉCNICA: CONCEPTOS CLAVE"
	lbl_titulo_nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_titulo_nota.add_theme_font_size_override("font_size", 18)
	lbl_titulo_nota.add_theme_color_override("font_color", Color(0.35, 0.92, 1.0))
	vbox_nota.add_child(lbl_titulo_nota)

	var lbl_magnitud := Label.new()
	lbl_magnitud.text = "Magnitud: Fuerza Electrostática (Ley de Coulomb)"
	lbl_magnitud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_magnitud.add_theme_font_size_override("font_size", 15)
	lbl_magnitud.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	vbox_nota.add_child(lbl_magnitud)

	var caja_formula := PanelContainer.new()
	caja_formula.add_theme_stylebox_override("panel", _crear_estilo_panel(Color(0.02, 0.05, 0.09, 0.95), Color(0.2, 0.55, 0.75), 6, 10))
	vbox_nota.add_child(caja_formula)

	var lbl_formula := Label.new()
	lbl_formula.text = "F = k · |q₁ · q₂| / r²"
	lbl_formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_formula.add_theme_font_size_override("font_size", 22)
	lbl_formula.add_theme_color_override("font_color", Color(0.4, 1.0, 0.65))
	caja_formula.add_child(lbl_formula)

	var lbl_vars := Label.new()
	lbl_vars.text = "• q₁ y q₂ (µC): Cargas iguales se repelen y signos opuestos (+ y -) se atraen.\n• r (m): Distancia entre cargas; aumentar |q₁| incrementa la fuerza F (N)."
	lbl_vars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_vars.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_vars.add_theme_font_size_override("font_size", 13)
	lbl_vars.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	vbox_nota.add_child(lbl_vars)

	var btn_entendido := Button.new()
	btn_entendido.text = "[ ENTENDIDO / CONTINUAR ]  (Enter / Espacio / E)"
	btn_entendido.custom_minimum_size = Vector2(0, 42)
	btn_entendido.focus_mode = Control.FOCUS_NONE
	btn_entendido.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_entendido.add_theme_stylebox_override("normal", _crear_estilo_boton(Color(0.08, 0.36, 0.24, 0.96), Color(0.3, 1.0, 0.6)))
	btn_entendido.add_theme_stylebox_override("hover", _crear_estilo_boton(Color(0.12, 0.48, 0.32, 0.98), Color(0.5, 1.0, 0.75)))
	btn_entendido.add_theme_stylebox_override("pressed", _crear_estilo_boton(Color(0.06, 0.28, 0.18, 1.0), Color(0.3, 1.0, 0.6)))
	btn_entendido.add_theme_font_size_override("font_size", 14)
	btn_entendido.add_theme_color_override("font_color", Color(0.45, 1.0, 0.7))
	btn_entendido.pressed.connect(_pasar_a_panel_puzzle)
	vbox_nota.add_child(btn_entendido)

	# ==========================================================================
	# 2. PANEL PRINCIPAL DEL PUZZLE (INTERACTIVO, SIN PÁRRAFOS TEÓRICOS)
	# ==========================================================================
	panel_puzzle = PanelContainer.new()
	panel_puzzle.custom_minimum_size = Vector2(620, 0)
	panel_puzzle.focus_mode = Control.FOCUS_NONE
	panel_puzzle.mouse_filter = Control.MOUSE_FILTER_STOP
	panel_puzzle.add_theme_stylebox_override("panel", _crear_estilo_panel(Color(0.04, 0.07, 0.12, 0.96), Color(0.28, 0.78, 0.98), 10, 18))
	panel_puzzle.visible = false
	centro.add_child(panel_puzzle)

	var vbox_p := VBoxContainer.new()
	vbox_p.add_theme_constant_override("separation", 10)
	vbox_p.mouse_filter = Control.MOUSE_FILTER_PASS
	panel_puzzle.add_child(vbox_p)

	# Cabecera compacta + botones Nota y Cerrar
	var hbox_top := HBoxContainer.new()
	hbox_top.add_theme_constant_override("separation", 8)
	vbox_p.add_child(hbox_top)

	var btn_ver_nota := Button.new()
	btn_ver_nota.text = "[?] Nota"
	btn_ver_nota.focus_mode = Control.FOCUS_NONE
	btn_ver_nota.add_theme_stylebox_override("normal", _crear_estilo_boton(Color(0.08, 0.16, 0.26, 0.95), Color(0.3, 0.7, 0.95)))
	btn_ver_nota.pressed.connect(_mostrar_nota_tecnica)
	hbox_top.add_child(btn_ver_nota)

	var lbl_titulo_p := Label.new()
	lbl_titulo_p.text = "EMISOR ELECTROSTÁTICO (q₁)"
	lbl_titulo_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_titulo_p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_titulo_p.add_theme_font_size_override("font_size", 16)
	lbl_titulo_p.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	hbox_top.add_child(lbl_titulo_p)

	var btn_x := Button.new()
	btn_x.text = "[X] Esc"
	btn_x.focus_mode = Control.FOCUS_NONE
	btn_x.add_theme_stylebox_override("normal", _crear_estilo_boton(Color(0.28, 0.1, 0.12, 0.95), Color(0.95, 0.35, 0.35)))
	btn_x.pressed.connect(_cerrar_todo)
	hbox_top.add_child(btn_x)

	# Barra superior compacta: OBJETIVO vs ACTUAL + ProgressBar dinámica
	var caja_hud := PanelContainer.new()
	caja_hud.add_theme_stylebox_override("panel", _crear_estilo_panel(Color(0.02, 0.04, 0.08, 0.95), Color(0.2, 0.45, 0.65), 6, 10))
	vbox_p.add_child(caja_hud)

	var vbox_hud := VBoxContainer.new()
	vbox_hud.add_theme_constant_override("separation", 6)
	caja_hud.add_child(vbox_hud)

	var hbox_hud := HBoxContainer.new()
	vbox_hud.add_child(hbox_hud)

	lbl_hud_objetivo = Label.new()
	lbl_hud_objetivo.text = "OBJETIVO: ≥ 100 N (↑ Atracción)"
	lbl_hud_objetivo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_hud_objetivo.add_theme_font_size_override("font_size", 14)
	lbl_hud_objetivo.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0))
	hbox_hud.add_child(lbl_hud_objetivo)

	lbl_hud_actual = Label.new()
	lbl_hud_actual.text = "ACTUAL: 144 N (↓)"
	lbl_hud_actual.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_hud_actual.add_theme_font_size_override("font_size", 15)
	hbox_hud.add_child(lbl_hud_actual)

	barra_progreso = ProgressBar.new()
	barra_progreso.custom_minimum_size = Vector2(0, 16)
	barra_progreso.min_value = 0.0
	barra_progreso.max_value = FUERZA_MAXIMA
	barra_progreso.show_percentage = false
	barra_progreso.focus_mode = Control.FOCUS_NONE
	vbox_hud.add_child(barra_progreso)

	# Esquema visual simple del sistema físico (Line2D + ColorRect + pulsos)
	var caja_esquema := Panel.new()
	caja_esquema.custom_minimum_size = Vector2(580, 168)
	caja_esquema.focus_mode = Control.FOCUS_NONE
	var sb_esq := StyleBoxFlat.new()
	sb_esq.bg_color = Color(0.02, 0.04, 0.07, 0.98)
	sb_esq.border_color = Color(0.18, 0.35, 0.52)
	sb_esq.set_border_width_all(2)
	sb_esq.set_corner_radius_all(8)
	caja_esquema.add_theme_stylebox_override("panel", sb_esq)
	vbox_p.add_child(caja_esquema)

	# Suelo de referencia en el esquema
	var suelo_esq := ColorRect.new()
	suelo_esq.position = Vector2(20, 146)
	suelo_esq.size = Vector2(420, 8)
	suelo_esq.color = Color(0.22, 0.32, 0.42, 0.9)
	caja_esquema.add_child(suelo_esq)

	# Líneas de campo (Line2D) y pulsos móviles (ColorRect)
	lineas_campo_vis.clear()
	pulsos_campo_vis.clear()
	var xs_campo := [185.0, 230.0, 275.0]
	for x_c in xs_campo:
		var l := Line2D.new()
		l.width = 2.5
		l.points = PackedVector2Array([Vector2(x_c, 42), Vector2(x_c, 120)])
		caja_esquema.add_child(l)
		lineas_campo_vis.append(l)

		for p_i in range(2):
			var pulso := ColorRect.new()
			pulso.size = Vector2(8, 8)
			pulso.position = Vector2(x_c - 4, 60 + p_i * 30)
			caja_esquema.add_child(pulso)
			pulsos_campo_vis.append(pulso)

	# Bloque visual del Emisor q1 (arriba)
	rect_emisor_vis = ColorRect.new()
	rect_emisor_vis.position = Vector2(150, 12)
	rect_emisor_vis.size = Vector2(160, 30)
	rect_emisor_vis.color = Color(0.95, 0.25, 0.25)
	caja_esquema.add_child(rect_emisor_vis)

	lbl_emisor_vis = Label.new()
	lbl_emisor_vis.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl_emisor_vis.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_emisor_vis.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_emisor_vis.add_theme_font_size_override("font_size", 13)
	lbl_emisor_vis.add_theme_color_override("font_color", Color.WHITE)
	rect_emisor_vis.add_child(lbl_emisor_vis)

	# Bloque visual de la Esfera q2 = +6 uC (se eleva o baja en tiempo real)
	rect_esfera_vis = ColorRect.new()
	rect_esfera_vis.position = Vector2(165, 110)
	rect_esfera_vis.size = Vector2(130, 34)
	rect_esfera_vis.color = Color(0.92, 0.32, 0.38)
	caja_esquema.add_child(rect_esfera_vis)

	lbl_esfera_vis = Label.new()
	lbl_esfera_vis.text = "OBSTÁCULO q₂ (+6 µC)"
	lbl_esfera_vis.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl_esfera_vis.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_esfera_vis.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_esfera_vis.add_theme_font_size_override("font_size", 12)
	lbl_esfera_vis.add_theme_color_override("font_color", Color.WHITE)
	rect_esfera_vis.add_child(lbl_esfera_vis)

	# Columna derecha del esquema: Medidor visual de vector de fuerza
	var marco_vec := ColorRect.new()
	marco_vec.position = Vector2(465, 18)
	marco_vec.size = Vector2(90, 132)
	marco_vec.color = Color(0.05, 0.09, 0.15, 0.95)
	caja_esquema.add_child(marco_vec)

	var linea_umbral := Line2D.new()
	linea_umbral.points = PackedVector2Array([Vector2(465, 52), Vector2(555, 52)])
	linea_umbral.width = 2.0
	linea_umbral.default_color = Color(0.3, 1.0, 0.55, 0.85)
	caja_esquema.add_child(linea_umbral)

	barra_vector_vis = ColorRect.new()
	barra_vector_vis.position = Vector2(492, 100)
	barra_vector_vis.size = Vector2(36, 40)
	barra_vector_vis.color = Color(1.0, 0.35, 0.35)
	caja_esquema.add_child(barra_vector_vis)

	lbl_vector_vis = Label.new()
	lbl_vector_vis.position = Vector2(460, 126)
	lbl_vector_vis.size = Vector2(100, 22)
	lbl_vector_vis.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_vector_vis.add_theme_font_size_override("font_size", 12)
	caja_esquema.add_child(lbl_vector_vis)

	# Controles Interactivos Directos: 1) Interruptor de Polaridad
	var hbox_pol := HBoxContainer.new()
	hbox_pol.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_pol.add_theme_constant_override("separation", 10)
	vbox_p.add_child(hbox_pol)

	var lbl_pol_tag := Label.new()
	lbl_pol_tag.text = "POLARIDAD q₁:"
	lbl_pol_tag.custom_minimum_size = Vector2(120, 0)
	lbl_pol_tag.add_theme_font_size_override("font_size", 13)
	hbox_pol.add_child(lbl_pol_tag)

	btn_pol_pos = Button.new()
	btn_pol_pos.text = "[1] POLO (+)"
	btn_pol_pos.custom_minimum_size = Vector2(135, 36)
	btn_pol_pos.focus_mode = Control.FOCUS_NONE
	btn_pol_pos.pressed.connect(func(): _cambiar_polaridad(1))
	hbox_pol.add_child(btn_pol_pos)

	btn_pol_neg = Button.new()
	btn_pol_neg.text = "[2] POLO (-)"
	btn_pol_neg.custom_minimum_size = Vector2(135, 36)
	btn_pol_neg.focus_mode = Control.FOCUS_NONE
	btn_pol_neg.pressed.connect(func(): _cambiar_polaridad(-1))
	hbox_pol.add_child(btn_pol_neg)

	btn_pol_off = Button.new()
	btn_pol_off.text = "[0] APAGADO"
	btn_pol_off.custom_minimum_size = Vector2(125, 36)
	btn_pol_off.focus_mode = Control.FOCUS_NONE
	btn_pol_off.pressed.connect(func(): _cambiar_polaridad(0))
	hbox_pol.add_child(btn_pol_off)

	# Controles Interactivos Directos: 2) Slider + Botones de Carga |q1|
	var hbox_q := HBoxContainer.new()
	hbox_q.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_q.add_theme_constant_override("separation", 10)
	vbox_p.add_child(hbox_q)

	var lbl_q_tag := Label.new()
	lbl_q_tag.text = "CARGA |q₁|:"
	lbl_q_tag.custom_minimum_size = Vector2(120, 0)
	lbl_q_tag.add_theme_font_size_override("font_size", 13)
	hbox_q.add_child(lbl_q_tag)

	var btn_q_menos := Button.new()
	btn_q_menos.text = "◀ [A / ←]"
	btn_q_menos.custom_minimum_size = Vector2(90, 34)
	btn_q_menos.focus_mode = Control.FOCUS_NONE
	btn_q_menos.pressed.connect(func(): _cambiar_magnitud(-1))
	hbox_q.add_child(btn_q_menos)

	slider_q = HSlider.new()
	slider_q.min_value = 0
	slider_q.max_value = opciones_carga.size() - 1
	slider_q.step = 1
	slider_q.value = indice_carga
	slider_q.custom_minimum_size = Vector2(170, 28)
	slider_q.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider_q.focus_mode = Control.FOCUS_NONE
	slider_q.value_changed.connect(_on_slider_q_changed)
	hbox_q.add_child(slider_q)

	var btn_q_mas := Button.new()
	btn_q_mas.text = "[D / →] ▶"
	btn_q_mas.custom_minimum_size = Vector2(90, 34)
	btn_q_mas.focus_mode = Control.FOCUS_NONE
	btn_q_mas.pressed.connect(func(): _cambiar_magnitud(1))
	hbox_q.add_child(btn_q_mas)

	lbl_valor_q = Label.new()
	lbl_valor_q.custom_minimum_size = Vector2(80, 0)
	lbl_valor_q.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_valor_q.add_theme_font_size_override("font_size", 15)
	lbl_valor_q.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	hbox_q.add_child(lbl_valor_q)

	# Botón Confirmar / Cerrar y leyenda de controles verificados
	var btn_confirmar := Button.new()
	btn_confirmar.text = "[ APLICAR Y VOLVER AL NIVEL ]  (Enter / Espacio / E / Esc)"
	btn_confirmar.custom_minimum_size = Vector2(0, 40)
	btn_confirmar.focus_mode = Control.FOCUS_NONE
	btn_confirmar.add_theme_stylebox_override("normal", _crear_estilo_boton(Color(0.08, 0.34, 0.24, 0.96), Color(0.3, 0.95, 0.55)))
	btn_confirmar.add_theme_stylebox_override("hover", _crear_estilo_boton(Color(0.12, 0.46, 0.32, 0.98), Color(0.45, 1.0, 0.7)))
	btn_confirmar.add_theme_font_size_override("font_size", 14)
	btn_confirmar.pressed.connect(_cerrar_todo)
	vbox_p.add_child(btn_confirmar)

	var lbl_keys := Label.new()
	lbl_keys.text = "Atajos: [1/2/0] Polaridad  |  [A/D o ←/→] Carga |q₁|  |  [Enter/Espacio/E/Esc] Cerrar"
	lbl_keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_keys.add_theme_font_size_override("font_size", 11)
	lbl_keys.add_theme_color_override("font_color", Color(0.62, 0.76, 0.88))
	vbox_p.add_child(lbl_keys)

func _on_slider_q_changed(valor: float) -> void:
	if _actualizando_ui:
		return
	indice_carga = clampi(int(round(valor)), 0, opciones_carga.size() - 1)
	_actualizar_estado()

func _cambiar_polaridad(nueva_pol: int) -> void:
	polaridad_emisor = nueva_pol
	_actualizar_estado()

func _cambiar_magnitud(delta_idx: int) -> void:
	indice_carga = clampi(indice_carga + delta_idx, 0, opciones_carga.size() - 1)
	_actualizar_estado()

func _calcular_fuerza() -> float:
	if polaridad_emisor == 0:
		return 0.0
	var q1_mag: float = opciones_carga[indice_carga]
	return K_COULOMB * (q1_mag * Q_ESFERA) / (DISTANCIA_R * DISTANCIA_R)

func _actualizar_estilos_botones_polaridad() -> void:
	if not btn_pol_pos:
		return
	var act_pos := polaridad_emisor == 1
	var act_neg := polaridad_emisor == -1
	var act_off := polaridad_emisor == 0

	btn_pol_pos.add_theme_stylebox_override("normal", _crear_estilo_boton(
		Color(0.55, 0.14, 0.16, 0.98) if act_pos else Color(0.12, 0.15, 0.22, 0.9),
		Color(1.0, 0.45, 0.45) if act_pos else Color(0.3, 0.35, 0.45)
	))
	btn_pol_neg.add_theme_stylebox_override("normal", _crear_estilo_boton(
		Color(0.08, 0.38, 0.55, 0.98) if act_neg else Color(0.12, 0.15, 0.22, 0.9),
		Color(0.35, 0.95, 1.0) if act_neg else Color(0.3, 0.35, 0.45)
	))
	btn_pol_off.add_theme_stylebox_override("normal", _crear_estilo_boton(
		Color(0.26, 0.28, 0.34, 0.98) if act_off else Color(0.12, 0.15, 0.22, 0.9),
		Color(0.75, 0.8, 0.88) if act_off else Color(0.3, 0.35, 0.45)
	))

func _actualizar_estado() -> void:
	_actualizando_ui = true
	var q1_mag: float = opciones_carga[indice_carga]
	var fuerza: float = _calcular_fuerza()

	if slider_q:
		slider_q.value = indice_carga
	if lbl_valor_q:
		lbl_valor_q.text = "%.0f µC" % q1_mag
	_actualizar_estilos_botones_polaridad()

	var era_despejado := despejado
	despejado = (polaridad_emisor == -1) and (fuerza >= FUERZA_PESO_UMBRAL)

	# Actualizar mundo exterior
	if polaridad_emisor > 0:
		emisor_sprite.modulate = Color(1.0, 0.35, 0.35)
		lbl_emisor_mundo.text = "q₁ = +%.0f µC (↓↓ %.0f N)" % [q1_mag, fuerza]
		lbl_emisor_mundo.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	elif polaridad_emisor < 0:
		emisor_sprite.modulate = Color(0.25, 0.85, 1.0)
		lbl_emisor_mundo.text = "q₁ = -%.0f µC (↑↑ %.0f N)" % [q1_mag, fuerza]
		lbl_emisor_mundo.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
	else:
		emisor_sprite.modulate = Color(0.7, 0.75, 0.8)
		lbl_emisor_mundo.text = "q₁ = 0 µC (0 N)"
		lbl_emisor_mundo.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

	var destino_y := POS_ESFERA_ELEVADA if despejado else POS_ESFERA_SUELO
	if era_despejado != despejado and is_inside_tree():
		var tw := create_tween()
		tw.tween_property(esfera_body, "position", destino_y, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		esfera_body.position = destino_y

	if despejado:
		lbl_estado_mundo.text = "PASO DESPEJADO (%.0f N ↑)" % fuerza
		lbl_estado_mundo.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	elif polaridad_emisor == 1:
		lbl_estado_mundo.text = "REPULSIÓN (%.0f N ↓)" % fuerza
		lbl_estado_mundo.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	elif polaridad_emisor == -1:
		lbl_estado_mundo.text = "ATRACCIÓN: %.0f / 100 N ↑" % fuerza
		lbl_estado_mundo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	else:
		lbl_estado_mundo.text = "EMISOR APAGADO"
		lbl_estado_mundo.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

	# Actualizar HUD y Esquema del Panel
	if lbl_hud_actual:
		var fill_sb := StyleBoxFlat.new()
		fill_sb.set_corner_radius_all(4)
		if despejado:
			lbl_hud_actual.text = "ACTUAL: %.0f N (↑ ¡ELEVADA!)" % fuerza
			lbl_hud_actual.add_theme_color_override("font_color", Color(0.3, 1.0, 0.55))
			barra_progreso.value = fuerza
			fill_sb.bg_color = Color(0.25, 0.95, 0.5)
		elif polaridad_emisor == -1:
			lbl_hud_actual.text = "ACTUAL: %.0f N (↑ Atracción)" % fuerza
			lbl_hud_actual.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
			barra_progreso.value = fuerza
			fill_sb.bg_color = Color(0.95, 0.75, 0.2)
		elif polaridad_emisor == 1:
			lbl_hud_actual.text = "ACTUAL: %.0f N (↓ Repulsión)" % fuerza
			lbl_hud_actual.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
			barra_progreso.value = 0.0
			fill_sb.bg_color = Color(0.95, 0.3, 0.3)
		else:
			lbl_hud_actual.text = "ACTUAL: 0 N (Apagado)"
			lbl_hud_actual.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
			barra_progreso.value = 0.0
			fill_sb.bg_color = Color(0.4, 0.45, 0.5)
		barra_progreso.add_theme_stylebox_override("fill", fill_sb)

	if rect_emisor_vis:
		if polaridad_emisor == 1:
			rect_emisor_vis.color = Color(0.88, 0.22, 0.26)
			lbl_emisor_vis.text = "EMISOR q₁ = +%.0f µC" % q1_mag
		elif polaridad_emisor == -1:
			rect_emisor_vis.color = Color(0.14, 0.62, 0.86)
			lbl_emisor_vis.text = "EMISOR q₁ = -%.0f µC" % q1_mag
		else:
			rect_emisor_vis.color = Color(0.32, 0.36, 0.42)
			lbl_emisor_vis.text = "EMISOR q₁ = 0 µC"

		# Posición vertical de la esfera en el esquema según la fuerza
		var y_esf_vis := 112.0
		if polaridad_emisor == -1:
			var avance := clampf(fuerza / FUERZA_MAXIMA, 0.0, 1.0)
			y_esf_vis = lerpf(112.0, 52.0, avance)
		elif polaridad_emisor == 1:
			y_esf_vis = 114.0
		rect_esfera_vis.position.y = y_esf_vis
		rect_esfera_vis.color = Color(0.22, 0.85, 0.48) if despejado else Color(0.88, 0.3, 0.36)

		# Barra de vector de fuerza lateral
		var h_vec := clampf((fuerza / FUERZA_MAXIMA) * 95.0, 4.0, 95.0) if polaridad_emisor != 0 else 4.0
		if polaridad_emisor == -1:
			barra_vector_vis.size = Vector2(36, h_vec)
			barra_vector_vis.position = Vector2(492, 120.0 - h_vec)
			barra_vector_vis.color = Color(0.25, 0.95, 0.55) if despejado else Color(0.3, 0.85, 1.0)
			lbl_vector_vis.text = "↑ %.0f N" % fuerza
		elif polaridad_emisor == 1:
			barra_vector_vis.size = Vector2(36, h_vec * 0.55)
			barra_vector_vis.position = Vector2(492, 65.0)
			barra_vector_vis.color = Color(1.0, 0.35, 0.35)
			lbl_vector_vis.text = "↓ %.0f N" % fuerza
		else:
			barra_vector_vis.size = Vector2(36, 4)
			barra_vector_vis.position = Vector2(492, 116)
			barra_vector_vis.color = Color(0.5, 0.55, 0.6)
			lbl_vector_vis.text = "0 N"

	_actualizando_ui = false
	queue_redraw()

func _esta_modal_abierto() -> bool:
	return (fondo_oscuro != null and fondo_oscuro.visible)

func _ocultar_textos_mundo(ocultar: bool) -> void:
	for n in get_tree().get_nodes_in_group("texto_mundo_flotante"):
		if n is CanvasItem:
			n.modulate.a = 0.0 if ocultar else 1.0
	if ocultar and lbl_prompt:
		lbl_prompt.visible = false

func _obtener_jugador() -> Node2D:
	if is_instance_valid(jugador_ref):
		return jugador_ref
	var p := get_parent()
	if p:
		var j := p.get_node_or_null("CharacterBody2D") as Node2D
		if not j:
			j = p.get_node_or_null("Jugador") as Node2D
		if j:
			jugador_ref = j
			return j
	return null

func _congelar_jugador(congelar: bool) -> void:
	var j := _obtener_jugador()
	if j:
		if j is CharacterBody2D and congelar:
			(j as CharacterBody2D).velocity = Vector2.ZERO
		j.set_physics_process(not congelar)

func _abrir_fluido() -> void:
	fondo_oscuro.visible = true
	panel_nota.visible = true
	panel_puzzle.visible = false
	_ocultar_textos_mundo(true)
	_congelar_jugador(true)
	_actualizar_estado()

func _mostrar_nota_tecnica() -> void:
	fondo_oscuro.visible = true
	panel_nota.visible = true
	panel_puzzle.visible = false
	_ocultar_textos_mundo(true)

func _pasar_a_panel_puzzle() -> void:
	fondo_oscuro.visible = true
	panel_nota.visible = false
	panel_puzzle.visible = true
	_ocultar_textos_mundo(true)
	_actualizar_estado()

func _cerrar_todo() -> void:
	fondo_oscuro.visible = false
	panel_nota.visible = false
	panel_puzzle.visible = false
	_ocultar_textos_mundo(false)
	_congelar_jugador(false)
	lbl_prompt.visible = jugador_cerca

func _verificar_solapamiento() -> void:
	if not area_terminal or not area_terminal.monitoring:
		return
	var detectado := false
	for b in area_terminal.get_overlapping_bodies():
		if b is CharacterBody2D or b.is_in_group("jugador"):
			detectado = true
			jugador_ref = b
			break
	jugador_cerca = detectado
	lbl_prompt.visible = jugador_cerca and not _esta_modal_abierto()

func _input(event: InputEvent) -> void:
	if not _esta_modal_abierto():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if panel_nota.visible:
			if kc in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E]:
				_tecla_e_prev = true
				_pasar_a_panel_puzzle()
				get_viewport().set_input_as_handled()
			elif kc == KEY_ESCAPE:
				_tecla_e_prev = true
				_cerrar_todo()
				get_viewport().set_input_as_handled()
		elif panel_puzzle.visible:
			if kc in [KEY_ESCAPE, KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				_tecla_e_prev = true
				_cerrar_todo()
				get_viewport().set_input_as_handled()
			elif kc in [KEY_1, KEY_KP_1]:
				_cambiar_polaridad(1)
				get_viewport().set_input_as_handled()
			elif kc in [KEY_2, KEY_KP_2]:
				_cambiar_polaridad(-1)
				get_viewport().set_input_as_handled()
			elif kc in [KEY_0, KEY_KP_0]:
				_cambiar_polaridad(0)
				get_viewport().set_input_as_handled()
			elif kc in [KEY_A, KEY_LEFT]:
				_cambiar_magnitud(-1)
				get_viewport().set_input_as_handled()
			elif kc in [KEY_D, KEY_RIGHT]:
				_cambiar_magnitud(1)
				get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if _esta_modal_abierto():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if kc == KEY_E and jugador_cerca:
			_tecla_e_prev = true
			_abrir_fluido()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	var fuerza := _calcular_fuerza()
	var vel_flujo := clampf(fuerza / 45.0, 0.8, 3.6) if polaridad_emisor != 0 else 0.0
	tiempo_anim += delta * vel_flujo
	_verificar_solapamiento()
	_animar_esquema_interno(fuerza)
	queue_redraw()

	var e_actual: bool = Input.is_physical_key_pressed(KEY_E) or Input.is_key_pressed(KEY_E)
	if e_actual and not _tecla_e_prev and not _esta_modal_abierto() and jugador_cerca:
		_abrir_fluido()
	_tecla_e_prev = e_actual

func _animar_esquema_interno(fuerza: float) -> void:
	if not panel_puzzle or not panel_puzzle.visible:
		return
	var col_linea := Color(0.4, 0.45, 0.5, 0.35)
	if polaridad_emisor == 1:
		col_linea = Color(1.0, 0.35, 0.35, 0.85)
	elif polaridad_emisor == -1:
		col_linea = Color(0.3, 1.0, 0.55, 0.9) if despejado else Color(0.3, 0.88, 1.0, 0.85)

	var grosor := 1.5 + (fuerza / FUERZA_MAXIMA) * 3.0 if polaridad_emisor != 0 else 1.5
	var y_ini := 42.0
	var y_fin := rect_esfera_vis.position.y

	for i in range(lineas_campo_vis.size()):
		var l := lineas_campo_vis[i]
		var x_c := l.points[0].x
		l.points = PackedVector2Array([Vector2(x_c, y_ini), Vector2(x_c, y_fin)])
		l.width = grosor
		l.default_color = col_linea

		for p_i in range(2):
			var idx_p := i * 2 + p_i
			var pulso := pulsos_campo_vis[idx_p]
			pulso.visible = (polaridad_emisor != 0)
			pulso.color = col_linea.lightened(0.25)
			var fase := fmod(tiempo_anim + float(p_i) * 0.5 + float(i) * 0.2, 1.0)
			var py := lerpf(y_ini, y_fin - 8.0, fase) if polaridad_emisor == 1 else lerpf(y_fin - 8.0, y_ini, fase)
			pulso.position = Vector2(x_c - 4.0, py)

func _draw() -> void:
	var color_cable := Color(0.3, 0.9, 1.0, 0.85) if polaridad_emisor == -1 else (Color(1.0, 0.4, 0.4, 0.85) if polaridad_emisor == 1 else Color(0.45, 0.5, 0.55, 0.7))
	draw_polyline(PackedVector2Array([
		POS_TERMINAL + Vector2(0, -20),
		Vector2(POS_TERMINAL.x, POS_EMISOR.y),
		POS_EMISOR
	]), color_cable, 3.0)

	if polaridad_emisor == 0:
		return

	var y_top := POS_EMISOR.y + 24.0
	var y_bot := esfera_body.position.y - 36.0
	if y_bot <= y_top + 12.0:
		y_bot = y_top + 18.0

	var offsets_x := [-26.0, 0.0, 26.0]
	var num_flechas: int = indice_carga + 1

	for ox in offsets_x:
		var x_linea: float = POS_EMISOR.x + ox
		draw_dashed_line(Vector2(x_linea, y_top), Vector2(x_linea, y_bot), color_cable, 2.2, 6.0)
		for i in range(num_flechas):
			var fase := fmod((tiempo_anim + float(i) / float(num_flechas)), 1.0)
			if polaridad_emisor == 1:
				var py := lerpf(y_top + 6.0, y_bot - 4.0, fase)
				_dibujar_flecha_vertical(Vector2(x_linea, py), 1.0, Color(1.0, 0.35, 0.35))
			elif polaridad_emisor == -1:
				var py := lerpf(y_bot - 4.0, y_top + 6.0, fase)
				var col_atr := Color(0.3, 1.0, 0.6) if despejado else Color(0.3, 0.9, 1.0)
				_dibujar_flecha_vertical(Vector2(x_linea, py), -1.0, col_atr)

func _dibujar_flecha_vertical(punta: Vector2, dir_y: float, col: Color) -> void:
	var ala1 := punta + Vector2(-6.0, -8.0 * dir_y)
	var ala2 := punta + Vector2(6.0, -8.0 * dir_y)
	draw_line(punta, ala1, col, 2.5)
	draw_line(punta, ala2, col, 2.5)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D or body.is_in_group("jugador"):
		jugador_cerca = true
		jugador_ref = body
		lbl_prompt.visible = not _esta_modal_abierto()

func _on_body_exited(body: Node2D) -> void:
	if body == jugador_ref:
		jugador_cerca = false
		lbl_prompt.visible = false
		if _esta_modal_abierto():
			_cerrar_todo()

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _esta_modal_abierto():
			_cerrar_todo()
		else:
			_abrir_fluido()
