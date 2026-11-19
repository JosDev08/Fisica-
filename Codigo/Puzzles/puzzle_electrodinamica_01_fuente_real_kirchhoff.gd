extends "res://Codigo/Puzzles/puzzle_base.gd"

# ==============================================================================
# PUZZLE ELECTRODINÁMICA 01: FUENTE REAL Y KIRCHHOFF (Física II/III Ingeniería)
# Fórmulas destacadas: V_ab = fem - I * r_i   |   I = V_ab / R_L
# Datos: fem = 48 V, r_i = 2 Ohm, V_ab = 40 V nominal.
# Solución: I = (48 - 40) / 2 = 4 A => R_L = V_ab / I = 40 / 4 = 10 Ohm.
# Opciones: 8 Ohm, 10 Ohm, 12 Ohm, 20 Ohm.
# Al resolver: abre suavemente la compuerta metálica hija en Capa 5 (Suelo).
# ==============================================================================

const FEM_V := 48.0
const R_INTERNA_OHM := 2.0
const VAB_OBJETIVO_V := 40.0
const OPCIONES_RL: Array[int] = [8, 10, 12, 20]

@export var respuesta_correcta_ohm: int = 10
@export var altura_apertura: float = 116.0
@export var velocidad_apertura: float = 180.0

@onready var compuerta_body: StaticBody2D = $CompuertaMetalica
@onready var compuerta_col: CollisionShape2D = $CompuertaMetalica/CollisionShape2D
@onready var compuerta_sprite: Sprite2D = $CompuertaMetalica/Sprite2D
@onready var lbl_estado_compuerta: Label = $CompuertaMetalica/EstadoCompuerta

var resuelto: bool = false
var pos_cerrada: Vector2 = Vector2.ZERO
var pos_abierta: Vector2 = Vector2.ZERO
var indice_sel: int = 0 # Inicia en 8 Ohm (no resuelto)

var botones_opcion: Array[Button] = []
var lbl_lectura: Label
var barra_vab: ProgressBar
var lbl_feedback: Label
var btn_comprobar: Button


func _init() -> void:
	titulo_panel = "ELECTRODINÁMICA 01 — FUENTE REAL Y KIRCHHOFF"
	texto_prompt = "[E] Resolver Puzzle"
	ancho_panel = 680.0


func _inicializar_puzzle() -> void:
	if compuerta_body != null:
		pos_cerrada = compuerta_body.position
		pos_abierta = pos_cerrada + Vector2(0.0, -altura_apertura)
	_aplicar_estado_compuerta()


