extends Node2D

# ==============================================================================
# PUZZLE 2 (NIVEL 3 - TRAMO 2): TENSIÓN TÁCTICA E INDUCCIÓN DE FARADAY
# ε = N · f · ΔΦ_B
# - Incluye plataformas tácticas elevadas, un Núcleo Secundario custodiado por
#   enemigos en (1920, -96) que desbloquea la Barrera de Contención (2515, -56),
#   cables de energía (Line2D) e indicadores luminosos (ColorRect) reactivos.
# - Consola interactiva limpia (PanelContainer alfa ~0.95 en CanvasLayer 10)
#   con simulación en tiempo real de imán oscilante + osciloscopio Line2D.
# ==============================================================================

const GRUPO_TEXTOS_MUNDO := "texto_mundo_nivel3"

const POS_NUCLEO_SECUNDARIO := Vector2(1920, -96)
const POS_BARRERA_LASER := Vector2(2515, -56)
const POS_TERMINAL := Vector2(2595, -32)
const POS_GENERADOR := Vector2(2675, -36)
const POS_COMPUERTA_CERRADA := Vector2(2728, -56)
const POS_COMPUERTA_ABIERTA := Vector2(2728, -168)
const POS_PUENTE_INDUCCION := Vector2(2872, 8)

const VALORES_ESPIRAS: Array[int] = [20, 30, 40, 50, 60]
const VALORES_FRECUENCIA: Array[float] = [1.0, 2.0, 3.0, 4.0, 5.0]
const FLUJO_BASE_WB: float = 1.0
const VOLTAJE_OBJETIVO: float = 120.0
const VOLTAJE_MAX_BARRA: float = 200.0

var idx_espiras: int = 1      # 30 espiras inicial
var idx_frecuencia: int = 1   # 2.0 Hz inicial -> 60.0 V inicial
var nucleo_secundario_activo: bool = false
var completado: bool = false
var tiempo_sim: float = 0.0

var jugador_cerca_terminal: bool = false
var jugador_cerca_nucleo: bool = false
var jugador_ref: Node2D = null
var area_terminal_ref: Area2D = null
var area_nucleo_ref: Area2D = null
var _tecla_e_prev: bool = false

# Nodos del mundo
var barrera_laser_body: StaticBody2D
var barrera_laser_col: CollisionShape2D
var barrera_laser_visual: ColorRect
var luz_nucleo_rect: ColorRect
var lbl_prompt_nucleo: Label
var lbl_estado_nucleo: Label

var iman_mundo: Node2D
var compuerta_body: StaticBody2D
var compuerta_col: CollisionShape2D
var puente_ind_body: StaticBody2D
var puente_ind_col: CollisionShape2D
var puente_ind_sprite: Sprite2D
var lbl_prompt: Label
var lbl_estado_mundo: Label

var cables_tramo2_entrada: Array[Line2D] = []
var cables_tramo2_salida: Array[Line2D] = []
var luces_tramo2_entrada: Array[ColorRect] = []
var luces_tramo2_salida: Array[ColorRect] = []

# Nodos UI
var ui_layer: CanvasLayer
var panel_ui: PanelContainer
var lbl_objetivo_actual: Label
var barra_progreso: ProgressBar
var fill_style_barra: StyleBoxFlat
var lienzo_simulacion: Control
var linea_onda_objetivo: Line2D
var linea_onda_actual: Line2D
var lbl_operacion_corta: Label
var lbl_estado_corto: Label
var btn_esp_menos: Button
var btn_esp_mas: Button
var lbl_val_espiras: Label
var btn_frec_menos: Button
var btn_frec_mas: Button
var lbl_val_frecuencia: Label
var btn_confirmar_accion: Button

func _ready() -> void:
	_construir_tramo_2_tactico()
	_crear_nucleo_secundario_y_barrera()
	_crear_generador_y_compuerta()
	_crear_terminal()
	_crear_ui()
	_actualizar_visuales()

# ==============================================================================
# TRAMO 2: CABLES E INTERRUPTOR SECUNDARIO
# ==============================================================================
func _construir_tramo_2_tactico() -> void:
	var contenedor := Node2D.new()
	contenedor.name = "EscenarioTramo2Tactico"
	add_child(contenedor)

	# Cableado de entrada (Tramo 1 -> Núcleo Secundario -> Barrera / Terminal Faraday)
	var pts_entrada := PackedVector2Array([
		Vector2(1320, 26),
		Vector2(1580, 26),
		Vector2(1580, -54),
		Vector2(1920, -54),
		Vector2(2240, -54),
		Vector2(2240, 26),
		Vector2(2515, 26),
		Vector2(2595, 26),
		Vector2(2595, -28)
	])
	var cable_in := _crear_cable_energia(contenedor, pts_entrada)
	cables_tramo2_entrada.append(cable_in)

	for pt in [Vector2(1580, -54), Vector2(1920, -54), Vector2(2240, -54), Vector2(2515, 26)]:
		luces_tramo2_entrada.append(_crear_indicador_luz(contenedor, pt))

	# Cableado de salida (Generador Faraday -> Compuerta -> Pasarela -> Sala Maestra Tramo 3)
	var pts_salida := PackedVector2Array([
		POS_GENERADOR,
		Vector2(POS_COMPUERTA_CERRADA.x, POS_GENERADOR.y),
		POS_PUENTE_INDUCCION,
		Vector2(3030, 8),
		Vector2(3030, 26),
		Vector2(3200, 26)
	])
	var cable_out := _crear_cable_energia(contenedor, pts_salida)
	cables_tramo2_salida.append(cable_out)

	for pt in [Vector2(2675, 26), Vector2(2728, 26), Vector2(2872, 26), Vector2(3040, 26)]:
		luces_tramo2_salida.append(_crear_indicador_luz(contenedor, pt))

