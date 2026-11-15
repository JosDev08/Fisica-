extends Node2D

# ==============================================================================
# NIVEL 2 — PUZZLE DE CAPACITORES EN SERIE Y PARALELO (PUENTE RETRÁCTIL)
# Archivo: res://Codigo/nivel_2_capacitores.gd
# Escena vinculada: res://Escenas/escena_02.tscn -> Avance a res://Escenas/escena_03.tscn
#
# Características implementadas:
# - Lógica física completa de capacitores en Serie y Paralelo:
#     C1 = 6.0 µF, C2 = 12.0 µF, Meta C_eq = 18.0 µF
#     Serie:    C_eq = (C1 * C2) / (C1 + C2) = 4.0 µF (Insuficiente)
#     Paralelo: C_eq = C1 + C2 = 18.0 µF (Activa el puente retráctil)
# - Panel visual limpio (PanelContainer oscuro con alfa ~0.95 en CanvasLayer layer = 10),
#   ocultando todos los textos flotantes del escenario mientras el modal está abierto.
# - Diagrama dinámico en tiempo real (Line2D + ColorRect) que redibuja las ramas
#   en Serie (1 lazo único) o Paralelo (2 ramas derivadas) con pulsos de energía,
#   junto con barra superior OBJETIVO vs ACTUAL y ProgressBar sin párrafos largos.
# - Controles de teclado verificados:
#     * [E] / [Esc]: Cerrar panel devolviendo de inmediato el movimiento al jugador
#     * [1] / [2] o Flechas Izquierda/Derecha (o A/D): Alternar Serie / Paralelo
#     * [Enter] / [Space]: Confirmar e intentar activar el puente retráctil
#   Procesa teclas únicamente cuando panel_contenedor.is_visible_in_tree() es true
#   y aplica focus_mode = Control.FOCUS_NONE en todos los botones.
# ==============================================================================

@export var c1_uf: float = 6.0
@export var c2_uf: float = 12.0
@export var meta_ceq_uf: float = 18.0
@export var escena_siguiente: String = "res://Escenas/escena_03.tscn"

const PARES_CAPACITORES: Array = [
	[6.0, 12.0],
	[4.0, 12.0],
	[10.0, 10.0],
	[6.0, 3.0],
	[12.0, 24.0]
]
const ESCENA_SIGUIENTE_DEFAULT: String = "res://Escenas/escena_03.tscn"

# Estado del puzzle: 0 = Serie, 1 = Paralelo
var modo_objetivo: int = 1
var modo_conexion: int = 0
var puente_activo: bool = false
var jugador_cerca: bool = false
var panel_abierto: bool = false
var area_terminal_ref: Area2D = null
var _tecla_e_prev: bool = false
var fase_energia: float = 0.0
var _delegado_a_nodo_hijo: bool = false

# Nodos del mundo
var cuerpo_puente: StaticBody2D = null
var colision_puente: CollisionShape2D = null
var visual_puente: Node2D = null
var rect_puente_relleno: ColorRect = null
var rect_puente_borde: ColorRect = null
var cable_energia: Line2D = null
var label_prompt: Label = null
var label_estado_puente: Label = null
var area_portal_salida: Area2D = null

# Nodos de la UI (CanvasLayer superior layer = 10)
var canvas_ui: CanvasLayer = null
var panel_contenedor: PanelContainer = null
var lbl_hud_estado: Label = null
var barra_progreso: ProgressBar = null
var lienzo_circuito: Control = null
var linea_serie: Line2D = null
var linea_paralelo_troncal: Line2D = null
var linea_paralelo_rama1: Line2D = null
var linea_paralelo_rama2: Line2D = null
var bloque_c1: ColorRect = null
var bloque_c2: ColorRect = null
var lbl_c1_diag: Label = null
var lbl_c2_diag: Label = null
var nodo_union_sup: ColorRect = null
var nodo_union_inf: ColorRect = null
var bloque_puente_diag: ColorRect = null
var lbl_bloque_puente_diag: Label = null
var pulsos_energia: Array[ColorRect] = []
var lbl_operacion_corta: Label = null
var btn_modo_serie: Button = null
var btn_modo_paralelo: Button = null
var btn_confirmar_puente: Button = null

func _ready() -> void:
	randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_asegurar_input_interactuar()

	# Si este script está en la raíz y ya existe PuzzlePuenteCapacitores con su propio script activo,
	# evitamos duplicar geometría en el mundo.
	var otro_puzzle := get_node_or_null("PuzzlePuenteCapacitores")
	if otro_puzzle != null and otro_puzzle != self and otro_puzzle.get_script() != null and otro_puzzle.get_script() != get_script():
		_delegado_a_nodo_hijo = true
		return

	_vincular_o_construir_mundo()
	_construir_interfaz_ui()
	generar_nuevo_puzzle()

