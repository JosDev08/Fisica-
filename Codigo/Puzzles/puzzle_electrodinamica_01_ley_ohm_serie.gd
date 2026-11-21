extends "res://Codigo/Puzzles/puzzle_base.gd"

# ==============================================================================
# PUZZLE ELECTRODINÁMICA 01: LEY DE OHM EN SERIE (Nivel Preuniversitario UNI)
# Fórmula destacada: V = I * (R_motor + Rx)  =>  Rx = (V / I) - R_motor
# Genera V, R_motor e I aleatorios con Rx entero exacto, 3 distractores realistas
# (R_total sin restar R_motor, sumar en vez de restar, etc.) y opciones.shuffle().
# Al resolver: abre suavemente la compuerta metálica hija en Capa 5 (Suelo).
# ==============================================================================

const OPCIONES_I_OBJ: Array[int] = [2, 3, 4, 5, 6]
const OPCIONES_RMOTOR: Array[int] = [2, 3, 4, 5, 6]
const OPCIONES_RX_BASE: Array[int] = [4, 6, 8, 10, 12, 14]

@export var respuesta_correcta_ohm: int = 8
@export var altura_apertura: float = 116.0
@export var velocidad_apertura: float = 180.0

@onready var compuerta_body: StaticBody2D = $CompuertaMetalica
@onready var compuerta_col: CollisionShape2D = $CompuertaMetalica/CollisionShape2D
@onready var compuerta_sprite: Sprite2D = $CompuertaMetalica/Sprite2D
@onready var lbl_estado_compuerta: Label = $CompuertaMetalica/EstadoCompuerta

var voltaje_v: int = 60
var r_motor_ohm: int = 4
var corriente_objetivo_a: int = 5
var opciones_rx: Array[int] = []

var resuelto: bool = false
var pos_cerrada: Vector2 = Vector2.ZERO
var pos_abierta: Vector2 = Vector2.ZERO
var indice_sel: int = 0

var lbl_enunciado: Label
var botones_opcion: Array[Button] = []
var lbl_lectura: Label
var barra_corriente: ProgressBar
var lbl_feedback: Label
var btn_comprobar: Button


func _init() -> void:
	titulo_panel = "ELECTRODINÁMICA 01 — LEY DE OHM EN SERIE"
	texto_prompt = "[E] Resolver Puzzle"
	ancho_panel = 680.0


func generar_problema() -> void:
	var combos: Array = []
	for i_val in OPCIONES_I_OBJ:
		for rm in OPCIONES_RMOTOR:
			for rx in OPCIONES_RX_BASE:
				var v_val: int = i_val * (rm + rx)
				if v_val >= 24 and v_val <= 120:
					combos.append([v_val, rm, i_val, rx])

	var elegida: Array = combos[randi() % combos.size()]
	voltaje_v = int(elegida[0])
	r_motor_ohm = int(elegida[1])
	corriente_objetivo_a = int(elegida[2])
	respuesta_correcta_ohm = int(elegida[3])

	# 3 distractores típicos: R_total (V/I sin restar R_motor), restar R_motor de más, mitad
	var d_rtotal: int = respuesta_correcta_ohm + r_motor_ohm
	var d_menos: int = maxi(2, respuesta_correcta_ohm - r_motor_ohm)
	var d_mitad: int = maxi(2, int(round(float(respuesta_correcta_ohm) * 0.5)))
	var d_doble: int = respuesta_correcta_ohm * 2

	opciones_rx = construir_opciones_int(
		respuesta_correcta_ohm,
		[d_rtotal, d_menos, d_mitad, d_doble],
		2,
		60,
		2
	)
	indice_sel = indice_inicial_no_correcto(opciones_rx, respuesta_correcta_ohm)


func _inicializar_puzzle() -> void:
	if compuerta_body != null:
		pos_cerrada = compuerta_body.position
		pos_abierta = pos_cerrada + Vector2(0.0, -altura_apertura)
	_aplicar_estado_compuerta()