func _crear_cable_energia(padre: Node2D, puntos: PackedVector2Array) -> Line2D:
	var base := Line2D.new()
	base.points = puntos
	base.width = 7.0
	base.default_color = Color(0.08, 0.1, 0.14, 0.9)
	base.z_index = -3
	padre.add_child(base)

	var linea := Line2D.new()
	linea.points = puntos
	linea.width = 3.0
	linea.default_color = Color(0.85, 0.22, 0.25, 0.75)
	linea.z_index = -2
	padre.add_child(linea)
	return linea

func _crear_indicador_luz(padre: Node2D, pos: Vector2) -> ColorRect:
	var marco := ColorRect.new()
	marco.position = pos - Vector2(7, 7)
	marco.size = Vector2(14, 14)
	marco.color = Color(0.06, 0.08, 0.12, 0.95)
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marco.z_index = -1
	padre.add_child(marco)

	var luz := ColorRect.new()
	luz.position = pos - Vector2(4, 4)
	luz.size = Vector2(8, 8)
	luz.color = Color(0.9, 0.22, 0.25, 0.9)
	luz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	luz.z_index = -1
	padre.add_child(luz)
	return luz

func _crear_nucleo_secundario_y_barrera() -> void:
	# 1. Interruptor / Núcleo Secundario en la plataforma táctica (1920, -96)
	var area_n := Area2D.new()
	area_nucleo_ref = area_n
	area_n.name = "NucleoSecundarioTramo2"
	area_n.position = POS_NUCLEO_SECUNDARIO
	area_n.monitoring = true
	area_n.monitorable = true
	area_n.collision_layer = 0
	area_n.collision_mask = 1
	area_n.input_pickable = true
	add_child(area_n)

	var col_n := CollisionShape2D.new()
	var rect_n := RectangleShape2D.new()
	rect_n.size = Vector2(96, 86)
	col_n.shape = rect_n
	area_n.add_child(col_n)

	var torre_base := ColorRect.new()
	torre_base.position = Vector2(-18, -22)
	torre_base.size = Vector2(36, 44)
	torre_base.color = Color(0.14, 0.18, 0.26, 0.98)
	torre_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area_n.add_child(torre_base)

	luz_nucleo_rect = ColorRect.new()
	luz_nucleo_rect.position = Vector2(-11, -14)
	luz_nucleo_rect.size = Vector2(22, 22)
	luz_nucleo_rect.color = Color(0.95, 0.25, 0.25, 0.95)
	luz_nucleo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area_n.add_child(luz_nucleo_rect)

	lbl_estado_nucleo = Label.new()
	lbl_estado_nucleo.position = Vector2(-120, -56)
	lbl_estado_nucleo.size = Vector2(240, 22)
	lbl_estado_nucleo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_estado_nucleo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_estado_nucleo.add_theme_font_size_override("font_size", 11)
	lbl_estado_nucleo.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_estado_nucleo.add_theme_constant_override("outline_size", 4)
	lbl_estado_nucleo.add_to_group(GRUPO_TEXTOS_MUNDO)
	area_n.add_child(lbl_estado_nucleo)

	lbl_prompt_nucleo = Label.new()
	lbl_prompt_nucleo.text = "[E] Activar Núcleo Secundario"
	lbl_prompt_nucleo.position = Vector2(-115, -38)
	lbl_prompt_nucleo.size = Vector2(230, 20)
	lbl_prompt_nucleo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_prompt_nucleo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_prompt_nucleo.add_theme_font_size_override("font_size", 12)
	lbl_prompt_nucleo.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	lbl_prompt_nucleo.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_prompt_nucleo.add_theme_constant_override("outline_size", 4)
	lbl_prompt_nucleo.visible = false
	lbl_prompt_nucleo.add_to_group(GRUPO_TEXTOS_MUNDO)
	area_n.add_child(lbl_prompt_nucleo)

	area_n.body_entered.connect(_on_nucleo_body_entered)
	area_n.body_exited.connect(_on_nucleo_body_exited)
	area_n.input_event.connect(_on_nucleo_input_event)

	# 2. Barrera Láser de Contención en (2515, -56) que protege la consola de Faraday
	barrera_laser_body = StaticBody2D.new()
	barrera_laser_body.name = "BarreraContencionTramo2"
	barrera_laser_body.position = POS_BARRERA_LASER
	barrera_laser_body.collision_layer = 16
	barrera_laser_body.collision_mask = 1
	add_child(barrera_laser_body)

	barrera_laser_col = CollisionShape2D.new()
	var rect_b := RectangleShape2D.new()
	rect_b.size = Vector2(14, 112)
	barrera_laser_col.shape = rect_b
	barrera_laser_body.add_child(barrera_laser_col)

	barrera_laser_visual = ColorRect.new()
	barrera_laser_visual.position = Vector2(-5, -56)
	barrera_laser_visual.size = Vector2(10, 112)
	barrera_laser_visual.color = Color(1.0, 0.22, 0.28, 0.85)
	barrera_laser_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barrera_laser_body.add_child(barrera_laser_visual)

