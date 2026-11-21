extends "res://Codigo/Puzzles/puzzle_base.gd"

# ==============================================================================
# PUZZLE ELECTROSTÁTICA 02: INTENSIDAD DE CAMPO ELÉCTRICO (Nivel UNI)
# Fórmula destacada: E = k * |q| / d^2  =>  |q| = E * d^2 / k
# Genera d y E aleatorios con carga q entera exacta en uC, 3 distractores
# realistas (olvidar d^2, multiplicar/dividir mal) y opciones.shuffle().
# Al resolver: activa y solidifica un puente energético hijo en Capa 5 (Suelo).
# ==============================================================================

const K_COULOMB := 9.0e9
# Pares [d_m, lista_q_uC] donde E_en_10e4 = (9 * q) / (10 * d^2) es siempre decimal exacto limpio
const CONFIGS_CAMPO: Array = [
	[1, [2, 4, 5, 6, 8]],
	[2, [10, 12, 16, 20, 24, 28]],
	[3, [10, 15, 20, 25, 30, 40]],
	[6, [20, 32, 40, 48]],
]

@export var respuesta_correcta_uc: int = 20

@onready var puente_body: StaticBody2D = $PuenteEnergetico
@onready var puente_col: CollisionShape2D = $PuenteEnergetico/CollisionShape2D
@onready var puente_sprite: Sprite2D = $PuenteEnergetico/Sprite2D
@onready var lbl_estado_puente: Label = $PuenteEnergetico/EstadoPuente

var distancia_m: int = 2
var e_objetivo_10e4: float = 4.5
var e_objetivo_nc: float = 4.5e4
var opciones_q_uc: Array[int] = []

var resuelto: bool = false
var indice_sel: int = 0
var tiempo_fx: float = 0.0

var lbl_enunciado: Label
var botones_opcion: Array[Button] = []
var lbl_lectura: Label
var barra_campo: ProgressBar
var lbl_feedback: Label
var btn_comprobar: Button


func _init() -> void:
	titulo_panel = "ELECTROSTÁTICA 02 — CAMPO ELÉCTRICO"
	texto_prompt = "[E] Resolver Puzzle"
	ancho_panel = 680.0


func generar_problema() -> void:
	var cfg: Array = CONFIGS_CAMPO[randi() % CONFIGS_CAMPO.size()]
	distancia_m = int(cfg[0])
	var lista_q: Array = cfg[1]
	respuesta_correcta_uc = int(lista_q[randi() % lista_q.size()])

	e_objetivo_nc = K_COULOMB * (float(respuesta_correcta_uc) * 1.0e-6) / float(distancia_m * distancia_m)
	e_objetivo_10e4 = e_objetivo_nc / 1.0e4

	# 3 distractores típicos: olvidar d^2 (q / d), mitad, doble, o sumar d
	var d_sin_cuad: int = maxi(1, int(round(float(respuesta_correcta_uc) / float(distancia_m))))
	var d_mitad: int = maxi(1, int(round(float(respuesta_correcta_uc) * 0.5)))
	var d_doble: int = respuesta_correcta_uc * 2
	var d_por_15: int = int(round(float(respuesta_correcta_uc) * 1.5))

	opciones_q_uc = construir_opciones_int(
		respuesta_correcta_uc,
		[d_sin_cuad, d_doble, d_mitad, d_por_15],
		1,
		200,
		2
	)
	indice_sel = indice_inicial_no_correcto(opciones_q_uc, respuesta_correcta_uc)


func _inicializar_puzzle() -> void:
	_aplicar_estado_puente(true)


