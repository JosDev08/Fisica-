extends "res://Codigo/Puzzles/puzzle_base.gd"

# ==============================================================================
# PUZZLE PREFAB: ELECTROSTÁTICA — LEY DE COULOMB (F = k · |q1·q2| / r²)
# - Emisor superior + Esfera cargada en Capa 5 (Suelo) integrados en la escena.
# - El jugador ajusta polaridad (+ / - / 0) y carga |q1| para atraer y elevar
#   la esfera obstáculo y despejar el camino.
# ==============================================================================

const K_COULOMB: float = 9.0
const OPCIONES_R: Array[float] = [1.0, 1.5, 3.0] # 9 / r^2 = 9, 4, 1 (siempre entero exacto)
const OPCIONES_Q1: Array[float] = [2.0, 3.0, 4.0, 5.0, 6.0, 8.0]
const OPCIONES_Q2: Array[float] = [3.0, 4.0, 5.0, 6.0, 8.0]

@export var valor_objetivo: float = 96.0
@export var q_esfera: float = 6.0
@export var objetivo_aleatorio: bool = true
@export var altura_elevacion: float = 98.0

var distancia_r: float = 1.5
var polaridad_emisor: int = 1 # +1 repulsión, -1 atracción, 0 apagado
var indice_q1: int = 0
var despejado: bool = false
var _pos_esfera_inicial: Vector2 = Vector2(110, -44)

@onready var emisor_sprite: Sprite2D = $EmisorSuperior
@onready var lbl_emisor_mundo: Label = $EmisorSuperior/LblEmisor
@onready var esfera_body: StaticBody2D = $EsferaCargada
@onready var esfera_col: CollisionShape2D = $EsferaCargada/CollisionShape2D
@onready var lbl_esfera_mundo: Label = $EsferaCargada/LblEsfera
@onready var lbl_estado_mundo: Label = $LblEstadoMundo

# UI
var lbl_hud_estado: Label
var barra_fuerza: ProgressBar
var lbl_formula: Label
var lbl_q1_val: Label
var btn_pol_pos: Button
var btn_pol_neg: Button
var btn_pol_off: Button
var btn_aplicar: Button


func generar_problema() -> void:
	if objetivo_aleatorio:
		distancia_r = OPCIONES_R[randi() % OPCIONES_R.size()]
		q_esfera = OPCIONES_Q2[randi() % OPCIONES_Q2.size()]
		var q1_win: float = OPCIONES_Q1[randi_range(1, OPCIONES_Q1.size() - 1)]
		valor_objetivo = round(K_COULOMB * (q1_win * q_esfera) / (distancia_r * distancia_r))

	# Garantizar estado inicial no resuelto
	polaridad_emisor = 1
	indice_q1 = randi() % OPCIONES_Q1.size()
	var intentos := 0
	while intentos < 20 and ((polaridad_emisor == -1 and is_equal_approx(_calcular_fuerza(), valor_objetivo))):
		indice_q1 = (indice_q1 + 1) % OPCIONES_Q1.size()
		intentos += 1


func _inicializar_puzzle() -> void:
	titulo_panel = "EMISOR ELECTROSTÁTICO — LEY DE COULOMB"
	if lbl_titulo_ui != null:
		lbl_titulo_ui.text = titulo_panel
	if esfera_body != null:
		_pos_esfera_inicial = esfera_body.position
	_actualizar_estado(false)


