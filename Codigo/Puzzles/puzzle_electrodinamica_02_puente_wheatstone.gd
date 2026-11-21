extends "res://Codigo/Puzzles/puzzle_base.gd"

# ==============================================================================
# PUZZLE ELECTRODINÁMICA 02: PUENTE DE WHEATSTONE (Física II/III Ingeniería)
# Fórmula destacada: R1 / R2 = R3 / Rx   (Equilibrio: I_G = 0)
# Genera R1, R2 y R3 aleatorios con solución entera exacta Rx = (R2 * R3) / R1,
# 3 distractores realistas y mezcla los 4 botones con opciones.shuffle().
# Al resolver: hace subir la plataforma elevadora hija en Capa 5 (Suelo).
# ==============================================================================

const V_PUENTE_V := 12.0
const BASES_R1: Array[int] = [10, 12, 15, 20, 25]
const FACTORES_M: Array[int] = [2, 3, 4]
const BASES_R3: Array[int] = [12, 15, 18, 20, 24, 30]

@export var respuesta_correcta_ohm: int = 60
@export var altura_elevacion: float = 160.0
@export var velocidad_elevador: float = 95.0
@export var pausa_extremos: float = 1.6
@export var ciclo_continuo: bool = true

@onready var elevador_body: AnimatableBody2D = $PlataformaElevadora
@onready var elevador_sprite: Sprite2D = $PlataformaElevadora/Sprite2D
@onready var lbl_estado_elevador: Label = $PlataformaElevadora/EstadoElevador

var r1_ohm: int = 15
var r2_ohm: int = 45
var r3_ohm: int = 20
var opciones_rx: Array[int] = []

var resuelto: bool = false
var pos_base: Vector2 = Vector2.ZERO
var pos_cima: Vector2 = Vector2.ZERO
var subiendo: bool = true
var pausa_actual: float = 0.0
var indice_sel: int = 0

var lbl_enunciado: Label
var botones_opcion: Array[Button] = []
var lbl_lectura: Label
var barra_equilibrio: ProgressBar
var lbl_feedback: Label
var btn_comprobar: Button


func _init() -> void:
	titulo_panel = "ELECTRODINÁMICA 02 — PUENTE DE WHEATSTONE"
	texto_prompt = "[E] Resolver Puzzle"
	ancho_panel = 680.0


func generar_problema() -> void:
	var factor_m: int = FACTORES_M[randi() % FACTORES_M.size()]
	var base_a: int = BASES_R1[randi() % BASES_R1.size()]
	var base_b: int = BASES_R3[randi() % BASES_R3.size()]

	if randi() % 2 == 0:
		# R2 = m * R1  =>  Rx = m * R3
		r1_ohm = base_a
		r2_ohm = base_a * factor_m
		r3_ohm = base_b
		respuesta_correcta_ohm = r3_ohm * factor_m
	else:
		# R1 = m * R2  =>  Rx = R3 / m (asegurando división exacta)
		r2_ohm = base_a
		r1_ohm = base_a * factor_m
		respuesta_correcta_ohm = base_b
		r3_ohm = base_b * factor_m

	# 3 distractores típicos: error aditivo (R3 + R2 - R1), fórmula invertida (R1*R3/R2), factor 1.5x / 0.5x
	var d_aditivo: int = maxi(4, r3_ohm + r2_ohm - r1_ohm)
	var d_invertido: int = maxi(4, int(round(float(r1_ohm * r3_ohm) / float(r2_ohm))))
	var d_alto: int = int(round(float(respuesta_correcta_ohm) * 1.5))
	var d_mitad: int = maxi(4, int(round(float(respuesta_correcta_ohm) * 0.5)))

	opciones_rx = construir_opciones_int(
		respuesta_correcta_ohm,
		[d_mitad, d_aditivo, d_alto, d_invertido],
		4,
		400,
		5
	)
	indice_sel = indice_inicial_no_correcto(opciones_rx, respuesta_correcta_ohm)


func _inicializar_puzzle() -> void:
	if elevador_body != null:
		pos_base = elevador_body.position
		pos_cima = pos_base + Vector2(0.0, -altura_elevacion)
	_aplicar_estado_elevador()