func _activar_nucleo_secundario() -> void:
	if nucleo_secundario_activo:
		return
	nucleo_secundario_activo = true
	barrera_laser_col.set_deferred("disabled", true)
	if barrera_laser_visual:
		barrera_laser_visual.visible = false
	_actualizar_visuales()

func _crear_generador_y_compuerta() -> void:
	# 1. Bobina Generadora de Faraday en el mundo
	var gen_node := Node2D.new()
	gen_node.position = POS_GENERADOR
	add_child(gen_node)

	var spr_gen := Sprite2D.new()
	var tex_gen := load("res://assets/nivel_3/generador_faraday.svg") as Texture2D
	if tex_gen:
		spr_gen.texture = tex_gen
	gen_node.add_child(spr_gen)

	# Imán N-S móvil que entra y sale de la bobina en el mundo
	iman_mundo = Node2D.new()
	iman_mundo.position = Vector2(0, -18)
	gen_node.add_child(iman_mundo)

	var polo_n := Polygon2D.new()
	polo_n.polygon = PackedVector2Array([Vector2(-24, -7), Vector2(0, -7), Vector2(0, 7), Vector2(-24, 7)])
	polo_n.color = Color(0.95, 0.25, 0.25)
	iman_mundo.add_child(polo_n)

	var polo_s := Polygon2D.new()
	polo_s.polygon = PackedVector2Array([Vector2(0, -7), Vector2(24, -7), Vector2(24, 7), Vector2(0, 7)])
	polo_s.color = Color(0.25, 0.55, 0.95)
	iman_mundo.add_child(polo_s)

	# 2. Compuerta de Inducción en Capa 5 (Suelo = 16)
	compuerta_body = StaticBody2D.new()
	compuerta_body.name = "CompuertaFaraday"
	compuerta_body.position = POS_COMPUERTA_CERRADA
	compuerta_body.collision_layer = 16
	compuerta_body.collision_mask = 1
	add_child(compuerta_body)

	compuerta_col = CollisionShape2D.new()
	var rect_c := RectangleShape2D.new()
	rect_c.size = Vector2(22, 112)
	compuerta_col.shape = rect_c
	compuerta_body.add_child(compuerta_col)

	var poly_c := Polygon2D.new()
	poly_c.polygon = PackedVector2Array([
		Vector2(-10, -56), Vector2(10, -56), Vector2(10, 56), Vector2(-10, 56)
	])
	poly_c.color = Color(0.95, 0.65, 0.15, 0.9)
	compuerta_body.add_child(poly_c)

	# 3. Pasarela de Inducción sobre el foso (x = 2736..3008, y = 8)
	puente_ind_body = StaticBody2D.new()
	puente_ind_body.name = "PuenteInduccion"
	puente_ind_body.position = POS_PUENTE_INDUCCION
	puente_ind_body.collision_layer = 16
	puente_ind_body.collision_mask = 1
	add_child(puente_ind_body)

	puente_ind_col = CollisionShape2D.new()
	var rect_p := RectangleShape2D.new()
	rect_p.size = Vector2(280, 20)
	puente_ind_col.shape = rect_p
	puente_ind_col.disabled = true
	puente_ind_body.add_child(puente_ind_col)

	puente_ind_sprite = Sprite2D.new()
	var tex_p := load("res://assets/nivel_3/puente_metalico.svg") as Texture2D
	if tex_p:
		puente_ind_sprite.texture = tex_p
		puente_ind_sprite.scale = Vector2(1.75, 1.0)
	puente_ind_body.add_child(puente_ind_sprite)

	lbl_estado_mundo = Label.new()
	lbl_estado_mundo.position = Vector2(POS_GENERADOR.x - 135, -122)
	lbl_estado_mundo.size = Vector2(270, 40)
	lbl_estado_mundo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_estado_mundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_estado_mundo.add_theme_font_size_override("font_size", 12)
	lbl_estado_mundo.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_estado_mundo.add_theme_constant_override("outline_size", 4)
	lbl_estado_mundo.add_to_group(GRUPO_TEXTOS_MUNDO)
	add_child(lbl_estado_mundo)