func _construir_contenido_panel(vbox: VBoxContainer) -> void:
	var lbl_ref := Label.new()
	lbl_ref.text = "F = k · |q₁ · q₂| / r²   (Signos opuestos se atraen ↑ | Iguales se repelen ↓)"
	lbl_ref.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_ref.add_theme_font_size_override("font_size", 12)
	lbl_ref.add_theme_color_override("font_color", COLOR_CIAN)
	vbox.add_child(lbl_ref)

	lbl_hud_estado = Label.new()
	lbl_hud_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_hud_estado.add_theme_font_size_override("font_size", 16)
	vbox.add_child(lbl_hud_estado)

	barra_fuerza = ProgressBar.new()
	barra_fuerza.custom_minimum_size = Vector2(0, 18)
	barra_fuerza.show_percentage = false
	vbox.add_child(barra_fuerza)

	lbl_formula = Label.new()
	lbl_formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_formula.add_theme_font_size_override("font_size", 14)
	vbox.add_child(lbl_formula)

	# Controles de polaridad
	var hb_pol := HBoxContainer.new()
	hb_pol.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_pol.add_theme_constant_override("separation", 10)
	vbox.add_child(hb_pol)

	btn_pol_pos = Button.new()
	btn_pol_pos.text = "[1] POLO (+)"
	btn_pol_pos.custom_minimum_size = Vector2(150, 38)
	btn_pol_pos.focus_mode = Control.FOCUS_NONE
	btn_pol_pos.pressed.connect(func(): _cambiar_polaridad(1))
	hb_pol.add_child(btn_pol_pos)

	btn_pol_neg = Button.new()
	btn_pol_neg.text = "[2] POLO (-)"
	btn_pol_neg.custom_minimum_size = Vector2(150, 38)
	btn_pol_neg.focus_mode = Control.FOCUS_NONE
	btn_pol_neg.pressed.connect(func(): _cambiar_polaridad(-1))
	hb_pol.add_child(btn_pol_neg)

	btn_pol_off = Button.new()
	btn_pol_off.text = "[0] APAGADO"
	btn_pol_off.custom_minimum_size = Vector2(140, 38)
	btn_pol_off.focus_mode = Control.FOCUS_NONE
	btn_pol_off.pressed.connect(func(): _cambiar_polaridad(0))
	hb_pol.add_child(btn_pol_off)

	# Controles de magnitud |q1|
	var hb_q := HBoxContainer.new()
	hb_q.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_q.add_theme_constant_override("separation", 12)
	vbox.add_child(hb_q)

	var btn_menos := Button.new()
	btn_menos.text = "◀ [A / ←] -|q₁|"
	btn_menos.custom_minimum_size = Vector2(140, 36)
	btn_menos.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_menos, COLOR_CIAN)
	btn_menos.pressed.connect(func(): _cambiar_q1(-1))
	hb_q.add_child(btn_menos)

	lbl_q1_val = Label.new()
	lbl_q1_val.custom_minimum_size = Vector2(150, 0)
	lbl_q1_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_q1_val.add_theme_font_size_override("font_size", 16)
	lbl_q1_val.add_theme_color_override("font_color", COLOR_AMARILLO)
	hb_q.add_child(lbl_q1_val)

	var btn_mas := Button.new()
	btn_mas.text = "+|q₁| [D / →] ▶"
	btn_mas.custom_minimum_size = Vector2(140, 36)
	btn_mas.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_mas, COLOR_CIAN)
	btn_mas.pressed.connect(func(): _cambiar_q1(1))
	hb_q.add_child(btn_mas)

	btn_aplicar = Button.new()
	btn_aplicar.text = "APLICAR Y VOLVER AL NIVEL  [Enter / E]"
	btn_aplicar.custom_minimum_size = Vector2(0, 42)
	btn_aplicar.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_aplicar, COLOR_VERDE)
	btn_aplicar.pressed.connect(cerrar_panel)
	vbox.add_child(btn_aplicar)


func _al_abrir_panel() -> void:
	_actualizar_estado(false)


func _procesar_tecla_panel(kc: int) -> bool:
	match kc:
		KEY_1, KEY_KP_1:
			_cambiar_polaridad(1)
			return true
		KEY_2, KEY_KP_2:
			_cambiar_polaridad(-1)
			return true
		KEY_0, KEY_KP_0:
			_cambiar_polaridad(0)
			return true
		KEY_A, KEY_LEFT:
			_cambiar_q1(-1)
			return true
		KEY_D, KEY_RIGHT:
			_cambiar_q1(1)
			return true
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			cerrar_panel()
			return true
	return false


func _cambiar_polaridad(p: int) -> void:
	polaridad_emisor = p
	_actualizar_estado(true)