func generar_nuevo_puzzle() -> void:
	var par: Array = PARES_CAPACITORES[randi() % PARES_CAPACITORES.size()]
	c1_uf = float(par[0])
	c2_uf = float(par[1])
	modo_objetivo = randi() % 2 # 0 = Serie, 1 = Paralelo
	if modo_objetivo == 0:
		meta_ceq_uf = (c1_uf * c2_uf) / (c1_uf + c2_uf)
	else:
		meta_ceq_uf = c1_uf + c2_uf

	# Verificar con un bucle while que el control nunca empiece ya resuelto ni coincida con el OBJETIVO
	modo_conexion = randi() % 2
	while is_equal_approx(calcular_capacitancia_actual(), meta_ceq_uf) or modo_conexion == modo_objetivo:
		modo_conexion = 1 - modo_conexion

	if barra_progreso != null:
		barra_progreso.max_value = max(c1_uf + c2_uf, meta_ceq_uf * 1.5)
	if lbl_c1_diag != null:
		lbl_c1_diag.text = "C1\n%.0f µF" % c1_uf
	if lbl_c2_diag != null:
		lbl_c2_diag.text = "C2\n%.0f µF" % c2_uf

	_actualizar_estado_circuito()

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

# ==============================================================================
# CONSTRUCCIÓN O VINCULACIÓN DE NODOS DEL MUNDO
# ==============================================================================
func _vincular_o_construir_mundo() -> void:
	# Soporte híbrido: si existen nodos pre-creados en la escena (ej. PuzzlePuente), los usa;
	# si no existen, construye el terminal y el puente retráctil en las coordenadas de escena_02.tscn.
	var terminal_existente := get_node_or_null("PuzzlePuente/TerminalPuenteArea") as Area2D
	if terminal_existente == null:
		terminal_existente = get_node_or_null("TerminalPuente") as Area2D

	var puente_existente := get_node_or_null("PuzzlePuente/PuenteBody") as StaticBody2D
	if puente_existente == null:
		puente_existente = get_node_or_null("PuenteRetractil") as StaticBody2D

	if terminal_existente != null and puente_existente != null:
		area_terminal_ref = terminal_existente
		area_terminal_ref.monitoring = true
		area_terminal_ref.collision_mask = 1 # Capa 1: Jugador
		if not area_terminal_ref.body_entered.is_connected(_on_terminal_body_entered):
			area_terminal_ref.body_entered.connect(_on_terminal_body_entered)
		if not area_terminal_ref.body_exited.is_connected(_on_terminal_body_exited):
			area_terminal_ref.body_exited.connect(_on_terminal_body_exited)

		cuerpo_puente = puente_existente
		cuerpo_puente.collision_layer = 16 # Capa 5: Suelo
		colision_puente = cuerpo_puente.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if colision_puente != null:
			colision_puente.disabled = true

		label_prompt = area_terminal_ref.get_node_or_null("PromptLabel") as Label
		if label_prompt == null:
			label_prompt = Label.new()
			label_prompt.name = "PromptLabel"
			label_prompt.text = "[E] Interactuar"
			label_prompt.position = Vector2(-65, -72)
			label_prompt.add_theme_font_size_override("font_size", 14)
			label_prompt.add_theme_color_override("font_color", Color(1.0, 0.95, 0.3))
			label_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			label_prompt.add_theme_constant_override("outline_size", 4)
			label_prompt.visible = false
			area_terminal_ref.add_child(label_prompt)
		label_prompt.add_to_group("texto_mundo_nivel2")

		label_estado_puente = get_node_or_null("PuzzlePuente/LabelPuenteEstado") as Label
		if label_estado_puente == null:
			label_estado_puente = get_node_or_null("LabelEstadoPuente") as Label
		if label_estado_puente != null:
			label_estado_puente.add_to_group("texto_mundo_nivel2")
		return

	# Construcción limpia para escena_02.tscn
	# 1. Cable de energía entre el terminal (-96, -32) y el puente (168, 10)
	cable_energia = Line2D.new()
	cable_energia.name = "CableEnergiaPuente"
	cable_energia.width = 4.0
	cable_energia.default_color = Color(0.95, 0.55, 0.15, 0.85)
	cable_energia.points = PackedVector2Array([
		Vector2(-96, -16),
		Vector2(-96, 10),
		Vector2(-64, 10)
	])
	cable_energia.z_index = -1
	add_child(cable_energia)

	# 2. Puente Retráctil en Capa 5 Suelo (collision_layer = 16)
	cuerpo_puente = StaticBody2D.new()
	cuerpo_puente.name = "PuenteRetractil"
	cuerpo_puente.position = Vector2(168, 10)
	cuerpo_puente.collision_layer = 16 # Capa 5: Suelo
	cuerpo_puente.collision_mask = 0
	add_child(cuerpo_puente)

	colision_puente = CollisionShape2D.new()
	colision_puente.name = "CollisionShape2D"
	var shape_puente := RectangleShape2D.new()
	shape_puente.size = Vector2(464, 20)
	colision_puente.shape = shape_puente
	colision_puente.disabled = true
	cuerpo_puente.add_child(colision_puente)

	visual_puente = Node2D.new()
	visual_puente.name = "VisualPuente"
	cuerpo_puente.add_child(visual_puente)

	rect_puente_relleno = ColorRect.new()
	rect_puente_relleno.offset_left = -232.0
	rect_puente_relleno.offset_top = -10.0
	rect_puente_relleno.offset_right = 232.0
	rect_puente_relleno.offset_bottom = 10.0
	rect_puente_relleno.color = Color(0.9, 0.45, 0.1, 0.22)
	visual_puente.add_child(rect_puente_relleno)

	rect_puente_borde = ColorRect.new()
	rect_puente_borde.offset_left = -232.0
	rect_puente_borde.offset_top = -10.0
	rect_puente_borde.offset_right = 232.0
	rect_puente_borde.offset_bottom = -6.0
	rect_puente_borde.color = Color(1.0, 0.55, 0.15, 0.45)
	visual_puente.add_child(rect_puente_borde)

	label_estado_puente = Label.new()
	label_estado_puente.name = "LabelEstadoPuente"
	label_estado_puente.text = "PUENTE DESACTIVADO (4.0 / 18.0 µF)"
	label_estado_puente.position = Vector2(35, -24)
	label_estado_puente.add_theme_font_size_override("font_size", 13)
	label_estado_puente.add_theme_color_override("font_color", Color(1.0, 0.65, 0.25))
	label_estado_puente.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label_estado_puente.add_theme_constant_override("outline_size", 4)
	label_estado_puente.add_to_group("texto_mundo_nivel2")
	add_child(label_estado_puente)

	# 3. Terminal interactivo (Area2D en Capa 1 Jugador)
	var area_term := Area2D.new()
	area_term.name = "TerminalPuente"
	area_term.position = Vector2(-96, -32)
	area_term.collision_layer = 0
	area_term.collision_mask = 1 # Capa 1: Jugador
	area_term.monitoring = true
	area_term.monitorable = true
	add_child(area_term)
	area_terminal_ref = area_term

	var col_term := CollisionShape2D.new()
	var shape_term := RectangleShape2D.new()
	shape_term.size = Vector2(96, 84)
	col_term.shape = shape_term
	area_term.add_child(col_term)

	if ResourceLoader.exists("res://assets/nivel_2/terminal_capacitores.svg"):
		var spr_term := Sprite2D.new()
		spr_term.texture = load("res://assets/nivel_2/terminal_capacitores.svg")
		area_term.add_child(spr_term)
	else:
		var cuerpo_kiosco := ColorRect.new()
		cuerpo_kiosco.offset_left = -20.0
		cuerpo_kiosco.offset_top = -28.0
		cuerpo_kiosco.offset_right = 20.0
		cuerpo_kiosco.offset_bottom = 28.0
		cuerpo_kiosco.color = Color(0.12, 0.2, 0.32, 1.0)
		area_term.add_child(cuerpo_kiosco)

	label_prompt = Label.new()
	label_prompt.name = "LabelPrompt"
	label_prompt.text = "[E] Interactuar"
	label_prompt.position = Vector2(-58, -64)
	label_prompt.add_theme_font_size_override("font_size", 14)
	label_prompt.add_theme_color_override("font_color", Color(1.0, 0.95, 0.3))
	label_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label_prompt.add_theme_constant_override("outline_size", 4)
	label_prompt.visible = false
	label_prompt.add_to_group("texto_mundo_nivel2")
	area_term.add_child(label_prompt)

	area_term.body_entered.connect(_on_terminal_body_entered)
	area_term.body_exited.connect(_on_terminal_body_exited)

