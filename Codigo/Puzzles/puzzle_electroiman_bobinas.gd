extends "res://Codigo/Puzzles/puzzle_base.gd"

# ==============================================================================
# PUZZLE PREFAB: ELECTROIMÁN Y BOBINAS (B = 0.002 · N · I)
# - Terminal en (0, 0) + ElectroimanSuperior + PuenteElectroiman (Capa 5 Suelo)
#   + BarreraMagnetica visibles en el editor 2D.
# - El jugador calibra Sentido (Horario=N / Antihorario=S), Espiras N y Corriente I
#   para atraer y alinear el puente metálico sin sobrecarga magnética.
# ==============================================================================

const FACTOR_MU: float = 0.001
const OPCIONES_N: Array[int] = [100, 150, 200, 250, 300]
const OPCIONES_I: Array[float] = [2.0, 4.0, 6.0, 8.0, 10.0]

@export var valor_objetivo: float = 1.20
@export var limite_sobrecarga: float = 1.35
@export var objetivo_aleatorio: bool = true
@export var altura_elevacion: float = 60.0

var idx_n: int = 1      # 150 esp
var idx_i: int = 1      # 4.0 A -> 0.60 T inicial
var sentido: int = 1    # 1 = Horario (Polo N abajo -> Repulsión), -1 = Antihorario (Polo S abajo -> Atracción)
var puente_alineado: bool = false
var _pos_puente_alineado: Vector2 = Vector2(142, 8)

@onready var electroiman_sprite: Sprite2D = $ElectroimanSuperior
@onready var puente_body: StaticBody2D = $PuenteElectroiman
@onready var puente_col: CollisionShape2D = $PuenteElectroiman/CollisionShape2D
@onready var puente_sprite: Sprite2D = $PuenteElectroiman/Sprite2D
@onready var barrera_body: StaticBody2D = $BarreraMagnetica
@onready var barrera_col: CollisionShape2D = $BarreraMagnetica/CollisionShape2D
@onready var lbl_estado_mundo: Label = $LblEstadoPuente

# UI
var lbl_hud_estado: Label
var barra_b: ProgressBar
var lbl_formula: Label
var lbl_n_val: Label
var lbl_i_val: Label
var btn_horario: Button
var btn_antihorario: Button


func generar_problema() -> void:
	if objetivo_aleatorio:
		var n_w: int = OPCIONES_N[randi_range(1, OPCIONES_N.size() - 1)]
		var i_w: float = OPCIONES_I[randi_range(1, OPCIONES_I.size() - 1)]
		valor_objetivo = snappedf(FACTOR_MU * float(n_w) * i_w, 0.01)
		limite_sobrecarga = snappedf(valor_objetivo + 0.15, 0.01)

	sentido = 1
	idx_n = randi() % OPCIONES_N.size()
	idx_i = randi() % OPCIONES_I.size()
	var intentos := 0
	while intentos < 30 and (is_equal_approx(_calcular_b(), valor_objetivo) or _calcular_b() > limite_sobrecarga):
		idx_n = randi() % OPCIONES_N.size()
		idx_i = randi() % OPCIONES_I.size()
		intentos += 1


func _inicializar_puzzle() -> void:
	titulo_panel = "ELECTROIMÁN — CAMPO MAGNÉTICO (LEY DE AMPÈRE)"
	if lbl_titulo_ui != null:
		lbl_titulo_ui.text = titulo_panel
	if puente_body != null:
		_pos_puente_alineado = puente_body.position
	_actualizar_estado(false)