func _crear_terminal() -> void:
	var area := Area2D.new()
	area_terminal_ref = area
	area.name = "PalancaFaraday"
	area.position = POS_TERMINAL
	area.monitoring = true
	area.monitorable = true
	area.collision_layer = 0
	area.collision_mask = 1
	area.input_pickable = true
	add_child(area)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(120, 120)
	col.shape = rect
	area.add_child(col)

	var spr := Sprite2D.new()
	var tex := load("res://assets/nivel_3/panel_magnetico.svg") as Texture2D
	if tex:
		spr.texture = tex
	area.add_child(spr)

	lbl_prompt = Label.new()
	lbl_prompt.text = "[E] Interactuar"
	lbl_prompt.position = Vector2(-105, -62)
	lbl_prompt.size = Vector2(210, 24)
	lbl_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_prompt.add_theme_font_size_override("font_size", 13)
	lbl_prompt.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	lbl_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_prompt.add_theme_constant_override("outline_size", 4)
	lbl_prompt.visible = false
	lbl_prompt.add_to_group(GRUPO_TEXTOS_MUNDO)
	area.add_child(lbl_prompt)

	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	area.input_event.connect(_on_area_input_event)

# ==============================================================================
# CONSOLA DE ALTO NIVEL INTERACTIVO (CERO MUROS DE TEXTO)
# ==============================================================================
func _crear_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)

	panel_ui = PanelContainer.new()
	panel_ui.custom_minimum_size = Vector2(650, 440)
	panel_ui.set_anchors_preset(Control.PRESET_CENTER)
	panel_ui.offset_left = -325
	panel_ui.offset_top = -220
	panel_ui.offset_right = 325
	panel_ui.offset_bottom = 220
	panel_ui.visible = false

	var style_panel := StyleBoxFlat.new()
	style_panel.bg_color = Color(0.06, 0.08, 0.13, 0.96)
	style_panel.border_color = Color(0.3, 0.85, 1.0, 0.9)
	style_panel.set_border_width_all(2)
	style_panel.set_corner_radius_all(10)
	style_panel.content_margin_left = 20
	style_panel.content_margin_right = 20
	style_panel.content_margin_top = 14
	style_panel.content_margin_bottom = 14
	panel_ui.add_theme_stylebox_override("panel", style_panel)
	ui_layer.add_child(panel_ui)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel_ui.add_child(vbox)

	var titulo := Label.new()
	titulo.text = "GENERADOR DE INDUCCIÓN DE FARADAY — CALIBRACIÓN EN TIEMPO REAL"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 15)
	titulo.add_theme_color_override("font_color", Color(0.4, 0.92, 1.0))
	vbox.add_child(titulo)

	lbl_objetivo_actual = Label.new()
	lbl_objetivo_actual.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_objetivo_actual.add_theme_font_size_override("font_size", 15)
	vbox.add_child(lbl_objetivo_actual)

	barra_progreso = ProgressBar.new()
	barra_progreso.min_value = 0.0
	barra_progreso.max_value = VOLTAJE_MAX_BARRA
	barra_progreso.step = 1.0
	barra_progreso.show_percentage = false
	barra_progreso.custom_minimum_size = Vector2(580, 18)

	var bg_bar := StyleBoxFlat.new()
	bg_bar.bg_color = Color(0.12, 0.15, 0.22, 1.0)
	bg_bar.set_corner_radius_all(5)
	barra_progreso.add_theme_stylebox_override("background", bg_bar)

	fill_style_barra = StyleBoxFlat.new()
	fill_style_barra.bg_color = Color(0.95, 0.72, 0.2, 1.0)
	fill_style_barra.set_corner_radius_all(5)
	barra_progreso.add_theme_stylebox_override("fill", fill_style_barra)
	vbox.add_child(barra_progreso)

	# Lienzo de Simulación Gráfica + Osciloscopio Line2D en tiempo real
	lienzo_simulacion = Control.new()
	lienzo_simulacion.custom_minimum_size = Vector2(590, 165)
	lienzo_simulacion.clip_contents = true
	lienzo_simulacion.draw.connect(_on_dibujar_simulacion_faraday)
	vbox.add_child(lienzo_simulacion)

	linea_onda_objetivo = Line2D.new()
	linea_onda_objetivo.width = 2.0
	linea_onda_objetivo.default_color = Color(0.35, 0.95, 0.65, 0.42)
	lienzo_simulacion.add_child(linea_onda_objetivo)

	linea_onda_actual = Line2D.new()
	linea_onda_actual.width = 3.0
	linea_onda_actual.default_color = Color(1.0, 0.8, 0.25, 0.95)
	lienzo_simulacion.add_child(linea_onda_actual)

	lbl_operacion_corta = Label.new()
	lbl_operacion_corta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_operacion_corta.add_theme_font_size_override("font_size", 14)
	lbl_operacion_corta.add_theme_color_override("font_color", Color(0.85, 0.93, 1.0))
	vbox.add_child(lbl_operacion_corta)

	lbl_estado_corto = Label.new()
	lbl_estado_corto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_estado_corto.add_theme_font_size_override("font_size", 13)
	vbox.add_child(lbl_estado_corto)

	# Controles Multivariable: Espiras N ([1]/[2] o [W/S]) y Frecuencia f ([A/D] o [◀/▶])
	var fila_esp := HBoxContainer.new()
	fila_esp.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_esp.add_theme_constant_override("separation", 12)
	vbox.add_child(fila_esp)

	btn_esp_menos = _crear_boton_ui("▼ [1 / S] -Espiras", Vector2(155, 32))
	btn_esp_menos.pressed.connect(func(): _cambiar_espiras(-1))
	fila_esp.add_child(btn_esp_menos)

	lbl_val_espiras = Label.new()
	lbl_val_espiras.custom_minimum_size = Vector2(210, 28)
	lbl_val_espiras.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_val_espiras.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_val_espiras.add_theme_font_size_override("font_size", 14)
	fila_esp.add_child(lbl_val_espiras)

	btn_esp_mas = _crear_boton_ui("▲ [2 / W] +Espiras", Vector2(155, 32))
	btn_esp_mas.pressed.connect(func(): _cambiar_espiras(1))
	fila_esp.add_child(btn_esp_mas)

	var fila_frec := HBoxContainer.new()
	fila_frec.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_frec.add_theme_constant_override("separation", 12)
	vbox.add_child(fila_frec)

	btn_frec_menos = _crear_boton_ui("◀ [A] -Frecuencia Hz", Vector2(165, 32))
	btn_frec_menos.pressed.connect(func(): _cambiar_frecuencia(-1))
	fila_frec.add_child(btn_frec_menos)

	lbl_val_frecuencia = Label.new()
	lbl_val_frecuencia.custom_minimum_size = Vector2(190, 28)
	lbl_val_frecuencia.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_val_frecuencia.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_val_frecuencia.add_theme_font_size_override("font_size", 14)
	fila_frec.add_child(lbl_val_frecuencia)

	btn_frec_mas = _crear_boton_ui("[D] +Frecuencia Hz ▶", Vector2(165, 32))
	btn_frec_mas.pressed.connect(func(): _cambiar_frecuencia(1))
	fila_frec.add_child(btn_frec_mas)

	var fila_pie := HBoxContainer.new()
	fila_pie.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_pie.add_theme_constant_override("separation", 16)
	vbox.add_child(fila_pie)

	btn_confirmar_accion = _crear_boton_ui("⚡ [Enter / Espacio] Estabilizar Inducción", Vector2(290, 34))
	btn_confirmar_accion.pressed.connect(_accion_confirmar_panel)
	fila_pie.add_child(btn_confirmar_accion)

	var btn_cerrar := _crear_boton_ui("Cerrar [E / Esc]", Vector2(150, 34))
	btn_cerrar.pressed.connect(_cerrar_panel)
	fila_pie.add_child(btn_cerrar)