func _construir_contenido_panel(vbox: VBoxContainer) -> void:
	var caja_formula := PanelContainer.new()
	caja_formula.add_theme_stylebox_override("panel", crear_caja(Color(0.11, 0.09, 0.05, 0.98), COLOR_AMARILLO, 2, 10))
	vbox.add_child(caja_formula)

	var lbl_formula := Label.new()
	lbl_formula.text = "FÓRMULA:   V = I * (R_motor + Rx)   =>   Rx = (V / I) - R_motor"
	lbl_formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_formula.add_theme_font_size_override("font_size", 16)
	lbl_formula.add_theme_color_override("font_color", COLOR_AMARILLO)
	lbl_formula.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_formula.add_theme_constant_override("outline_size", 3)
	caja_formula.add_child(lbl_formula)

	var caja_enunciado := PanelContainer.new()
	caja_enunciado.add_theme_stylebox_override("panel", crear_caja(Color(0.07, 0.11, 0.14, 0.96), COLOR_CIAN, 2, 12))
	vbox.add_child(caja_enunciado)

	lbl_enunciado = Label.new()
	lbl_enunciado.text = (
		"ENUNCIADO (Nivel Preuniversitario):\n"
		+ "Una fuente de V = %d V alimenta un motor de R_motor = %d Ohm, pero el circuito exige exactamente "
		+ "I = %d A para no quemar el fusible.\n"
		+ "Elige la resistencia protectora Rx que debe conectarse en serie (V = I * (R_motor + Rx))."
	) % [voltaje_v, r_motor_ohm, corriente_objetivo_a]
	lbl_enunciado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_enunciado.add_theme_font_size_override("font_size", 14)
	lbl_enunciado.add_theme_color_override("font_color", Color(0.95, 0.97, 0.99))
	caja_enunciado.add_child(lbl_enunciado)

	var lbl_sel_titulo := Label.new()
	lbl_sel_titulo.text = "ELIGE LA RESISTENCIA PROTECTORA Rx EN SERIE:"
	lbl_sel_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sel_titulo.add_theme_font_size_override("font_size", 13)
	lbl_sel_titulo.add_theme_color_override("font_color", COLOR_CIAN)
	vbox.add_child(lbl_sel_titulo)

	var fila_opc := HBoxContainer.new()
	fila_opc.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_opc.add_theme_constant_override("separation", 12)
	vbox.add_child(fila_opc)

	botones_opcion.clear()
	for i in range(opciones_rx.size()):
		var btn := Button.new()
		btn.text = "%d Ohm" % opciones_rx[i]
		btn.custom_minimum_size = Vector2(132, 40)
		btn.focus_mode = Control.FOCUS_NONE
		var idx_local := i
		btn.pressed.connect(func() -> void: _seleccionar_opcion(idx_local))
		fila_opc.add_child(btn)
		botones_opcion.append(btn)

	var caja_sim := PanelContainer.new()
	caja_sim.add_theme_stylebox_override("panel", crear_caja(Color(0.04, 0.09, 0.11, 0.96), Color(0.28, 0.65, 0.52), 2, 10))
	vbox.add_child(caja_sim)

	var v_sim := VBoxContainer.new()
	v_sim.add_theme_constant_override("separation", 6)
	caja_sim.add_child(v_sim)

	lbl_lectura = Label.new()
	lbl_lectura.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_lectura.add_theme_font_size_override("font_size", 14)
	lbl_lectura.add_theme_color_override("font_color", COLOR_CIAN)
	v_sim.add_child(lbl_lectura)

	barra_corriente = ProgressBar.new()
	barra_corriente.custom_minimum_size = Vector2(0, 18)
	barra_corriente.show_percentage = false
	v_sim.add_child(barra_corriente)

	lbl_feedback = Label.new()
	lbl_feedback.text = "Calcula R_total = %d / %d y resta R_motor = %d Ohm para hallar Rx." % [
		voltaje_v, corriente_objetivo_a, r_motor_ohm
	]
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
		_seleccionar_opcion(mini(opciones_rx.size() - 1, indice_sel + 1))
		return true
	if kc == KEY_ENTER or kc == KEY_KP_ENTER:
		_comprobar_respuesta()
		return true
	return false


