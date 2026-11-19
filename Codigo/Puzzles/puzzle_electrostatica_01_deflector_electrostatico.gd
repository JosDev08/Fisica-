extends "res://Codigo/Puzzles/puzzle_base.gd"

# ==============================================================================
# PUZZLE ELECTROSTÁTICA 01: DEFLECTOR ELECTROSTÁTICO (Física II/III Ingeniería)
# Fórmula destacada: E = dV / d
# Datos: d = 0.05 m, E = 2.4 x 10^4 V/m => dV = E * d = 1200 V.
# Opciones: 120 V, 480 V, 1200 V, 2400 V.
# Al resolver: desactiva la barrera de plasma hija en Capa 5 (Suelo).
# ==============================================================================

const DISTANCIA_M := 0.05
const E_OBJETIVO_VM := 2.4e4
const OPCIONES_DV: Array[int] = [120, 480, 1200, 2400]

@export var respuesta_correcta_v: int = 1200

@onready var barrera_body: StaticBody2D = $BarreraPlasma
@onready var barrera_col: CollisionShape2D = $BarreraPlasma/CollisionShape2D
@onready var barrera_sprite: Sprite2D = $BarreraPlasma/Sprite2D
@onready var lbl_estado_barrera: Label = $BarreraPlasma/EstadoBarrera

var resuelto: bool = false
var indice_sel: int = 1 # Inicia en 480 V (no resuelto)
var tiempo_fx: float = 0.0

var botones_opcion: Array[Button] = []
var lbl_lectura: Label
var barra_campo: ProgressBar
var lbl_feedback: Label
var btn_comprobar: Button


func _init() -> void:
	titulo_panel = "ELECTROSTÁTICA 01 — DEFLECTOR ELECTROSTÁTICO"
	texto_prompt = "[E] Resolver Puzzle"
	ancho_panel = 680.0


func _inicializar_puzzle() -> void:
	_aplicar_estado_barrera(true)


func _construir_contenido_panel(vbox: VBoxContainer) -> void:
	# Recuadro destacado de fórmula física
	var caja_formula := PanelContainer.new()
	caja_formula.add_theme_stylebox_override("panel", crear_caja(Color(0.08, 0.14, 0.24, 0.98), COLOR_AMARILLO, 2, 10))
	vbox.add_child(caja_formula)

	var lbl_formula := Label.new()
	lbl_formula.text = "FÓRMULA DE INGENIERÍA:   E = dV / d"
	lbl_formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_formula.add_theme_font_size_override("font_size", 17)
	lbl_formula.add_theme_color_override("font_color", COLOR_AMARILLO)
	lbl_formula.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_formula.add_theme_constant_override("outline_size", 3)
	caja_formula.add_child(lbl_formula)

	# Enunciado con datos de ingeniería
	var caja_enunciado := PanelContainer.new()
	caja_enunciado.add_theme_stylebox_override("panel", crear_caja(Color(0.05, 0.09, 0.17, 0.96), COLOR_CIAN, 2, 12))
	vbox.add_child(caja_enunciado)

	var lbl_enunciado := Label.new()
	lbl_enunciado.text = (
		"FÍSICA II/III — DEFLECTOR DE IONES:\n"
		+ "Una placa deflectora electrostática separa haces de iones entre dos electrodos paralelos "
		+ "separados d = 0.05 m. Para desviar el haz y apagar la barrera se requiere un campo uniforme "
		+ "E = 2.4 x 10^4 V/m.\n"
		+ "Calcula la diferencia de potencial dV (en Voltios) que debe aplicarse."
	)
	lbl_enunciado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_enunciado.add_theme_font_size_override("font_size", 14)
	lbl_enunciado.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	caja_enunciado.add_child(lbl_enunciado)

	var lbl_sel := Label.new()
	lbl_sel.text = "SELECCIONA LA DIFERENCIA DE POTENCIAL dV:"
	lbl_sel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sel.add_theme_font_size_override("font_size", 13)
	lbl_sel.add_theme_color_override("font_color", COLOR_CIAN)
	vbox.add_child(lbl_sel)

	var fila_opc := HBoxContainer.new()
	fila_opc.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_opc.add_theme_constant_override("separation", 12)
	vbox.add_child(fila_opc)

	botones_opcion.clear()
	for i in range(OPCIONES_DV.size()):
		var btn := Button.new()
		btn.text = "%d V" % OPCIONES_DV[i]
		btn.custom_minimum_size = Vector2(132, 40)
		btn.focus_mode = Control.FOCUS_NONE
		var idx_local := i
		btn.pressed.connect(func() -> void: _seleccionar_opcion(idx_local))
		fila_opc.add_child(btn)
		botones_opcion.append(btn)

	# Telemetría del deflector
	var caja_sim := PanelContainer.new()
	caja_sim.add_theme_stylebox_override("panel", crear_caja(Color(0.04, 0.07, 0.13, 0.96), Color(0.24, 0.55, 0.78), 2, 10))
	vbox.add_child(caja_sim)

	var v_sim := VBoxContainer.new()
	v_sim.add_theme_constant_override("separation", 6)
	caja_sim.add_child(v_sim)

	lbl_lectura = Label.new()
	lbl_lectura.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_lectura.add_theme_font_size_override("font_size", 14)
	lbl_lectura.add_theme_color_override("font_color", COLOR_CIAN)
	v_sim.add_child(lbl_lectura)

	barra_campo = ProgressBar.new()
	barra_campo.custom_minimum_size = Vector2(0, 18)
	barra_campo.show_percentage = false
	v_sim.add_child(barra_campo)

	lbl_feedback = Label.new()
	lbl_feedback.text = "Despeja dV = E * d y presiona COMPROBAR para verificar tu cálculo."
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
		_seleccionar_opcion(mini(OPCIONES_DV.size() - 1, indice_sel + 1))
		return true
	if kc == KEY_ENTER or kc == KEY_KP_ENTER:
		_comprobar_respuesta()
		return true
	return false