func _crear_boton_ui(texto: String, tam_min: Vector2) -> Button:
	var btn := Button.new()
	btn.text = texto
	btn.custom_minimum_size = tam_min
	btn.focus_mode = Control.FOCUS_NONE
	return btn

# ==============================================================================
# LÓGICA MATEMÁTICA E INTERACCIÓN
# ==============================================================================
func _calcular_voltaje_inducido() -> float:
	var n: int = VALORES_ESPIRAS[idx_espiras]
	var f: float = VALORES_FRECUENCIA[idx_frecuencia]
	return float(n) * f * FLUJO_BASE_WB

func _cambiar_espiras(delta_idx: int) -> void:
	idx_espiras = clampi(idx_espiras + delta_idx, 0, VALORES_ESPIRAS.size() - 1)
	_verificar_estado_induccion()

func _cambiar_frecuencia(delta_idx: int) -> void:
	idx_frecuencia = clampi(idx_frecuencia + delta_idx, 0, VALORES_FRECUENCIA.size() - 1)
	_verificar_estado_induccion()

func _accion_confirmar_panel() -> void:
	if completado:
		_cerrar_panel()
	else:
		_verificar_estado_induccion()

func _verificar_estado_induccion() -> void:
	if not nucleo_secundario_activo:
		nucleo_secundario_activo = true
		barrera_laser_col.set_deferred("disabled", true)
		if barrera_laser_visual:
			barrera_laser_visual.visible = false

	var fem := _calcular_voltaje_inducido()
	if is_equal_approx(fem, VOLTAJE_OBJETIVO) and not completado:
		completado = true
		_activar_compuerta_y_puente()
	_actualizar_visuales()

