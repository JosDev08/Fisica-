extends Node2D

# ==============================================================================
# PUZZLE 2 (NIVEL 1): ELECTRODINÁMICA — LEY DE OHM (I = V / R) Y FUSIBLE
# Un puente eléctrico sobre el abismo (x = 592..736) requiere una corriente
# exacta I_meta = 4.0 A para energizar sus bobinas.
# Si la corriente supera I_max = 5.0 A, el fusible se quema por sobrecorriente
# y el jugador debe reemplazarlo antes de volver a intentar.
# ==============================================================================

const POS_TABLERO := Vector2(525, -32)
const POS_PUENTE_ACTIVO := Vector2(664, 8)
const POS_PUENTE_APAGADO := Vector2(664, 92)
const POS_BARRERA := Vector2(588, -56)

const CORRIENTE_META := 4.0 # Amperios exactos requeridos
const CORRIENTE_MAX_FUSIBLE := 5.0 # Amperios máximos antes de quemar el fusible

var voltajes_disponibles: Array[float] = [12.0, 24.0, 36.0, 48.0]
var resistencias_disponibles: Array[float] = [2.0, 3.0, 4.0, 6.0, 8.0, 12.0]

var idx_v: int = 1 # 24 V por defecto
var idx_r: int = 4 # 8 Ohm por defecto -> I = 24 / 8 = 3.0 A
var fusible_quemado: bool = false
var puente_activo: bool = false

var jugador_cerca: bool = false
var jugador_ref: Node2D = null
var area_tablero: Area2D = null
var _tecla_e_prev: bool = false
var _actualizando_ui: bool = false
var fase_pulsos: float = 0.0

# Nodos del mundo
var puente_body: StaticBody2D
var puente_col: CollisionShape2D
var puente_sprite: Sprite2D
var barrera_body: StaticBody2D
var barrera_col: CollisionShape2D
var barrera_visual: Polygon2D
var lbl_prompt: Label
var lbl_estado_puente: Label

# Nodos UI (CanvasLayer layer = 10)
var ui_layer: CanvasLayer
var fondo_oscuro: ColorRect
var panel_nota: PanelContainer
var panel_puzzle: PanelContainer

# Controles HUD y simulación dentro de panel_puzzle
var lbl_hud_objetivo: Label
var lbl_hud_actual: Label
var barra_progreso: ProgressBar
var slider_v: HSlider
var slider_r: HSlider
var lbl_val_v: Label
var lbl_val_r: Label
var btn_reemplazar_fusible: Button

# Esquema visual interactivo del circuito
var cable_loop_vis: Line2D
var filamento_intacto_vis: Line2D
var filamento_roto_izq_vis: Line2D
var filamento_roto_der_vis: Line2D
var zigzag_r_vis: Line2D
var bloque_fuente_vis: ColorRect
var lbl_fuente_vis: Label
var bloque_fusible_vis: ColorRect
var lbl_fusible_vis: Label
var bloque_resistor_vis: ColorRect
var lbl_resistor_vis: Label
var bloque_motor_vis: ColorRect
var lbl_motor_vis: Label
var pulsos_circuito_vis: Array[ColorRect] = []
var ruta_pulsos: Array[Vector2] = [
	Vector2(90, 34),
	Vector2(490, 34),
	Vector2(490, 134),
	Vector2(90, 134)
]

func _ready() -> void:
	_crear_puente_y_barrera()
	_crear_tablero()
	_crear_ui()
	_actualizar_circuito()