func _seleccionar_opcion(idx: int) -> void:
	if resuelto:
		return
	indice_sel = clampi(idx, 0, OPCIONES_DV.size() - 1)
	_actualizar_ui()


func _actualizar_ui() -> void:
	var dv_sel: int = OPCIONES_DV[indice_sel]
	var e_calc: float = float(dv_sel) / DISTANCIA_M
	var e_10e4: float = e_calc / 1.0e4

	for i in range(botones_opcion.size()):
		var activo := (i == indice_sel)
		var col := COLOR_VERDE if (resuelto and activo) else (COLOR_AMARILLO if activo else COLOR_CIAN)
		estilizar_boton(botones_opcion[i], col, resuelto and not activo)
		botones_opcion[i].disabled = resuelto

	lbl_lectura.text = (
		"dV = %d V  |  d = 0.05 m  =>  E = dV / d = %.2f x 10^4 V/m   (Meta: 2.40 x 10^4 V/m)"
		% [dv_sel, e_10e4]
	)
	var col_barra := COLOR_VERDE if dv_sel == respuesta_correcta_v else (COLOR_ROJO if e_calc > E_OBJETIVO_VM else COLOR_AMARILLO)
	actualizar_barra(barra_campo, e_10e4, 4.8, col_barra)

	if resuelto:
		btn_comprobar.text = "BARRERA DE PLASMA DESACTIVADA — CERRAR"
		estilizar_boton(btn_comprobar, COLOR_VERDE)
	else:
		btn_comprobar.text = "COMPROBAR dV = %d V (ENTER)" % dv_sel
		estilizar_boton(btn_comprobar, COLOR_CIAN)


func _comprobar_respuesta() -> void:
	if resuelto:
		cerrar_panel()
		return

	var dv_sel: int = OPCIONES_DV[indice_sel]
	var e_calc: float = float(dv_sel) / DISTANCIA_M
	var e_10e4: float = e_calc / 1.0e4

	if dv_sel == respuesta_correcta_v:
		resuelto = true
		lbl_feedback.text = (
			"¡CORRECTO! Paso 1: De E = dV / d despejamos dV = E * d.\n"
			+ "Paso 2: dV = (2.4 x 10^4 V/m) * (0.05 m) = 24000 * 0.05 = 1200 V.\n"
			+ "El haz de iones se desvía al punto nominal. Barrera de plasma desactivada."
		)
		lbl_feedback.add_theme_color_override("font_color", COLOR_VERDE)
		_aplicar_estado_barrera(false)
		_actualizar_ui()
		return

	if dv_sel == 480:
		lbl_feedback.text = (
			"INCORRECTO (480 V): Con dV = 480 V obtienes E = 480 / 0.05 = 0.96 x 10^4 V/m (insuficiente).\n"
			+ "Paso a paso: No dividas 24000 / 50; multiplica E * d = 24000 * (5 / 100)."
		)
	elif dv_sel == 120:
		lbl_feedback.text = (
			"INCORRECTO (120 V): Con dV = 120 V obtienes E = 0.24 x 10^4 V/m (10 veces menor).\n"
			+ "Paso a paso: Revisa la coma decimal: 2.4 x 10^4 = 24000, y 24000 * 0.05 = 240 * 5."
		)
	else:
		lbl_feedback.text = (
			"INCORRECTO (%d V): Genera E = %.2f x 10^4 V/m (excede el campo objetivo de 2.4 x 10^4 V/m).\n"
			+ "Paso a paso: Aplica dV = E * d = (2.4 x 10^4) * (5 x 10^-2) = 12 x 10^2 V."
		) % [dv_sel, e_10e4]
	lbl_feedback.add_theme_color_override("font_color", COLOR_ROJO)


func _aplicar_estado_barrera(inmediato: bool) -> void:
	if barrera_col != null:
		barrera_col.set_deferred("disabled", resuelto)
	if lbl_estado_barrera != null:
		lbl_estado_barrera.text = "PLASMA OFF" if resuelto else "BARRERA ACTIVA"
		lbl_estado_barrera.add_theme_color_override("font_color", COLOR_VERDE if resuelto else COLOR_ROJO)
	if barrera_sprite != null and inmediato:
		barrera_sprite.modulate = Color(0.25, 1.0, 0.6, 0.14) if resuelto else Color(1.0, 1.0, 1.0, 1.0)


func _procesar_mundo(delta: float) -> void:
	if barrera_sprite == null:
		return
	tiempo_fx += delta
	if resuelto:
		barrera_sprite.modulate = barrera_sprite.modulate.lerp(Color(0.25, 1.0, 0.6, 0.12), minf(1.0, delta * 6.0))
	else:
		var pulso := 0.85 + 0.15 * sin(tiempo_fx * 8.0)
		barrera_sprite.modulate = Color(1.0, pulso, pulso, 0.92)
