extends "res://Codigo/Puzzles/puzzle_base.gd"

# ==============================================================================
# PUZZLE ELECTROSTÁTICA 01: EQUILIBRIO DE COULOMB (Nivel Preuniversitario UNI)
# Enunciado: q1 = +4 uC (x = 0 m), q2 = +16 uC (x = 6 m).
# Condición de equilibrio: k*q1/x^2 = k*q2/(6-x)^2  =>  x = 2 m.
# Al resolver: desactiva la barrera de plasma hija.
# ==============================================================================

const Q1_UC := 4.0
const Q2_UC := 16.0
const DISTANCIA_TOTAL := 6.0
const OPCIONES_X: Array[float] = [1.0, 2.0, 3.0, 4.0, 5.0]

@export var respuesta_correcta_m: float = 2.0

@onready var barrera_body: StaticBody2D = $BarreraPlasma
@onready var barrera_col: CollisionShape2D = $BarreraPlasma/CollisionShape2D
@onready var barrera_sprite: Sprite2D = $BarreraPlasma/Sprite2D
@onready var lbl_estado_barrera: Label = $BarreraPlasma/EstadoBarrera

var resuelto: bool = false
var indice_sel: int = 2 # Inicia en x = 3 m (no resuelto)
var tiempo_fx: float = 0.0

var botones_opcion: Array[Button] = []
var lbl_lectura: Label
var barra_equilibrio: ProgressBar
var lbl_feedback: Label
var btn_comprobar: Button


func _init() -> void:
	titulo_panel = "ELECTROSTÁTICA 01 — EQUILIBRIO DE COULOMB"
	texto_prompt = "[E] Resolver Puzzle"
	ancho_panel = 660.0


func _inicializar_puzzle() -> void:
	_aplicar_estado_barrera(true)


func _construir_contenido_panel(vbox: VBoxContainer) -> void:
	var caja_enunciado := PanelContainer.new()
	caja_enunciado.add_theme_stylebox_override("panel", crear_caja(Color(0.06, 0.11, 0.20, 0.96), COLOR_CIAN, 2, 12))
	vbox.add_child(caja_enunciado)

	var lbl_enunciado := Label.new()
	lbl_enunciado.text = (
		"ENUNCIADO (Nivel Preuniversitario):\n"
		+ "Dos cargas fijas q1 = +4 uC (x = 0 m) y q2 = +16 uC (x = 6 m) están separadas 6 m.\n"
		+ "Ubica la carga de prueba q0 en la posición x entre ambas donde la fuerza eléctrica resultante "
		+ "sea nula (k*q1/x^2 = k*q2/(6-x)^2)."
	)
	lbl_enunciado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_enunciado.add_theme_font_size_override("font_size", 14)
	lbl_enunciado.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	caja_enunciado.add_child(lbl_enunciado)

	var lbl_sel_titulo := Label.new()
	lbl_sel_titulo.text = "SELECCIONA LA POSICIÓN x DE LA CARGA DE PRUEBA q0:"
	lbl_sel_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sel_titulo.add_theme_font_size_override("font_size", 13)
	lbl_sel_titulo.add_theme_color_override("font_color", COLOR_AMARILLO)
	vbox.add_child(lbl_sel_titulo)

	var fila_opc := HBoxContainer.new()
	fila_opc.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_opc.add_theme_constant_override("separation", 10)
	vbox.add_child(fila_opc)

	botones_opcion.clear()
	for i in range(OPCIONES_X.size()):
		var btn := Button.new()
		btn.text = "x = %d m" % int(OPCIONES_X[i])
		btn.custom_minimum_size = Vector2(104, 38)
		btn.focus_mode = Control.FOCUS_NONE
		var idx_local := i
		btn.pressed.connect(func() -> void: _seleccionar_opcion(idx_local))
		fila_opc.add_child(btn)
		botones_opcion.append(btn)

	var caja_sim := PanelContainer.new()
	caja_sim.add_theme_stylebox_override("panel", crear_caja(Color(0.04, 0.08, 0.14, 0.96), Color(0.24, 0.55, 0.78), 2, 10))
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
	lbl_feedback.text = "Elige x y presiona COMPROBAR para evaluar el equilibrio de fuerzas."
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
		_seleccionar_opcion(mini(OPCIONES_X.size() - 1, indice_sel + 1))
		return true
	if kc == KEY_ENTER or kc == KEY_KP_ENTER:
		_comprobar_respuesta()
		return true
	return false


func _seleccionar_opcion(idx: int) -> void:
	if resuelto:
		return
	indice_sel = clampi(idx, 0, OPCIONES_X.size() - 1)
	_actualizar_ui()