func _activar_compuerta_y_puente() -> void:
	compuerta_col.set_deferred("disabled", true)
	puente_ind_col.set_deferred("disabled", false)
	if is_inside_tree():
		var tw := create_tween()
		tw.tween_property(compuerta_body, "position", POS_COMPUERTA_ABIERTA, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _actualizar_visuales() -> void:
	var n: int = VALORES_ESPIRAS[idx_espiras]
	var f: float = VALORES_FRECUENCIA[idx_frecuencia]
	var fem: float = _calcular_voltaje_inducido()
	var sobrecarga: bool = fem > VOLTAJE_OBJETIVO + 1.0

	# Estado del Núcleo Secundario en el mundo
	if luz_nucleo_rect and lbl_estado_nucleo:
		if nucleo_secundario_activo:
			luz_nucleo_rect.color = Color(0.25, 0.95, 1.0, 0.95)
			lbl_estado_nucleo.text = "NÚCLEO SECUNDARIO: ACTIVO (Barrera Desbloqueada)"
			lbl_estado_nucleo.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
		else:
			luz_nucleo_rect.color = Color(0.95, 0.25, 0.25, 0.95)
			lbl_estado_nucleo.text = "NÚCLEO SECUNDARIO: BLOQUEADO [E]"
			lbl_estado_nucleo.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))

	# Cables de entrada Tramo 2
	var col_in := Color(0.25, 1.0, 0.55, 0.95) if completado else (Color(0.25, 0.92, 1.0, 0.92) if nucleo_secundario_activo else Color(0.85, 0.22, 0.25, 0.75))
	for c in cables_tramo2_entrada:
		if c:
			c.default_color = col_in
	for l in luces_tramo2_entrada:
		if l:
			l.color = col_in

	# Cables de salida Tramo 2
	var col_out := Color(0.25, 1.0, 0.55, 0.95) if completado else Color(0.85, 0.22, 0.25, 0.75)
	for c in cables_tramo2_salida:
		if c:
			c.default_color = col_out
	for l in luces_tramo2_salida:
		if l:
			l.color = col_out

	# HUD Consola
	if lbl_objetivo_actual:
		lbl_objetivo_actual.text = "OBJETIVO: 120.0 V (Inducción Estable)   |   ACTUAL: %.1f V" % fem
		if completado or is_equal_approx(fem, VOLTAJE_OBJETIVO):
			lbl_objetivo_actual.add_theme_color_override("font_color", Color(0.3, 1.0, 0.55))
		elif sobrecarga:
			lbl_objetivo_actual.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		else:
			lbl_objetivo_actual.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))

	if barra_progreso and fill_style_barra:
		barra_progreso.value = clampf(fem, 0.0, VOLTAJE_MAX_BARRA)
		if completado or is_equal_approx(fem, VOLTAJE_OBJETIVO):
			fill_style_barra.bg_color = Color(0.22, 0.95, 0.5, 1.0)
		elif sobrecarga:
			fill_style_barra.bg_color = Color(0.95, 0.25, 0.28, 1.0)
		else:
			fill_style_barra.bg_color = Color(0.95, 0.72, 0.2, 1.0)

	if lbl_operacion_corta:
		lbl_operacion_corta.text = "ε = N × f × ΔΦ = %d esp × %.1f Hz × 1.0 Wb = %.1f V" % [n, f, fem]

	if lbl_val_espiras:
		lbl_val_espiras.text = "Espiras (N): %d" % n
	if lbl_val_frecuencia:
		lbl_val_frecuencia.text = "Frecuencia (f): %.1f Hz" % f

	if lbl_estado_corto:
		if completado:
			lbl_estado_corto.text = "ESTADO: ¡INDUCCIÓN DE 120.0 V SINCRONIZADA! Compuerta y pasarela activas."
			lbl_estado_corto.add_theme_color_override("font_color", Color(0.3, 1.0, 0.55))
			if btn_confirmar_accion:
				btn_confirmar_accion.text = "✅ [Enter / Espacio] Continuar"
		elif sobrecarga:
			lbl_estado_corto.text = "ALERTA: SOBREVOLTAJE INDUCIDO (> 120.0 V) — Reduce espiras N o frecuencia f."
			lbl_estado_corto.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		else:
			lbl_estado_corto.text = "VOLTAJE INSUFICIENTE (< 120.0 V) — Ajusta espiras N y frecuencia f."
			lbl_estado_corto.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))

	if completado:
		puente_ind_sprite.modulate = Color(0.4, 1.0, 0.65, 1.0)
		lbl_estado_mundo.text = "⚡ GENERADOR FARADAY: 120.0 V ESTABLES\nPasarela hacia Sala Maestra Activa"
		lbl_estado_mundo.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	else:
		puente_ind_sprite.modulate = Color(0.6, 0.65, 0.75, 0.45)
		lbl_estado_mundo.text = "Generador Faraday: %.1f V / 120.0 V\nCalibra N y f para activar pasarela" % fem
		lbl_estado_mundo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))

	_actualizar_ondas_osciloscopio()
	if lienzo_simulacion:
		lienzo_simulacion.queue_redraw()
	queue_redraw()

