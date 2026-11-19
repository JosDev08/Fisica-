extends "res://Codigo/Puzzles/puzzle_base.gd"

# ==============================================================================
# PUZZLE ELECTROSTÁTICA 02: LEY DE GAUSS EN SONDA (Física II/III Ingeniería)
# Fórmula destacada: E = (k * Q) / r^2   (Ley de Gauss, r > R)
# Datos: R = 0.2 m, Q = +8 uC, r = 0.6 m, k = 9 x 10^9 N*m^2/C^2.
# Solución: E = (9e9 * 8e-6) / 0.6^2 = 72000 / 0.36 = 200000 N/C = 200 kN/C.
# Opciones: 72 kN/C, 120 kN/C, 200 kN/C, 360 kN/C.
# Al resolver: activa y solidifica el puente energético hijo en Capa 5 (Suelo).
# ==============================================================================

const OPCIONES_E_KNC: Array[int] = [72, 120, 200, 360]

@export var respuesta_correcta_knc: int = 200

@onready var puente_body: StaticBody2D = $PuenteEnergetico
@onready var puente_col: CollisionShape2D = $PuenteEnergetico/CollisionShape2D
@onready var puente_sprite: Sprite2D = $PuenteEnergetico/Sprite2D
@onready var lbl_estado_puente: Label = $PuenteEnergetico/EstadoPuente

var resuelto: bool = false
var indice_sel: int = 1 # Inicia en 120 kN/C (no resuelto)
var tiempo_fx: float = 0.0

var botones_opcion: Array[Button] = []
var lbl_lectura: Label
var barra_gauss: ProgressBar
var lbl_feedback: Label
var btn_comprobar: Button


func _init() -> void:
	titulo_panel = "ELECTROSTÁTICA 02 — LEY DE GAUSS (SONDA)"
	texto_prompt = "[E] Resolver Puzzle"
	ancho_panel = 680.0


func _inicializar_puzzle() -> void:
	_aplicar_estado_puente(true)


func _construir_contenido_panel(vbox: VBoxContainer) -> void:
	# Recuadro destacado de fórmula física
	var caja_formula := PanelContainer.new()
	caja_formula.add_theme_stylebox_override("panel", crear_caja(Color(0.10, 0.08, 0.22, 0.98), COLOR_AMARILLO, 2, 10))
	vbox.add_child(caja_formula)

	var lbl_formula := Label.new()
	lbl_formula.text = "FÓRMULA DE INGENIERÍA:   E = (k * Q) / r^2   (Ley de Gauss, r > R)"
	lbl_formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_formula.add_theme_font_size_override("font_size", 16)
	lbl_formula.add_theme_color_override("font_color", COLOR_AMARILLO)
	lbl_formula.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_formula.add_theme_constant_override("outline_size", 3)
	caja_formula.add_child(lbl_formula)

	# Enunciado con datos de ingeniería
	var caja_enunciado := PanelContainer.new()
	caja_enunciado.add_theme_stylebox_override("panel", crear_caja(Color(0.06, 0.06, 0.16, 0.96), COLOR_CIAN, 2, 12))
	vbox.add_child(caja_enunciado)

	var lbl_enunciado := Label.new()
	lbl_enunciado.text = (
		"FÍSICA II/III — SENSOR ESFÉRICO DE ALTO VOLTAJE:\n"
		+ "Un sensor de alto voltaje modela un nodo esférico conductor de radio R = 0.2 m con carga neta "
		+ "Q = +8 uC (k = 9 x 10^9 N*m^2/C^2).\n"
		+ "Calcula la intensidad de campo eléctrico E en la sonda ubicada a r = 0.6 m del centro "
		+ "para energizar el puente."
	)
	lbl_enunciado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_enunciado.add_theme_font_size_override("font_size", 14)
	lbl_enunciado.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	caja_enunciado.add_child(lbl_enunciado)

	var lbl_sel := Label.new()
	lbl_sel.text = "SELECCIONA LA INTENSIDAD DE CAMPO ELÉCTRICO E EN LA SONDA (1 kN/C = 10^3 N/C):"
	lbl_sel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sel.add_theme_font_size_override("font_size", 13)
	lbl_sel.add_theme_color_override("font_color", COLOR_CIAN)
	vbox.add_child(lbl_sel)

	var fila_opc := HBoxContainer.new()
	fila_opc.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_opc.add_theme_constant_override("separation", 12)
	vbox.add_child(fila_opc)

	botones_opcion.clear()
	for i in range(OPCIONES_E_KNC.size()):
		var btn := Button.new()
		btn.text = "%d kN/C" % OPCIONES_E_KNC[i]
		btn.custom_minimum_size = Vector2(132, 40)
		btn.focus_mode = Control.FOCUS_NONE
		var idx_local := i
		btn.pressed.connect(func() -> void: _seleccionar_opcion(idx_local))
		fila_opc.add_child(btn)
		botones_opcion.append(btn)

	# Telemetría de la sonda
	var caja_sim := PanelContainer.new()
	caja_sim.add_theme_stylebox_override("panel", crear_caja(Color(0.05, 0.05, 0.13, 0.96), Color(0.48, 0.40, 0.88), 2, 10))
	vbox.add_child(caja_sim)

	var v_sim := VBoxContainer.new()
	v_sim.add_theme_constant_override("separation", 6)
	caja_sim.add_child(v_sim)

	lbl_lectura = Label.new()
	lbl_lectura.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_lectura.add_theme_font_size_override("font_size", 14)
	lbl_lectura.add_theme_color_override("font_color", COLOR_CIAN)
	v_sim.add_child(lbl_lectura)

	barra_gauss = ProgressBar.new()
	barra_gauss.custom_minimum_size = Vector2(0, 18)
	barra_gauss.show_percentage = false
	v_sim.add_child(barra_gauss)

	lbl_feedback = Label.new()
	lbl_feedback.text = "Para r = 0.6 m > R = 0.2 m, toda la carga Q actúa como puntual en el centro. Evalúa E."
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
		_seleccionar_opcion(mini(OPCIONES_E_KNC.size() - 1, indice_sel + 1))
		return true
	if kc == KEY_ENTER or kc == KEY_KP_ENTER:
		_comprobar_respuesta()
		return true
	return false


