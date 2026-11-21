extends "res://Codigo/Puzzles/puzzle_base.gd"

# ==============================================================================
# PUZZLE ELECTROSTÁTICA 02: LEY DE GAUSS EN SONDA (Física II/III Ingeniería)
# Fórmula destacada: E = (k * Q) / r^2   (Ley de Gauss, r > R)
# Genera R, r y Q aleatorios con solución entera exacta en kN/C, 3 distractores
# realistas (sin elevar r^2, sin dividir, confundir r con R) y opciones.shuffle().
# Al resolver: activa y solidifica el puente energético hijo en Capa 5 (Suelo).
# ==============================================================================

# Configuraciones [R_m, r_m, Q_lista_uC] que siempre producen E entero exacto en kN/C:
# E_kNC = (9 * Q_uC) / (r_m^2)
const CONFIGS_GAUSS: Array = [
	[0.10, 0.30, [2, 3, 4, 5, 6]],      # 100 * Q -> 200..600 kN/C
	[0.20, 0.50, [5, 10, 15]],          # 36 * Q  -> 180, 360, 540 kN/C
	[0.20, 0.60, [4, 8, 12, 16]],       # 25 * Q  -> 100, 200, 300, 400 kN/C
	[0.30, 0.90, [9, 18, 27]],          # 100/9*Q -> 100, 200, 300 kN/C
	[0.25, 1.00, [8, 10, 12, 16, 20]],  # 9 * Q   -> 72, 90, 108, 144, 180 kN/C
]

@export var respuesta_correcta_knc: int = 200

@onready var puente_body: StaticBody2D = $PuenteEnergetico
@onready var puente_col: CollisionShape2D = $PuenteEnergetico/CollisionShape2D
@onready var puente_sprite: Sprite2D = $PuenteEnergetico/Sprite2D
@onready var lbl_estado_puente: Label = $PuenteEnergetico/EstadoPuente

var radio_esfera_m: float = 0.20
var dist_sonda_m: float = 0.60
var carga_q_uc: int = 8
var opciones_e_knc: Array[int] = []

var resuelto: bool = false
var indice_sel: int = 0
var tiempo_fx: float = 0.0

var lbl_enunciado: Label
var botones_opcion: Array[Button] = []
var lbl_lectura: Label
var barra_gauss: ProgressBar
var lbl_feedback: Label
var btn_comprobar: Button


func _init() -> void:
	titulo_panel = "ELECTROSTÁTICA 02 — LEY DE GAUSS (SONDA)"
	texto_prompt = "[E] Resolver Puzzle"
	ancho_panel = 680.0


func generar_problema() -> void:
	var cfg: Array = CONFIGS_GAUSS[randi() % CONFIGS_GAUSS.size()]
	radio_esfera_m = float(cfg[0])
	dist_sonda_m = float(cfg[1])
	var lista_q: Array = cfg[2]
	carga_q_uc = int(lista_q[randi() % lista_q.size()])

	var num_kq_kn: float = 9.0 * float(carga_q_uc) # en kN*m^2/C
	respuesta_correcta_knc = int(round(num_kq_kn / (dist_sonda_m * dist_sonda_m)))

	# 3 distractores típicos: olvidar r^2 (kQ/r), olvidar dividir (kQ), factor erróneo (1.8x o 0.5x)
	var d_sin_cuadrado: int = maxi(10, int(round(num_kq_kn / dist_sonda_m)))
	var d_solo_kq: int = maxi(10, int(round(num_kq_kn)))
	var d_alto: int = int(round(float(respuesta_correcta_knc) * 1.8))
	var d_mitad: int = maxi(10, int(round(float(respuesta_correcta_knc) * 0.5)))

	opciones_e_knc = construir_opciones_int(
		respuesta_correcta_knc,
		[d_sin_cuadrado, d_alto, d_solo_kq, d_mitad],
		10,
		5000,
		maxi(20, int(round(float(respuesta_correcta_knc) * 0.25)))
	)
	indice_sel = indice_inicial_no_correcto(opciones_e_knc, respuesta_correcta_knc)


func _inicializar_puzzle() -> void:
	_aplicar_estado_puente(true)


