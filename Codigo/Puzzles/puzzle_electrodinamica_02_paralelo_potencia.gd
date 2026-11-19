extends "res://Codigo/Puzzles/puzzle_base.gd"

# ==============================================================================
# PUZZLE ELECTRODINÁMICA 02: PARALELO Y POTENCIA (Nivel Preuniversitario UNI)
# Enunciado: V = 24 V, P = 144 W (I_total = 6 A), rama fija R1 = 6 Ohm.
# En paralelo: I1 = V/R1 = 24/6 = 4 A => I2 = 6 - 4 = 2 A => R2 = 24/2 = 12 Ohm.
# Al resolver: hace subir la plataforma elevadora hija en Capa 5 (Suelo).
# ==============================================================================

const VOLTAJE_V := 24.0
const R1_OHM := 6.0
const POTENCIA_OBJETIVO_W := 144.0
const I_OBJETIVO_A := 6.0
const OPCIONES_R2: Array[int] = [3, 6, 8, 12, 18, 24]

@export var respuesta_correcta_ohm: int = 12
@export var altura_elevacion: float = 160.0
@export var velocidad_elevador: float = 95.0
@export var pausa_extremos: float = 1.6
@export var ciclo_continuo: bool = true

@onready var elevador_body: AnimatableBody2D = $PlataformaElevadora
@onready var elevador_sprite: Sprite2D = $PlataformaElevadora/Sprite2D
@onready var lbl_estado_elevador: Label = $PlataformaElevadora/EstadoElevador

var resuelto: bool = false
var pos_base: Vector2 = Vector2.ZERO
var pos_cima: Vector2 = Vector2.ZERO
var subiendo: bool = true
var pausa_actual: float = 0.0
var indice_sel: int = 1 # Inicia en R2 = 6 Ohm (no resuelto)

var botones_opcion: Array[Button] = []
var lbl_lectura: Label
var barra_potencia: ProgressBar
var lbl_feedback: Label
var btn_comprobar: Button


func _init() -> void:
	titulo_panel = "ELECTRODINÁMICA 02 — PARALELO Y POTENCIA"
	texto_prompt = "[E] Resolver Puzzle"
	ancho_panel = 660.0


func _inicializar_puzzle() -> void:
	if elevador_body != null:
		pos_base = elevador_body.position
		pos_cima = pos_base + Vector2(0.0, -altura_elevacion)
	_aplicar_estado_elevador()


func _construir_contenido_panel(vbox: VBoxContainer) -> void:
	var caja_enunciado := PanelContainer.new()
	caja_enunciado.add_theme_stylebox_override("panel", crear_caja(Color(0.05, 0.11, 0.13, 0.96), COLOR_AMARILLO, 2, 12))
	vbox.add_child(caja_enunciado)

	var lbl_enunciado := Label.new()
	lbl_enunciado.text = (
		"ENUNCIADO (Nivel Preuniversitario):\n"
		+ "Un generador de V = 24 V debe entregar una potencia total P = 144 W (I_total = 6 A) "
		+ "a una plataforma elevadora.\n"
		+ "Si ya existe una rama fija R1 = 6 Ohm, selecciona la resistencia R2 que debes conectar en paralelo."
	)
	lbl_enunciado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_enunciado.add_theme_font_size_override("font_size", 14)
	lbl_enunciado.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	caja_enunciado.add_child(lbl_enunciado)

	var lbl_sel_titulo := Label.new()
	lbl_sel_titulo.text = "SELECCIONA LA RESISTENCIA R2 EN PARALELO CON R1 = 6 Ohm:"
	lbl_sel_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sel_titulo.add_theme_font_size_override("font_size", 13)
	lbl_sel_titulo.add_theme_color_override("font_color", COLOR_AMARILLO)
	vbox.add_child(lbl_sel_titulo)

	var fila_opc := HBoxContainer.new()
	fila_opc.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_opc.add_theme_constant_override("separation", 8)
	vbox.add_child(fila_opc)

	botones_opcion.clear()
	for i in range(OPCIONES_R2.size()):
		var btn := Button.new()
		btn.text = "%d Ohm" % OPCIONES_R2[i]
		btn.custom_minimum_size = Vector2(92, 38)
		btn.focus_mode = Control.FOCUS_NONE
		var idx_local := i
		btn.pressed.connect(func() -> void: _seleccionar_opcion(idx_local))
		fila_opc.add_child(btn)
		botones_opcion.append(btn)

	var caja_sim := PanelContainer.new()
	caja_sim.add_theme_stylebox_override("panel", crear_caja(Color(0.04, 0.09, 0.11, 0.96), Color(0.25, 0.72, 0.78), 2, 10))
	vbox.add_child(caja_sim)

	var v_sim := VBoxContainer.new()
	v_sim.add_theme_constant_override("separation", 6)
	caja_sim.add_child(v_sim)

	lbl_lectura = Label.new()
	lbl_lectura.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_lectura.add_theme_font_size_override("font_size", 14)
	lbl_lectura.add_theme_color_override("font_color", COLOR_CIAN)
	v_sim.add_child(lbl_lectura)

	barra_potencia = ProgressBar.new()
	barra_potencia.custom_minimum_size = Vector2(0, 18)
	barra_potencia.show_percentage = false
	v_sim.add_child(barra_potencia)

	lbl_feedback = Label.new()
	lbl_feedback.text = "Usa P = V * I_total y recuerda que en paralelo I_total = V/R1 + V/R2."
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
		_seleccionar_opcion(mini(OPCIONES_R2.size() - 1, indice_sel + 1))
		return true
	if kc == KEY_ENTER or kc == KEY_KP_ENTER:
		_comprobar_respuesta()
		return true
	return false