# ==============================================================================
# UI DEL PUZZLE (PANEL LIMPIO ALFA ~0.95 EN CANVASLAYER SUPERIOR + DIAGRAMA VIVO)
# ==============================================================================
func _construir_interfaz_ui() -> void:
	canvas_ui = CanvasLayer.new()
	canvas_ui.name = "CanvasPuenteCapacitores"
	canvas_ui.layer = 10
	canvas_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas_ui)

	panel_contenedor = PanelContainer.new()
	panel_contenedor.name = "PanelPuenteCapacitores"
	panel_contenedor.anchor_left = 0.5
	panel_contenedor.anchor_top = 0.5
	panel_contenedor.anchor_right = 0.5
	panel_contenedor.anchor_bottom = 0.5
	panel_contenedor.offset_left = -350.0
	panel_contenedor.offset_top = -235.0
	panel_contenedor.offset_right = 350.0
	panel_contenedor.offset_bottom = 235.0
	panel_contenedor.visible = false
	panel_contenedor.focus_mode = Control.FOCUS_NONE

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.05, 0.08, 0.14, 0.95)
	estilo.border_color = Color(0.2, 0.8, 1.0, 0.95)
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(10)
	estilo.set_content_margin_all(18)
	panel_contenedor.add_theme_stylebox_override("panel", estilo)
	canvas_ui.add_child(panel_contenedor)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.focus_mode = Control.FOCUS_NONE
	panel_contenedor.add_child(vbox)

	# 1. Encabezado compacto + Botón [X]
	var header_hbox := HBoxContainer.new()
	header_hbox.focus_mode = Control.FOCUS_NONE
	vbox.add_child(header_hbox)

	var lbl_titulo := Label.new()
	lbl_titulo.text = "BANCO DE CAPACITORES — PUENTE RETRÁCTIL"
	lbl_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_titulo.add_theme_font_size_override("font_size", 18)
	lbl_titulo.add_theme_color_override("font_color", Color(0.35, 0.9, 1.0))
	header_hbox.add_child(lbl_titulo)

	var btn_cerrar_x := Button.new()
	btn_cerrar_x.text = " [X] Cerrar (E / Esc) "
	btn_cerrar_x.focus_mode = Control.FOCUS_NONE
	btn_cerrar_x.pressed.connect(_cerrar_panel)
	header_hbox.add_child(btn_cerrar_x)

	# 2. Barra de estado superior compacta: OBJETIVO: 18.0 µF vs ACTUAL: [valor] µF + ProgressBar
	var hud_hbox := HBoxContainer.new()
	hud_hbox.add_theme_constant_override("separation", 16)
	hud_hbox.focus_mode = Control.FOCUS_NONE
	vbox.add_child(hud_hbox)

	lbl_hud_estado = Label.new()
	lbl_hud_estado.text = "OBJETIVO: 18.0 µF   |   ACTUAL: 4.0 µF"
	lbl_hud_estado.add_theme_font_size_override("font_size", 16)
	lbl_hud_estado.add_theme_color_override("font_color", Color(1.0, 0.78, 0.25))
	hud_hbox.add_child(lbl_hud_estado)

	barra_progreso = ProgressBar.new()
	barra_progreso.min_value = 0.0
	barra_progreso.max_value = meta_ceq_uf
	barra_progreso.value = 4.0
	barra_progreso.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra_progreso.custom_minimum_size = Vector2(200, 24)
	barra_progreso.show_percentage = false
	barra_progreso.focus_mode = Control.FOCUS_NONE
	hud_hbox.add_child(barra_progreso)

	# 3. Lienzo del diagrama interactivo del circuito en tiempo real
	var marco_diag := PanelContainer.new()
	marco_diag.custom_minimum_size = Vector2(640, 215)
	marco_diag.focus_mode = Control.FOCUS_NONE
	var estilo_diag := StyleBoxFlat.new()
	estilo_diag.bg_color = Color(0.03, 0.05, 0.09, 0.98)
	estilo_diag.border_color = Color(0.18, 0.35, 0.55, 0.85)
	estilo_diag.set_border_width_all(2)
	estilo_diag.set_corner_radius_all(8)
	marco_diag.add_theme_stylebox_override("panel", estilo_diag)
	vbox.add_child(marco_diag)

	lienzo_circuito = Control.new()
	lienzo_circuito.custom_minimum_size = Vector2(636, 211)
	lienzo_circuito.focus_mode = Control.FOCUS_NONE
	marco_diag.add_child(lienzo_circuito)

	_construir_nodos_diagrama()

	# 4. Operación corta en 1 línea (sin párrafos largos)
	lbl_operacion_corta = Label.new()
	lbl_operacion_corta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_operacion_corta.add_theme_font_size_override("font_size", 15)
	lbl_operacion_corta.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	vbox.add_child(lbl_operacion_corta)

	# 5. Controles de Topología ([ 1: EN SERIE ] / [ 2: EN PARALELO ]) y Confirmación
	var botones_hbox := HBoxContainer.new()
	botones_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	botones_hbox.add_theme_constant_override("separation", 14)
	botones_hbox.focus_mode = Control.FOCUS_NONE
	vbox.add_child(botones_hbox)

	btn_modo_serie = Button.new()
	btn_modo_serie.text = " [1 / ◄] CONEXIÓN EN SERIE "
	btn_modo_serie.custom_minimum_size = Vector2(215, 38)
	btn_modo_serie.focus_mode = Control.FOCUS_NONE
	btn_modo_serie.pressed.connect(func(): _seleccionar_modo(0))
	botones_hbox.add_child(btn_modo_serie)

	btn_modo_paralelo = Button.new()
	btn_modo_paralelo.text = " [2 / ►] CONEXIÓN EN PARALELO "
	btn_modo_paralelo.custom_minimum_size = Vector2(215, 38)
	btn_modo_paralelo.focus_mode = Control.FOCUS_NONE
	btn_modo_paralelo.pressed.connect(func(): _seleccionar_modo(1))
	botones_hbox.add_child(btn_modo_paralelo)

	btn_confirmar_puente = Button.new()
	btn_confirmar_puente.text = " [Enter/Espacio] ACTIVAR PUENTE "
	btn_confirmar_puente.custom_minimum_size = Vector2(185, 38)
	btn_confirmar_puente.focus_mode = Control.FOCUS_NONE
	btn_confirmar_puente.pressed.connect(_confirmar_activacion_puente)
	botones_hbox.add_child(btn_confirmar_puente)

	# 6. Pie de controles claro y directo
	var lbl_controles := Label.new()
	lbl_controles.text = "Teclado: [1/2] o [◄/►] Alternar Serie/Paralelo  |  [Enter/Espacio] Activar Puente  |  [E/Esc] Cerrar"
	lbl_controles.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_controles.add_theme_font_size_override("font_size", 12)
	lbl_controles.add_theme_color_override("font_color", Color(0.65, 0.78, 0.9))
	vbox.add_child(lbl_controles)