func _cambiar_q1(delta_idx: int) -> void:
	indice_q1 = clampi(indice_q1 + delta_idx, 0, OPCIONES_Q1.size() - 1)
	_actualizar_estado(true)


func _calcular_fuerza() -> float:
	if polaridad_emisor == 0:
		return 0.0
	var q1: float = OPCIONES_Q1[indice_q1]
	return round(K_COULOMB * (q1 * q_esfera) / (distancia_r * distancia_r))


func _actualizar_estado(animar: bool) -> void:
	var q1: float = OPCIONES_Q1[indice_q1]
	var fuerza: float = _calcular_fuerza()
	var era_despejado := despejado
	despejado = (polaridad_emisor == -1) and is_equal_approx(fuerza, valor_objetivo)

	var col_estado: Color = COLOR_VERDE if despejado else (COLOR_ROJO if polaridad_emisor == 1 or fuerza > valor_objetivo else COLOR_AMARILLO)

	if lbl_hud_estado != null:
		var dir_txt := "↑ ATRACCIÓN" if polaridad_emisor == -1 else ("↓ REPULSIÓN" if polaridad_emisor == 1 else "APAGADO")
		lbl_hud_estado.text = "OBJETIVO: %.0f N (↑)   |   ACTUAL: %.0f N (%s)" % [valor_objetivo, fuerza, dir_txt]
		lbl_hud_estado.add_theme_color_override("font_color", col_estado)
		actualizar_barra(barra_fuerza, fuerza if polaridad_emisor == -1 else 0.0, valor_objetivo * 1.5, col_estado)

		var signo_txt := "-" if polaridad_emisor == -1 else ("+" if polaridad_emisor == 1 else "0")
		lbl_q1_val.text = "q₁ = %s%.0f µC" % [signo_txt, q1 if polaridad_emisor != 0 else 0.0]
		lbl_formula.text = "F = 9 · |%.0f × +%.0f| / %.1f² = %.0f N" % [q1 if polaridad_emisor != 0 else 0.0, q_esfera, distancia_r, fuerza]
		lbl_formula.add_theme_color_override("font_color", col_estado)

		estilizar_boton(btn_pol_pos, COLOR_ROJO if polaridad_emisor == 1 else Color(0.45, 0.5, 0.58))
		estilizar_boton(btn_pol_neg, COLOR_CIAN if polaridad_emisor == -1 else Color(0.45, 0.5, 0.58))
		estilizar_boton(btn_pol_off, COLOR_AMARILLO if polaridad_emisor == 0 else Color(0.45, 0.5, 0.58))

	# Actualizar visuales del mundo
	if lbl_esfera_mundo != null:
		lbl_esfera_mundo.text = "q₂ = +%.0f µC" % q_esfera
	if emisor_sprite != null:
		emisor_sprite.modulate = Color(0.3, 0.9, 1.0) if polaridad_emisor == -1 else (Color(1.0, 0.35, 0.35) if polaridad_emisor == 1 else Color(0.7, 0.75, 0.8))
	if lbl_emisor_mundo != null:
		lbl_emisor_mundo.text = "q₁ = %s%.0f µC" % ["-" if polaridad_emisor == -1 else ("+" if polaridad_emisor == 1 else ""), q1 if polaridad_emisor != 0 else 0.0]
	if lbl_estado_mundo != null:
		lbl_estado_mundo.text = "PASO DESPEJADO (%.0f N ↑)" % fuerza if despejado else "OBJETIVO: %.0f N ↑" % valor_objetivo
		lbl_estado_mundo.add_theme_color_override("font_color", COLOR_VERDE if despejado else COLOR_AMARILLO)

	if esfera_body != null:
		var destino := _pos_esfera_inicial - Vector2(0.0, altura_elevacion) if despejado else _pos_esfera_inicial
		if animar and era_despejado != despejado and is_inside_tree():
			var tw := create_tween()
			tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_property(esfera_body, "position", destino, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			esfera_body.position = destino
		if esfera_col != null:
			esfera_col.set_deferred("disabled", despejado)
