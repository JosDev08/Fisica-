extends "res://Codigo/Puzzles/puzzle_base.gd"

# ==============================================================================
# PUZZLE ELECTROSTÁTICA 02: INTENSIDAD DE CAMPO ELÉCTRICO (Nivel UNI)
# Enunciado: E = 4.5 x 10^4 N/C, d = 2 m, k = 9 x 10^9 N*m^2/C^2.
# Fórmula: E = k * |q| / d^2  =>  |q| = (4.5e4 * 4) / 9e9 = 20 uC.
# Al resolver: activa y solidifica un puente energético hijo en Capa 5 (Suelo).
# ==============================================================================

const K_COULOMB := 9.0e9
const DISTANCIA_M := 2.0
const E_OBJETIVO_NC := 4.5e4
const OPCIONES_Q_UC: Array[int] = [5, 10, 15, 20, 30, 40]

@export var respuesta_correcta_uc: int = 20

@onready var puente_body: StaticBody2D = $PuenteEnergetico
@onready var puente_col: CollisionShape2D = $PuenteEnergetico/CollisionShape2D
@onready var puente_sprite: Sprite2D = $PuenteEnergetico/Sprite2D
@onready var lbl_estado_puente: Label = $PuenteEnergetico/EstadoPuente

var resuelto: bool = false
var indice_sel: int = 1 # Inicia en 10 uC (no resuelto)
var tiempo_fx: float = 0.0

var botones_opcion: Array[Button] = []
var lbl_lectura: Label
var barra_campo: ProgressBar
var lbl_feedback: Label
var btn_comprobar: Button


func _init() -> void:
	titulo_panel = "ELECTROSTÁTICA 02 — CAMPO ELÉCTRICO"
	texto_prompt = "[E] Resolver Puzzle"
	ancho_panel = 660.0


func _inicializar_puzzle() -> void:
	_aplicar_estado_puente(true)


func _construir_contenido_panel(vbox: VBoxContainer) -> void:
	var caja_enunciado := PanelContainer.new()
	caja_enunciado.add_theme_stylebox_override("panel", crear_caja(Color(0.07, 0.07, 0.18, 0.96), COLOR_CIAN, 2, 12))
	vbox.add_child(caja_enunciado)

	var lbl_enunciado := Label.new()
	lbl_enunciado.text = (
		"ENUNCIADO (Nivel Preuniversitario):\n"
		+ "Un sensor requiere una intensidad de campo eléctrico E = 4.5 x 10^4 N/C a una distancia d = 2 m "
		+ "de una carga puntual (k = 9 x 10^9 N*m^2/C^2).\n"
		+ "Selecciona el valor de la carga fuente q en microcoulombs (E = k*|q|/d^2)."
	)
	lbl_enunciado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_enunciado.add_theme_font_size_override("font_size", 14)
	lbl_enunciado.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	caja_enunciado.add_child(lbl_enunciado)

	var lbl_sel_titulo := Label.new()
	lbl_sel_titulo.text = "SELECCIONA LA CARGA FUENTE q (1 uC = 10^-6 C):"
	lbl_sel_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sel_titulo.add_theme_font_size_override("font_size", 13)
	lbl_sel_titulo.add_theme_color_override("font_color", COLOR_AMARILLO)
	vbox.add_child(lbl_sel_titulo)

	var fila_opc := HBoxContainer.new()
	fila_opc.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_opc.add_theme_constant_override("separation", 8)
	vbox.add_child(fila_opc)

	botones_opcion.clear()
	for i in range(OPCIONES_Q_UC.size()):
		var btn := Button.new()
		btn.text = "%d uC" % OPCIONES_Q_UC[i]
		btn.custom_minimum_size = Vector2(92, 38)
		btn.focus_mode = Control.FOCUS_NONE
		var idx_local := i
		btn.pressed.connect(func() -> void: _seleccionar_opcion(idx_local))
		fila_opc.add_child(btn)
		botones_opcion.append(btn)

	var caja_sim := PanelContainer.new()
	caja_sim.add_theme_stylebox_override("panel", crear_caja(Color(0.05, 0.06, 0.14, 0.96), Color(0.45, 0.38, 0.85), 2, 10))
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
	lbl_feedback.text = "Despeja |q| = E * d^2 / k y presiona COMPROBAR para activar el puente energético."
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
		_seleccionar_opcion(mini(OPCIONES_Q_UC.size() - 1, indice_sel + 1))
		return true
	if kc == KEY_ENTER or kc == KEY_KP_ENTER:
		_comprobar_respuesta()
		return true
	return false


func _seleccionar_opcion(idx: int) -> void:
	if resuelto:
		return
	indice_sel = clampi(idx, 0, OPCIONES_Q_UC.size() - 1)
	_actualizar_ui()