func _construir_nodos_diagrama() -> void:
	# Líneas de conexión para modo SERIE (un solo camino continuo)
	linea_serie = Line2D.new()
	linea_serie.width = 4.0
	linea_serie.default_color = Color(1.0, 0.6, 0.15, 0.95)
	linea_serie.points = PackedVector2Array([
		Vector2(65, 130),
		Vector2(65, 48),
		Vector2(540, 48),
		Vector2(540, 172),
		Vector2(65, 172),
		Vector2(65, 130)
	])
	lienzo_circuito.add_child(linea_serie)

	# Líneas de conexión para modo PARALELO (troncal + 2 ramas independientes)
	linea_paralelo_troncal = Line2D.new()
	linea_paralelo_troncal.width = 4.0
	linea_paralelo_troncal.default_color = Color(0.2, 1.0, 0.55, 0.95)
	linea_paralelo_troncal.points = PackedVector2Array([
		Vector2(65, 130),
		Vector2(65, 32),
		Vector2(540, 32),
		Vector2(540, 184),
		Vector2(65, 184),
		Vector2(65, 130)
	])
	lienzo_circuito.add_child(linea_paralelo_troncal)

	linea_paralelo_rama1 = Line2D.new()
	linea_paralelo_rama1.width = 4.0
	linea_paralelo_rama1.default_color = Color(0.2, 1.0, 0.55, 0.95)
	linea_paralelo_rama1.points = PackedVector2Array([
		Vector2(215, 32),
		Vector2(215, 184)
	])
	lienzo_circuito.add_child(linea_paralelo_rama1)

	linea_paralelo_rama2 = Line2D.new()
	linea_paralelo_rama2.width = 4.0
	linea_paralelo_rama2.default_color = Color(0.2, 1.0, 0.55, 0.95)
	linea_paralelo_rama2.points = PackedVector2Array([
		Vector2(365, 32),
		Vector2(365, 184)
	])
	lienzo_circuito.add_child(linea_paralelo_rama2)

	# Nodos de derivación (visibles en modo Paralelo)
	nodo_union_sup = ColorRect.new()
	nodo_union_sup.size = Vector2(10, 10)
	nodo_union_sup.position = Vector2(210, 27)
	nodo_union_sup.color = Color(0.4, 1.0, 0.7)
	lienzo_circuito.add_child(nodo_union_sup)

	nodo_union_inf = ColorRect.new()
	nodo_union_inf.size = Vector2(10, 10)
	nodo_union_inf.position = Vector2(210, 179)
	nodo_union_inf.color = Color(0.4, 1.0, 0.7)
	lienzo_circuito.add_child(nodo_union_inf)

	# Bloque Fuente V (izquierda)
	var bloque_fuente := ColorRect.new()
	bloque_fuente.position = Vector2(26, 78)
	bloque_fuente.size = Vector2(78, 56)
	bloque_fuente.color = Color(0.1, 0.2, 0.34, 1.0)
	lienzo_circuito.add_child(bloque_fuente)

	var lbl_fuente := Label.new()
	lbl_fuente.text = "FUENTE\n+   -"
	lbl_fuente.position = Vector2(6, 6)
	lbl_fuente.add_theme_font_size_override("font_size", 13)
	lbl_fuente.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	bloque_fuente.add_child(lbl_fuente)

	# Bloque Capacitor C1 (6 µF)
	bloque_c1 = ColorRect.new()
	bloque_c1.size = Vector2(96, 48)
	bloque_c1.color = Color(0.12, 0.28, 0.45, 1.0)
	lienzo_circuito.add_child(bloque_c1)

	var placa1_a := ColorRect.new()
	placa1_a.position = Vector2(12, 6)
	placa1_a.size = Vector2(5, 36)
	placa1_a.color = Color(0.35, 0.92, 1.0)
	bloque_c1.add_child(placa1_a)

	var placa1_b := ColorRect.new()
	placa1_b.position = Vector2(22, 6)
	placa1_b.size = Vector2(5, 36)
	placa1_b.color = Color(0.35, 0.92, 1.0)
	bloque_c1.add_child(placa1_b)

	lbl_c1_diag = Label.new()
	lbl_c1_diag.text = "C1\n%.0f µF" % c1_uf
	lbl_c1_diag.position = Vector2(34, 4)
	lbl_c1_diag.add_theme_font_size_override("font_size", 13)
	lbl_c1_diag.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	bloque_c1.add_child(lbl_c1_diag)

	# Bloque Capacitor C2
	bloque_c2 = ColorRect.new()
	bloque_c2.size = Vector2(96, 48)
	bloque_c2.color = Color(0.12, 0.28, 0.45, 1.0)
	lienzo_circuito.add_child(bloque_c2)

	var placa2_a := ColorRect.new()
	placa2_a.position = Vector2(12, 6)
	placa2_a.size = Vector2(5, 36)
	placa2_a.color = Color(0.35, 0.92, 1.0)
	bloque_c2.add_child(placa2_a)

	var placa2_b := ColorRect.new()
	placa2_b.position = Vector2(22, 6)
	placa2_b.size = Vector2(5, 36)
	placa2_b.color = Color(0.35, 0.92, 1.0)
	bloque_c2.add_child(placa2_b)

	lbl_c2_diag = Label.new()
	lbl_c2_diag.text = "C2\n%.0f µF" % c2_uf
	lbl_c2_diag.position = Vector2(34, 4)
	lbl_c2_diag.add_theme_font_size_override("font_size", 13)
	lbl_c2_diag.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	bloque_c2.add_child(lbl_c2_diag)

	# Bloque Receptor del Puente (derecha)
	bloque_puente_diag = ColorRect.new()
	bloque_puente_diag.position = Vector2(490, 78)
	bloque_puente_diag.size = Vector2(105, 58)
	bloque_puente_diag.color = Color(0.28, 0.14, 0.08, 1.0)
	lienzo_circuito.add_child(bloque_puente_diag)

	lbl_bloque_puente_diag = Label.new()
	lbl_bloque_puente_diag.text = "PUENTE\nAPAGADO"
	lbl_bloque_puente_diag.position = Vector2(10, 8)
	lbl_bloque_puente_diag.add_theme_font_size_override("font_size", 13)
	lbl_bloque_puente_diag.add_theme_color_override("font_color", Color(1.0, 0.7, 0.35))
	bloque_puente_diag.add_child(lbl_bloque_puente_diag)

	# Pulsos animados de energía sobre los cables
	for i in range(6):
		var pulso := ColorRect.new()
		pulso.size = Vector2(8, 8)
		pulso.color = Color(1.0, 0.85, 0.3, 0.95)
		lienzo_circuito.add_child(pulso)
		pulsos_energia.append(pulso)

