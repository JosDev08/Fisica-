extends Node2D

# ==============================================================================
# TRAMO 3 (NIVEL 3): SALA DEL PUZZLE MAESTRO Y COMPUERTA FINAL A ESCENA 4
# - Extiende el mapa desde x = 3020 hasta x = 4480 con la gran Sala de Control
#   Final, pasarelas tácticas, arcos de reactor, 3 Pilones de Estado conectados
#   por cables (Line2D) e indicadores luminosos (ColorRect).
# - Consola del Puzzle Maestro en 2 Fases en tiempo real:
#   * FASE 1: Confinamiento Magnético (B = 0.0025 * N1 * I1 -> Meta: 1.50 T)
#   * FASE 2: Sincronización de Potencia Inducida (P = B * N2 * f -> Meta: 180.0 kW)
# - Al estabilizar ambas fases, se abre la Compuerta Maestra hacia Escena_4.tscn.
# ==============================================================================

const ESCENA_FINAL_BOSQUE := "res://Escenas/Escena_4.tscn"
const GRUPO_TEXTOS_MUNDO := "texto_mundo_nivel3"

const POS_CONSOLA_MAESTRA := Vector2(3960, -32)
const POS_PUERTA := Vector2(4180, -56)
const POS_PUERTA_ABIERTA := Vector2(4180, -172)

# Fase 1: B = 0.0025 * N1 * I1 (Meta = 1.50 T)
const F1_ESPIRAS: Array[int] = [100, 150, 200, 250, 300]
const F1_CORRIENTES: Array[float] = [2.0, 3.0, 4.0, 5.0, 6.0]
const F1_FACTOR_MU: float = 0.0025
const F1_META_TESLA: float = 1.50
const F1_MAX_BARRA: float = 2.50

# Fase 2: P = B_fijo(1.50) * N2 * f (Meta = 180.0 kW)
const F2_ESPIRAS: Array[int] = [20, 30, 40, 50, 60]
const F2_FRECUENCIAS: Array[float] = [1.0, 2.0, 3.0, 4.0, 5.0]
const F2_META_POTENCIA: float = 180.0
const F2_MAX_BARRA: float = 300.0

var fase_actual: int = 1
var fase_1_completada: bool = false
var puerta_abierta: bool = false

var idx_param_a: int = 1 # Espiras N1 o N2
var idx_param_b: int = 1 # Corriente I1 o Frecuencia f
var tiempo_sim: float = 0.0

var jugador_cerca_consola: bool = false
var jugador_cerca_portal: bool = false
var jugador_ref: Node2D = null
var area_consola_ref: Area2D = null
var area_portal_ref: Area2D = null
var _tecla_e_prev: bool = false

# Nodos del mundo (Sala Maestra)
var puerta_body: StaticBody2D
var puerta_col: CollisionShape2D
var puerta_sprite: Sprite2D
var lbl_prompt_consola: Label
var lbl_prompt_portal: Label
var lbl_estado_puerta: Label

var cables_tramo3: Array[Line2D] = []
var luces_tramo3: Array[ColorRect] = []
var luz_pilon_1: ColorRect
var luz_pilon_2: ColorRect
var luz_pilon_3: ColorRect

# Nodos UI (Consola Maestra)
var ui_layer: CanvasLayer
var panel_ui: PanelContainer
var lbl_titulo_fase: Label
var lbl_objetivo_actual: Label
var barra_progreso: ProgressBar
var fill_style_barra: StyleBoxFlat
var lienzo_simulacion: Control
var linea_onda_meta: Line2D
var linea_onda_jugador: Line2D
var lbl_operacion_corta: Label
var lbl_estado_corto: Label
var btn_a_menos: Button
var btn_a_mas: Button
var lbl_val_a: Label
var btn_b_menos: Button
var btn_b_mas: Button
var lbl_val_b: Label
var btn_accion_principal: Button

func _ready() -> void:
	_ocultar_puerta_ohm_antigua()
	_construir_sala_maestra_tramo_3()
	_crear_consola_y_puerta_final()
	_crear_ui()
	_actualizar_visuales()

func _ocultar_puerta_ohm_antigua() -> void:
	var puerta_antigua := get_parent().get_node_or_null("PuertaOhm")
	if puerta_antigua:
		puerta_antigua.visible = false
		if puerta_antigua is CollisionObject2D:
			puerta_antigua.collision_layer = 0
			puerta_antigua.collision_mask = 0
		puerta_antigua.set_process(false)