func _construir_contenido_panel(vbox: VBoxContainer) -> void:
	# Recuadro destacado de fórmulas físicas
	var caja_formula := PanelContainer.new()
	caja_formula.add_theme_stylebox_override("panel", crear_caja(Color(0.11, 0.09, 0.05, 0.98), COLOR_AMARILLO, 2, 10))
	vbox.add_child(caja_formula)

	var lbl_formula := Label.new()
	lbl_formula.text = "FÓRMULAS DE INGENIERÍA:   V_ab = fem - I * r_i   |   I = V_ab / R_L"
	lbl_formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_formula.add_theme_font_size_override("font_size", 16)
	lbl_formula.add_theme_color_override("font_color", COLOR_AMARILLO)
	lbl_formula.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_formula.add_theme_constant_override("outline_size", 3)
	caja_formula.add_child(lbl_formula)

	# Enunciado con datos de ingeniería
	var caja_enunciado := PanelContainer.new()
	caja_enunciado.add_theme_stylebox_override("panel", crear_caja(Color(0.06, 0.10, 0.13, 0.96), COLOR_CIAN, 2, 12))
	vbox.add_child(caja_enunciado)

	var lbl_enunciado := Label.new()
	lbl_enunciado.text = (
		"FÍSICA II/III — ACTUADOR CON FUENTE REAL:\n"
		+ "Una batería industrial de fem = 48 V con resistencia interna r_i = 2 Ohm alimenta el actuador "
		+ "de una compuerta. Para operar en su punto nominal requiere un voltaje en terminales exacto "
		+ "V_ab = 40 V.\n"
		+ "Selecciona la resistencia de carga R_L del actuador."
	)
	lbl_enunciado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_enunciado.add_theme_font_size_override("font_size", 14)
	lbl_enunciado.add_theme_color_override("font_color", Color(0.95, 0.97, 0.99))
	caja_enunciado.add_child(lbl_enunciado)

	var lbl_sel := Label.new()
	lbl_sel.text = "SELECCIONA LA RESISTENCIA DE CARGA R_L DEL ACTUADOR:"
	lbl_sel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sel.add_theme_font_size_override("font_size", 13)
	lbl_sel.add_theme_color_override("font_color", COLOR_CIAN)
	vbox.add_child(lbl_sel)

	var fila_opc := HBoxContainer.new()
	fila_opc.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_opc.add_theme_constant_override("separation", 12)
	vbox.add_child(fila_opc)

	botones_opcion.clear()
	for i in range(OPCIONES_RL.size()):
		var btn := Button.new()
		btn.text = "%d Ohm" % OPCIONES_RL[i]
		btn.custom_minimum_size = Vector2(132, 40)
		btn.focus_mode = Control.FOCUS_NONE
		var idx_local := i
		btn.pressed.connect(func() -> void: _seleccionar_opcion(idx_local))
		fila_opc.add_child(btn)
		botones_opcion.append(btn)

	# Telemetría de terminales
	var caja_sim := PanelContainer.new()
	caja_sim.add_theme_stylebox_override("panel", crear_caja(Color(0.04, 0.08, 0.11, 0.96), Color(0.28, 0.65, 0.52), 2, 10))
	vbox.add_child(caja_sim)

	var v_sim := VBoxContainer.new()
	v_sim.add_theme_constant_override("separation", 6)
	caja_sim.add_child(v_sim)

	lbl_lectura = Label.new()
	lbl_lectura.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_lectura.add_theme_font_size_override("font_size", 14)
	lbl_lectura.add_theme_color_override("font_color", COLOR_CIAN)
	v_sim.add_child(lbl_lectura)

	barra_vab = ProgressBar.new()
	barra_vab.custom_minimum_size = Vector2(0, 18)
	barra_vab.show_percentage = false
	v_sim.add_child(barra_vab)

	lbl_feedback = Label.new()
	lbl_feedback.text = "Halla primero la corriente I desde la caída interna (fem - V_ab = I * r_i) y luego R_L."
	lbl_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_feedback.add_theme_font_size_override("font_size", 13)
	lbl_feedback.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0))
	vbox.add_child(lbl_feedback)

	btn_comprobar = Button.new()
	btn_comprobar.text = "COMPROBAR RESPUESTA (ENTER)"
	btn_comprobar.custom_minimum_size = Vector2(0, 42)
	btn_comprobar.focus_mode = Control.FOCUS_NONE
	btn_comprobar.pressed.connect(_comprobar_respuesta)
	vbox.add_child(btn_comprobar)

	_actualizar_ui()


func _al_abrir_panel() -> void:
	_actualizar_ui()


func _procesar_tecla_panel(kc: int) -> bool:
	if resuelto:
		if kc == KEY_ENTER or kc == KEY_KP_ENTER or kc == KEY_SPACE:
			cerrar_panel()
			return true
		return false
	if kc == KEY_LEFT or kc == KEY_A:
		_seleccionar_opcion(maxi(0, indice_sel - 1))
		return true
	if kc == KEY_RIGHT or kc == KEY_D:
		_seleccionar_opcion(mini(OPCIONES_RL.size() - 1, indice_sel + 1))
		return true
	if kc == KEY_ENTER or kc == KEY_KP_ENTER:
		_comprobar_respuesta()
		return true
	return false


func _seleccionar_opcion(idx: int) -> void:
	if resuelto:
		return
	indice_sel = clampi(idx, 0, OPCIONES_RL.size() - 1)
	_actualizar_ui()