func _actualizar_ui() -> void:
	var x_val: float = OPCIONES_X[indice_sel]
	var d2: float = DISTANCIA_TOTAL - x_val
	var f1_rel: float = Q1_UC / (x_val * x_val)
	var f2_rel: float = Q2_UC / (d2 * d2)
	var menor: float = minf(f1_rel, f2_rel)
	var mayor: float = maxf(f1_rel, f2_rel)
	var similitud: float = (menor / mayor) * 100.0 if mayor > 0.0 else 0.0

	for i in range(botones_opcion.size()):
		var activo := (i == indice_sel)
		var col := COLOR_VERDE if (resuelto and activo) else (COLOR_AMARILLO if activo else COLOR_CIAN)
		estilizar_boton(botones_opcion[i], col, resuelto and not activo)
		botones_opcion[i].disabled = resuelto

	lbl_lectura.text = (
		"x = %d m  |  q1/x^2 = %.2f   vs   q2/(6-x)^2 = %.2f  (Simetría: %.0f%%)"
		% [int(x_val), f1_rel, f2_rel, similitud]
	)
	var col_barra := COLOR_VERDE if absf(x_val - respuesta_correcta_m) < 0.01 else (COLOR_AMARILLO if similitud >= 55.0 else COLOR_ROJO)
	actualizar_barra(barra_equilibrio, similitud, 100.0, col_barra)

	if resuelto:
		btn_comprobar.text = "BARRERA DE PLASMA DESACTIVADA — CERRAR"
		estilizar_boton(btn_comprobar, COLOR_VERDE)
	else:
		btn_comprobar.text = "COMPROBAR x = %d m (ENTER)" % int(x_val)
		estilizar_boton(btn_comprobar, COLOR_CIAN)


func _comprobar_respuesta() -> void:
	if resuelto:
		cerrar_panel()
		return

	var x_val: float = OPCIONES_X[indice_sel]
	if absf(x_val - respuesta_correcta_m) < 0.01:
		resuelto = true
		lbl_feedback.text = (
			"¡CORRECTO! Raíz a ambos lados: sqrt(4)/x = sqrt(16)/(6-x) => 2/x = 4/(6-x) => 12 - 2x = 4x => x = 2 m.\n"
			+ "En x = 2 m las fuerzas se equilibran (F1 = F2). Barrera de plasma desactivada."
		)
		lbl_feedback.add_theme_color_override("font_color", COLOR_VERDE)
		_aplicar_estado_barrera(false)
		_actualizar_ui()
		return

	var d2: float = DISTANCIA_TOTAL - x_val
	var f1_rel: float = Q1_UC / (x_val * x_val)
	var f2_rel: float = Q2_UC / (d2 * d2)
	if f1_rel > f2_rel:
		lbl_feedback.text = (
			"INCORRECTO (x = %d m): q1/x^2 = %.2f > q2/(6-x)^2 = %.2f (domina q1).\n"
			+ "Pista: Aléjate un poco de q1. Extrae raíz cuadrada: 2/x = 4/(6 - x)."
		) % [int(x_val), f1_rel, f2_rel]
	else:
		lbl_feedback.text = (
			"INCORRECTO (x = %d m): q1/x^2 = %.2f < q2/(6-x)^2 = %.2f (domina q2 = +16 uC).\n"
			+ "Pista: El punto nulo siempre está más cerca de la carga de menor magnitud (q1). Plantea 2/x = 4/(6 - x)."
		) % [int(x_val), f1_rel, f2_rel]
	lbl_feedback.add_theme_color_override("font_color", COLOR_ROJO)


func _aplicar_estado_barrera(inmediato: bool) -> void:
	if barrera_col != null:
		barrera_col.set_deferred("disabled", resuelto)
	if lbl_estado_barrera != null:
		lbl_estado_barrera.text = "PLASMA OFF" if resuelto else "BARRERA ACTIVA"
		lbl_estado_barrera.add_theme_color_override("font_color", COLOR_VERDE if resuelto else COLOR_ROJO)
	if barrera_sprite != null and inmediato:
		barrera_sprite.modulate = Color(0.25, 1.0, 0.6, 0.14) if resuelto else Color(1.0, 1.0, 1.0, 1.0)


func _procesar_mundo(delta: float) -> void:
	if barrera_sprite == null:
		return
	tiempo_fx += delta
	if resuelto:
		barrera_sprite.modulate = barrera_sprite.modulate.lerp(Color(0.25, 1.0, 0.6, 0.12), minf(1.0, delta * 6.0))
	else:
		var pulso := 0.85 + 0.15 * sin(tiempo_fx * 8.0)
		barrera_sprite.modulate = Color(1.0, pulso, pulso, 0.92)