# ==============================================================================
# LÓGICA MATEMÁTICA Y VISUAL DEL CIRCUITO EN TIEMPO REAL
# ==============================================================================
func calcular_capacitancia_actual() -> float:
	if modo_conexion == 0:
		# Serie: (C1 * C2) / (C1 + C2) = 4.0 µF
		return (c1_uf * c2_uf) / (c1_uf + c2_uf)
	# Paralelo: C1 + C2 = 18.0 µF
	return c1_uf + c2_uf

func _seleccionar_modo(nuevo_modo: int) -> void:
	modo_conexion = clampi(nuevo_modo, 0, 1)
	_actualizar_estado_circuito()

func _actualizar_estado_circuito() -> void:
	var ceq := calcular_capacitancia_actual()
	var en_meta := is_equal_approx(ceq, meta_ceq_uf)

	if lbl_c1_diag != null:
		lbl_c1_diag.text = "C1\n%.0f µF" % c1_uf
	if lbl_c2_diag != null:
		lbl_c2_diag.text = "C2\n%.0f µF" % c2_uf

	# Actualizar barra superior compacta y ProgressBar
	if lbl_hud_estado != null:
		lbl_hud_estado.text = "OBJETIVO: %.1f µF   |   ACTUAL: %.1f µF" % [meta_ceq_uf, ceq]
		lbl_hud_estado.add_theme_color_override(
			"font_color",
			Color(0.25, 1.0, 0.55) if en_meta else Color(1.0, 0.72, 0.22)
		)

	if barra_progreso != null:
		barra_progreso.max_value = max(c1_uf + c2_uf, meta_ceq_uf * 1.5)
		barra_progreso.value = ceq
		var estilo_fill := StyleBoxFlat.new()
		estilo_fill.bg_color = Color(0.18, 0.92, 0.45) if en_meta else Color(0.95, 0.55, 0.15)
		estilo_fill.set_corner_radius_all(4)
		barra_progreso.add_theme_stylebox_override("fill", estilo_fill)

	# Redibujar topología en el diagrama
	if modo_conexion == 0:
		# MODO SERIE: C1 y C2 seguidos en la línea superior
		linea_serie.visible = true
		linea_paralelo_troncal.visible = false
		linea_paralelo_rama1.visible = false
		linea_paralelo_rama2.visible = false
		nodo_union_sup.visible = false
		nodo_union_inf.visible = false

		bloque_c1.position = Vector2(165, 24)
		bloque_c2.position = Vector2(315, 24)
		lbl_operacion_corta.text = "Topología SERIE:   C_eq = (%.0f × %.0f) / (%.0f + %.0f) = %.1f µF" % [c1_uf, c2_uf, c1_uf, c2_uf, ceq]
		lbl_operacion_corta.add_theme_color_override("font_color", Color(0.3, 1.0, 0.55) if en_meta else Color(1.0, 0.72, 0.28))
		btn_modo_serie.modulate = Color(1.0, 0.9, 0.45)
		btn_modo_paralelo.modulate = Color(0.75, 0.78, 0.85)
	else:
		# MODO PARALELO: C1 y C2 en ramas paralelas verticales
		linea_serie.visible = false
		linea_paralelo_troncal.visible = true
		linea_paralelo_rama1.visible = true
		linea_paralelo_rama2.visible = true
		nodo_union_sup.visible = true
		nodo_union_inf.visible = true

		bloque_c1.position = Vector2(167, 84)
		bloque_c2.position = Vector2(317, 84)
		lbl_operacion_corta.text = "Topología PARALELO:   C_eq = %.0f µF + %.0f µF = %.1f µF" % [c1_uf, c2_uf, ceq]
		lbl_operacion_corta.add_theme_color_override("font_color", Color(0.3, 1.0, 0.55) if en_meta else Color(1.0, 0.72, 0.28))
		btn_modo_serie.modulate = Color(0.75, 0.78, 0.85)
		btn_modo_paralelo.modulate = Color(0.4, 1.0, 0.65)

	if label_estado_puente != null and not puente_activo:
		label_estado_puente.text = "PUENTE DESACTIVADO (%.1f / %.1f µF)" % [ceq, meta_ceq_uf]

	if bloque_puente_diag != null and lbl_bloque_puente_diag != null:
		if puente_activo:
			bloque_puente_diag.color = Color(0.08, 0.36, 0.2, 1.0)
			lbl_bloque_puente_diag.text = "PUENTE\nACTIVO"
			lbl_bloque_puente_diag.add_theme_color_override("font_color", Color(0.35, 1.0, 0.6))
		elif en_meta:
			bloque_puente_diag.color = Color(0.1, 0.28, 0.22, 1.0)
			lbl_bloque_puente_diag.text = "PUENTE\nLISTO [Enter]"
			lbl_bloque_puente_diag.add_theme_color_override("font_color", Color(0.45, 1.0, 0.7))
		else:
			bloque_puente_diag.color = Color(0.28, 0.14, 0.08, 1.0)
			lbl_bloque_puente_diag.text = "PUENTE\nSIN CARGA"
			lbl_bloque_puente_diag.add_theme_color_override("font_color", Color(1.0, 0.68, 0.3))