# ==============================================================================
# TRAMO 3: SALA DEL PUZZLE MAESTRO (PILONES Y RED DE ENERGÍA REACTIVOS)
# ==============================================================================
func _construir_sala_maestra_tramo_3() -> void:
	var sala := Node2D.new()
	sala.name = "SalaPuzzleMaestroTramo3"
	add_child(sala)

	# 1. Tres Pilones de Sincronización en la Sala Maestra (Ampère, Faraday, Reactor Maestro)
	luz_pilon_1 = _crear_pilon_estado(sala, Vector2(3840, -76), "PILÓN I: AMPÈRE")
	luz_pilon_2 = _crear_pilon_estado(sala, Vector2(3960, -110), "PILÓN II: FARADAY")
	luz_pilon_3 = _crear_pilon_estado(sala, Vector2(4080, -76), "PILÓN III: SINCRONÍA")

	# 2. Red de cables de energía que convergen en la Consola Maestra y la Compuerta Final
	var pts_red := PackedVector2Array([
		Vector2(3200, 26),
		Vector2(3350, 26),
		Vector2(3680, 26),
		Vector2(3840, 26),
		Vector2(3960, 26),
		Vector2(4080, 26),
		Vector2(4180, 26),
		Vector2(4180, -56)
	])
	cables_tramo3.append(_crear_cable_energia(sala, pts_red))

	var pts_techo := PackedVector2Array([
		Vector2(3840, -76),
		Vector2(3960, -110),
		Vector2(4080, -76),
		Vector2(4180, -110)
	])
	cables_tramo3.append(_crear_cable_energia(sala, pts_techo))

	for pt in [Vector2(3350, 26), Vector2(3680, 26), Vector2(3840, 26), Vector2(3960, 26), Vector2(4080, 26), Vector2(4180, 26)]:
		luces_tramo3.append(_crear_indicador_luz(sala, pt))

func _crear_pilon_estado(padre: Node2D, pos: Vector2, titulo: String) -> ColorRect:
	var nodo := Node2D.new()
	nodo.position = pos
	nodo.z_index = -2
	padre.add_child(nodo)

	var columna := ColorRect.new()
	columna.position = Vector2(-22, -42)
	columna.size = Vector2(44, 84)
	columna.color = Color(0.08, 0.11, 0.17, 0.95)
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nodo.add_child(columna)

	var nucleo := ColorRect.new()
	nucleo.position = Vector2(-12, -26)
	nucleo.size = Vector2(24, 52)
	nucleo.color = Color(0.88, 0.22, 0.25, 0.9)
	nucleo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nodo.add_child(nucleo)

	var lbl := Label.new()
	lbl.text = titulo
	lbl.position = Vector2(-75, -62)
	lbl.size = Vector2(150, 18)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0, 0.9))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_to_group(GRUPO_TEXTOS_MUNDO)
	nodo.add_child(lbl)

	return nucleo

func _crear_cable_energia(padre: Node2D, puntos: PackedVector2Array) -> Line2D:
	var base := Line2D.new()
	base.points = puntos
	base.width = 8.0
	base.default_color = Color(0.07, 0.09, 0.14, 0.92)
	base.z_index = -3
	padre.add_child(base)

	var linea := Line2D.new()
	linea.points = puntos
	linea.width = 3.5
	linea.default_color = Color(0.85, 0.22, 0.25, 0.78)
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