func _actualizar_ondas_osciloscopio() -> void:
	if not linea_onda_objetivo or not linea_onda_actual:
		return
	var x0 := 285.0
	var ancho := 285.0
	var cy := 82.0
	var f_actual: float = VALORES_FRECUENCIA[idx_frecuencia]
	var fem: float = _calcular_voltaje_inducido()

	var pts_obj := PackedVector2Array()
	var pts_act := PackedVector2Array()
	var muestras := 48
	var amp_obj := 42.0 # 120 V referencia
	var amp_act := clampf((fem / VOLTAJE_OBJETIVO) * 42.0, 6.0, 68.0)

	for i in range(muestras + 1):
		var t_norm := float(i) / float(muestras)
		var px := x0 + t_norm * ancho
		var y_obj := cy - sin(t_norm * 3.0 * TAU - tiempo_sim * 3.0) * amp_obj
		var y_act := cy - sin(t_norm * f_actual * TAU - tiempo_sim * f_actual * 1.8) * amp_act
		pts_obj.append(Vector2(px, y_obj))
		pts_act.append(Vector2(px, y_act))

	linea_onda_objetivo.points = pts_obj
	linea_onda_actual.points = pts_act

	if completado or is_equal_approx(fem, VOLTAJE_OBJETIVO):
		linea_onda_actual.default_color = Color(0.25, 1.0, 0.55, 0.98)
	elif fem > VOLTAJE_OBJETIVO + 1.0:
		linea_onda_actual.default_color = Color(1.0, 0.32, 0.35, 0.98)
	else:
		linea_onda_actual.default_color = Color(1.0, 0.82, 0.25, 0.95)

