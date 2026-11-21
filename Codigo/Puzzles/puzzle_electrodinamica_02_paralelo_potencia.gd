extends "res://Codigo/Puzzles/puzzle_base.gd"

# ==============================================================================
# PUZZLE ELECTRODINÁMICA 02: PARALELO Y POTENCIA (Nivel Preuniversitario UNI)
# Fórmulas destacadas: P = V * I_total   |   I_total = V/R1 + V/R2
# Genera V, R1 y R2 aleatorios divisores de V (I1, I2, I_total y P enteros exactos),
# 3 distractores realistas y mezcla los 4 botones con opciones.shuffle().
# Al resolver: hace subir la plataforma elevadora hija en Capa 5 (Suelo).
# ==============================================================================

# Configuraciones [V, [divisores_limpios]] para garantizar I1, I2 y P enteros exactos
const CONFIGS_PARALELO: Array = [
	[24, [4, 6, 8, 12, 24]],
	[36, [6, 9, 12, 18, 36]],
	[48, [6, 8, 12, 16, 24]],
	[60, [10, 12, 15, 20, 30]],
]

@export var respuesta_correcta_ohm: int = 12
@export var altura_elevacion: float = 160.0
@export var velocidad_elevador: float = 95.0
@export var pausa_extremos: float = 1.6
@export var ciclo_continuo: bool = true

@onready var elevador_body: AnimatableBody2D = $PlataformaElevadora
@onready var elevador_sprite: Sprite2D = $PlataformaElevadora/Sprite2D
@onready var lbl_estado_elevador: Label = $PlataformaElevadora/EstadoElevador

var voltaje_v: int = 24
var r1_ohm: int = 6
var i1_a: int = 4
var i2_a: int = 2
var i_objetivo_a: int = 6
var potencia_objetivo_w: int = 144
var opciones_r2: Array[int] = []

var resuelto: bool = false
var pos_base: Vector2 = Vector2.ZERO
var pos_cima: Vector2 = Vector2.ZERO
var subiendo: bool = true
var pausa_actual: float = 0.0
var indice_sel: int = 0

var lbl_enunciado: Label
var botones_opcion: Array[Button] = []
var lbl_lectura: Label
var barra_potencia: ProgressBar
var lbl_feedback: Label
var btn_comprobar: Button


func _init() -> void:
	titulo_panel = "ELECTRODINÁMICA 02 — PARALELO Y POTENCIA"
	texto_prompt = "[E] Resolver Puzzle"
	ancho_panel = 680.0