func _confirmar_activacion_puente() -> void:
	var ceq := calcular_capacitancia_actual()
	if is_equal_approx(ceq, meta_ceq_uf):
		puente_activo = true
		if colision_puente != null:
			colision_puente.set_deferred("disabled", false)
		if rect_puente_relleno != null and rect_puente_borde != null:
			rect_puente_relleno.color = Color(0.15, 0.92, 0.55, 0.92)
			rect_puente_borde.color = Color(0.55, 1.0, 0.8, 1.0)
		elif cuerpo_puente != null:
			var poly := cuerpo_puente.get_node_or_null("PuenteVisual") as Polygon2D
			if poly != null:
				poly.color = Color(0.15, 0.92, 0.55, 0.95)
		if cable_energia != null:
			cable_energia.default_color = Color(0.2, 1.0, 0.55, 0.95)
		if label_estado_puente != null:
			label_estado_puente.text = "PUENTE EXTENDIDO (%.1f µF)" % meta_ceq_uf
			label_estado_puente.add_theme_color_override("font_color", Color(0.25, 1.0, 0.55))
		_actualizar_estado_circuito()
		_cerrar_panel()
	else:
		puente_activo = false
		if colision_puente != null:
			colision_puente.set_deferred("disabled", true)
		if rect_puente_relleno != null and rect_puente_borde != null:
			rect_puente_relleno.color = Color(0.9, 0.45, 0.1, 0.22)
			rect_puente_borde.color = Color(1.0, 0.55, 0.15, 0.45)
		if cable_energia != null:
			cable_energia.default_color = Color(0.95, 0.55, 0.15, 0.85)
		if label_estado_puente != null:
			label_estado_puente.text = "PUENTE DESACTIVADO (%.1f / %.1f µF)" % [ceq, meta_ceq_uf]
			label_estado_puente.add_theme_color_override("font_color", Color(1.0, 0.65, 0.25))
		_actualizar_estado_circuito()