func _on_dibujar_simulacion_faraday() -> void:
	if not lienzo_simulacion:
		return
	var w := lienzo_simulacion.size.x
	var h := lienzo_simulacion.size.y
	if w <= 10.0:
		w = 590.0
		h = 165.0

	lienzo_simulacion.draw_rect(Rect2(0, 0, w, h), Color(0.04, 0.06, 0.1, 0.95), true)
	lienzo_simulacion.draw_rect(Rect2(0, 0, w, h), Color(0.22, 0.45, 0.68, 0.6), false, 1.5)

	# Mitad izquierda: Bobina + Imán N-S oscilando en tiempo real
	var cx_bobina := 135.0
	var cy_bobina := h * 0.52
	var f_actual: float = VALORES_FRECUENCIA[idx_frecuencia]
	var desp_x := sin(tiempo_sim * f_actual * 2.2) * 42.0

	# Dibujar núcleo y espiras de cobre según N
	lienzo_simulacion.draw_rect(Rect2(cx_bobina - 54, cy_bobina - 26, 108, 52), Color(0.14, 0.18, 0.26, 0.9), true)
	var num_espiras_vis: int = int(VALORES_ESPIRAS[idx_espiras] / 5)
	for i in range(num_espiras_vis):
		var t := float(i) / float(max(num_espiras_vis - 1, 1))
		var ex := lerpf(cx_bobina - 46.0, cx_bobina + 46.0, t)
		lienzo_simulacion.draw_line(Vector2(ex, cy_bobina - 28), Vector2(ex, cy_bobina + 28), Color(0.95, 0.62, 0.22, 0.9), 3.0)

	# Imán N-S oscilante
	var iman_x := cx_bobina + desp_x
	lienzo_simulacion.draw_rect(Rect2(iman_x - 32, cy_bobina - 12, 32, 24), Color(0.92, 0.25, 0.28, 1.0), true)
	lienzo_simulacion.draw_rect(Rect2(iman_x, cy_bobina - 12, 32, 24), Color(0.25, 0.58, 0.96, 1.0), true)

	var font := ThemeDB.fallback_font
	if font:
		lienzo_simulacion.draw_string(font, Vector2(iman_x - 20, cy_bobina + 5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		lienzo_simulacion.draw_string(font, Vector2(iman_x + 12, cy_bobina + 5), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		lienzo_simulacion.draw_string(font, Vector2(24, 20), "BOBINA + IMÁN OSCILANTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.88, 1.0))
		lienzo_simulacion.draw_string(font, Vector2(292, 20), "OSCILOSCOPIO FEM INDUCIDA (META: 120 V)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.88, 1.0))

	# Mitad derecha: Rejilla del osciloscopio
	lienzo_simulacion.draw_rect(Rect2(280, 26, 295, h - 38), Color(0.02, 0.04, 0.07, 0.95), true)
	lienzo_simulacion.draw_rect(Rect2(280, 26, 295, h - 38), Color(0.2, 0.4, 0.55, 0.6), false, 1.0)
	lienzo_simulacion.draw_line(Vector2(280, 82), Vector2(575, 82), Color(0.3, 0.45, 0.6, 0.4), 1.0)

# ==============================================================================
# ENTRADA, VISIBILIDAD Y ACTUALIZACIÓN EN TIEMPO REAL
# ==============================================================================
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if kc == KEY_E:
			_tecla_e_prev = true
			if panel_ui and panel_ui.is_visible_in_tree():
				_cerrar_panel()
				get_viewport().set_input_as_handled()
			elif jugador_cerca_nucleo and not nucleo_secundario_activo:
				_activar_nucleo_secundario()
				get_viewport().set_input_as_handled()
			elif jugador_cerca_terminal:
				_abrir_panel()
				get_viewport().set_input_as_handled()
			return

		if not panel_ui or not panel_ui.is_visible_in_tree():
			return

		if kc in [KEY_1, KEY_KP_1, KEY_S, KEY_DOWN]:
			_cambiar_espiras(-1)
			get_viewport().set_input_as_handled()
		elif kc in [KEY_2, KEY_KP_2, KEY_W, KEY_UP]:
			_cambiar_espiras(1)
			get_viewport().set_input_as_handled()
		elif kc in [KEY_A, KEY_LEFT]:
			_cambiar_frecuencia(-1)
			get_viewport().set_input_as_handled()
		elif kc in [KEY_D, KEY_RIGHT]:
			_cambiar_frecuencia(1)
			get_viewport().set_input_as_handled()
		elif kc in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_accion_confirmar_panel()
			get_viewport().set_input_as_handled()
		elif kc == KEY_ESCAPE:
			_cerrar_panel()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	tiempo_sim += delta
	var f_actual: float = VALORES_FRECUENCIA[idx_frecuencia]
	if iman_mundo:
		iman_mundo.position = Vector2(sin(tiempo_sim * f_actual * 2.2) * 22.0, -18.0)

	if panel_ui and panel_ui.is_visible_in_tree():
		_actualizar_ondas_osciloscopio()
		if lienzo_simulacion:
			lienzo_simulacion.queue_redraw()

	# Detección en Núcleo Secundario
	if area_nucleo_ref and area_nucleo_ref.monitoring:
		var det_n := false
		for b in area_nucleo_ref.get_overlapping_bodies():
			if b is CharacterBody2D or b.is_in_group("jugador"):
				det_n = true
				jugador_ref = b
				break
		jugador_cerca_nucleo = det_n
		if lbl_prompt_nucleo:
			lbl_prompt_nucleo.visible = jugador_cerca_nucleo and not nucleo_secundario_activo and not (panel_ui and panel_ui.is_visible_in_tree())

	# Detección en Terminal Faraday
	if area_terminal_ref and area_terminal_ref.monitoring:
		var detectado := false
		for b in area_terminal_ref.get_overlapping_bodies():
			if b is CharacterBody2D or b.is_in_group("jugador"):
				detectado = true
				jugador_ref = b
				break
		jugador_cerca_terminal = detectado
		if lbl_prompt:
			lbl_prompt.visible = jugador_cerca_terminal and not (panel_ui and panel_ui.is_visible_in_tree())

	var e_actual: bool = Input.is_physical_key_pressed(KEY_E) or Input.is_key_pressed(KEY_E)
	if e_actual and not _tecla_e_prev:
		if panel_ui and panel_ui.is_visible_in_tree():
			_cerrar_panel()
		elif jugador_cerca_nucleo and not nucleo_secundario_activo:
			_activar_nucleo_secundario()
		elif jugador_cerca_terminal:
			_abrir_panel()
	_tecla_e_prev = e_actual

func _draw() -> void:
	var col_cable := Color(0.3, 1.0, 0.55, 0.9) if completado else Color(0.35, 0.9, 1.0, 0.85)
	draw_polyline(PackedVector2Array([
		POS_GENERADOR,
		Vector2(POS_COMPUERTA_CERRADA.x, POS_GENERADOR.y),
		POS_PUENTE_INDUCCION
	]), col_cable, 3.0)

func _abrir_panel() -> void:
	if not nucleo_secundario_activo:
		_activar_nucleo_secundario()
	panel_ui.visible = true
	_cambiar_visibilidad_textos_mundo(false)
	if jugador_ref and jugador_ref.has_method("set_physics_process"):
		jugador_ref.set_physics_process(false)
	_actualizar_visuales()

func _cerrar_panel() -> void:
	panel_ui.visible = false
	_cambiar_visibilidad_textos_mundo(true)
	if jugador_ref and jugador_ref.has_method("set_physics_process"):
		jugador_ref.set_physics_process(true)

func _cambiar_visibilidad_textos_mundo(mostrar: bool) -> void:
	for nodo in get_tree().get_nodes_in_group(GRUPO_TEXTOS_MUNDO):
		if nodo is CanvasItem:
			if nodo == lbl_prompt:
				nodo.visible = mostrar and jugador_cerca_terminal
			elif nodo == lbl_prompt_nucleo:
				nodo.visible = mostrar and jugador_cerca_nucleo and not nucleo_secundario_activo
			else:
				nodo.visible = mostrar

func _on_nucleo_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D or body.is_in_group("jugador"):
		jugador_cerca_nucleo = true
		jugador_ref = body

func _on_nucleo_body_exited(body: Node2D) -> void:
	if body == jugador_ref:
		jugador_cerca_nucleo = false
		if lbl_prompt_nucleo:
			lbl_prompt_nucleo.visible = false

func _on_nucleo_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_activar_nucleo_secundario()

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D or body.is_in_group("jugador"):
		jugador_cerca_terminal = true
		jugador_ref = body
		if lbl_prompt and not (panel_ui and panel_ui.is_visible_in_tree()):
			lbl_prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body == jugador_ref:
		jugador_cerca_terminal = false
		if lbl_prompt:
			lbl_prompt.visible = false
		if panel_ui and panel_ui.is_visible_in_tree():
			_cerrar_panel()

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if panel_ui and panel_ui.is_visible_in_tree():
			_cerrar_panel()
		else:
			_abrir_panel()