func _crear_puente_y_barrera() -> void:
	puente_body = StaticBody2D.new()
	puente_body.name = "PuenteOhm"
	puente_body.position = POS_PUENTE_APAGADO
	puente_body.collision_layer = 16 # Capa 5: Suelo
	puente_body.collision_mask = 1   # Capa 1: Jugador
	add_child(puente_body)

	puente_col = CollisionShape2D.new()
	var rect_puente := RectangleShape2D.new()
	rect_puente.size = Vector2(160, 20)
	puente_col.shape = rect_puente
	puente_col.disabled = true
	puente_body.add_child(puente_col)

	puente_sprite = Sprite2D.new()
	var tex_puente := load("res://assets/nivel_1/puente_ohm.svg") as Texture2D
	if tex_puente:
		puente_sprite.texture = tex_puente
	puente_body.add_child(puente_sprite)

	barrera_body = StaticBody2D.new()
	barrera_body.name = "BarreraAbismoOhm"
	barrera_body.position = POS_BARRERA
	barrera_body.collision_layer = 16
	barrera_body.collision_mask = 1
	add_child(barrera_body)

	barrera_col = CollisionShape2D.new()
	var rect_barrera := RectangleShape2D.new()
	rect_barrera.size = Vector2(14, 112)
	barrera_col.shape = rect_barrera
	barrera_body.add_child(barrera_col)

	barrera_visual = Polygon2D.new()
	barrera_visual.polygon = PackedVector2Array([
		Vector2(-5, -56), Vector2(5, -56), Vector2(5, 56), Vector2(-5, 56)
	])
	barrera_visual.color = Color(1.0, 0.35, 0.2, 0.75)
	barrera_body.add_child(barrera_visual)

	lbl_estado_puente = Label.new()
	lbl_estado_puente.position = Vector2(POS_PUENTE_ACTIVO.x - 130, -48)
	lbl_estado_puente.size = Vector2(260, 38)
	lbl_estado_puente.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_estado_puente.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_estado_puente.add_theme_font_size_override("font_size", 12)
	lbl_estado_puente.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_estado_puente.add_theme_constant_override("outline_size", 4)
	lbl_estado_puente.add_to_group("texto_mundo_flotante")
	add_child(lbl_estado_puente)