# ==============================================================================
# DETECCIÓN DEL JUGADOR Y CONTROL DE VISIBILIDAD (CERO SUPERPOSICIÓN)
# ==============================================================================
func _es_jugador(body: Node) -> bool:
	if body == null:
		return false
	return body.name == "CharacterBody2D" or body.name == "Jugador" or body.is_in_group("jugador") or body is CharacterBody2D

func _on_terminal_body_entered(body: Node) -> void:
	if _es_jugador(body):
		jugador_cerca = true
		if label_prompt != null and not panel_abierto:
			label_prompt.visible = true

func _on_terminal_body_exited(body: Node) -> void:
	if _es_jugador(body):
		jugador_cerca = false
		if label_prompt != null:
			label_prompt.visible = false
		if panel_abierto:
			_cerrar_panel()

# Compatibilidad con nombres de señales heredadas en caso de estar conectadas en escena
func _on_terminal_puente_body_entered(body: Node) -> void:
	_on_terminal_body_entered(body)

func _on_terminal_puente_body_exited(body: Node) -> void:
	_on_terminal_body_exited(body)

func _on_area_puerta_salida_body_entered(body: Node) -> void:
	if _es_jugador(body) and puente_activo:
		_avanzar_a_escena_03()

func _verificar_proximidad_continua() -> void:
	if area_terminal_ref == null:
		return
	var encontrado := false
	for body in area_terminal_ref.get_overlapping_bodies():
		if _es_jugador(body):
			encontrado = true
			break
	jugador_cerca = encontrado
	if label_prompt != null:
		label_prompt.visible = jugador_cerca and not panel_abierto