func _construir_contenido_panel(vbox: VBoxContainer) -> void:
	var caja_formula := PanelContainer.new()
	caja_formula.add_theme_stylebox_override("panel", crear_caja(Color(0.10, 0.08, 0.22, 0.98), COLOR_AMARILLO, 2, 10))
	vbox.add_child(caja_formula)

	var lbl_formula := Label.new()
	lbl_formula.text = "FÓRMULA:   E = k * |q| / d^2   =>   |q| = (E * d^2) / k"
	lbl_formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_formula.add_theme_font_size_override("font_size", 16)
	lbl_formula.add_theme_color_override("font_color", COLOR_AMARILLO)
	lbl_formula.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_formula.add_theme_constant_override("outline_size", 3)
	caja_formula.add_child(lbl_formula)

	var caja_enunciado := PanelContainer.new()
	caja_enunciado.add_theme_stylebox_override("panel", crear_caja(Color(0.07, 0.07, 0.18, 0.96), COLOR_CIAN, 2, 12))
	vbox.add_child(caja_enunciado)

	lbl_enunciado = Label.new()
	lbl_enunciado.text = (
		"ENUNCIADO (Nivel Preuniversitario):\n"
		+ "Un sensor requiere una intensidad de campo eléctrico E = %.2f x 10^4 N/C a una distancia d = %d m "
		+ "de una carga puntual (k = 9 x 10^9 N*m^2/C^2).\n"
		+ "Selecciona el valor de la carga fuente q en microcoulombs (E = k*|q|/d^2)."
	) % [e_objetivo_10e4, distancia_m]
	lbl_enunciado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_enunciado.add_theme_font_size_override("font_size", 14)
	lbl_enunciado.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	caja_enunciado.add_child(lbl_enunciado)

	var lbl_sel_titulo := Label.new()
	lbl_sel_titulo.text = "SELECCIONA LA CARGA FUENTE q (1 uC = 10^-6 C):"
	lbl_sel_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sel_titulo.add_theme_font_size_override("font_size", 13)
	lbl_sel_titulo.add_theme_color_override("font_color", COLOR_CIAN)
	vbox.add_child(lbl_sel_titulo)

	var fila_opc := HBoxContainer.new()
	fila_opc.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_opc.add_theme_constant_override("separation", 12)
	vbox.add_child(fila_opc)

	botones_opcion.clear()
	for i in range(opciones_q_uc.size()):
		var btn := Button.new()
		btn.text = "%d uC" % opciones_q_uc[i]
		btn.custom_minimum_size = Vector2(132, 40)
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
	lbl_feedback.text = "Despeja |q| = (%.2fx10^4 * %d^2) / (9x10^9) y presiona COMPROBAR." % [
		e_objetivo_10e4, distancia_m
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
		_seleccionar_opcion(mini(opciones_q_uc.size() - 1, indice_sel + 1))
		return true
	if kc == KEY_ENTER or kc == KEY_KP_ENTER:
		_comprobar_respuesta()
		return true
	return false


func _seleccionar_opcion(idx: int) -> void:
	if resuelto:
		return
	indice_sel = clampi(idx, 0, opciones_q_uc.size() - 1)
	_actualizar_ui()


func _calcular_campo_nc(q_uc: int) -> float:
	return K_COULOMB * (float(q_uc) * 1.0e-6) / float(distancia_m * distancia_m)


func _actualizar_ui() -> void:
	var q_sel: int = opciones_q_uc[indice_sel]
	var e_calc: float = _calcular_campo_nc(q_sel)
	var e_en_10e4: float = e_calc / 1.0e4

	for i in range(botones_opcion.size()):
		var activo := (i == indice_sel)
		var col := COLOR_VERDE if (resuelto and activo) else (COLOR_AMARILLO if activo else COLOR_CIAN)
		estilizar_boton(botones_opcion[i], col, resuelto and not activo)
		botones_opcion[i].disabled = resuelto

	lbl_lectura.text = (
		"Opción: q = %d uC  |  d = %d m  |  Meta del sensor: E = %.2f x 10^4 N/C"
		% [q_sel, distancia_m, e_objetivo_10e4]
	)
	actualizar_barra(barra_campo, e_en_10e4, e_objetivo_10e4 * 2.0, COLOR_VERDE if resuelto else COLOR_CIAN)

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

	var q_sel: int = opciones_q_uc[indice_sel]
	var e_calc: float = _calcular_campo_nc(q_sel)
	var e_en_10e4: float = e_calc / 1.0e4
	var d2: int = distancia_m * distancia_m

	if q_sel == respuesta_correcta_uc:
		resuelto = true
		lbl_feedback.text = (
			"¡CORRECTO! |q| = (E * d^2) / k = (%.2fx10^4 * %d) / (9x10^9) = %d x 10^-6 C = %d uC.\n"
			+ "El sensor alcanza %.2f x 10^4 N/C y solidifica el puente energético."
		) % [e_objetivo_10e4, d2, respuesta_correcta_uc, respuesta_correcta_uc, e_objetivo_10e4]
		lbl_feedback.add_theme_color_override("font_color", COLOR_VERDE)
		_aplicar_estado_puente(false)
		_actualizar_ui()
		return

	if e_calc < e_objetivo_nc:
		lbl_feedback.text = (
			"INCORRECTO (q = %d uC): Genera E = %.2f x 10^4 N/C (menor que %.2f x 10^4 N/C).\n"
			+ "Pista: Recuerda elevar d = %d m al cuadrado (d^2 = %d) y despejar |q| = (E * %d) / (9x10^9)."
		) % [q_sel, e_en_10e4, e_objetivo_10e4, distancia_m, d2, d2]
	else:
		lbl_feedback.text = (
			"INCORRECTO (q = %d uC): Genera E = %.2f x 10^4 N/C (satura el sensor; meta: %.2f x 10^4 N/C).\n"
			+ "Pista: Verifica las potencias de 10 en |q| = (%.2fx10^4 * %d) / (9x10^9) = %d uC."
		) % [q_sel, e_en_10e4, e_objetivo_10e4, e_objetivo_10e4, d2, respuesta_correcta_uc]
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