func _crear_tablero() -> void:
	area_tablero = Area2D.new()
	area_tablero.name = "TableroOhm"
	area_tablero.position = POS_TABLERO
	area_tablero.monitoring = true
	area_tablero.monitorable = true
	area_tablero.collision_layer = 0
	area_tablero.collision_mask = 1 # Capa 1: Jugador
	area_tablero.input_pickable = true
	add_child(area_tablero)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(120, 120)
	col.shape = rect
	area_tablero.add_child(col)

	var spr := Sprite2D.new()
	var tex := load("res://assets/nivel_1/tablero_electrico.svg") as Texture2D
	if tex:
		spr.texture = tex
	area_tablero.add_child(spr)

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
	area_tablero.add_child(lbl_prompt)

	area_tablero.body_entered.connect(_on_body_entered)
	area_tablero.body_exited.connect(_on_body_exited)
	area_tablero.input_event.connect(_on_area_input_event)

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
	lbl_magnitud.text = "Magnitud: Corriente Eléctrica (Ley de Ohm)"
	lbl_magnitud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_magnitud.add_theme_font_size_override("font_size", 15)
	lbl_magnitud.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	vbox_nota.add_child(lbl_magnitud)

	var caja_formula := PanelContainer.new()
	caja_formula.add_theme_stylebox_override("panel", _crear_estilo_panel(Color(0.02, 0.05, 0.09, 0.95), Color(0.2, 0.55, 0.75), 6, 10))
	vbox_nota.add_child(caja_formula)

	var lbl_formula := Label.new()
	lbl_formula.text = "I = V / R"
	lbl_formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_formula.add_theme_font_size_override("font_size", 22)
	lbl_formula.add_theme_color_override("font_color", Color(0.4, 1.0, 0.65))
	caja_formula.add_child(lbl_formula)

	var lbl_vars := Label.new()
	lbl_vars.text = "• V (Voltaje, V) impulsa la corriente I (A); R (Resistencia, Ω) se opone a su paso.\n• Si I supera el límite del fusible (5.0 A), el filamento se funde y abre el circuito."
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
	lbl_titulo_p.text = "PUENTE ELÉCTRICO — CONTROL V / R"
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
	lbl_hud_objetivo.text = "OBJETIVO: 4.00 A  (Máx Fusible: 5.0 A)"
	lbl_hud_objetivo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_hud_objetivo.add_theme_font_size_override("font_size", 14)
	lbl_hud_objetivo.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0))
	hbox_hud.add_child(lbl_hud_objetivo)

	lbl_hud_actual = Label.new()
	lbl_hud_actual.text = "ACTUAL: 3.00 A"
	lbl_hud_actual.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_hud_actual.add_theme_font_size_override("font_size", 15)
	hbox_hud.add_child(lbl_hud_actual)

	barra_progreso = ProgressBar.new()
	barra_progreso.custom_minimum_size = Vector2(0, 16)
	barra_progreso.min_value = 0.0
	barra_progreso.max_value = CORRIENTE_MAX_FUSIBLE
	barra_progreso.show_percentage = false
	barra_progreso.focus_mode = Control.FOCUS_NONE
	vbox_hud.add_child(barra_progreso)

	# Esquema visual simple del circuito (Line2D + ColorRect + pulsos)
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

	# Lazo de cables (Line2D)
	cable_loop_vis = Line2D.new()
	cable_loop_vis.width = 3.0
	cable_loop_vis.points = PackedVector2Array([
		Vector2(90, 34),
		Vector2(490, 34),
		Vector2(490, 134),
		Vector2(90, 134),
		Vector2(90, 34)
	])
	caja_esquema.add_child(cable_loop_vis)

	# Pulsos animados de corriente sobre el lazo
	pulsos_circuito_vis.clear()
	for i in range(8):
		var p := ColorRect.new()
		p.size = Vector2(8, 8)
		caja_esquema.add_child(p)
		pulsos_circuito_vis.append(p)

	# Bloque Izquierdo: Fuente de Voltaje V
	bloque_fuente_vis = ColorRect.new()
	bloque_fuente_vis.position = Vector2(36, 52)
	bloque_fuente_vis.size = Vector2(108, 64)
	bloque_fuente_vis.color = Color(0.1, 0.25, 0.42)
	caja_esquema.add_child(bloque_fuente_vis)

	lbl_fuente_vis = Label.new()
	lbl_fuente_vis.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl_fuente_vis.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_fuente_vis.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_fuente_vis.add_theme_font_size_override("font_size", 13)
	bloque_fuente_vis.add_child(lbl_fuente_vis)

	# Bloque Superior: Fusible 5.0 A con filamento Line2D
	bloque_fusible_vis = ColorRect.new()
	bloque_fusible_vis.position = Vector2(215, 14)
	bloque_fusible_vis.size = Vector2(150, 40)
	bloque_fusible_vis.color = Color(0.08, 0.16, 0.22)
	caja_esquema.add_child(bloque_fusible_vis)

	filamento_intacto_vis = Line2D.new()
	filamento_intacto_vis.width = 3.0
	filamento_intacto_vis.default_color = Color(0.35, 1.0, 0.6)
	filamento_intacto_vis.points = PackedVector2Array([Vector2(14, 28), Vector2(136, 28)])
	bloque_fusible_vis.add_child(filamento_intacto_vis)

	filamento_roto_izq_vis = Line2D.new()
	filamento_roto_izq_vis.width = 3.0
	filamento_roto_izq_vis.default_color = Color(1.0, 0.3, 0.3)
	filamento_roto_izq_vis.points = PackedVector2Array([Vector2(14, 28), Vector2(58, 22)])
	filamento_roto_izq_vis.visible = false
	bloque_fusible_vis.add_child(filamento_roto_izq_vis)

	filamento_roto_der_vis = Line2D.new()
	filamento_roto_der_vis.width = 3.0
	filamento_roto_der_vis.default_color = Color(1.0, 0.3, 0.3)
	filamento_roto_der_vis.points = PackedVector2Array([Vector2(92, 33), Vector2(136, 28)])
	filamento_roto_der_vis.visible = false
	bloque_fusible_vis.add_child(filamento_roto_der_vis)

	lbl_fusible_vis = Label.new()
	lbl_fusible_vis.position = Vector2(0, 2)
	lbl_fusible_vis.size = Vector2(150, 20)
	lbl_fusible_vis.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_fusible_vis.add_theme_font_size_override("font_size", 11)
	bloque_fusible_vis.add_child(lbl_fusible_vis)

	# Bloque Derecho: Resistencia R con trazo zigzag Line2D
	bloque_resistor_vis = ColorRect.new()
	bloque_resistor_vis.position = Vector2(436, 52)
	bloque_resistor_vis.size = Vector2(108, 64)
	bloque_resistor_vis.color = Color(0.24, 0.16, 0.1)
	caja_esquema.add_child(bloque_resistor_vis)

	zigzag_r_vis = Line2D.new()
	zigzag_r_vis.width = 2.5
	zigzag_r_vis.default_color = Color(1.0, 0.72, 0.3)
	zigzag_r_vis.points = PackedVector2Array([
		Vector2(14, 46), Vector2(28, 38), Vector2(42, 52),
		Vector2(56, 38), Vector2(70, 52), Vector2(84, 38), Vector2(94, 46)
	])
	bloque_resistor_vis.add_child(zigzag_r_vis)

	lbl_resistor_vis = Label.new()
	lbl_resistor_vis.position = Vector2(0, 6)
	lbl_resistor_vis.size = Vector2(108, 24)
	lbl_resistor_vis.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_resistor_vis.add_theme_font_size_override("font_size", 13)
	bloque_resistor_vis.add_child(lbl_resistor_vis)

	# Bloque Inferior: Motor del Puente (Meta 4.0 A)
	bloque_motor_vis = ColorRect.new()
	bloque_motor_vis.position = Vector2(205, 114)
	bloque_motor_vis.size = Vector2(170, 38)
	bloque_motor_vis.color = Color(0.14, 0.18, 0.26)
	caja_esquema.add_child(bloque_motor_vis)

	lbl_motor_vis = Label.new()
	lbl_motor_vis.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl_motor_vis.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_motor_vis.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_motor_vis.add_theme_font_size_override("font_size", 12)
	bloque_motor_vis.add_child(lbl_motor_vis)

	# Controles Interactivos Directos: 1) Voltaje V
	var hbox_v := HBoxContainer.new()
	hbox_v.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_v.add_theme_constant_override("separation", 10)
	vbox_p.add_child(hbox_v)

	var lbl_v_tag := Label.new()
	lbl_v_tag.text = "VOLTAJE (V):"
	lbl_v_tag.custom_minimum_size = Vector2(130, 0)
	lbl_v_tag.add_theme_font_size_override("font_size", 13)
	hbox_v.add_child(lbl_v_tag)

	var btn_v_menos := Button.new()
	btn_v_menos.text = "◀ [Q / ↓]"
	btn_v_menos.custom_minimum_size = Vector2(90, 34)
	btn_v_menos.focus_mode = Control.FOCUS_NONE
	btn_v_menos.pressed.connect(func(): _cambiar_voltaje(-1))
	hbox_v.add_child(btn_v_menos)

	slider_v = HSlider.new()
	slider_v.min_value = 0
	slider_v.max_value = voltajes_disponibles.size() - 1
	slider_v.step = 1
	slider_v.value = idx_v
	slider_v.custom_minimum_size = Vector2(170, 28)
	slider_v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider_v.focus_mode = Control.FOCUS_NONE
	slider_v.value_changed.connect(_on_slider_v_changed)
	hbox_v.add_child(slider_v)

	var btn_v_mas := Button.new()
	btn_v_mas.text = "[W / ↑] ▶"
	btn_v_mas.custom_minimum_size = Vector2(90, 34)
	btn_v_mas.focus_mode = Control.FOCUS_NONE
	btn_v_mas.pressed.connect(func(): _cambiar_voltaje(1))
	hbox_v.add_child(btn_v_mas)

	lbl_val_v = Label.new()
	lbl_val_v.custom_minimum_size = Vector2(75, 0)
	lbl_val_v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_val_v.add_theme_font_size_override("font_size", 15)
	lbl_val_v.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	hbox_v.add_child(lbl_val_v)

	# Controles Interactivos Directos: 2) Resistencia R
	var hbox_r := HBoxContainer.new()
	hbox_r.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_r.add_theme_constant_override("separation", 10)
	vbox_p.add_child(hbox_r)

	var lbl_r_tag := Label.new()
	lbl_r_tag.text = "RESISTENCIA (R):"
	lbl_r_tag.custom_minimum_size = Vector2(130, 0)
	lbl_r_tag.add_theme_font_size_override("font_size", 13)
	hbox_r.add_child(lbl_r_tag)

	var btn_r_menos := Button.new()
	btn_r_menos.text = "◀ [A / ←]"
	btn_r_menos.custom_minimum_size = Vector2(90, 34)
	btn_r_menos.focus_mode = Control.FOCUS_NONE
	btn_r_menos.pressed.connect(func(): _cambiar_resistencia(-1))
	hbox_r.add_child(btn_r_menos)

	slider_r = HSlider.new()
	slider_r.min_value = 0
	slider_r.max_value = resistencias_disponibles.size() - 1
	slider_r.step = 1
	slider_r.value = idx_r
	slider_r.custom_minimum_size = Vector2(170, 28)
	slider_r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider_r.focus_mode = Control.FOCUS_NONE
	slider_r.value_changed.connect(_on_slider_r_changed)
	hbox_r.add_child(slider_r)

	var btn_r_mas := Button.new()
	btn_r_mas.text = "[D / →] ▶"
	btn_r_mas.custom_minimum_size = Vector2(90, 34)
	btn_r_mas.focus_mode = Control.FOCUS_NONE
	btn_r_mas.pressed.connect(func(): _cambiar_resistencia(1))
	hbox_r.add_child(btn_r_mas)

	lbl_val_r = Label.new()
	lbl_val_r.custom_minimum_size = Vector2(75, 0)
	lbl_val_r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_val_r.add_theme_font_size_override("font_size", 15)
	lbl_val_r.add_theme_color_override("font_color", Color(1.0, 0.78, 0.35))
	hbox_r.add_child(lbl_val_r)

	# Fila de acciones: Reemplazar fusible + Confirmar/Cerrar
	var hbox_acciones := HBoxContainer.new()
	hbox_acciones.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_acciones.add_theme_constant_override("separation", 12)
	vbox_p.add_child(hbox_acciones)

	btn_reemplazar_fusible = Button.new()
	btn_reemplazar_fusible.text = "🔧 [R] REEMPLAZAR FUSIBLE QUEMADO"
	btn_reemplazar_fusible.custom_minimum_size = Vector2(260, 40)
	btn_reemplazar_fusible.focus_mode = Control.FOCUS_NONE
	btn_reemplazar_fusible.add_theme_stylebox_override("normal", _crear_estilo_boton(Color(0.55, 0.14, 0.14, 0.98), Color(1.0, 0.4, 0.4)))
	btn_reemplazar_fusible.add_theme_stylebox_override("hover", _crear_estilo_boton(Color(0.68, 0.18, 0.18, 1.0), Color(1.0, 0.6, 0.6)))
	btn_reemplazar_fusible.pressed.connect(_reemplazar_fusible)
	btn_reemplazar_fusible.visible = false
	hbox_acciones.add_child(btn_reemplazar_fusible)

	var btn_confirmar := Button.new()
	btn_confirmar.text = "[ APLICAR Y VOLVER AL NIVEL ]  (Enter / Espacio / E / Esc)"
	btn_confirmar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_confirmar.custom_minimum_size = Vector2(0, 40)
	btn_confirmar.focus_mode = Control.FOCUS_NONE
	btn_confirmar.add_theme_stylebox_override("normal", _crear_estilo_boton(Color(0.08, 0.34, 0.24, 0.96), Color(0.3, 0.95, 0.55)))
	btn_confirmar.add_theme_stylebox_override("hover", _crear_estilo_boton(Color(0.12, 0.46, 0.32, 0.98), Color(0.45, 1.0, 0.7)))
	btn_confirmar.add_theme_font_size_override("font_size", 14)
	btn_confirmar.pressed.connect(_cerrar_todo)
	hbox_acciones.add_child(btn_confirmar)

	var lbl_keys := Label.new()
	lbl_keys.text = "Atajos: [Q/W o ↓/↑] Voltaje  |  [A/D o ←/→] Resistencia  |  [R] Fusible  |  [Enter/Espacio/E/Esc] Cerrar"
	lbl_keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_keys.add_theme_font_size_override("font_size", 11)
	lbl_keys.add_theme_color_override("font_color", Color(0.62, 0.76, 0.88))
	vbox_p.add_child(lbl_keys)

