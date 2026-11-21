extends "res://Codigo/Puzzles/puzzle_base.gd"

# ==============================================================================
# PUZZLE ELECTRODINÁMICA 01: FUENTE REAL Y KIRCHHOFF (Física II/III Ingeniería)
# Fórmulas destacadas: V_ab = fem - I * r_i   |   I = V_ab / R_L
# Genera fem, r_i y V_ab aleatorios con I y R_L enteros exactos, 3 distractores
# realistas y mezcla los 4 botones con opciones.shuffle().
# Al resolver: abre suavemente la compuerta metálica hija en Capa 5 (Suelo).
# ==============================================================================

const OPCIONES_RI: Array[int] = [1, 2, 3, 4]
const OPCIONES_I: Array[int] = [2, 3, 4, 5, 6]
const OPCIONES_RL_BASE: Array[int] = [6, 8, 10, 12, 15, 16, 20]

@export var respuesta_correcta_ohm: int = 10
@export var altura_apertura: float = 116.0
@export var velocidad_apertura: float = 180.0

@onready var compuerta_body: StaticBody2D = $CompuertaMetalica
@onready var compuerta_col: CollisionShape2D = $CompuertaMetalica/CollisionShape2D
@onready var compuerta_sprite: Sprite2D = $CompuertaMetalica/Sprite2D
@onready var lbl_estado_compuerta: Label = $CompuertaMetalica/EstadoCompuerta

var fem_v: int = 48
var r_interna_ohm: int = 2
var vab_objetivo_v: int = 40
var i_nominal_a: int = 4
var opciones_rl: Array[int] = []

var resuelto: bool = false
var pos_cerrada: Vector2 = Vector2.ZERO
var pos_abierta: Vector2 = Vector2.ZERO
var indice_sel: int = 0

var lbl_enunciado: Label
var botones_opcion: Array[Button] = []
var lbl_lectura: Label
var barra_vab: ProgressBar
var lbl_feedback: Label
var btn_comprobar: Button


func _init() -> void:
	titulo_panel = "ELECTRODINÁMICA 01 — FUENTE REAL Y KIRCHHOFF"
	texto_prompt = "[E] Resolver Puzzle"
	ancho_panel = 680.0