func _ocultar_textos_mundo(ocultar: bool) -> void:
	for nodo in get_tree().get_nodes_in_group("texto_mundo_nivel2"):
		if nodo is CanvasItem:
			nodo.visible = not ocultar
	if label_prompt != null:
		label_prompt.visible = (not ocultar) and jugador_cerca
	if label_estado_puente != null:
		label_estado_puente.visible = not ocultar

func _set_movimiento_jugador(activo: bool) -> void:
	var escena := get_tree().current_scene
	if escena == null:
		return
	var jugador := escena.find_child("CharacterBody2D", true, false)
	if jugador == null:
		jugador = escena.find_child("Jugador", true, false)
	if jugador != null:
		jugador.set_physics_process(activo)

func _abrir_panel() -> void:
	panel_abierto = true
	panel_contenedor.visible = true
	_ocultar_textos_mundo(true)
	_set_movimiento_jugador(false)
	_actualizar_estado_circuito()

func _cerrar_panel() -> void:
	panel_abierto = false
	if panel_contenedor != null:
		panel_contenedor.visible = false
	_ocultar_textos_mundo(false)
	_set_movimiento_jugador(true)

func _avanzar_a_escena_03() -> void:
	_set_movimiento_jugador(true)
	get_tree().paused = false
	var destino := escena_siguiente if ResourceLoader.exists(escena_siguiente) else ESCENA_SIGUIENTE_DEFAULT
	if ResourceLoader.exists(destino):
		get_tree().change_scene_to_file(destino)

# ==============================================================================
# PROCESAMIENTO DE ANIMACIÓN Y TECLAS AUDITADAS
# ==============================================================================
func _process(delta: float) -> void:
	if _delegado_a_nodo_hijo:
		return

	_verificar_proximidad_continua()

	# Animación de pulsos de energía cuando el panel está visible
	if panel_abierto and panel_contenedor != null and panel_contenedor.is_visible_in_tree():
		var vel := 0.55 if modo_conexion == 0 else 1.65
		fase_energia = fmod(fase_energia + delta * vel, 1.0)
		_animar_pulsos_circuito()

	# Respaldo de tecla física E para abrir/cerrar
	var e_actual := Input.is_physical_key_pressed(KEY_E)
	if e_actual and not _tecla_e_prev:
		if panel_abierto and panel_contenedor != null and panel_contenedor.is_visible_in_tree():
			_cerrar_panel()
		elif jugador_cerca and not panel_abierto:
			_abrir_panel()
	_tecla_e_prev = e_actual

func _animar_pulsos_circuito() -> void:
	if pulsos_energia.size() < 6:
		return
	for i in range(pulsos_energia.size()):
		var t := fmod(fase_energia + float(i) / float(pulsos_energia.size()), 1.0)
		var p := pulsos_energia[i]
		if modo_conexion == 0:
			p.color = Color(1.0, 0.72, 0.2, 0.9)
			p.position = Vector2(75.0 + t * 455.0, 44.0)
		else:
			p.color = Color(0.25, 1.0, 0.6, 0.95)
			if i % 2 == 0:
				p.position = Vector2(211.0, 36.0 + t * 140.0)
			else:
				p.position = Vector2(361.0, 36.0 + t * 140.0)

func _unhandled_input(event: InputEvent) -> void:
	if _delegado_a_nodo_hijo:
		return

	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	var key: int = event.keycode if event.keycode != 0 else event.physical_keycode

	# Si el panel NO está visible en el árbol, solo permitir abrir con E si está cerca del terminal
	if panel_contenedor == null or not panel_contenedor.is_visible_in_tree():
		if (key == KEY_E or event.physical_keycode == KEY_E) and jugador_cerca and not panel_abierto:
			_tecla_e_prev = true
			_abrir_panel()
			get_viewport().set_input_as_handled()
		return

	# Controles exclusivos mientras panel_contenedor.is_visible_in_tree() es verdadero:
	if key == KEY_ESCAPE or key == KEY_E or event.physical_keycode == KEY_E:
		_tecla_e_prev = true
		_cerrar_panel()
		get_viewport().set_input_as_handled()
		return

	if key == KEY_1 or key == KEY_KP_1 or key == KEY_LEFT or key == KEY_A or event.physical_keycode == KEY_A:
		_seleccionar_modo(0)
		get_viewport().set_input_as_handled()
		return

	if key == KEY_2 or key == KEY_KP_2 or key == KEY_RIGHT or key == KEY_D or event.physical_keycode == KEY_D:
		_seleccionar_modo(1)
		get_viewport().set_input_as_handled()
		return

	if key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_SPACE:
		_confirmar_activacion_puente()
		get_viewport().set_input_as_handled()
		return
