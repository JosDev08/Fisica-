extends "res://Codigo/Puzzles/puzzle_base.gd"

# ==============================================================================
# PUZZLE ELECTROSTÁTICA 01: EQUILIBRIO DE COULOMB (Nivel Preuniversitario UNI)
# Fórmula destacada: k * q1 / x^2 = k * q2 / (L - x)^2
# Genera q1, q2 (razón de cuadrados exactos) y separación L aleatorios para que
# x sea siempre un entero exacto, con 3 distractores realistas y opciones.shuffle().
# Al resolver: desactiva la barrera de plasma hija en Capa 5 (Suelo).
# ==============================================================================

# Razones [a, b] donde sqrt(q1):sqrt(q2) = a:b => x = a * paso, L = (a + b) * paso
const RAZONES_RAIZ: Array = [
	[1, 2],
	[1, 3],
	[2, 3],
	[1, 4],
]
const ESCALAS_CARGA: Array[int] = [1, 2, 4]
const PASOS_DIST: Array[int] = [2, 3]

@export var respuesta_correcta_m: float = 2.0

@onready var barrera_body: StaticBody2D = $BarreraPlasma
@onready var barrera_col: CollisionShape2D = $BarreraPlasma/CollisionShape2D
@onready var barrera_sprite: Sprite2D = $BarreraPlasma/Sprite2D
@onready var lbl_estado_barrera: Label = $BarreraPlasma/EstadoBarrera

var q1_uc: int = 4
var q2_uc: int = 16
var raiz_a: int = 1
var raiz_b: int = 2
var distancia_total_m: int = 6
var respuesta_correcta_int: int = 2
var opciones_x: Array[int] = []

var resuelto: bool = false
var indice_sel: int = 0
var tiempo_fx: float = 0.0

var lbl_enunciado: Label
var botones_opcion: Array[Button] = []
var lbl_lectura: Label
var barra_equilibrio: ProgressBar
var lbl_feedback: Label
var btn_comprobar: Button


func _init() -> void:
	titulo_panel = "ELECTROSTÁTICA 01 — EQUILIBRIO DE COULOMB"
	texto_prompt = "[E] Resolver Puzzle"
	ancho_panel = 680.0


func generar_problema() -> void:
	var par: Array = RAZONES_RAIZ[randi() % RAZONES_RAIZ.size()]
	var escala: int = ESCALAS_CARGA[randi() % ESCALAS_CARGA.size()]
	var paso: int = PASOS_DIST[randi() % PASOS_DIST.size()]

	raiz_a = int(par[0])
	raiz_b = int(par[1])
	# Aleatoriamente decide si la carga menor está a la izquierda o a la derecha
	if randi() % 2 == 1:
		var tmp := raiz_a
		raiz_a = raiz_b
		raiz_b = tmp

	q1_uc = raiz_a * raiz_a * escala
	q2_uc = raiz_b * raiz_b * escala
	distancia_total_m = (raiz_a + raiz_b) * paso
	respuesta_correcta_int = raiz_a * paso
	respuesta_correcta_m = float(respuesta_correcta_int)

	# 3 distractores típicos dentro de (0, L): simétrico (L - x), punto medio (L / 2), desplazamiento +/- 1
	var d_simetrico: int = distancia_total_m - respuesta_correcta_int
	var d_medio: int = maxi(1, int(round(float(distancia_total_m) / 2.0)))
	var d_mas: int = mini(distancia_total_m - 1, respuesta_correcta_int + 1)
	var d_menos: int = maxi(1, respuesta_correcta_int - 1)

	opciones_x = construir_opciones_int(
		respuesta_correcta_int,
		[d_simetrico, d_medio, d_mas, d_menos],
		1,
		distancia_total_m - 1,
		1
	)
	indice_sel = indice_inicial_no_correcto(opciones_x, respuesta_correcta_int)


func _inicializar_puzzle() -> void:
	_aplicar_estado_barrera(true)


