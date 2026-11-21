extends "res://Codigo/Puzzles/puzzle_base.gd"

# ==============================================================================
# PUZZLE PREFAB: ELECTRODINÁMICA — LEY DE OHM (I = V / R) Y FUSIBLE
# - Incluye PuenteOhm (Capa 5 Suelo) y BarreraAbismo visibles en el editor 2D.
# - Si I supera el límite del fusible, se quema y debe reemplazarse.
# ==============================================================================

const VOLTAJES: Array[float] = [12.0, 18.0, 24.0, 36.0, 48.0, 60.0]
const RESISTENCIAS: Array[float] = [2.0, 3.0, 4.0, 6.0, 8.0, 12.0]

@export var valor_objetivo: float = 4.0
@export var factor_fusible: float = 1.5
@export var objetivo_aleatorio: bool = true
@export var offset_puente_apagado: Vector2 = Vector2(0, 84)

var idx_v: int = 2
var idx_r: int = 4
var fusible_quemado: bool = false
var puente_activo: bool = false
var _pos_puente_activo: Vector2 = Vector2(139, 10)

@onready var puente_body: StaticBody2D = $PuenteOhm
@onready var puente_col: CollisionShape2D = $PuenteOhm/CollisionShape2D
@onready var puente_sprite: Sprite2D = $PuenteOhm/Sprite2D
@onready var barrera_body: StaticBody2D = $BarreraAbismo
@onready var barrera_col: CollisionShape2D = $BarreraAbismo/CollisionShape2D
@onready var lbl_estado_puente: Label = $LblEstadoPuente

# UI
var lbl_hud_estado: Label
var barra_corriente: ProgressBar
var lbl_formula: Label
var lbl_v_val: Label
var lbl_r_val: Label
var btn_fusible: Button


func generar_problema() -> void:
	if objetivo_aleatorio:
		var candidatas: Array[float] = []
		for v_c in VOLTAJES:
			for r_c in RESISTENCIAS:
				var i_c: float = v_c / r_c
				if is_zero_approx(fmod(v_c * 2.0, r_c)) and i_c >= 2.0 and i_c <= 15.0:
					if not candidatas.has(i_c):
						candidatas.append(i_c)
		if not candidatas.is_empty():
			valor_objetivo = candidatas[randi() % candidatas.size()]

	var lim := _limite_fusible()
	idx_v = randi_range(0, VOLTAJES.size() - 1)
	idx_r = randi_range(0, RESISTENCIAS.size() - 1)
	var intentos := 0
	while intentos < 40 and (is_equal_approx(_corriente(), valor_objetivo) or _corriente() > lim):
		idx_v = randi_range(0, VOLTAJES.size() - 1)
		idx_r = randi_range(0, RESISTENCIAS.size() - 1)
		intentos += 1

	fusible_quemado = false
	puente_activo = false


func _inicializar_puzzle() -> void:
	titulo_panel = "PUENTE DE OHM — CORRIENTE I = V / R"
	if lbl_titulo_ui != null:
		lbl_titulo_ui.text = titulo_panel
	if puente_body != null:
		_pos_puente_activo = puente_body.position
	_actualizar_circuito(false)


func _construir_contenido_panel(vbox: VBoxContainer) -> void:
	var lbl_ref := Label.new()
	lbl_ref.text = "I = V / R   (No superes el límite del fusible o se fundirá el circuito)"
	lbl_ref.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_ref.add_theme_font_size_override("font_size", 12)
	lbl_ref.add_theme_color_override("font_color", COLOR_CIAN)
	vbox.add_child(lbl_ref)

	lbl_hud_estado = Label.new()
	lbl_hud_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_hud_estado.add_theme_font_size_override("font_size", 16)
	vbox.add_child(lbl_hud_estado)

	barra_corriente = ProgressBar.new()
	barra_corriente.custom_minimum_size = Vector2(0, 18)
	barra_corriente.show_percentage = false
	vbox.add_child(barra_corriente)

	lbl_formula = Label.new()
	lbl_formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_formula.add_theme_font_size_override("font_size", 14)
	vbox.add_child(lbl_formula)

	# Voltaje V
	var hb_v := HBoxContainer.new()
	hb_v.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_v.add_theme_constant_override("separation", 12)
	vbox.add_child(hb_v)

	var btn_v_m := Button.new()
	btn_v_m.text = "◀ [Q / ↓] -Voltaje"
	btn_v_m.custom_minimum_size = Vector2(150, 34)
	btn_v_m.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_v_m, COLOR_AMARILLO)
	btn_v_m.pressed.connect(func(): _ajustar_v(-1))
	hb_v.add_child(btn_v_m)

	lbl_v_val = Label.new()
	lbl_v_val.custom_minimum_size = Vector2(130, 0)
	lbl_v_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_v_val.add_theme_font_size_override("font_size", 15)
	hb_v.add_child(lbl_v_val)

	var btn_v_p := Button.new()
	btn_v_p.text = "+Voltaje [W / ↑] ▶"
	btn_v_p.custom_minimum_size = Vector2(150, 34)
	btn_v_p.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_v_p, COLOR_AMARILLO)
	btn_v_p.pressed.connect(func(): _ajustar_v(1))
	hb_v.add_child(btn_v_p)

	# Resistencia R
	var hb_r := HBoxContainer.new()
	hb_r.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_r.add_theme_constant_override("separation", 12)
	vbox.add_child(hb_r)

	var btn_r_m := Button.new()
	btn_r_m.text = "◀ [A / ←] -Resistencia"
	btn_r_m.custom_minimum_size = Vector2(150, 34)
	btn_r_m.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_r_m, COLOR_CIAN)
	btn_r_m.pressed.connect(func(): _ajustar_r(-1))
	hb_r.add_child(btn_r_m)

	lbl_r_val = Label.new()
	lbl_r_val.custom_minimum_size = Vector2(130, 0)
	lbl_r_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_r_val.add_theme_font_size_override("font_size", 15)
	hb_r.add_child(lbl_r_val)

	var btn_r_p := Button.new()
	btn_r_p.text = "+Resistencia [D / →] ▶"
	btn_r_p.custom_minimum_size = Vector2(150, 34)
	btn_r_p.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_r_p, COLOR_CIAN)
	btn_r_p.pressed.connect(func(): _ajustar_r(1))
	hb_r.add_child(btn_r_p)

	btn_fusible = Button.new()
	btn_fusible.text = "REEMPLAZAR FUSIBLE QUEMADO  [R]"
	btn_fusible.custom_minimum_size = Vector2(0, 38)
	btn_fusible.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_fusible, COLOR_ROJO)
	btn_fusible.visible = false
	btn_fusible.pressed.connect(_reemplazar_fusible)
	vbox.add_child(btn_fusible)

	var btn_ok := Button.new()
	btn_ok.text = "APLICAR Y VOLVER AL NIVEL  [Enter / E]"
	btn_ok.custom_minimum_size = Vector2(0, 40)
	btn_ok.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_ok, COLOR_VERDE)
	btn_ok.pressed.connect(cerrar_panel)
	vbox.add_child(btn_ok)