func _construir_contenido_panel(vbox: VBoxContainer) -> void:
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

	var caja_enunciado := PanelContainer.new()
	caja_enunciado.add_theme_stylebox_override("panel", crear_caja(Color(0.06, 0.06, 0.16, 0.96), COLOR_CIAN, 2, 12))
	vbox.add_child(caja_enunciado)

	lbl_enunciado = Label.new()
	lbl_enunciado.text = (
		"FÍSICA II/III — SENSOR ESFÉRICO DE ALTO VOLTAJE:\n"
		+ "Un sensor de alto voltaje modela un nodo esférico conductor de radio R = %.2f m con carga neta "
		+ "Q = +%d uC (k = 9 x 10^9 N*m^2/C^2).\n"
		+ "Calcula la intensidad de campo eléctrico E en la sonda ubicada a r = %.2f m del centro "
		+ "para energizar el puente."
	) % [radio_esfera_m, carga_q_uc, dist_sonda_m]
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
	for i in range(opciones_e_knc.size()):
		var btn := Button.new()
		btn.text = "%d kN/C" % opciones_e_knc[i]
		btn.custom_minimum_size = Vector2(132, 40)
		btn.focus_mode = Control.FOCUS_NONE
		var idx_local := i
		btn.pressed.connect(func() -> void: _seleccionar_opcion(idx_local))
		fila_opc.add_child(btn)
		botones_opcion.append(btn)

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
	lbl_feedback.text = "Para r = %.2f m > R = %.2f m, toda la carga Q = +%d uC actúa desde el centro." % [
		dist_sonda_m, radio_esfera_m, carga_q_uc
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
		_seleccionar_opcion(mini(opciones_e_knc.size() - 1, indice_sel + 1))
		return true
	if kc == KEY_ENTER or kc == KEY_KP_ENTER:
		_comprobar_respuesta()
		return true
	return false


func _seleccionar_opcion(idx: int) -> void:
	if resuelto:
		return
	indice_sel = clampi(idx, 0, opciones_e_knc.size() - 1)
	_actualizar_ui()


func _actualizar_ui() -> void:
	var e_sel: int = opciones_e_knc[indice_sel]
	var max_opc: float = 1.0
	for v in opciones_e_knc:
		max_opc = maxf(max_opc, float(v))

	for i in range(botones_opcion.size()):
		var activo := (i == indice_sel)
		var col := COLOR_VERDE if (resuelto and activo) else (COLOR_AMARILLO if activo else COLOR_CIAN)
		estilizar_boton(botones_opcion[i], col, resuelto and not activo)
		botones_opcion[i].disabled = resuelto

	lbl_lectura.text = (
		"Calibración elegida: E = %d kN/C   |   Datos: Q = +%d uC, r = %.2f m (r > R)"
		% [e_sel, carga_q_uc, dist_sonda_m]
	)
	actualizar_barra(barra_gauss, float(e_sel), max_opc, COLOR_VERDE if resuelto else COLOR_CIAN)

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

	var e_sel: int = opciones_e_knc[indice_sel]
	var kq_val: float = 9000.0 * float(carga_q_uc)
	var r2_val: float = dist_sonda_m * dist_sonda_m

	if e_sel == respuesta_correcta_knc:
		resuelto = true
		lbl_feedback.text = (
			"¡CORRECTO! Paso 1: Como r = %.2f m > R = %.2f m, por Ley de Gauss E = (k * Q) / r^2.\n"
			+ "Paso 2: k * Q = (9x10^9) * (%dx10^-6) = %.0f N*m^2/C; r^2 = (%.2f)^2 = %.2f m^2.\n"
			+ "Paso 3: E = %.0f / %.2f = %d kN/C. Puente energético solidificado."
		) % [dist_sonda_m, radio_esfera_m, carga_q_uc, kq_val, dist_sonda_m, r2_val, kq_val, r2_val, respuesta_correcta_knc]
		lbl_feedback.add_theme_color_override("font_color", COLOR_VERDE)
		_aplicar_estado_puente(false)
		_actualizar_ui()
		return

	var d_sin_cuad: int = int(round((9.0 * float(carga_q_uc)) / dist_sonda_m))
	if e_sel == d_sin_cuad:
		lbl_feedback.text = (
			"INCORRECTO (%d kN/C): Ese valor sale de dividir k*Q / r sin elevar r al cuadrado.\n"
			+ "Paso a paso: Eleva r = %.2f m al cuadrado (r^2 = %.2f m^2) y calcula %.0f / %.2f."
		) % [e_sel, dist_sonda_m, r2_val, kq_val, r2_val]
	else:
		lbl_feedback.text = (
			"INCORRECTO (%d kN/C): Recuerda que el campo depende de r = %.2f m (no del radio interno R = %.2f m).\n"
			+ "Paso a paso: E = (9x10^9 * %dx10^-6) / (%.2f)^2 = %.0f / %.2f N/C."
		) % [e_sel, dist_sonda_m, radio_esfera_m, carga_q_uc, dist_sonda_m, kq_val, r2_val]
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