func _crear_consola_y_puerta_final() -> void:
	# 1. Consola del Puzzle Maestro en (3960, -32)
	var area_c := Area2D.new()
	area_consola_ref = area_c
	area_c.name = "ConsolaMaestraNivel3"
	area_c.position = POS_CONSOLA_MAESTRA
	area_c.monitoring = true
	area_c.monitorable = true
	area_c.collision_layer = 0
	area_c.collision_mask = 1
	area_c.input_pickable = true
	add_child(area_c)

	var col_c := CollisionShape2D.new()
	var rect_c := RectangleShape2D.new()
	rect_c.size = Vector2(130, 120)
	col_c.shape = rect_c
	area_c.add_child(col_c)

	var spr_c := Sprite2D.new()
	var tex_c := load("res://assets/nivel_3/panel_magnetico.svg") as Texture2D
	if tex_c:
		spr_c.texture = tex_c
		spr_c.scale = Vector2(1.15, 1.15)
	area_c.add_child(spr_c)

	lbl_prompt_consola = Label.new()
	lbl_prompt_consola.text = "[E] Consola Maestra"
	lbl_prompt_consola.position = Vector2(-110, -64)
	lbl_prompt_consola.size = Vector2(220, 24)
	lbl_prompt_consola.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_prompt_consola.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_prompt_consola.add_theme_font_size_override("font_size", 13)
	lbl_prompt_consola.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	lbl_prompt_consola.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_prompt_consola.add_theme_constant_override("outline_size", 4)
	lbl_prompt_consola.visible = false
	lbl_prompt_consola.add_to_group(GRUPO_TEXTOS_MUNDO)
	area_c.add_child(lbl_prompt_consola)

	area_c.body_entered.connect(_on_consola_body_entered)
	area_c.body_exited.connect(_on_consola_body_exited)
	area_c.input_event.connect(_on_consola_input_event)

	# 2. Compuerta Electromagnética Final en (4180, -56)
	puerta_body = StaticBody2D.new()
	puerta_body.name = "PuertaElectromagneticaFinal"
	puerta_body.position = POS_PUERTA
	puerta_body.collision_layer = 16
	puerta_body.collision_mask = 1
	add_child(puerta_body)

	puerta_col = CollisionShape2D.new()
	var rect_p := RectangleShape2D.new()
	rect_p.size = Vector2(56, 112)
	puerta_col.shape = rect_p
	puerta_body.add_child(puerta_col)

	puerta_sprite = Sprite2D.new()
	var tex_p := load("res://assets/nivel_3/puerta_magnetica_final.svg") as Texture2D
	if tex_p:
		puerta_sprite.texture = tex_p
	puerta_body.add_child(puerta_sprite)

	lbl_estado_puerta = Label.new()
	lbl_estado_puerta.position = POS_PUERTA + Vector2(-150, -96)
	lbl_estado_puerta.size = Vector2(300, 40)
	lbl_estado_puerta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_estado_puerta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_estado_puerta.add_theme_font_size_override("font_size", 12)
	lbl_estado_puerta.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_estado_puerta.add_theme_constant_override("outline_size", 4)
	lbl_estado_puerta.add_to_group(GRUPO_TEXTOS_MUNDO)
	add_child(lbl_estado_puerta)

	# 3. Portal de Salida hacia Escena_4.tscn en (4180, -56)
	var area_p := Area2D.new()
	area_portal_ref = area_p
	area_p.name = "ZonaPortalEscena4"
	area_p.position = POS_PUERTA
	area_p.monitoring = true
	area_p.monitorable = true
	area_p.collision_layer = 0
	area_p.collision_mask = 1
	area_p.input_pickable = true
	add_child(area_p)

	var col_p := CollisionShape2D.new()
	var rect_ap := RectangleShape2D.new()
	rect_ap.size = Vector2(130, 130)
	col_p.shape = rect_ap
	area_p.add_child(col_p)

	lbl_prompt_portal = Label.new()
	lbl_prompt_portal.text = "[E] Sincronizar Salida"
	lbl_prompt_portal.position = Vector2(-115, -74)
	lbl_prompt_portal.size = Vector2(230, 24)
	lbl_prompt_portal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_prompt_portal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_prompt_portal.add_theme_font_size_override("font_size", 13)
	lbl_prompt_portal.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	lbl_prompt_portal.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_prompt_portal.add_theme_constant_override("outline_size", 4)
	lbl_prompt_portal.visible = false
	lbl_prompt_portal.add_to_group(GRUPO_TEXTOS_MUNDO)
	area_p.add_child(lbl_prompt_portal)

	area_p.body_entered.connect(_on_portal_body_entered)
	area_p.body_exited.connect(_on_portal_body_exited)
	area_p.input_event.connect(_on_portal_input_event)