func _construir_contenido_panel(vbox: VBoxContainer) -> void:
	var caja_formula := PanelContainer.new()
	caja_formula.add_theme_stylebox_override("panel", crear_caja(Color(0.08, 0.14, 0.24, 0.98), COLOR_AMARILLO, 2, 10))
	vbox.add_child(caja_formula)

	var lbl_formula := Label.new()
	lbl_formula.text = "FÓRMULA:   k * q1 / x^2 = k * q2 / (L - x)^2   =>   sqrt(q1) / x = sqrt(q2) / (L - x)"
	lbl_formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_formula.add_theme_font_size_override("font_size", 15)
	lbl_formula.add_theme_color_override("font_color", COLOR_AMARILLO)
	lbl_formula.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_formula.add_theme_constant_override("outline_size", 3)
	caja_formula.add_child(lbl_formula)

	var caja_enunciado := PanelContainer.new()
	caja_enunciado.add_theme_stylebox_override("panel", crear_caja(Color(0.06, 0.11, 0.20, 0.96), COLOR_CIAN, 2, 12))
	vbox.add_child(caja_enunciado)

	lbl_enunciado = Label.new()
	lbl_enunciado.text = (
		"ENUNCIADO (Nivel Preuniversitario):\n"
		+ "Dos cargas fijas q1 = +%d uC (x = 0 m) y q2 = +%d uC (x = %d m) están separadas L = %d m.\n"
		+ "Ubica la carga de prueba q0 en la posición x entre ambas donde la fuerza eléctrica resultante "
		+ "sea nula (k*q1/x^2 = k*q2/(%d-x)^2)."
	) % [q1_uc, q2_uc, distancia_total_m, distancia_total_m, distancia_total_m]
	lbl_enunciado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_enunciado.add_theme_font_size_override("font_size", 14)
	lbl_enunciado.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	caja_enunciado.add_child(lbl_enunciado)

	var lbl_sel_titulo := Label.new()
	lbl_sel_titulo.text = "SELECCIONA LA POSICIÓN x DE LA CARGA DE PRUEBA q0:"
	lbl_sel_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sel_titulo.add_theme_font_size_override("font_size", 13)
	lbl_sel_titulo.add_theme_color_override("font_color", COLOR_CIAN)
	vbox.add_child(lbl_sel_titulo)

	var fila_opc := HBoxContainer.new()
	fila_opc.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_opc.add_theme_constant_override("separation", 12)
	vbox.add_child(fila_opc)

	botones_opcion.clear()
	for i in range(opciones_x.size()):
		var btn := Button.new()
		btn.text = "x = %d m" % opciones_x[i]
		btn.custom_minimum_size = Vector2(132, 40)
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
		_seleccionar_opcion(mini(opciones_x.size() - 1, indice_sel + 1))
		return true
	if kc == KEY_ENTER or kc == KEY_KP_ENTER:
		_comprobar_respuesta()
		return true
	return false


func _seleccionar_opcion(idx: int) -> void:
	if resuelto:
		return
	indice_sel = clampi(idx, 0, opciones_x.size() - 1)
	_actualizar_ui()


func _actualizar_ui() -> void:
	var x_val: int = opciones_x[indice_sel]
	var d2: float = float(distancia_total_m - x_val)
	var f1_rel: float = float(q1_uc) / (float(x_val) * float(x_val))
	var f2_rel: float = float(q2_uc) / (d2 * d2)
	var menor: float = minf(f1_rel, f2_rel)
	var mayor: float = maxf(f1_rel, f2_rel)
	var similitud: float = (menor / mayor) * 100.0 if mayor > 0.0 else 0.0

	for i in range(botones_opcion.size()):
		var activo := (i == indice_sel)
		var col := COLOR_VERDE if (resuelto and activo) else (COLOR_AMARILLO if activo else COLOR_CIAN)
		estilizar_boton(botones_opcion[i], col, resuelto and not activo)
		botones_opcion[i].disabled = resuelto

	lbl_lectura.text = (
		"Opción: x = %d m  |  Distancias: d1 = %d m, d2 = %d m  (q1 = +%d uC, q2 = +%d uC)"
		% [x_val, x_val, distancia_total_m - x_val, q1_uc, q2_uc]
	)
	actualizar_barra(barra_equilibrio, 100.0 if resuelto else similitud, 100.0, COLOR_VERDE if resuelto else COLOR_CIAN)

	if resuelto:
		btn_comprobar.text = "BARRERA DE PLASMA DESACTIVADA — CERRAR"
		estilizar_boton(btn_comprobar, COLOR_VERDE)
	else:
		btn_comprobar.text = "COMPROBAR x = %d m (ENTER)" % x_val
		estilizar_boton(btn_comprobar, COLOR_CIAN)


func _comprobar_respuesta() -> void:
	if resuelto:
		cerrar_panel()
		return

	var x_val: int = opciones_x[indice_sel]
	var d2: int = distancia_total_m - x_val
	var f1_rel: float = float(q1_uc) / float(x_val * x_val)
	var f2_rel: float = float(q2_uc) / float(d2 * d2)

	if x_val == respuesta_correcta_int:
		resuelto = true
		lbl_feedback.text = (
			"¡CORRECTO! Raíz a ambos lados: %d/x = %d/(%d - x) => %d*(%d - x) = %d*x => x = %d m.\n"
			+ "En x = %d m, q1/x^2 = q2/(%d-x)^2 = %.2f y la fuerza resultante es nula. Barrera desactivada."
		) % [raiz_a, raiz_b, distancia_total_m, raiz_a, distancia_total_m, raiz_b, respuesta_correcta_int, respuesta_correcta_int, distancia_total_m, f1_rel]
		lbl_feedback.add_theme_color_override("font_color", COLOR_VERDE)
		_aplicar_estado_barrera(false)
		_actualizar_ui()
		return

	if f1_rel > f2_rel:
		lbl_feedback.text = (
			"INCORRECTO (x = %d m): q1/x^2 = %.2f > q2/(%d-x)^2 = %.2f (domina q1).\n"
			+ "Pista: Aléjate de q1 y plantea la proporción %d/x = %d/(%d - x)."
		) % [x_val, f1_rel, distancia_total_m, f2_rel, raiz_a, raiz_b, distancia_total_m]
	else:
		lbl_feedback.text = (
			"INCORRECTO (x = %d m): q1/x^2 = %.2f < q2/(%d-x)^2 = %.2f (domina q2).\n"
			+ "Pista: El punto de equilibrio está más cerca de la carga menor. Plantea %d/x = %d/(%d - x)."
		) % [x_val, f1_rel, distancia_total_m, f2_rel, raiz_a, raiz_b, distancia_total_m]
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