func _seleccionar_opcion(idx: int) -> void:
	if resuelto:
		return
	indice_sel = clampi(idx, 0, opciones_rx.size() - 1)
	_actualizar_ui()


func _actualizar_ui() -> void:
	var rx_sel: int = opciones_rx[indice_sel]
	var r_eq: float = float(r_motor_ohm + rx_sel)
	var i_calc: float = float(voltaje_v) / r_eq

	for i in range(botones_opcion.size()):
		var activo := (i == indice_sel)
		var col := COLOR_VERDE if (resuelto and activo) else (COLOR_AMARILLO if activo else COLOR_CIAN)
		estilizar_boton(botones_opcion[i], col, resuelto and not activo)
		botones_opcion[i].disabled = resuelto

	lbl_lectura.text = (
		"Opción: Rx = %d Ohm  |  V = %d V, R_motor = %d Ohm  |  Meta: I = %d A"
		% [rx_sel, voltaje_v, r_motor_ohm, corriente_objetivo_a]
	)
	actualizar_barra(barra_corriente, i_calc, float(corriente_objetivo_a) * 2.0, COLOR_VERDE if resuelto else COLOR_CIAN)

	if resuelto:
		btn_comprobar.text = "COMPUERTA METÁLICA ABIERTA — CERRAR"
		estilizar_boton(btn_comprobar, COLOR_VERDE)
	else:
		btn_comprobar.text = "COMPROBAR Rx = %d Ohm (ENTER)" % rx_sel
		estilizar_boton(btn_comprobar, COLOR_CIAN)


func _comprobar_respuesta() -> void:
	if resuelto:
		cerrar_panel()
		return

	var rx_sel: int = opciones_rx[indice_sel]
	var r_eq: int = r_motor_ohm + rx_sel
	var r_tot_meta: int = r_motor_ohm + respuesta_correcta_ohm
	var i_calc: float = float(voltaje_v) / float(r_eq)

	if rx_sel == respuesta_correcta_ohm:
		resuelto = true
		lbl_feedback.text = (
			"¡CORRECTO! En serie R_total = V / I = %d / %d = %d Ohm.\n"
			+ "Entonces Rx = %d - %d = %d Ohm. Corriente segura de %d A alcanzada: abriendo compuerta."
		) % [voltaje_v, corriente_objetivo_a, r_tot_meta, r_tot_meta, r_motor_ohm, respuesta_correcta_ohm, corriente_objetivo_a]
		lbl_feedback.add_theme_color_override("font_color", COLOR_VERDE)
		_aplicar_estado_compuerta()
		_actualizar_ui()
		return

	if i_calc > float(corriente_objetivo_a):
		lbl_feedback.text = (
			"INCORRECTO (Rx = %d Ohm): R_eq = %d + %d = %d Ohm => I = %d / %d = %.2f A > %d A (fusible en riesgo).\n"
			+ "Pista: Despeja R_total = %d / %d = %d Ohm y resta R_motor = %d Ohm."
		) % [rx_sel, r_motor_ohm, rx_sel, r_eq, voltaje_v, r_eq, i_calc, corriente_objetivo_a, voltaje_v, corriente_objetivo_a, r_tot_meta, r_motor_ohm]
	else:
		lbl_feedback.text = (
			"INCORRECTO (Rx = %d Ohm): R_eq = %d Ohm => I = %.2f A < %d A (corriente insuficiente).\n"
			+ "Pista: Reduce Rx para que R_motor + Rx = %d / %d = %d Ohm."
		) % [rx_sel, r_eq, i_calc, corriente_objetivo_a, voltaje_v, corriente_objetivo_a, r_tot_meta]
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