# ==============================================================================
# CONSOLA DEL PUZZLE MAESTRO (2 FASES EN TIEMPO REAL, CERO MUROS DE TEXTO)
# ==============================================================================
func _crear_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)

	panel_ui = PanelContainer.new()
	panel_ui.custom_minimum_size = Vector2(660, 445)
	panel_ui.set_anchors_preset(Control.PRESET_CENTER)
	panel_ui.offset_left = -330
	panel_ui.offset_top = -222
	panel_ui.offset_right = 330
	panel_ui.offset_bottom = 222
	panel_ui.visible = false

	var style_panel := StyleBoxFlat.new()
	style_panel.bg_color = Color(0.05, 0.07, 0.12, 0.96)
	style_panel.border_color = Color(0.3, 0.88, 1.0, 0.92)
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

	lbl_titulo_fase = Label.new()
	lbl_titulo_fase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_titulo_fase.add_theme_font_size_override("font_size", 15)
	lbl_titulo_fase.add_theme_color_override("font_color", Color(0.4, 0.95, 1.0))
	vbox.add_child(lbl_titulo_fase)

	lbl_objetivo_actual = Label.new()
	lbl_objetivo_actual.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_objetivo_actual.add_theme_font_size_override("font_size", 15)
	vbox.add_child(lbl_objetivo_actual)

	barra_progreso = ProgressBar.new()
	barra_progreso.min_value = 0.0
	barra_progreso.max_value = F1_MAX_BARRA
	barra_progreso.step = 0.01
	barra_progreso.show_percentage = false
	barra_progreso.custom_minimum_size = Vector2(590, 18)

	var bg_bar := StyleBoxFlat.new()
	bg_bar.bg_color = Color(0.12, 0.15, 0.22, 1.0)
	bg_bar.set_corner_radius_all(5)
	barra_progreso.add_theme_stylebox_override("background", bg_bar)

	fill_style_barra = StyleBoxFlat.new()
	fill_style_barra.bg_color = Color(0.95, 0.72, 0.2, 1.0)
	fill_style_barra.set_corner_radius_all(5)
	barra_progreso.add_theme_stylebox_override("fill", fill_style_barra)
	vbox.add_child(barra_progreso)

	# Lienzo de Simulación Gráfica + Sincronizador de Onda Line2D
	lienzo_simulacion = Control.new()
	lienzo_simulacion.custom_minimum_size = Vector2(600, 165)
	lienzo_simulacion.clip_contents = true
	lienzo_simulacion.draw.connect(_on_dibujar_reactor_maestro)
	vbox.add_child(lienzo_simulacion)

	linea_onda_meta = Line2D.new()
	linea_onda_meta.width = 2.0
	linea_onda_meta.default_color = Color(0.35, 0.95, 0.65, 0.42)
	lienzo_simulacion.add_child(linea_onda_meta)

	linea_onda_jugador = Line2D.new()
	linea_onda_jugador.width = 3.0
	linea_onda_jugador.default_color = Color(1.0, 0.8, 0.25, 0.95)
	lienzo_simulacion.add_child(linea_onda_jugador)

	lbl_operacion_corta = Label.new()
	lbl_operacion_corta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_operacion_corta.add_theme_font_size_override("font_size", 14)
	lbl_operacion_corta.add_theme_color_override("font_color", Color(0.85, 0.93, 1.0))
	vbox.add_child(lbl_operacion_corta)

	lbl_estado_corto = Label.new()
	lbl_estado_corto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_estado_corto.add_theme_font_size_override("font_size", 13)
	vbox.add_child(lbl_estado_corto)

	# Controles de Parámetro A ([1/S/▼] y [2/W/▲])
	var fila_a := HBoxContainer.new()
	fila_a.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_a.add_theme_constant_override("separation", 12)
	vbox.add_child(fila_a)

	btn_a_menos = _crear_boton_ui("▼ [1 / S] -Espiras", Vector2(160, 32))
	btn_a_menos.pressed.connect(func(): _ajustar_param_a(-1))
	fila_a.add_child(btn_a_menos)

	lbl_val_a = Label.new()
	lbl_val_a.custom_minimum_size = Vector2(210, 28)
	lbl_val_a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_val_a.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_val_a.add_theme_font_size_override("font_size", 14)
	fila_a.add_child(lbl_val_a)

	btn_a_mas = _crear_boton_ui("▲ [2 / W] +Espiras", Vector2(160, 32))
	btn_a_mas.pressed.connect(func(): _ajustar_param_a(1))
	fila_a.add_child(btn_a_mas)

	# Controles de Parámetro B ([A/◀] y [D/▶])
	var fila_b := HBoxContainer.new()
	fila_b.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_b.add_theme_constant_override("separation", 12)
	vbox.add_child(fila_b)

	btn_b_menos = _crear_boton_ui("◀ [A] Reducir", Vector2(160, 32))
	btn_b_menos.pressed.connect(func(): _ajustar_param_b(-1))
	fila_b.add_child(btn_b_menos)

	lbl_val_b = Label.new()
	lbl_val_b.custom_minimum_size = Vector2(210, 28)
	lbl_val_b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_val_b.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_val_b.add_theme_font_size_override("font_size", 14)
	fila_b.add_child(lbl_val_b)

	btn_b_mas = _crear_boton_ui("[D] Aumentar ▶", Vector2(160, 32))
	btn_b_mas.pressed.connect(func(): _ajustar_param_b(1))
	fila_b.add_child(btn_b_mas)

	var fila_pie := HBoxContainer.new()
	fila_pie.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_pie.add_theme_constant_override("separation", 16)
	vbox.add_child(fila_pie)

	btn_accion_principal = _crear_boton_ui("⚡ [Enter / Espacio] Sincronizar Fase", Vector2(300, 34))
	btn_accion_principal.pressed.connect(_ejecutar_accion_principal)
	fila_pie.add_child(btn_accion_principal)

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
# LÓGICA DE SINCRONIZACIÓN EN 2 FASES Y TRANSICIÓN A ESCENA 4
# ==============================================================================
func _calcular_valor_actual() -> float:
	if fase_actual == 1:
		var n1: int = F1_ESPIRAS[idx_param_a]
		var i1: float = F1_CORRIENTES[idx_param_b]
		return float(n1) * i1 * F1_FACTOR_MU
	else:
		var n2: int = F2_ESPIRAS[idx_param_a]
		var f2: float = F2_FRECUENCIAS[idx_param_b]
		return F1_META_TESLA * float(n2) * f2

func _ajustar_param_a(delta_idx: int) -> void:
	var max_idx := (F1_ESPIRAS.size() - 1) if fase_actual == 1 else (F2_ESPIRAS.size() - 1)
	idx_param_a = clampi(idx_param_a + delta_idx, 0, max_idx)
	_evaluar_progreso_automatico()

func _ajustar_param_b(delta_idx: int) -> void:
	var max_idx := (F1_CORRIENTES.size() - 1) if fase_actual == 1 else (F2_FRECUENCIAS.size() - 1)
	idx_param_b = clampi(idx_param_b + delta_idx, 0, max_idx)
	_evaluar_progreso_automatico()

func _evaluar_progreso_automatico() -> void:
	var val := _calcular_valor_actual()
	if fase_actual == 1 and is_equal_approx(val, F1_META_TESLA):
		fase_1_completada = true
	elif fase_actual == 2 and is_equal_approx(val, F2_META_POTENCIA) and not puerta_abierta:
		_desbloquear_puerta()
	_actualizar_visuales()