func _on_slider_v_changed(valor: float) -> void:
	if _actualizando_ui:
		return
	if fusible_quemado:
		_actualizando_ui = true
		slider_v.value = idx_v
		_actualizando_ui = false
		return
	idx_v = clampi(int(round(valor)), 0, voltajes_disponibles.size() - 1)
	_actualizar_circuito()

func _on_slider_r_changed(valor: float) -> void:
	if _actualizando_ui:
		return
	if fusible_quemado:
		_actualizando_ui = true
		slider_r.value = idx_r
		_actualizando_ui = false
		return
	idx_r = clampi(int(round(valor)), 0, resistencias_disponibles.size() - 1)
	_actualizar_circuito()

func _cambiar_voltaje(delta_idx: int) -> void:
	if fusible_quemado:
		return
	idx_v = clampi(idx_v + delta_idx, 0, voltajes_disponibles.size() - 1)
	_actualizar_circuito()

func _cambiar_resistencia(delta_idx: int) -> void:
	if fusible_quemado:
		return
	idx_r = clampi(idx_r + delta_idx, 0, resistencias_disponibles.size() - 1)
	_actualizar_circuito()

func _reemplazar_fusible() -> void:
	fusible_quemado = false
	idx_r = resistencias_disponibles.size() - 1
	_actualizar_circuito()