func _calcular_campo_nc(q_uc: int) -> float:
	return K_COULOMB * (float(q_uc) * 1.0e-6) / (DISTANCIA_M * DISTANCIA_M)


func _actualizar_ui() -> void:
	var q_sel: int = OPCIONES_Q_UC[indice_sel]
	var e_calc: float = _calcular_campo_nc(q_sel)
	var e_en_10e4: float = e_calc / 1.0e4

	for i in range(botones_opcion.size()):
		var activo := (i == indice_sel)
		var col := COLOR_VERDE if (resuelto and activo) else (COLOR_AMARILLO if activo else COLOR_CIAN)
		estilizar_boton(botones_opcion[i], col, resuelto and not activo)
		botones_opcion[i].disabled = resuelto

	lbl_lectura.text = (
		"q = %d uC  =>  E = %.2f x 10^4 N/C   (Meta del sensor: 4.50 x 10^4 N/C)"
		% [q_sel, e_en_10e4]
	)
	var col_barra := COLOR_VERDE if q_sel == respuesta_correcta_uc else (COLOR_ROJO if e_calc > E_OBJETIVO_NC else COLOR_AMARILLO)
	actualizar_barra(barra_campo, e_en_10e4, 9.0, col_barra)

	if resuelto:
		btn_comprobar.text = "PUENTE ENERGÉTICO SOLIDIFICADO — CERRAR"
		estilizar_boton(btn_comprobar, COLOR_VERDE)
	else:
		btn_comprobar.text = "COMPROBAR q = %d uC (ENTER)" % q_sel
		estilizar_boton(btn_comprobar, COLOR_CIAN)


func _comprobar_respuesta() -> void:
	if resuelto:
		cerrar_panel()
		return

	var q_sel: int = OPCIONES_Q_UC[indice_sel]
	var e_calc: float = _calcular_campo_nc(q_sel)
	var e_en_10e4: float = e_calc / 1.0e4

	if q_sel == respuesta_correcta_uc:
		resuelto = true
		lbl_feedback.text = (
			"¡CORRECTO! |q| = (E * d^2) / k = (4.5x10^4 * 2^2) / (9x10^9) = 18x10^4 / 9x10^9 = 2x10^-5 C = 20 uC.\n"
			+ "Sensor calibrado en 4.5 x 10^4 N/C. Puente energético activado y sólido."
		)
		lbl_feedback.add_theme_color_override("font_color", COLOR_VERDE)
		_aplicar_estado_puente(false)
		_actualizar_ui()
		return

	if e_calc < E_OBJETIVO_NC:
		lbl_feedback.text = (
			"INCORRECTO (q = %d uC): genera E = %.2f x 10^4 N/C, insuficiente para el sensor (4.5 x 10^4 N/C).\n"
			+ "Pista: Recuerda elevar d = 2 m al cuadrado (d^2 = 4) y despejar |q| = (E * d^2) / k."
		) % [q_sel, e_en_10e4]
	else:
		lbl_feedback.text = (
			"INCORRECTO (q = %d uC): genera E = %.2f x 10^4 N/C, satura el sensor (meta: 4.5 x 10^4 N/C).\n"
			+ "Pista: Verifica las potencias de 10: (4.5x10^4 * 4) / (9x10^9) = 2 x 10^-5 C = 20 x 10^-6 C."
		) % [q_sel, e_en_10e4]
	lbl_feedback.add_theme_color_override("font_color", COLOR_ROJO)


func _aplicar_estado_puente(inmediato: bool) -> void:
	if puente_col != null:
		puente_col.set_deferred("disabled", not resuelto)
	if lbl_estado_puente != null:
		lbl_estado_puente.text = "PUENTE ACTIVO" if resuelto else "PUENTE APAGADO"
		lbl_estado_puente.add_theme_color_override("font_color", COLOR_VERDE if resuelto else COLOR_ROJO)
	if puente_sprite != null and inmediato:
		puente_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0) if resuelto else Color(0.55, 0.72, 1.0, 0.26)


func _procesar_mundo(delta: float) -> void:
	if puente_sprite == null:
		return
	tiempo_fx += delta
	if resuelto:
		var brillo := 0.92 + 0.08 * sin(tiempo_fx * 5.0)
		puente_sprite.modulate = puente_sprite.modulate.lerp(Color(brillo, 1.0, 1.0, 1.0), minf(1.0, delta * 7.0))
	else:
		var parpadeo := 0.22 + 0.08 * sin(tiempo_fx * 4.0)
		puente_sprite.modulate = Color(0.55, 0.72, 1.0, parpadeo)