func _ejecutar_accion_principal() -> void:
	if puerta_abierta:
		_cargar_escena_4()
		return

	var val := _calcular_valor_actual()
	if fase_actual == 1:
		if is_equal_approx(val, F1_META_TESLA) or fase_1_completada:
			fase_1_completada = true
			fase_actual = 2
			idx_param_a = 1 # 30 esp
			idx_param_b = 1 # 2.0 Hz -> 90 kW inicial
			_actualizar_visuales()
	else:
		if is_equal_approx(val, F2_META_POTENCIA):
			_desbloquear_puerta()

func _desbloquear_puerta() -> void:
	puerta_abierta = true
	puerta_col.set_deferred("disabled", true)
	puerta_sprite.modulate = Color(0.4, 1.0, 0.65, 0.9)
	if is_inside_tree():
		var tw := create_tween()
		tw.tween_property(puerta_body, "position", POS_PUERTA_ABIERTA, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_actualizar_visuales()

func _cargar_escena_4() -> void:
	if jugador_ref and jugador_ref.has_method("set_physics_process"):
		jugador_ref.set_physics_process(true)
	if ResourceLoader.exists(ESCENA_FINAL_BOSQUE):
		get_tree().change_scene_to_file(ESCENA_FINAL_BOSQUE)

func _actualizar_visuales() -> void:
	# Estado de los Pilones de la Sala Maestra
	var p1_ok := false
	var p2_ok := false
	var nodo_p1 := get_parent().get_node_or_null("PuzzleElectroimanPuente")
	if nodo_p1 and "completado" in nodo_p1:
		p1_ok = bool(nodo_p1.get("completado"))
	var nodo_p2 := get_parent().get_node_or_null("PuzzleInduccionFaraday")
	if nodo_p2 and "completado" in nodo_p2:
		p2_ok = bool(nodo_p2.get("completado"))

	if luz_pilon_1:
		luz_pilon_1.color = Color(0.25, 1.0, 0.55, 0.95) if p1_ok else Color(0.9, 0.25, 0.25, 0.9)
	if luz_pilon_2:
		luz_pilon_2.color = Color(0.25, 1.0, 0.55, 0.95) if p2_ok else Color(0.9, 0.25, 0.25, 0.9)
	if luz_pilon_3:
		luz_pilon_3.color = Color(0.25, 1.0, 0.55, 0.95) if puerta_abierta else (Color(0.25, 0.9, 1.0, 0.95) if fase_1_completada else Color(0.9, 0.25, 0.25, 0.9))

	var col_red := Color(0.25, 1.0, 0.55, 0.95) if puerta_abierta else (Color(0.25, 0.9, 1.0, 0.9) if fase_1_completada else Color(0.85, 0.22, 0.25, 0.78))
	for c in cables_tramo3:
		if c:
			c.default_color = col_red
	for l in luces_tramo3:
		if l:
			l.color = col_red

	if lbl_estado_puerta:
		if puerta_abierta:
			lbl_estado_puerta.text = "✅ COMPUERTA MAESTRA ABIERTA\nAvanza o presiona [Enter] hacia Escena 4"
			lbl_estado_puerta.add_theme_color_override("font_color", Color(0.3, 1.0, 0.55))
		elif fase_1_completada:
			lbl_estado_puerta.text = "FASE 1 ESTABLE (1.50 T) — FALTA FASE 2 (180.0 kW)\n[E] Consola Maestra"
			lbl_estado_puerta.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
		else:
			lbl_estado_puerta.text = "COMPUERTA MAESTRA BLOQUEADA\n[E] Calibrar Reactor en 2 Fases"
			lbl_estado_puerta.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))

	# HUD de la Consola Maestra
	var val := _calcular_valor_actual()
	if fase_actual == 1:
		var n1: int = F1_ESPIRAS[idx_param_a]
		var i1: float = F1_CORRIENTES[idx_param_b]
		var en_meta_f1 := is_equal_approx(val, F1_META_TESLA)
		var sobrecarga_f1 := val > F1_META_TESLA + 0.02

		if lbl_titulo_fase:
			lbl_titulo_fase.text = "REACTOR MAESTRO — FASE 1/2: CONFINAMIENTO MAGNÉTICO (LEY DE AMPÈRE)"
		if lbl_objetivo_actual:
			lbl_objetivo_actual.text = "OBJETIVO FASE 1: 1.50 T   |   ACTUAL: %.2f T" % val
			lbl_objetivo_actual.add_theme_color_override("font_color", Color(0.3, 1.0, 0.55) if en_meta_f1 else (Color(1.0, 0.35, 0.35) if sobrecarga_f1 else Color(1.0, 0.85, 0.35)))
		if barra_progreso and fill_style_barra:
			barra_progreso.max_value = F1_MAX_BARRA
			barra_progreso.value = clampf(val, 0.0, F1_MAX_BARRA)
			fill_style_barra.bg_color = Color(0.22, 0.95, 0.5, 1.0) if en_meta_f1 else (Color(0.95, 0.25, 0.28, 1.0) if sobrecarga_f1 else Color(0.95, 0.72, 0.2, 1.0))
		if lbl_operacion_corta:
			lbl_operacion_corta.text = "B = (μ/L) × N₁ × I₁ = 0.0025 × %d esp × %.1f A = %.2f T" % [n1, i1, val]
		if lbl_val_a:
			lbl_val_a.text = "Espiras N₁: %d" % n1
		if lbl_val_b:
			lbl_val_b.text = "Corriente I₁: %.1f A" % i1
		if btn_b_menos:
			btn_b_menos.text = "◀ [A] -Corriente A"
		if btn_b_mas:
			btn_b_mas.text = "[D] +Corriente A ▶"

		if lbl_estado_corto and btn_accion_principal:
			if en_meta_f1:
				lbl_estado_corto.text = "FASE 1 ESTABILIZADA (1.50 T) — Presiona [Enter / Espacio] para pasar a la Fase 2."
				lbl_estado_corto.add_theme_color_override("font_color", Color(0.3, 1.0, 0.55))
				btn_accion_principal.text = "✅ [Enter / Espacio] Avanzar a Fase 2/2"
			elif sobrecarga_f1:
				lbl_estado_corto.text = "SOBRECARGA MAGNÉTICA (> 1.50 T) — Reduce N₁ o I₁."
				lbl_estado_corto.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
				btn_accion_principal.text = "⚠️ Calibra 1.50 T para avanzar"
			else:
				lbl_estado_corto.text = "CAMPO INSUFICIENTE (< 1.50 T) — Aumenta N₁ o I₁."
				lbl_estado_corto.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
				btn_accion_principal.text = "⚡ Calibra 1.50 T para avanzar"
	else:
		var n2: int = F2_ESPIRAS[idx_param_a]
		var f2: float = F2_FRECUENCIAS[idx_param_b]
		var en_meta_f2 := is_equal_approx(val, F2_META_POTENCIA) or puerta_abierta
		var sobrecarga_f2 := val > F2_META_POTENCIA + 2.0 and not puerta_abierta

		if lbl_titulo_fase:
			lbl_titulo_fase.text = "REACTOR MAESTRO — FASE 2/2: RESONANCIA ELECTROMAGNÉTICA (B = 1.50 T FIJO)"
		if lbl_objetivo_actual:
			lbl_objetivo_actual.text = "OBJETIVO FASE 2: 180.0 kW   |   ACTUAL: %.1f kW" % val
			lbl_objetivo_actual.add_theme_color_override("font_color", Color(0.3, 1.0, 0.55) if en_meta_f2 else (Color(1.0, 0.35, 0.35) if sobrecarga_f2 else Color(1.0, 0.85, 0.35)))
		if barra_progreso and fill_style_barra:
			barra_progreso.max_value = F2_MAX_BARRA
			barra_progreso.value = clampf(val, 0.0, F2_MAX_BARRA)
			fill_style_barra.bg_color = Color(0.22, 0.95, 0.5, 1.0) if en_meta_f2 else (Color(0.95, 0.25, 0.28, 1.0) if sobrecarga_f2 else Color(0.95, 0.72, 0.2, 1.0))
		if lbl_operacion_corta:
			lbl_operacion_corta.text = "P = B × N₂ × f = 1.50 T × %d esp × %.1f Hz = %.1f kW" % [n2, f2, val]
		if lbl_val_a:
			lbl_val_a.text = "Espiras N₂: %d" % n2
		if lbl_val_b:
			lbl_val_b.text = "Frecuencia f: %.1f Hz" % f2
		if btn_b_menos:
			btn_b_menos.text = "◀ [A] -Frecuencia Hz"
		if btn_b_mas:
			btn_b_mas.text = "[D] +Frecuencia Hz ▶"

		if lbl_estado_corto and btn_accion_principal:
			if puerta_abierta or en_meta_f2:
				lbl_estado_corto.text = "¡SINCRONIZACIÓN MAESTRA COMPLETA (180.0 kW)! Compuerta abierta hacia Escena 4."
				lbl_estado_corto.add_theme_color_override("font_color", Color(0.3, 1.0, 0.55))
				btn_accion_principal.text = "🌲 [Enter / Espacio] Entrar a Escena 4"
			elif sobrecarga_f2:
				lbl_estado_corto.text = "SOBRECARGA DE POTENCIA (> 180.0 kW) — Reduce N₂ o f."
				lbl_estado_corto.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
				btn_accion_principal.text = "⚠️ Estabiliza en 180.0 kW"
			else:
				lbl_estado_corto.text = "POTENCIA INSUFICIENTE (< 180.0 kW) — Ajusta N₂ y f."
				lbl_estado_corto.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
				btn_accion_principal.text = "⚡ Estabiliza en 180.0 kW"

	_actualizar_ondas_reactor()
	if lienzo_simulacion:
		lienzo_simulacion.queue_redraw()