func generar_problema() -> void:
	var combinaciones: Array = []
	for ri in OPCIONES_RI:
		for i_val in OPCIONES_I:
			for rl in OPCIONES_RL_BASE:
				var vab: int = i_val * rl
				var fem: int = vab + i_val * ri
				if fem >= 20 and fem <= 120 and rl > ri:
					combinaciones.append([fem, ri, vab, i_val, rl])

	var elegida: Array = combinaciones[randi() % combinaciones.size()]
	fem_v = int(elegida[0])
	r_interna_ohm = int(elegida[1])
	vab_objetivo_v = int(elegida[2])
	i_nominal_a = int(elegida[3])
	respuesta_correcta_ohm = int(elegida[4])

	# 3 distractores típicos: R_total (dividir fem/I), restar r_i extra, o doblar R_L
	var d_rtotal: int = respuesta_correcta_ohm + r_interna_ohm
	var d_menos_ri: int = maxi(2, respuesta_correcta_ohm - r_interna_ohm)
	var d_doble: int = respuesta_correcta_ohm * 2
	var d_mitad: int = maxi(2, int(round(float(respuesta_correcta_ohm) * 0.5)))

	opciones_rl = construir_opciones_int(
		respuesta_correcta_ohm,
		[d_rtotal, d_menos_ri, d_doble, d_mitad],
		2,
		100,
		2
	)
	indice_sel = indice_inicial_no_correcto(opciones_rl, respuesta_correcta_ohm)


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
	lbl_formula.text = "FÓRMULAS DE INGENIERÍA:   V_ab = fem - I * r_i   |   I = V_ab / R_L"
	lbl_formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_formula.add_theme_font_size_override("font_size", 16)
	lbl_formula.add_theme_color_override("font_color", COLOR_AMARILLO)
	lbl_formula.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_formula.add_theme_constant_override("outline_size", 3)
	caja_formula.add_child(lbl_formula)

	var caja_enunciado := PanelContainer.new()
	caja_enunciado.add_theme_stylebox_override("panel", crear_caja(Color(0.06, 0.10, 0.13, 0.96), COLOR_CIAN, 2, 12))
	vbox.add_child(caja_enunciado)

	lbl_enunciado = Label.new()
	lbl_enunciado.text = (
		"FÍSICA II/III — ACTUADOR CON FUENTE REAL:\n"
		+ "Una batería industrial de fem = %d V con resistencia interna r_i = %d Ohm alimenta el actuador "
		+ "de una compuerta. Para operar en su punto nominal requiere un voltaje en terminales exacto "
		+ "V_ab = %d V.\n"
		+ "Selecciona la resistencia de carga R_L del actuador."
	) % [fem_v, r_interna_ohm, vab_objetivo_v]
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
	for i in range(opciones_rl.size()):
		var btn := Button.new()
		btn.text = "%d Ohm" % opciones_rl[i]
		btn.custom_minimum_size = Vector2(132, 40)
		btn.focus_mode = Control.FOCUS_NONE
		var idx_local := i
		btn.pressed.connect(func() -> void: _seleccionar_opcion(idx_local))
		fila_opc.add_child(btn)
		botones_opcion.append(btn)

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
	lbl_feedback.text = "Halla I desde (%d - %d) = I * %d y luego despeja R_L = %d / I." % [
		fem_v, vab_objetivo_v, r_interna_ohm, vab_objetivo_v
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
		_seleccionar_opcion(mini(opciones_rl.size() - 1, indice_sel + 1))
		return true
	if kc == KEY_ENTER or kc == KEY_KP_ENTER:
		_comprobar_respuesta()
		return true
	return false


func _seleccionar_opcion(idx: int) -> void:
	if resuelto:
		return
	indice_sel = clampi(idx, 0, opciones_rl.size() - 1)
	_actualizar_ui()


func _actualizar_ui() -> void:
	var rl_sel: int = opciones_rl[indice_sel]
	var i_real: float = float(fem_v) / float(r_interna_ohm + rl_sel)
	var vab_real: float = float(fem_v) - i_real * float(r_interna_ohm)

	for i in range(botones_opcion.size()):
		var activo := (i == indice_sel)
		var col := COLOR_VERDE if (resuelto and activo) else (COLOR_AMARILLO if activo else COLOR_CIAN)
		estilizar_boton(botones_opcion[i], col, resuelto and not activo)
		botones_opcion[i].disabled = resuelto

	lbl_lectura.text = (
		"Opción: R_L = %d Ohm  |  fem = %d V, r_i = %d Ohm  |  Nominal: V_ab = %d V"
		% [rl_sel, fem_v, r_interna_ohm, vab_objetivo_v]
	)
	actualizar_barra(barra_vab, vab_real, float(fem_v), COLOR_VERDE if resuelto else COLOR_CIAN)

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

	var rl_sel: int = opciones_rl[indice_sel]
	var i_real: float = float(fem_v) / float(r_interna_ohm + rl_sel)
	var vab_real: float = float(fem_v) - i_real * float(r_interna_ohm)
	var caida_int: int = fem_v - vab_objetivo_v

	if rl_sel == respuesta_correcta_ohm:
		resuelto = true
		lbl_feedback.text = (
			"¡CORRECTO! Paso 1: De V_ab = fem - I * r_i => I = (%d - %d) / %d = %d / %d = %d A.\n"
			+ "Paso 2: Aplicamos Ley de Ohm en la carga: R_L = V_ab / I = %d / %d = %d Ohm.\n"
			+ "Actuador en punto nominal (%d V, %d A). Abriendo compuerta metálica."
		) % [fem_v, vab_objetivo_v, r_interna_ohm, caida_int, r_interna_ohm, i_nominal_a, vab_objetivo_v, i_nominal_a, respuesta_correcta_ohm, vab_objetivo_v, i_nominal_a]
		lbl_feedback.add_theme_color_override("font_color", COLOR_VERDE)
		_aplicar_estado_compuerta()
		_actualizar_ui()
		return

	if vab_real < float(vab_objetivo_v):
		lbl_feedback.text = (
			"INCORRECTO (R_L = %d Ohm): La corriente sube a I = %.2f A y el voltaje cae a V_ab = %.2f V (< %d V).\n"
			+ "Paso a paso: Despeja I = (%d - %d) / %d = %d A y luego R_L = %d / %d."
		) % [rl_sel, i_real, vab_real, vab_objetivo_v, fem_v, vab_objetivo_v, r_interna_ohm, i_nominal_a, vab_objetivo_v, i_nominal_a]
	else:
		lbl_feedback.text = (
			"INCORRECTO (R_L = %d Ohm): Con R_L = %d Ohm circula I = %.2f A y V_ab = %.2f V (> %d V).\n"
			+ "Paso a paso: No dividas fem (%d V) entre %d A; usa V_ab en terminales: R_L = %d / %d."
		) % [rl_sel, rl_sel, i_real, vab_real, vab_objetivo_v, fem_v, i_nominal_a, vab_objetivo_v, i_nominal_a]
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