func _actualizar_circuito() -> void:
	_actualizando_ui = true
	var v_actual: float = voltajes_disponibles[idx_v]
	var r_actual: float = resistencias_disponibles[idx_r]
	var i_teorica: float = v_actual / r_actual

	if not fusible_quemado and i_teorica > CORRIENTE_MAX_FUSIBLE + 0.01:
		fusible_quemado = true

	var estaba_activo := puente_activo

	if slider_v:
		slider_v.value = idx_v
		slider_v.editable = not fusible_quemado
	if slider_r:
		slider_r.value = idx_r
		slider_r.editable = not fusible_quemado
	if lbl_val_v:
		lbl_val_v.text = "%.0f V" % v_actual
	if lbl_val_r:
		lbl_val_r.text = "%.0f Ω" % r_actual

	var fill_sb := StyleBoxFlat.new()
	fill_sb.set_corner_radius_all(4)

	if fusible_quemado:
		puente_activo = false
		if btn_reemplazar_fusible:
			btn_reemplazar_fusible.visible = true
		if lbl_hud_actual:
			lbl_hud_actual.text = "ACTUAL: ¡%.1f A > 5.0 A! (FUSIBLE QUEMADO)" % i_teorica
			lbl_hud_actual.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
			barra_progreso.value = CORRIENTE_MAX_FUSIBLE
			fill_sb.bg_color = Color(0.95, 0.22, 0.22)
			barra_progreso.add_theme_stylebox_override("fill", fill_sb)
		lbl_estado_puente.text = "💥 FUSIBLE QUEMADO (%.1f A > 5 A)" % i_teorica
		lbl_estado_puente.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		puente_sprite.modulate = Color(0.45, 0.2, 0.2, 0.6)
	else:
		if btn_reemplazar_fusible:
			btn_reemplazar_fusible.visible = false
		puente_activo = is_equal_approx(i_teorica, CORRIENTE_META)

		if lbl_hud_actual:
			barra_progreso.value = clampf(i_teorica, 0.0, CORRIENTE_MAX_FUSIBLE)
			if puente_activo:
				lbl_hud_actual.text = "ACTUAL: %.2f A (¡PUENTE ACTIVO!)" % i_teorica
				lbl_hud_actual.add_theme_color_override("font_color", Color(0.3, 1.0, 0.55))
				fill_sb.bg_color = Color(0.25, 0.95, 0.5)
			else:
				lbl_hud_actual.text = "ACTUAL: %.2f A" % i_teorica
				lbl_hud_actual.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
				fill_sb.bg_color = Color(0.95, 0.72, 0.2)
			barra_progreso.add_theme_stylebox_override("fill", fill_sb)

		if puente_activo:
			lbl_estado_puente.text = "⚡ PUENTE ENERGIZADO (I = 4.0 A)"
			lbl_estado_puente.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
			puente_sprite.modulate = Color(0.4, 1.0, 0.7, 1.0)
		else:
			lbl_estado_puente.text = "Puente Apagado: I = %.1f / 4.0 A" % i_teorica
			lbl_estado_puente.add_theme_color_override("font_color", Color(1.0, 0.8, 0.35))
			puente_sprite.modulate = Color(0.6, 0.65, 0.75, 0.55)

	# Actualizar bloques del esquema visual
	if bloque_fuente_vis:
		lbl_fuente_vis.text = "FUENTE\nV = %.0f V" % v_actual
		lbl_resistor_vis.text = "R = %.0f Ω" % r_actual
		zigzag_r_vis.width = 1.8 + (r_actual / 12.0) * 2.8

		filamento_intacto_vis.visible = not fusible_quemado
		filamento_roto_izq_vis.visible = fusible_quemado
		filamento_roto_der_vis.visible = fusible_quemado
		if fusible_quemado:
			lbl_fusible_vis.text = "💥 FUSIBLE ROTO ([R])"
			lbl_fusible_vis.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
			bloque_fusible_vis.color = Color(0.32, 0.08, 0.1)
			cable_loop_vis.default_color = Color(0.55, 0.2, 0.2, 0.65)
			cable_loop_vis.width = 2.0
			bloque_motor_vis.color = Color(0.18, 0.1, 0.12)
			lbl_motor_vis.text = "PUENTE SIN CORRIENTE (0 A)"
		else:
			lbl_fusible_vis.text = "FUSIBLE 5.0 A [OK]"
			lbl_fusible_vis.add_theme_color_override("font_color", Color(0.45, 1.0, 0.65))
			bloque_fusible_vis.color = Color(0.08, 0.18, 0.22)
			cable_loop_vis.width = 2.0 + clampf(i_teorica / 5.0, 0.0, 1.0) * 3.0
			if puente_activo:
				cable_loop_vis.default_color = Color(0.25, 1.0, 0.55, 0.95)
				bloque_motor_vis.color = Color(0.1, 0.42, 0.24)
				lbl_motor_vis.text = "⚡ PUENTE ACTIVO (4.0 A)"
			else:
				cable_loop_vis.default_color = Color(0.95, 0.78, 0.25, 0.85)
				bloque_motor_vis.color = Color(0.14, 0.18, 0.26)
				lbl_motor_vis.text = "MOTOR PUENTE (%.1f / 4.0 A)" % i_teorica

	puente_col.set_deferred("disabled", not puente_activo)
	barrera_col.set_deferred("disabled", puente_activo)
	barrera_visual.visible = not puente_activo

	var pos_objetivo := POS_PUENTE_ACTIVO if puente_activo else POS_PUENTE_APAGADO
	if estaba_activo != puente_activo and is_inside_tree():
		var tw := create_tween()
		tw.tween_property(puente_body, "position", pos_objetivo, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		puente_body.position = pos_objetivo

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
	_actualizar_circuito()

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
	_actualizar_circuito()

func _cerrar_todo() -> void:
	fondo_oscuro.visible = false
	panel_nota.visible = false
	panel_puzzle.visible = false
	_ocultar_textos_mundo(false)
	_congelar_jugador(false)
	lbl_prompt.visible = jugador_cerca

func _verificar_solapamiento() -> void:
	if not area_tablero or not area_tablero.monitoring:
		return
	var detectado := false
	for b in area_tablero.get_overlapping_bodies():
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
			elif fusible_quemado and kc == KEY_R:
				_reemplazar_fusible()
				get_viewport().set_input_as_handled()
			elif kc in [KEY_Q, KEY_DOWN]:
				_cambiar_voltaje(-1)
				get_viewport().set_input_as_handled()
			elif kc in [KEY_W, KEY_UP]:
				_cambiar_voltaje(1)
				get_viewport().set_input_as_handled()
			elif kc in [KEY_A, KEY_LEFT]:
				_cambiar_resistencia(-1)
				get_viewport().set_input_as_handled()
			elif kc in [KEY_D, KEY_RIGHT]:
				_cambiar_resistencia(1)
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
	_verificar_solapamiento()
	_animar_pulsos_circuito(delta)

	var e_actual: bool = Input.is_physical_key_pressed(KEY_E) or Input.is_key_pressed(KEY_E)
	if e_actual and not _tecla_e_prev and not _esta_modal_abierto() and jugador_cerca:
		_abrir_fluido()
	_tecla_e_prev = e_actual

func _animar_pulsos_circuito(delta: float) -> void:
	if not panel_puzzle or not panel_puzzle.visible:
		return
	var v_actual: float = voltajes_disponibles[idx_v]
	var r_actual: float = resistencias_disponibles[idx_r]
	var i_real: float = 0.0 if fusible_quemado else (v_actual / r_actual)

	fase_pulsos = fmod(fase_pulsos + delta * i_real * 0.18, 1.0)
	var col_p := Color(0.3, 1.0, 0.55) if puente_activo else Color(1.0, 0.85, 0.3)

	for i in range(pulsos_circuito_vis.size()):
		var p := pulsos_circuito_vis[i]
		p.visible = not fusible_quemado
		p.color = col_p
		var t := fmod(fase_pulsos + float(i) / float(pulsos_circuito_vis.size()), 1.0)
		p.position = _punto_en_rectangulo(t) - Vector2(4, 4)

func _punto_en_rectangulo(t: float) -> Vector2:
	# Perímetro sobre ruta_pulsos (400 x 100 -> total 1000 px)
	var dist := t * 1000.0
	if dist < 400.0:
		return ruta_pulsos[0].lerp(ruta_pulsos[1], dist / 400.0)
	elif dist < 500.0:
		return ruta_pulsos[1].lerp(ruta_pulsos[2], (dist - 400.0) / 100.0)
	elif dist < 900.0:
		return ruta_pulsos[2].lerp(ruta_pulsos[3], (dist - 500.0) / 400.0)
	else:
		return ruta_pulsos[3].lerp(ruta_pulsos[0], (dist - 900.0) / 100.0)

func _draw() -> void:
	var col_cable := Color(0.3, 1.0, 0.55, 0.9) if puente_activo else (Color(1.0, 0.3, 0.3, 0.85) if fusible_quemado else Color(1.0, 0.8, 0.3, 0.75))
	draw_polyline(PackedVector2Array([
		POS_TABLERO + Vector2(0, 20),
		Vector2(POS_TABLERO.x, 12),
		Vector2(592, 12),
		puente_body.position
	]), col_cable, 3.0)

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