func _actualizar_ondas_reactor() -> void:
	if not linea_onda_meta or not linea_onda_jugador:
		return
	var x0 := 285.0
	var ancho := 295.0
	var cy := 82.0
	var val := _calcular_valor_actual()
	var meta := F1_META_TESLA if fase_actual == 1 else F2_META_POTENCIA
	var ratio := clampf(val / meta, 0.15, 1.65)
	var frec_vis := (F1_CORRIENTES[idx_param_b] * 0.75) if fase_actual == 1 else F2_FRECUENCIAS[idx_param_b]

	var pts_m := PackedVector2Array()
	var pts_j := PackedVector2Array()
	var muestras := 50
	for i in range(muestras + 1):
		var t := float(i) / float(muestras)
		var px := x0 + t * ancho
		var ym := cy - sin(t * 3.0 * TAU - tiempo_sim * 3.2) * 42.0
		var yj := cy - sin(t * frec_vis * TAU - tiempo_sim * 3.2) * (42.0 * ratio)
		pts_m.append(Vector2(px, ym))
		pts_j.append(Vector2(px, yj))

	linea_onda_meta.points = pts_m
	linea_onda_jugador.points = pts_j

	var en_meta := is_equal_approx(val, meta) or (fase_actual == 2 and puerta_abierta)
	var sobrecarga := val > meta + (0.02 if fase_actual == 1 else 2.0)
	if en_meta:
		linea_onda_jugador.default_color = Color(0.25, 1.0, 0.55, 0.98)
	elif sobrecarga:
		linea_onda_jugador.default_color = Color(1.0, 0.32, 0.35, 0.98)
	else:
		linea_onda_jugador.default_color = Color(1.0, 0.82, 0.25, 0.95)