func _seleccionar_opcion(idx: int) -> void:
	if resuelto:
		return
	indice_sel = clampi(idx, 0, OPCIONES_E_KNC.size() - 1)
	_actualizar_ui()


func _actualizar_ui() -> void:
	var e_sel: int = OPCIONES_E_KNC[indice_sel]
	var q_impl_uc: float = (float(e_sel) * 1.0e3 * 0.36) / 9.0e9 * 1.0e6

	for i in range(botones_opcion.size()):
		var activo := (i == indice_sel)
		var col := COLOR_VERDE if (resuelto and activo) else (COLOR_AMARILLO if activo else COLOR_CIAN)
		estilizar_boton(botones_opcion[i], col, resuelto and not activo)
		botones_opcion[i].disabled = resuelto

	lbl_lectura.text = (
		"Calibración elegida: E = %d kN/C  (implica Q_enc = %.1f uC a r = 0.6 m; dato real: Q = +8.0 uC)"
		% [e_sel, q_impl_uc]
	)
	var col_barra := COLOR_VERDE if e_sel == respuesta_correcta_knc else (COLOR_ROJO if e_sel > respuesta_correcta_knc else COLOR_AMARILLO)
	actualizar_barra(barra_gauss, float(e_sel), 360.0, col_barra)

	if resuelto:
		btn_comprobar.text = "PUENTE ENERGÉTICO SOLIDIFICADO — CERRAR"
		estilizar_boton(btn_comprobar, COLOR_VERDE)
	else:
		btn_comprobar.text = "COMPROBAR E = %d kN/C (ENTER)" % e_sel
		estilizar_boton(btn_comprobar, COLOR_CIAN)


func _comprobar_respuesta() -> void:
	if resuelto:
		cerrar_panel()
		return

	var e_sel: int = OPCIONES_E_KNC[indice_sel]
	if e_sel == respuesta_correcta_knc:
		resuelto = true
		lbl_feedback.text = (
			"¡CORRECTO! Paso 1: Como r = 0.6 m > R = 0.2 m, por Ley de Gauss E = (k * Q) / r^2.\n"
			+ "Paso 2: k * Q = (9x10^9) * (8x10^-6) = 72000 N*m^2/C; r^2 = (0.6)^2 = 0.36 m^2.\n"
			+ "Paso 3: E = 72000 / 0.36 = 200000 N/C = 200 kN/C. Puente energético solidificado."
		)
		lbl_feedback.add_theme_color_override("font_color", COLOR_VERDE)
		_aplicar_estado_puente(false)
		_actualizar_ui()
		return

	if e_sel == 120:
		lbl_feedback.text = (
			"INCORRECTO (120 kN/C): Ese valor sale de dividir k*Q / r (72000 / 0.6) sin elevar r al cuadrado.\n"
			+ "Paso a paso: Eleva r = 0.6 m al cuadrado => r^2 = 0.36 m^2, y luego calcula 72000 / 0.36."
		)
	elif e_sel == 72:
		lbl_feedback.text = (
			"INCORRECTO (72 kN/C): 72000 es únicamente el numerador k * Q = (9x10^9) * (8x10^-6).\n"
			+ "Paso a paso: Falta dividir entre r^2 = (0.6)^2 = 0.36 m^2."
		)
	else:
		lbl_feedback.text = (
			"INCORRECTO (360 kN/C): No uses el radio de la esfera R = 0.2 m ni mezcles r con R.\n"
			+ "Paso a paso: La sonda está a r = 0.6 m del centro => E = (9x10^9 * 8x10^-6) / (0.6)^2."
		)
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