func _construir_contenido_panel(vbox: VBoxContainer) -> void:
	var caja_formula := PanelContainer.new()
	caja_formula.add_theme_stylebox_override("panel", crear_caja(Color(0.05, 0.13, 0.15, 0.98), COLOR_AMARILLO, 2, 10))
	vbox.add_child(caja_formula)

	var lbl_formula := Label.new()
	lbl_formula.text = "FÓRMULA DE INGENIERÍA:   R1 / R2 = R3 / Rx   (Equilibrio: I_G = 0)"
	lbl_formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_formula.add_theme_font_size_override("font_size", 16)
	lbl_formula.add_theme_color_override("font_color", COLOR_AMARILLO)
	lbl_formula.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_formula.add_theme_constant_override("outline_size", 3)
	caja_formula.add_child(lbl_formula)

	var caja_enunciado := PanelContainer.new()
	caja_enunciado.add_theme_stylebox_override("panel", crear_caja(Color(0.05, 0.10, 0.13, 0.96), COLOR_CIAN, 2, 12))
	vbox.add_child(caja_enunciado)

	lbl_enunciado = Label.new()
	lbl_enunciado.text = (
		"FÍSICA II/III — CALIBRACIÓN DE ELEVADOR:\n"
		+ "El sistema de control del elevador usa un Puente de Wheatstone para calibrar la carga. "
		+ "Las ramas fijas son R1 = %d Ohm, R2 = %d Ohm y R3 = %d Ohm.\n"
		+ "Ajusta el potenciómetro Rx para equilibrar el puente (V_G = 0 V) y activar el elevador."
	) % [r1_ohm, r2_ohm, r3_ohm]
	lbl_enunciado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_enunciado.add_theme_font_size_override("font_size", 14)
	lbl_enunciado.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	caja_enunciado.add_child(lbl_enunciado)

	var lbl_sel := Label.new()
	lbl_sel.text = "AJUSTA EL POTENCIÓMETRO Rx PARA EQUILIBRAR EL GALVANÓMETRO:"
	lbl_sel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sel.add_theme_font_size_override("font_size", 13)
	lbl_sel.add_theme_color_override("font_color", COLOR_CIAN)
	vbox.add_child(lbl_sel)

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
	caja_sim.add_theme_stylebox_override("panel", crear_caja(Color(0.04, 0.08, 0.11, 0.96), Color(0.25, 0.72, 0.78), 2, 10))
	vbox.add_child(caja_sim)

	var v_sim := VBoxContainer.new()
	v_sim.add_theme_constant_override("separation", 6)
	caja_sim.add_child(v_sim)

	lbl_lectura = Label.new()
	lbl_lectura.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_lectura.add_theme_font_size_override("font_size", 14)
	lbl_lectura.add_theme_color_override("font_color", COLOR_CIAN)
	v_sim.add_child(lbl_lectura)

	barra_equilibrio = ProgressBar.new()
	barra_equilibrio.custom_minimum_size = Vector2(0, 18)
	barra_equilibrio.show_percentage = false
	v_sim.add_child(barra_equilibrio)

	lbl_feedback = Label.new()
	lbl_feedback.text = "Iguala R1 / R2 = R3 / Rx (es decir, Rx = (%d * %d) / %d) y presiona COMPROBAR." % [
		r2_ohm, r3_ohm, r1_ohm
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


func _calcular_vg(rx_ohm: int) -> float:
	var va: float = V_PUENTE_V * float(r2_ohm) / float(r1_ohm + r2_ohm)
	var vb: float = V_PUENTE_V * float(rx_ohm) / float(r3_ohm + rx_ohm)
	return va - vb


func _actualizar_ui() -> void:
	var rx_sel: int = opciones_rx[indice_sel]
	var vg: float = _calcular_vg(rx_sel)
	var equilibrio_pct: float = clampf((1.0 - absf(vg) / 3.0) * 100.0, 0.0, 100.0)

	for i in range(botones_opcion.size()):
		var activo := (i == indice_sel)
		var col := COLOR_VERDE if (resuelto and activo) else (COLOR_AMARILLO if activo else COLOR_CIAN)
		estilizar_boton(botones_opcion[i], col, resuelto and not activo)
		botones_opcion[i].disabled = resuelto

	lbl_lectura.text = (
		"Opción: Rx = %d Ohm  |  R1 = %d, R2 = %d, R3 = %d Ohm  |  Meta: V_G = 0.00 V"
		% [rx_sel, r1_ohm, r2_ohm, r3_ohm]
	)
	actualizar_barra(barra_equilibrio, 100.0 if resuelto else equilibrio_pct, 100.0, COLOR_VERDE if resuelto else COLOR_CIAN)

	if resuelto:
		btn_comprobar.text = "PUENTE EQUILIBRADO — ELEVADOR ACTIVO (CERRAR)"
		estilizar_boton(btn_comprobar, COLOR_VERDE)
	else:
		btn_comprobar.text = "COMPROBAR Rx = %d Ohm (ENTER)" % rx_sel
		estilizar_boton(btn_comprobar, COLOR_CIAN)


func _comprobar_respuesta() -> void:
	if resuelto:
		cerrar_panel()
		return

	var rx_sel: int = opciones_rx[indice_sel]
	var vg: float = _calcular_vg(rx_sel)
	var prod: int = r2_ohm * r3_ohm

	if rx_sel == respuesta_correcta_ohm:
		resuelto = true
		subiendo = true
		pausa_actual = 0.0
		lbl_feedback.text = (
			"¡CORRECTO! Paso 1: En equilibrio R1 / R2 = R3 / Rx => %d / %d = %d / Rx.\n"
			+ "Paso 2: Rx = (R2 * R3) / R1 = (%d * %d) / %d = %d / %d = %d Ohm (V_G = 0 V).\n"
			+ "Puente de Wheatstone calibrado. Elevando plataforma en Capa 5."
		) % [r1_ohm, r2_ohm, r3_ohm, r2_ohm, r3_ohm, r1_ohm, prod, r1_ohm, respuesta_correcta_ohm]
		lbl_feedback.add_theme_color_override("font_color", COLOR_VERDE)
		_aplicar_estado_elevador()
		_actualizar_ui()
		return

	if vg > 0.0:
		lbl_feedback.text = (
			"INCORRECTO (Rx = %d Ohm): El galvanómetro marca V_G = %+.2f V (Rx es demasiado pequeña).\n"
			+ "Paso a paso: Despeja Rx = (R2 * R3) / R1 = (%d * %d) / %d = %d / %d."
		) % [rx_sel, vg, r2_ohm, r3_ohm, r1_ohm, prod, r1_ohm]
	else:
		lbl_feedback.text = (
			"INCORRECTO (Rx = %d Ohm): El galvanómetro se invierte a V_G = %+.2f V (Rx es demasiado grande).\n"
			+ "Paso a paso: Verifica la proporción %d / %d = %d / Rx => Rx = %d / %d."
		) % [rx_sel, vg, r1_ohm, r2_ohm, r3_ohm, prod, r1_ohm]
	lbl_feedback.add_theme_color_override("font_color", COLOR_ROJO)


func _aplicar_estado_elevador() -> void:
	if lbl_estado_elevador != null:
		lbl_estado_elevador.text = "V_G = 0V ACTIVO" if resuelto else "DESCALIBRADO"
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