func _on_dibujar_reactor_maestro() -> void:
	if not lienzo_simulacion:
		return
	var w := lienzo_simulacion.size.x
	var h := lienzo_simulacion.size.y
	if w <= 10.0:
		w = 600.0
		h = 165.0

	lienzo_simulacion.draw_rect(Rect2(0, 0, w, h), Color(0.04, 0.06, 0.1, 0.95), true)
	lienzo_simulacion.draw_rect(Rect2(0, 0, w, h), Color(0.22, 0.45, 0.68, 0.6), false, 1.5)

	# Mitad izquierda: Núcleo del Reactor Maestro con anillos concéntricos
	var cx := 135.0
	var cy := h * 0.54
	var val := _calcular_valor_actual()
	var meta := F1_META_TESLA if fase_actual == 1 else F2_META_POTENCIA
	var en_meta := is_equal_approx(val, meta) or (fase_actual == 2 and puerta_abierta)
	var sobrecarga := val > meta + (0.02 if fase_actual == 1 else 2.0)

	var col_anillo_1 := Color(0.25, 1.0, 0.55, 0.9) if (fase_1_completada or (fase_actual == 1 and en_meta)) else (Color(1.0, 0.32, 0.35, 0.9) if (fase_actual == 1 and sobrecarga) else Color(0.95, 0.72, 0.22, 0.85))
	var col_anillo_2 := Color(0.25, 1.0, 0.55, 0.95) if puerta_abierta else (Color(1.0, 0.32, 0.35, 0.9) if (fase_actual == 2 and sobrecarga) else (Color(0.3, 0.88, 1.0, 0.85) if fase_actual == 2 else Color(0.3, 0.38, 0.5, 0.45)))

	var pulso := sin(tiempo_sim * 4.0) * 3.0
	lienzo_simulacion.draw_arc(Vector2(cx, cy), 46.0 + pulso, 0.0, TAU, 40, col_anillo_1, 4.0)
	lienzo_simulacion.draw_arc(Vector2(cx, cy), 28.0 - pulso * 0.6, 0.0, TAU, 32, col_anillo_2, 4.0)
	lienzo_simulacion.draw_circle(Vector2(cx, cy), 12.0, col_anillo_2)

	var font := ThemeDB.fallback_font
	if font:
		var txt_f1 := "F1: 1.50 T OK" if fase_1_completada else "F1: AMPÈRE"
		var txt_f2 := "F2: 180 kW OK" if puerta_abierta else "F2: FARADAY"
		lienzo_simulacion.draw_string(font, Vector2(20, 20), "NÚCLEO MAESTRO (" + txt_f1 + " | " + txt_f2 + ")", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.92, 1.0))
		lienzo_simulacion.draw_string(font, Vector2(290, 20), "SINCRONIZADOR DE ONDA EN TIEMPO REAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.92, 1.0))

	# Mitad derecha: Osciloscopio de sincronía
	lienzo_simulacion.draw_rect(Rect2(280, 26, 305, h - 38), Color(0.02, 0.04, 0.07, 0.95), true)
	lienzo_simulacion.draw_rect(Rect2(280, 26, 305, h - 38), Color(0.2, 0.4, 0.55, 0.6), false, 1.0)
	lienzo_simulacion.draw_line(Vector2(280, 82), Vector2(585, 82), Color(0.3, 0.45, 0.6, 0.4), 1.0)

# ==============================================================================
# ENTRADA, DETECCIÓN Y CONTROL DE CÁMARA/MOVIMIENTO
# ==============================================================================
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if kc == KEY_E:
			_tecla_e_prev = true
			if panel_ui and panel_ui.is_visible_in_tree():
				_cerrar_panel()
				get_viewport().set_input_as_handled()
			elif jugador_cerca_consola or jugador_cerca_portal:
				_abrir_panel()
				get_viewport().set_input_as_handled()
			return

		if not panel_ui or not panel_ui.is_visible_in_tree():
			return

		if kc in [KEY_1, KEY_KP_1, KEY_S, KEY_DOWN]:
			_ajustar_param_a(-1)
			get_viewport().set_input_as_handled()
		elif kc in [KEY_2, KEY_KP_2, KEY_W, KEY_UP]:
			_ajustar_param_a(1)
			get_viewport().set_input_as_handled()
		elif kc in [KEY_A, KEY_LEFT]:
			_ajustar_param_b(-1)
			get_viewport().set_input_as_handled()
		elif kc in [KEY_D, KEY_RIGHT]:
			_ajustar_param_b(1)
			get_viewport().set_input_as_handled()
		elif kc in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_ejecutar_accion_principal()
			get_viewport().set_input_as_handled()
		elif kc == KEY_ESCAPE:
			_cerrar_panel()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	tiempo_sim += delta
	if panel_ui and panel_ui.is_visible_in_tree():
		_actualizar_ondas_reactor()
		if lienzo_simulacion:
			lienzo_simulacion.queue_redraw()

	var nodo_p1 := get_parent().get_node_or_null("PuzzleElectroimanPuente")
	if luz_pilon_1 and nodo_p1 and "completado" in nodo_p1:
		luz_pilon_1.color = Color(0.25, 1.0, 0.55, 0.95) if bool(nodo_p1.get("completado")) else Color(0.9, 0.25, 0.25, 0.9)
	var nodo_p2 := get_parent().get_node_or_null("PuzzleInduccionFaraday")
	if luz_pilon_2 and nodo_p2 and "completado" in nodo_p2:
		luz_pilon_2.color = Color(0.25, 1.0, 0.55, 0.95) if bool(nodo_p2.get("completado")) else Color(0.9, 0.25, 0.25, 0.9)

	if area_consola_ref and area_consola_ref.monitoring:
		var det_c := false
		for b in area_consola_ref.get_overlapping_bodies():
			if b is CharacterBody2D or b.is_in_group("jugador"):
				det_c = true
				jugador_ref = b
				break
		jugador_cerca_consola = det_c
		if lbl_prompt_consola:
			lbl_prompt_consola.visible = jugador_cerca_consola and not (panel_ui and panel_ui.is_visible_in_tree())

	if area_portal_ref and area_portal_ref.monitoring:
		var det_p := false
		for b in area_portal_ref.get_overlapping_bodies():
			if b is CharacterBody2D or b.is_in_group("jugador"):
				det_p = true
				jugador_ref = b
				break
		jugador_cerca_portal = det_p
		if lbl_prompt_portal:
			lbl_prompt_portal.visible = jugador_cerca_portal and not (panel_ui and panel_ui.is_visible_in_tree())

	var e_actual: bool = Input.is_physical_key_pressed(KEY_E) or Input.is_key_pressed(KEY_E)
	if e_actual and not _tecla_e_prev:
		if panel_ui and panel_ui.is_visible_in_tree():
			_cerrar_panel()
		elif jugador_cerca_consola or jugador_cerca_portal:
			_abrir_panel()
	_tecla_e_prev = e_actual

func _abrir_panel() -> void:
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
			if nodo == lbl_prompt_consola:
				nodo.visible = mostrar and jugador_cerca_consola
			elif nodo == lbl_prompt_portal:
				nodo.visible = mostrar and jugador_cerca_portal
			else:
				nodo.visible = mostrar

func _on_consola_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D or body.is_in_group("jugador"):
		jugador_cerca_consola = true
		jugador_ref = body
		_actualizar_visuales()

func _on_consola_body_exited(body: Node2D) -> void:
	if body == jugador_ref:
		jugador_cerca_consola = false
		if lbl_prompt_consola:
			lbl_prompt_consola.visible = false
		if not jugador_cerca_portal and panel_ui and panel_ui.is_visible_in_tree():
			_cerrar_panel()

func _on_consola_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if panel_ui and panel_ui.is_visible_in_tree():
			_cerrar_panel()
		else:
			_abrir_panel()

func _on_portal_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D or body.is_in_group("jugador"):
		jugador_cerca_portal = true
		jugador_ref = body
		if puerta_abierta:
			_cargar_escena_4()

func _on_portal_body_exited(body: Node2D) -> void:
	if body == jugador_ref:
		jugador_cerca_portal = false
		if lbl_prompt_portal:
			lbl_prompt_portal.visible = false
		if not jugador_cerca_consola and panel_ui and panel_ui.is_visible_in_tree():
			_cerrar_panel()

func _on_portal_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if panel_ui and panel_ui.is_visible_in_tree():
			_cerrar_panel()
		else:
			_abrir_panel()