func _seleccionar_opcion(idx: int) -> void:
	if resuelto:
		return
	indice_sel = clampi(idx, 0, OPCIONES_R2.size() - 1)
	_actualizar_ui()


func _actualizar_ui() -> void:
	var r2_sel: int = OPCIONES_R2[indice_sel]
	var i1: float = VOLTAJE_V / R1_OHM
	var i2: float = VOLTAJE_V / float(r2_sel)
	var i_tot: float = i1 + i2
	var r_eq: float = (R1_OHM * float(r2_sel)) / (R1_OHM + float(r2_sel))
	var p_tot: float = VOLTAJE_V * i_tot

	for i in range(botones_opcion.size()):
		var activo := (i == indice_sel)
		var col := COLOR_VERDE if (resuelto and activo) else (COLOR_AMARILLO if activo else COLOR_CIAN)
		estilizar_boton(botones_opcion[i], col, resuelto and not activo)
		botones_opcion[i].disabled = resuelto

	lbl_lectura.text = (
		"R2 = %d Ohm  |  R_eq = %.2f Ohm  |  I_total = %.2f A  =>  P = %.1f W  (Meta: 144 W)"
		% [r2_sel, r_eq, i_tot, p_tot]
	)
	var col_barra := COLOR_VERDE if r2_sel == respuesta_correcta_ohm else (COLOR_ROJO if p_tot > POTENCIA_OBJETIVO_W else COLOR_AMARILLO)
	actualizar_barra(barra_potencia, p_tot, 288.0, col_barra)

	if resuelto:
		btn_comprobar.text = "PLATAFORMA ELEVADORA ENERGIZADA — CERRAR"
		estilizar_boton(btn_comprobar, COLOR_VERDE)
	else:
		btn_comprobar.text = "COMPROBAR R2 = %d Ohm (ENTER)" % r2_sel
		estilizar_boton(btn_comprobar, COLOR_CIAN)


func _comprobar_respuesta() -> void:
	if resuelto:
		cerrar_panel()
		return

	var r2_sel: int = OPCIONES_R2[indice_sel]
	var i1: float = VOLTAJE_V / R1_OHM
	var i2: float = VOLTAJE_V / float(r2_sel)
	var i_tot: float = i1 + i2
	var p_tot: float = VOLTAJE_V * i_tot

	if r2_sel == respuesta_correcta_ohm:
		resuelto = true
		subiendo = true
		pausa_actual = 0.0
		lbl_feedback.text = (
			"¡CORRECTO! I1 = 24/6 = 4 A => falta I2 = 6 - 4 = 2 A => R2 = 24/2 = 12 Ohm (R_eq = 4 Ohm).\n"
			+ "Potencia exacta P = 24 * 6 = 144 W entregada. Elevando plataforma en Capa 5."
		)
		lbl_feedback.add_theme_color_override("font_color", COLOR_VERDE)
		_aplicar_estado_elevador()
		_actualizar_ui()
		return

	if p_tot > POTENCIA_OBJETIVO_W:
		lbl_feedback.text = (
			"INCORRECTO (R2 = %d Ohm): I2 = %.2f A => I_total = %.2f A y P = %.1f W (excede 144 W).\n"
			+ "Pista: Como I1 = 24/6 = 4 A, la segunda rama solo necesita I2 = 6 - 4 = 2 A. Aplica R2 = V / I2."
		) % [r2_sel, i2, i_tot, p_tot]
	else:
		lbl_feedback.text = (
			"INCORRECTO (R2 = %d Ohm): I2 = %.2f A => I_total = %.2f A y P = %.1f W (falta potencia para 144 W).\n"
			+ "Pista: Con 1/R_eq = 1/6 + 1/R2 y R_eq = V/I_total = 4 Ohm, despeja R2 = 12 Ohm."
		) % [r2_sel, i2, i_tot, p_tot]
	lbl_feedback.add_theme_color_override("font_color", COLOR_ROJO)


func _aplicar_estado_elevador() -> void:
	if lbl_estado_elevador != null:
		lbl_estado_elevador.text = "144 W ACTIVO" if resuelto else "SIN POTENCIA"
		lbl_estado_elevador.add_theme_color_override("font_color", COLOR_VERDE if resuelto else COLOR_AMARILLO)
	if elevador_sprite != null:
		elevador_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0) if resuelto else Color(0.68, 0.72, 0.78, 0.92)


func _physics_process(delta: float) -> void:
	if not resuelto or elevador_body == null or get_tree().paused:
		return
	if pausa_actual > 0.0:
		pausa_actual -= delta
		return

	var objetivo := pos_cima if subiendo else pos_base
	elevador_body.position = elevador_body.position.move_toward(objetivo, velocidad_elevador * delta)
	if elevador_body.position.distance_to(objetivo) <= 0.5:
		elevador_body.position = objetivo
		if ciclo_continuo:
			subiendo = not subiendo
			pausa_actual = pausa_extremos
