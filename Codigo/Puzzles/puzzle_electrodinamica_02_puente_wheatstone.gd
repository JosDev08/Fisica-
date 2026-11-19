extends "res://Codigo/Puzzles/puzzle_base.gd"

# ==============================================================================
# PUZZLE ELECTRODINÁMICA 02: PUENTE DE WHEATSTONE (Física II/III Ingeniería)
# Fórmula destacada: R1 / R2 = R3 / Rx   (Equilibrio: I_G = 0)
# Datos: R1 = 15 Ohm, R2 = 45 Ohm, R3 = 20 Ohm.
# Solución: 15 / 45 = 20 / Rx => 1/3 = 20 / Rx => Rx = 60 Ohm (V_G = 0 V).
# Opciones: 30 Ohm, 45 Ohm, 60 Ohm, 90 Ohm.
# Al resolver: hace subir la plataforma elevadora hija en Capa 5 (Suelo).
# ==============================================================================

const R1_OHM := 15.0
const R2_OHM := 45.0
const R3_OHM := 20.0
const V_PUENTE_V := 12.0
const OPCIONES_RX: Array[int] = [30, 45, 60, 90]

@export var respuesta_correcta_ohm: int = 60
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
var indice_sel: int = 0 # Inicia en 30 Ohm (no resuelto)

var botones_opcion: Array[Button] = []
var lbl_lectura: Label
var barra_equilibrio: ProgressBar
var lbl_feedback: Label
var btn_comprobar: Button


func _init() -> void:
	titulo_panel = "ELECTRODINÁMICA 02 — PUENTE DE WHEATSTONE"
	texto_prompt = "[E] Resolver Puzzle"
	ancho_panel = 680.0


func _inicializar_puzzle() -> void:
	if elevador_body != null:
		pos_base = elevador_body.position
		pos_cima = pos_base + Vector2(0.0, -altura_elevacion)
	_aplicar_estado_elevador()


func _construir_contenido_panel(vbox: VBoxContainer) -> void:
	# Recuadro destacado de fórmula física
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

	# Enunciado con datos de ingeniería
	var caja_enunciado := PanelContainer.new()
	caja_enunciado.add_theme_stylebox_override("panel", crear_caja(Color(0.05, 0.10, 0.13, 0.96), COLOR_CIAN, 2, 12))
	vbox.add_child(caja_enunciado)

	var lbl_enunciado := Label.new()
	lbl_enunciado.text = (
		"FÍSICA II/III — CALIBRACIÓN DE ELEVADOR:\n"
		+ "El sistema de control del elevador usa un Puente de Wheatstone para calibrar la carga. "
		+ "Las ramas fijas son R1 = 15 Ohm, R2 = 45 Ohm y R3 = 20 Ohm.\n"
		+ "Ajusta el potenciómetro Rx para equilibrar el puente (V_G = 0 V) y activar el elevador."
	)
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
	for i in range(OPCIONES_RX.size()):
		var btn := Button.new()
		btn.text = "%d Ohm" % OPCIONES_RX[i]
		btn.custom_minimum_size = Vector2(132, 40)
		btn.focus_mode = Control.FOCUS_NONE
		var idx_local := i
		btn.pressed.connect(func() -> void: _seleccionar_opcion(idx_local))
		fila_opc.add_child(btn)
		botones_opcion.append(btn)

	# Telemetría del galvanómetro
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
	lbl_feedback.text = "Iguala las razones R1 / R2 = R3 / Rx (o R1 * Rx = R2 * R3) y presiona COMPROBAR."
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


func _calcular_vg(rx_ohm: int) -> float:
	var va: float = V_PUENTE_V * R2_OHM / (R1_OHM + R2_OHM)
	var vb: float = V_PUENTE_V * float(rx_ohm) / (R3_OHM + float(rx_ohm))
	return va - vb


func _actualizar_ui() -> void:
	var rx_sel: int = OPCIONES_RX[indice_sel]
	var razon_izq: float = R1_OHM / R2_OHM
	var razon_der: float = R3_OHM / float(rx_sel)
	var vg: float = _calcular_vg(rx_sel)
	var equilibrio_pct: float = clampf((1.0 - absf(vg) / 2.5) * 100.0, 0.0, 100.0)

	for i in range(botones_opcion.size()):
		var activo := (i == indice_sel)
		var col := COLOR_VERDE if (resuelto and activo) else (COLOR_AMARILLO if activo else COLOR_CIAN)
		estilizar_boton(botones_opcion[i], col, resuelto and not activo)
		botones_opcion[i].disabled = resuelto

	lbl_lectura.text = (
		"R1/R2 = %.3f  vs  R3/Rx = %.3f   |   Galvanómetro V_G = %+.2f V  (Meta: 0.00 V)"
		% [razon_izq, razon_der, vg]
	)
	var col_barra := COLOR_VERDE if rx_sel == respuesta_correcta_ohm else (COLOR_AMARILLO if equilibrio_pct >= 60.0 else COLOR_ROJO)
	actualizar_barra(barra_equilibrio, equilibrio_pct, 100.0, col_barra)

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

	var rx_sel: int = OPCIONES_RX[indice_sel]
	var vg: float = _calcular_vg(rx_sel)

	if rx_sel == respuesta_correcta_ohm:
		resuelto = true
		subiendo = true
		pausa_actual = 0.0
		lbl_feedback.text = (
			"¡CORRECTO! Paso 1: Condición de equilibrio R1 / R2 = R3 / Rx => 15 / 45 = 20 / Rx.\n"
			+ "Paso 2: Simplificamos 1 / 3 = 20 / Rx => Rx = 3 * 20 = 60 Ohm (V_G = 0 V, I_G = 0 A).\n"
			+ "Puente de Wheatstone calibrado. Elevando plataforma en Capa 5."
		)
		lbl_feedback.add_theme_color_override("font_color", COLOR_VERDE)
		_aplicar_estado_elevador()
		_actualizar_ui()
		return

	if vg > 0.0:
		lbl_feedback.text = (
			"INCORRECTO (Rx = %d Ohm): El galvanómetro marca V_G = %+.2f V (rama derecha con R3/Rx demasiado alta).\n"
			+ "Paso a paso: Despeja Rx = (R2 * R3) / R1 = (45 * 20) / 15."
		) % [rx_sel, vg]
	else:
		lbl_feedback.text = (
			"INCORRECTO (Rx = %d Ohm): El galvanómetro se invierte a V_G = %+.2f V (Rx es demasiado grande).\n"
			+ "Paso a paso: Como R2 es el triple de R1 (45 = 3 * 15), Rx debe ser exactamente el triple de R3 (20 Ohm)."
		) % [rx_sel, vg]
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