func _actualizar_ui() -> void:
	var rl_sel: int = OPCIONES_RL[indice_sel]
	var i_real: float = FEM_V / (R_INTERNA_OHM + float(rl_sel))
	var vab_real: float = FEM_V - i_real * R_INTERNA_OHM

	for i in range(botones_opcion.size()):
		var activo := (i == indice_sel)
		var col := COLOR_VERDE if (resuelto and activo) else (COLOR_AMARILLO if activo else COLOR_CIAN)
		estilizar_boton(botones_opcion[i], col, resuelto and not activo)
		botones_opcion[i].disabled = resuelto

	lbl_lectura.text = (
		"R_L = %d Ohm  |  I = 48/(2+%d) = %.2f A  =>  V_ab = %.2f V   (Nominal: 40.00 V)"
		% [rl_sel, rl_sel, i_real, vab_real]
	)
	var col_barra := COLOR_VERDE if rl_sel == respuesta_correcta_ohm else (COLOR_ROJO if vab_real < VAB_OBJETIVO_V else COLOR_AMARILLO)
	actualizar_barra(barra_vab, vab_real, FEM_V, col_barra)

	if resuelto:
		btn_comprobar.text = "COMPUERTA METÁLICA ABIERTA — CERRAR"
		estilizar_boton(btn_comprobar, COLOR_VERDE)
	else:
		btn_comprobar.text = "COMPROBAR R_L = %d Ohm (ENTER)" % rl_sel
		estilizar_boton(btn_comprobar, COLOR_CIAN)


func _comprobar_respuesta() -> void:
	if resuelto:
		cerrar_panel()
		return

	var rl_sel: int = OPCIONES_RL[indice_sel]
	var i_real: float = FEM_V / (R_INTERNA_OHM + float(rl_sel))
	var vab_real: float = FEM_V - i_real * R_INTERNA_OHM

	if rl_sel == respuesta_correcta_ohm:
		resuelto = true
		lbl_feedback.text = (
			"¡CORRECTO! Paso 1: De V_ab = fem - I * r_i => 40 = 48 - I * 2 => I = 8 / 2 = 4 A.\n"
			+ "Paso 2: Aplicamos Ley de Ohm a la carga: R_L = V_ab / I = 40 / 4 = 10 Ohm.\n"
			+ "Actuador en punto nominal (40 V, 4 A). Abriendo compuerta metálica."
		)
		lbl_feedback.add_theme_color_override("font_color", COLOR_VERDE)
		_aplicar_estado_compuerta()
		_actualizar_ui()
		return

	if vab_real < VAB_OBJETIVO_V:
		lbl_feedback.text = (
			"INCORRECTO (R_L = %d Ohm): La corriente sube a I = %.2f A y el voltaje cae a V_ab = %.2f V (< 40 V).\n"
			+ "Paso a paso: Despeja I = (48 - 40) / 2 = 4 A y luego calcula R_L = 40 / 4."
		) % [rl_sel, i_real, vab_real]
	else:
		lbl_feedback.text = (
			"INCORRECTO (R_L = %d Ohm): Con R_L = %d Ohm circula I = %.2f A y V_ab = %.2f V (> 40 V).\n"
			+ "Paso a paso: No dividas la fem (48 V) entre 4 A; usa el voltaje en terminales R_L = V_ab / I = 40 / 4."
		) % [rl_sel, rl_sel, i_real, vab_real]
	lbl_feedback.add_theme_color_override("font_color", COLOR_ROJO)


func _aplicar_estado_compuerta() -> void:
	if compuerta_col != null:
		compuerta_col.set_deferred("disabled", resuelto)
	if lbl_estado_compuerta != null:
		lbl_estado_compuerta.text = "ABIERTA" if resuelto else "SELLADA"
		lbl_estado_compuerta.add_theme_color_override("font_color", COLOR_VERDE if resuelto else COLOR_ROJO)
	if compuerta_sprite != null:
		compuerta_sprite.modulate = Color(0.62, 1.0, 0.78, 0.92) if resuelto else Color(1.0, 1.0, 1.0, 1.0)


func _procesar_mundo(delta: float) -> void:
	if compuerta_body == null or get_tree().paused:
		return
	var destino := pos_abierta if resuelto else pos_cerrada
	compuerta_body.position = compuerta_body.position.move_toward(destino, velocidad_apertura * delta)
