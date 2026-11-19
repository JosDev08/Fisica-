extends "res://Codigo/Puzzles/puzzle_base.gd"

# ==============================================================================
# PUZZLE ELECTRODINÁMICA 01: LEY DE OHM EN SERIE (Nivel Preuniversitario UNI)
# Enunciado: V = 60 V, R_motor = 4 Ohm, I = 5 A exigida por el fusible.
# Fórmula: V = I * (R_motor + Rx) => 60 = 5 * (4 + Rx) => Rx = 8 Ohm.
# Al resolver: abre suavemente la compuerta metálica hija.
# ==============================================================================

const VOLTAJE_V := 60.0
const R_MOTOR_OHM := 4.0
const CORRIENTE_OBJETIVO_A := 5.0
const OPCIONES_RX: Array[int] = [2, 4, 6, 8, 10, 12]

@export var respuesta_correcta_ohm: int = 8
@export var altura_apertura: float = 116.0
@export var velocidad_apertura: float = 180.0

@onready var compuerta_body: StaticBody2D = $CompuertaMetalica
@onready var compuerta_col: CollisionShape2D = $CompuertaMetalica/CollisionShape2D
@onready var compuerta_sprite: Sprite2D = $CompuertaMetalica/Sprite2D
@onready var lbl_estado_compuerta: Label = $CompuertaMetalica/EstadoCompuerta

var resuelto: bool = false
var pos_cerrada: Vector2 = Vector2.ZERO
var pos_abierta: Vector2 = Vector2.ZERO
var indice_sel: int = 1 # Inicia en Rx = 4 Ohm (no resuelto)

var botones_opcion: Array[Button] = []
var lbl_lectura: Label
var barra_corriente: ProgressBar
var lbl_feedback: Label
var btn_comprobar: Button


func _init() -> void:
	titulo_panel = "ELECTRODINÁMICA 01 — LEY DE OHM EN SERIE"
	texto_prompt = "[E] Resolver Puzzle"
	ancho_panel = 660.0


func _inicializar_puzzle() -> void:
	if compuerta_body != null:
		pos_cerrada = compuerta_body.position
		pos_abierta = pos_cerrada + Vector2(0.0, -altura_apertura)
	_aplicar_estado_compuerta()


func _construir_contenido_panel(vbox: VBoxContainer) -> void:
	var caja_enunciado := PanelContainer.new()
	caja_enunciado.add_theme_stylebox_override("panel", crear_caja(Color(0.07, 0.11, 0.14, 0.96), COLOR_AMARILLO, 2, 12))
	vbox.add_child(caja_enunciado)

	var lbl_enunciado := Label.new()
	lbl_enunciado.text = (
		"ENUNCIADO (Nivel Preuniversitario):\n"
		+ "Una fuente de V = 60 V alimenta un motor de R_motor = 4 Ohm, pero el circuito exige exactamente "
		+ "I = 5 A para no quemar el fusible.\n"
		+ "Elige la resistencia protectora Rx que debe conectarse en serie (V = I * (R_motor + Rx))."
	)
	lbl_enunciado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_enunciado.add_theme_font_size_override("font_size", 14)
	lbl_enunciado.add_theme_color_override("font_color", Color(0.95, 0.97, 0.99))
	caja_enunciado.add_child(lbl_enunciado)

	var lbl_sel_titulo := Label.new()
	lbl_sel_titulo.text = "ELIGE LA RESISTENCIA PROTECTORA Rx EN SERIE:"
	lbl_sel_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sel_titulo.add_theme_font_size_override("font_size", 13)
	lbl_sel_titulo.add_theme_color_override("font_color", COLOR_AMARILLO)
	vbox.add_child(lbl_sel_titulo)

	var fila_opc := HBoxContainer.new()
	fila_opc.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_opc.add_theme_constant_override("separation", 8)
	vbox.add_child(fila_opc)

	botones_opcion.clear()
	for i in range(OPCIONES_RX.size()):
		var btn := Button.new()
		btn.text = "%d Ohm" % OPCIONES_RX[i]
		btn.custom_minimum_size = Vector2(92, 38)
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
	lbl_feedback.text = "Calcula R_total = V / I y resta R_motor para hallar Rx."
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
		_seleccionar_opcion(mini(OPCIONES_RX.size() - 1, indice_sel + 1))
		return true
	if kc == KEY_ENTER or kc == KEY_KP_ENTER:
		_comprobar_respuesta()
		return true
	return false


func _seleccionar_opcion(idx: int) -> void:
	if resuelto:
		return
	indice_sel = clampi(idx, 0, OPCIONES_RX.size() - 1)
	_actualizar_ui()


func _actualizar_ui() -> void:
	var rx_sel: int = OPCIONES_RX[indice_sel]
	var r_eq: float = R_MOTOR_OHM + float(rx_sel)
	var i_calc: float = VOLTAJE_V / r_eq

	for i in range(botones_opcion.size()):
		var activo := (i == indice_sel)
		var col := COLOR_VERDE if (resuelto and activo) else (COLOR_AMARILLO if activo else COLOR_CIAN)
		estilizar_boton(botones_opcion[i], col, resuelto and not activo)
		botones_opcion[i].disabled = resuelto

	var aviso_fusible := "  [¡FUSIBLE EN RIESGO!]" if i_calc > CORRIENTE_OBJETIVO_A + 0.01 else ""
	lbl_lectura.text = (
		"R_eq = 4 + %d = %.0f Ohm  =>  I = 60 / %.0f = %.2f A  (Meta: 5.00 A)%s"
		% [rx_sel, r_eq, r_eq, i_calc, aviso_fusible]
	)
	var col_barra := COLOR_VERDE if rx_sel == respuesta_correcta_ohm else (COLOR_ROJO if i_calc > CORRIENTE_OBJETIVO_A else COLOR_AMARILLO)
	actualizar_barra(barra_corriente, i_calc, 10.0, col_barra)

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

	var rx_sel: int = OPCIONES_RX[indice_sel]
	var r_eq: float = R_MOTOR_OHM + float(rx_sel)
	var i_calc: float = VOLTAJE_V / r_eq

	if rx_sel == respuesta_correcta_ohm:
		resuelto = true
		lbl_feedback.text = (
			"¡CORRECTO! En serie las resistencias se suman: R_total = V/I = 60/5 = 12 Ohm.\n"
			+ "Entonces Rx = 12 - 4 = 8 Ohm. Corriente segura de 5 A alcanzada: abriendo compuerta metálica."
		)
		lbl_feedback.add_theme_color_override("font_color", COLOR_VERDE)
		_aplicar_estado_compuerta()
		_actualizar_ui()
		return

	if i_calc > CORRIENTE_OBJETIVO_A:
		lbl_feedback.text = (
			"INCORRECTO (Rx = %d Ohm): I = 60 / %.0f = %.2f A > 5 A. ¡La corriente excede el fusible!\n"
			+ "Pista: Necesitas mayor resistencia en serie. Despeja R_total = 60 / 5 = 12 Ohm y luego Rx = R_total - 4."
		) % [rx_sel, r_eq, i_calc]
	else:
		lbl_feedback.text = (
			"INCORRECTO (Rx = %d Ohm): I = 60 / %.0f = %.2f A < 5 A. El motor no recibe suficiente corriente.\n"
			+ "Pista: Reduce Rx para que R_motor + Rx = V / I = 12 Ohm."
		) % [rx_sel, r_eq, i_calc]
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