func _construir_contenido_panel(vbox: VBoxContainer) -> void:
	var lbl_ref := Label.new()
	lbl_ref.text = "B = 0.001 × N × I   (El puente es Polo N: requiere Polo S [Antihorario] para atracción ↑)"
	lbl_ref.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_ref.add_theme_font_size_override("font_size", 12)
	lbl_ref.add_theme_color_override("font_color", COLOR_CIAN)
	vbox.add_child(lbl_ref)

	lbl_hud_estado = Label.new()
	lbl_hud_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_hud_estado.add_theme_font_size_override("font_size", 16)
	vbox.add_child(lbl_hud_estado)

	barra_b = ProgressBar.new()
	barra_b.custom_minimum_size = Vector2(0, 18)
	barra_b.show_percentage = false
	vbox.add_child(barra_b)

	lbl_formula = Label.new()
	lbl_formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_formula.add_theme_font_size_override("font_size", 14)
	vbox.add_child(lbl_formula)

	# Sentido de corriente
	var hb_s := HBoxContainer.new()
	hb_s.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_s.add_theme_constant_override("separation", 12)
	vbox.add_child(hb_s)

	btn_horario = Button.new()
	btn_horario.text = "[1] HORARIO (Polo N ↓)"
	btn_horario.custom_minimum_size = Vector2(220, 36)
	btn_horario.focus_mode = Control.FOCUS_NONE
	btn_horario.pressed.connect(func():
		sentido = 1
		_actualizar_estado(true)
	)
	hb_s.add_child(btn_horario)

	btn_antihorario = Button.new()
	btn_antihorario.text = "[2] ANTIHORARIO (Polo S ↑)"
	btn_antihorario.custom_minimum_size = Vector2(220, 36)
	btn_antihorario.focus_mode = Control.FOCUS_NONE
	btn_antihorario.pressed.connect(func():
		sentido = -1
		_actualizar_estado(true)
	)
	hb_s.add_child(btn_antihorario)

	# Espiras N
	var hb_n := HBoxContainer.new()
	hb_n.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_n.add_theme_constant_override("separation", 12)
	vbox.add_child(hb_n)

	var btn_nm := Button.new()
	btn_nm.text = "◀ [S / ↓] -Espiras N"
	btn_nm.custom_minimum_size = Vector2(150, 34)
	btn_nm.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_nm, COLOR_CIAN)
	btn_nm.pressed.connect(func(): _ajustar_n(-1))
	hb_n.add_child(btn_nm)

	lbl_n_val = Label.new()
	lbl_n_val.custom_minimum_size = Vector2(140, 0)
	lbl_n_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_n_val.add_theme_font_size_override("font_size", 15)
	hb_n.add_child(lbl_n_val)

	var btn_np := Button.new()
	btn_np.text = "+Espiras N [W / ↑] ▶"
	btn_np.custom_minimum_size = Vector2(150, 34)
	btn_np.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_np, COLOR_CIAN)
	btn_np.pressed.connect(func(): _ajustar_n(1))
	hb_n.add_child(btn_np)

	# Corriente I
	var hb_i := HBoxContainer.new()
	hb_i.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_i.add_theme_constant_override("separation", 12)
	vbox.add_child(hb_i)

	var btn_im := Button.new()
	btn_im.text = "◀ [A / ←] -Corriente I"
	btn_im.custom_minimum_size = Vector2(150, 34)
	btn_im.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_im, COLOR_AMARILLO)
	btn_im.pressed.connect(func(): _ajustar_i(-1))
	hb_i.add_child(btn_im)

	lbl_i_val = Label.new()
	lbl_i_val.custom_minimum_size = Vector2(140, 0)
	lbl_i_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_i_val.add_theme_font_size_override("font_size", 15)
	hb_i.add_child(lbl_i_val)

	var btn_ip := Button.new()
	btn_ip.text = "+Corriente I [D / →] ▶"
	btn_ip.custom_minimum_size = Vector2(150, 34)
	btn_ip.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_ip, COLOR_AMARILLO)
	btn_ip.pressed.connect(func(): _ajustar_i(1))
	hb_i.add_child(btn_ip)

	var btn_ok := Button.new()
	btn_ok.text = "APLICAR Y VOLVER AL NIVEL  [Enter / E]"
	btn_ok.custom_minimum_size = Vector2(0, 40)
	btn_ok.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_ok, COLOR_VERDE)
	btn_ok.pressed.connect(cerrar_panel)
	vbox.add_child(btn_ok)


func _al_abrir_panel() -> void:
	_actualizar_estado(false)