func generar_problema() -> void:
	var cfg: Array = CONFIGS_PARALELO[randi() % CONFIGS_PARALELO.size()]
	voltaje_v = int(cfg[0])
	var divs: Array = cfg[1]

	var idx1: int = randi() % divs.size()
	var idx2: int = randi() % divs.size()
	while idx2 == idx1:
		idx2 = randi() % divs.size()

	r1_ohm = int(divs[idx1])
	respuesta_correcta_ohm = int(divs[idx2])
	i1_a = int(voltaje_v / r1_ohm)
	i2_a = int(voltaje_v / respuesta_correcta_ohm)
	i_objetivo_a = i1_a + i2_a
	potencia_objetivo_w = voltaje_v * i_objetivo_a

	# 3 distractores típicos: R_eq (V/I_total), suma serie (R1 + R2), mitad o doble de R2
	var d_req: int = maxi(2, int(round(float(voltaje_v) / float(i_objetivo_a))))
	var d_mitad: int = maxi(2, int(round(float(respuesta_correcta_ohm) * 0.5)))
	var d_doble: int = respuesta_correcta_ohm * 2
	var d_serie: int = r1_ohm + respuesta_correcta_ohm

	opciones_r2 = construir_opciones_int(
		respuesta_correcta_ohm,
		[d_req, d_mitad, d_doble, d_serie],
		2,
		120,
		2
	)
	indice_sel = indice_inicial_no_correcto(opciones_r2, respuesta_correcta_ohm)


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
	lbl_formula.text = "FÓRMULAS:   P = V * I_total   |   I_total = V / R1 + V / R2"
	lbl_formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_formula.add_theme_font_size_override("font_size", 16)
	lbl_formula.add_theme_color_override("font_color", COLOR_AMARILLO)
	lbl_formula.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_formula.add_theme_constant_override("outline_size", 3)
	caja_formula.add_child(lbl_formula)

	var caja_enunciado := PanelContainer.new()
	caja_enunciado.add_theme_stylebox_override("panel", crear_caja(Color(0.05, 0.11, 0.13, 0.96), COLOR_CIAN, 2, 12))
	vbox.add_child(caja_enunciado)

	lbl_enunciado = Label.new()
	lbl_enunciado.text = (
		"ENUNCIADO (Nivel Preuniversitario):\n"
		+ "Un generador de V = %d V debe entregar una potencia total P = %d W (I_total = %d A) "
		+ "a una plataforma elevadora.\n"
		+ "Si ya existe una rama fija R1 = %d Ohm, selecciona la resistencia R2 que debes conectar en paralelo."
	) % [voltaje_v, potencia_objetivo_w, i_objetivo_a, r1_ohm]
	lbl_enunciado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_enunciado.add_theme_font_size_override("font_size", 14)
	lbl_enunciado.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	caja_enunciado.add_child(lbl_enunciado)

	var lbl_sel_titulo := Label.new()
	lbl_sel_titulo.text = "SELECCIONA LA RESISTENCIA R2 EN PARALELO CON R1 = %d Ohm:" % r1_ohm
	lbl_sel_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sel_titulo.add_theme_font_size_override("font_size", 13)
	lbl_sel_titulo.add_theme_color_override("font_color", COLOR_CIAN)
	vbox.add_child(lbl_sel_titulo)

	var fila_opc := HBoxContainer.new()
	fila_opc.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_opc.add_theme_constant_override("separation", 12)
	vbox.add_child(fila_opc)

	botones_opcion.clear()
	for i in range(opciones_r2.size()):
		var btn := Button.new()
		btn.text = "%d Ohm" % opciones_r2[i]
		btn.custom_minimum_size = Vector2(132, 40)
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
	lbl_feedback.text = "En paralelo V = %d V es igual en ambas ramas: calcula I1 = %d/%d, luego I2 y R2." % [
		voltaje_v, voltaje_v, r1_ohm
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
		_seleccionar_opcion(mini(opciones_r2.size() - 1, indice_sel + 1))
		return true
	if kc == KEY_ENTER or kc == KEY_KP_ENTER:
		_comprobar_respuesta()
		return true
	return false


func _seleccionar_opcion(idx: int) -> void:
	if resuelto:
		return
	indice_sel = clampi(idx, 0, opciones_r2.size() - 1)
	_actualizar_ui()


func _actualizar_ui() -> void:
	var r2_sel: int = opciones_r2[indice_sel]
	var i2_calc: float = float(voltaje_v) / float(r2_sel)
	var i_tot: float = float(i1_a) + i2_calc
	var p_tot: float = float(voltaje_v) * i_tot

	for i in range(botones_opcion.size()):
		var activo := (i == indice_sel)
		var col := COLOR_VERDE if (resuelto and activo) else (COLOR_AMARILLO if activo else COLOR_CIAN)
		estilizar_boton(botones_opcion[i], col, resuelto and not activo)
		botones_opcion[i].disabled = resuelto

	lbl_lectura.text = (
		"Opción: R2 = %d Ohm  |  V = %d V, R1 = %d Ohm  |  Meta: P = %d W (%d A)"
		% [r2_sel, voltaje_v, r1_ohm, potencia_objetivo_w, i_objetivo_a]
	)
	actualizar_barra(barra_potencia, p_tot, float(potencia_objetivo_w) * 2.0, COLOR_VERDE if resuelto else COLOR_CIAN)

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

	var r2_sel: int = opciones_r2[indice_sel]
	var i2_calc: float = float(voltaje_v) / float(r2_sel)
	var i_tot: float = float(i1_a) + i2_calc
	var p_tot: float = float(voltaje_v) * i_tot

	if r2_sel == respuesta_correcta_ohm:
		resuelto = true
		subiendo = true
		pausa_actual = 0.0
		lbl_feedback.text = (
			"¡CORRECTO! Paso 1: I1 = %d / %d = %d A => falta I2 = %d - %d = %d A.\n"
			+ "Paso 2: R2 = V / I2 = %d / %d = %d Ohm => P = %d * %d = %d W.\n"
			+ "Plataforma elevadora energizada en Capa 5."
		) % [voltaje_v, r1_ohm, i1_a, i_objetivo_a, i1_a, i2_a, voltaje_v, i2_a, respuesta_correcta_ohm, voltaje_v, i_objetivo_a, potencia_objetivo_w]
		lbl_feedback.add_theme_color_override("font_color", COLOR_VERDE)
		_aplicar_estado_elevador()
		_actualizar_ui()
		return

	if p_tot > float(potencia_objetivo_w):
		lbl_feedback.text = (
			"INCORRECTO (R2 = %d Ohm): I2 = %.2f A => I_total = %.2f A y P = %.1f W (excede %d W).\n"
			+ "Pista: Como I1 = %d / %d = %d A, la segunda rama requiere I2 = %d - %d = %d A => R2 = %d / %d."
		) % [r2_sel, i2_calc, i_tot, p_tot, potencia_objetivo_w, voltaje_v, r1_ohm, i1_a, i_objetivo_a, i1_a, i2_a, voltaje_v, i2_a]
	else:
		lbl_feedback.text = (
			"INCORRECTO (R2 = %d Ohm): I2 = %.2f A => I_total = %.2f A y P = %.1f W (falta potencia para %d W).\n"
			+ "Pista: Halla I2 = I_total - I1 = %d - %d = %d A y aplica R2 = %d / %d."
		) % [r2_sel, i2_calc, i_tot, p_tot, potencia_objetivo_w, i_objetivo_a, i1_a, i2_a, voltaje_v, i2_a]
	lbl_feedback.add_theme_color_override("font_color", COLOR_ROJO)


func _aplicar_estado_elevador() -> void:
	if lbl_estado_elevador != null:
		lbl_estado_elevador.text = "%d W ACTIVO" % potencia_objetivo_w if resuelto else "SIN POTENCIA"
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