func _al_abrir_panel() -> void:
	_actualizar_circuito(false)


func _procesar_tecla_panel(kc: int) -> bool:
	match kc:
		KEY_Q, KEY_DOWN:
			_ajustar_v(-1)
			return true
		KEY_W, KEY_UP:
			_ajustar_v(1)
			return true
		KEY_A, KEY_LEFT:
			_ajustar_r(-1)
			return true
		KEY_D, KEY_RIGHT:
			_ajustar_r(1)
			return true
		KEY_R:
			if fusible_quemado:
				_reemplazar_fusible()
			return true
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			cerrar_panel()
			return true
	return false


func _limite_fusible() -> float:
	return valor_objetivo * factor_fusible


func _corriente() -> float:
	return VOLTAJES[idx_v] / RESISTENCIAS[idx_r]


func _ajustar_v(d: int) -> void:
	if fusible_quemado:
		return
	idx_v = clampi(idx_v + d, 0, VOLTAJES.size() - 1)
	_actualizar_circuito(true)


func _ajustar_r(d: int) -> void:
	if fusible_quemado:
		return
	idx_r = clampi(idx_r + d, 0, RESISTENCIAS.size() - 1)
	_actualizar_circuito(true)


func _reemplazar_fusible() -> void:
	fusible_quemado = false
	idx_v = 0
	idx_r = RESISTENCIAS.size() - 1
	_actualizar_circuito(true)


func _actualizar_circuito(animar: bool) -> void:
	var v: float = VOLTAJES[idx_v]
	var r: float = RESISTENCIAS[idx_r]
	var lim: float = _limite_fusible()
	var i_val: float = _corriente()

	if i_val > lim + 0.01:
		fusible_quemado = true

	var era_activo := puente_activo
	puente_activo = (not fusible_quemado) and is_equal_approx(i_val, valor_objetivo)
	var col: Color = COLOR_ROJO if fusible_quemado else (COLOR_VERDE if puente_activo else COLOR_AMARILLO)

	if lbl_hud_estado != null:
		if fusible_quemado:
			lbl_hud_estado.text = "¡FUSIBLE QUEMADO! (Superó %.1f A) — Reemplaza el fusible [R]" % lim
		else:
			lbl_hud_estado.text = "OBJETIVO: %.1f A (Máx %.1f A)   |   ACTUAL: %.1f A" % [valor_objetivo, lim, i_val]
		lbl_hud_estado.add_theme_color_override("font_color", col)
		actualizar_barra(barra_corriente, 0.0 if fusible_quemado else i_val, lim, col)
		lbl_v_val.text = "V = %.0f V" % v
		lbl_r_val.text = "R = %.0f Ω" % r
		lbl_formula.text = "I = V / R = %.0f V / %.0f Ω = %.1f A" % [v, r, i_val]
		lbl_formula.add_theme_color_override("font_color", col)
		btn_fusible.visible = fusible_quemado

	if puente_body != null:
		var destino := _pos_puente_activo if puente_activo else (_pos_puente_activo + offset_puente_apagado)
		if animar and era_activo != puente_activo and is_inside_tree():
			var tw := create_tween()
			tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_property(puente_body, "position", destino, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			puente_body.position = destino
		if puente_col != null:
			puente_col.set_deferred("disabled", not puente_activo)
		if puente_sprite != null:
			puente_sprite.modulate = Color(0.35, 1.0, 0.65, 1.0) if puente_activo else Color(0.75, 0.35, 0.35, 0.45)

	if barrera_body != null:
		barrera_body.visible = not puente_activo
		if barrera_col != null:
			barrera_col.set_deferred("disabled", puente_activo)

	if lbl_estado_puente != null:
		if puente_activo:
			lbl_estado_puente.text = "PUENTE ENERGIZADO (%.1f A)" % valor_objetivo
			lbl_estado_puente.add_theme_color_override("font_color", COLOR_VERDE)
		elif fusible_quemado:
			lbl_estado_puente.text = "FUSIBLE QUEMADO"
			lbl_estado_puente.add_theme_color_override("font_color", COLOR_ROJO)
		else:
			lbl_estado_puente.text = "PUENTE APAGADO (Meta: %.1f A)" % valor_objetivo
			lbl_estado_puente.add_theme_color_override("font_color", COLOR_AMARILLO)