func _procesar_tecla_panel(kc: int) -> bool:
	match kc:
		KEY_1, KEY_KP_1:
			sentido = 1
			_actualizar_estado(true)
			return true
		KEY_2, KEY_KP_2:
			sentido = -1
			_actualizar_estado(true)
			return true
		KEY_S, KEY_DOWN:
			_ajustar_n(-1)
			return true
		KEY_W, KEY_UP:
			_ajustar_n(1)
			return true
		KEY_A, KEY_LEFT:
			_ajustar_i(-1)
			return true
		KEY_D, KEY_RIGHT:
			_ajustar_i(1)
			return true
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			cerrar_panel()
			return true
	return false


func _ajustar_n(d: int) -> void:
	idx_n = clampi(idx_n + d, 0, OPCIONES_N.size() - 1)
	_actualizar_estado(true)


func _ajustar_i(d: int) -> void:
	idx_i = clampi(idx_i + d, 0, OPCIONES_I.size() - 1)
	_actualizar_estado(true)


func _calcular_b() -> float:
	return FACTOR_MU * float(OPCIONES_N[idx_n]) * OPCIONES_I[idx_i]


func _actualizar_estado(animar: bool) -> void:
	var n := OPCIONES_N[idx_n]
	var i_val := OPCIONES_I[idx_i]
	var b := _calcular_b()
	var sobrecarga := b > limite_sobrecarga
	var era_alineado := puente_alineado
	puente_alineado = (sentido == -1) and is_equal_approx(b, valor_objetivo) and not sobrecarga

	var col: Color = COLOR_VERDE if puente_alineado else (COLOR_ROJO if (sobrecarga or sentido == 1) else COLOR_AMARILLO)

	if lbl_hud_estado != null:
		var estado_txt := "¡PUENTE ALINEADO!" if puente_alineado else ("SOBRECARGA" if sobrecarga else ("REPULSIÓN" if sentido == 1 else "ATRACCIÓN"))
		lbl_hud_estado.text = "OBJETIVO: %.2f T (Polo S)   |   ACTUAL: %.2f T (%s)" % [valor_objetivo, b, estado_txt]
		lbl_hud_estado.add_theme_color_override("font_color", col)
		actualizar_barra(barra_b, b, limite_sobrecarga * 1.6, col)
		lbl_n_val.text = "N = %d esp" % n
		lbl_i_val.text = "I = %.1f A" % i_val
		lbl_formula.text = "B = 0.001 × %d × %.1f A = %.2f T" % [n, i_val, b]
		lbl_formula.add_theme_color_override("font_color", col)

		estilizar_boton(btn_horario, COLOR_ROJO if sentido == 1 else Color(0.42, 0.48, 0.56))
		estilizar_boton(btn_antihorario, COLOR_CIAN if sentido == -1 else Color(0.42, 0.48, 0.56))

	if electroiman_sprite != null:
		electroiman_sprite.modulate = Color(0.35, 1.0, 0.65) if puente_alineado else (Color(1.0, 0.35, 0.35) if sentido == 1 else Color(0.35, 0.85, 1.0))

	if puente_body != null:
		var destino := _pos_puente_alineado if puente_alineado else (_pos_puente_alineado + Vector2(0.0, altura_elevacion))
		if animar and era_alineado != puente_alineado and is_inside_tree():
			var tw := create_tween()
			tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_property(puente_body, "position", destino, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			puente_body.position = destino
		if puente_col != null:
			puente_col.set_deferred("disabled", not puente_alineado)
		if puente_sprite != null:
			puente_sprite.modulate = Color(0.35, 1.0, 0.65, 1.0) if puente_alineado else Color(0.8, 0.45, 0.35, 0.55)

	if barrera_body != null:
		barrera_body.visible = not puente_alineado
		if barrera_col != null:
			barrera_col.set_deferred("disabled", puente_alineado)

	if lbl_estado_mundo != null:
		lbl_estado_mundo.text = "PUENTE MAGNÉTICO ALINEADO (%.2f T)" % valor_objetivo if puente_alineado else "PUENTE CAÍDO (Meta: %.2f T Polo S)" % valor_objetivo
		lbl_estado_mundo.add_theme_color_override("font_color", COLOR_VERDE if puente_alineado else COLOR_AMARILLO)
