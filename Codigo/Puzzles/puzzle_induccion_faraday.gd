extends "res://Codigo/Puzzles/puzzle_base.gd"

# ==============================================================================
# PUZZLE PREFAB: INDUCCIÓN DE FARADAY (ε = N · f · ΔΦ_B)
# - Terminal en (0, 0) + GeneradorFaraday + CompuertaFaraday (Capa 5)
#   + PuenteInduccion (Capa 5) visibles e integrados en el editor 2D.
# ==============================================================================

const VALORES_N: Array[int] = [20, 30, 40, 50, 60]
const VALORES_F: Array[float] = [1.0, 2.0, 3.0, 4.0, 5.0]
const VALORES_FLUJO: Array[float] = [0.5, 1.0, 2.0]

@export var valor_objetivo: float = 120.0
@export var flujo_base_wb: float = 1.0
@export var objetivo_aleatorio: bool = true

var idx_n: int = 1
var idx_f: int = 1
var completado: bool = false
var _tiempo_iman: float = 0.0
var _pos_compuerta_cerrada: Vector2 = Vector2(133, -56)

@onready var iman_oscilante: Node2D = $GeneradorFaraday/ImanOscilante
@onready var compuerta_body: StaticBody2D = $CompuertaFaraday
@onready var compuerta_col: CollisionShape2D = $CompuertaFaraday/CollisionShape2D
@onready var puente_body: StaticBody2D = $PuenteInduccion
@onready var puente_col: CollisionShape2D = $PuenteInduccion/CollisionShape2D
@onready var puente_sprite: Sprite2D = $PuenteInduccion/Sprite2D
@onready var lbl_estado_mundo: Label = $LblEstadoFaraday

# UI
var lbl_hud_estado: Label
var barra_fem: ProgressBar
var lbl_formula: Label
var lbl_n_val: Label
var lbl_f_val: Label


func generar_problema() -> void:
	if objetivo_aleatorio:
		flujo_base_wb = VALORES_FLUJO[randi() % VALORES_FLUJO.size()]
		var nw: int = VALORES_N[randi_range(1, VALORES_N.size() - 1)]
		var fw: float = VALORES_F[randi_range(1, VALORES_F.size() - 1)]
		valor_objetivo = float(nw) * fw * flujo_base_wb

	idx_n = randi() % VALORES_N.size()
	idx_f = randi() % VALORES_F.size()
	var intentos := 0
	while intentos < 25 and is_equal_approx(_calcular_fem(), valor_objetivo):
		idx_n = randi() % VALORES_N.size()
		idx_f = randi() % VALORES_F.size()
		intentos += 1
	completado = false


func _inicializar_puzzle() -> void:
	titulo_panel = "GENERADOR DE FARADAY — INDUCCIÓN (ε = N · f · ΔΦ)"
	if lbl_titulo_ui != null:
		lbl_titulo_ui.text = titulo_panel
	if compuerta_body != null:
		_pos_compuerta_cerrada = compuerta_body.position
	_actualizar_estado(false)


func _construir_contenido_panel(vbox: VBoxContainer) -> void:
	var lbl_ref := Label.new()
	lbl_ref.text = "ε = N × f × ΔΦ   (Ajusta espiras N y frecuencia f para inducir la FEM exacta)"
	lbl_ref.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_ref.add_theme_font_size_override("font_size", 12)
	lbl_ref.add_theme_color_override("font_color", COLOR_CIAN)
	vbox.add_child(lbl_ref)

	lbl_hud_estado = Label.new()
	lbl_hud_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_hud_estado.add_theme_font_size_override("font_size", 16)
	vbox.add_child(lbl_hud_estado)

	barra_fem = ProgressBar.new()
	barra_fem.custom_minimum_size = Vector2(0, 18)
	barra_fem.show_percentage = false
	vbox.add_child(barra_fem)

	lbl_formula = Label.new()
	lbl_formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_formula.add_theme_font_size_override("font_size", 14)
	vbox.add_child(lbl_formula)

	# Espiras N
	var hb_n := HBoxContainer.new()
	hb_n.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_n.add_theme_constant_override("separation", 12)
	vbox.add_child(hb_n)

	var btn_nm := Button.new()
	btn_nm.text = "◀ [1 / S] -Espiras N"
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
	btn_np.text = "+Espiras N [2 / W] ▶"
	btn_np.custom_minimum_size = Vector2(150, 34)
	btn_np.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_np, COLOR_CIAN)
	btn_np.pressed.connect(func(): _ajustar_n(1))
	hb_n.add_child(btn_np)

	# Frecuencia f
	var hb_f := HBoxContainer.new()
	hb_f.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_f.add_theme_constant_override("separation", 12)
	vbox.add_child(hb_f)

	var btn_fm := Button.new()
	btn_fm.text = "◀ [A / ←] -Frecuencia f"
	btn_fm.custom_minimum_size = Vector2(150, 34)
	btn_fm.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_fm, COLOR_AMARILLO)
	btn_fm.pressed.connect(func(): _ajustar_f(-1))
	hb_f.add_child(btn_fm)

	lbl_f_val = Label.new()
	lbl_f_val.custom_minimum_size = Vector2(140, 0)
	lbl_f_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_f_val.add_theme_font_size_override("font_size", 15)
	hb_f.add_child(lbl_f_val)

	var btn_fp := Button.new()
	btn_fp.text = "+Frecuencia f [D / →] ▶"
	btn_fp.custom_minimum_size = Vector2(150, 34)
	btn_fp.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_fp, COLOR_AMARILLO)
	btn_fp.pressed.connect(func(): _ajustar_f(1))
	hb_f.add_child(btn_fp)

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
		KEY_1, KEY_KP_1, KEY_S, KEY_DOWN:
			_ajustar_n(-1)
			return true
		KEY_2, KEY_KP_2, KEY_W, KEY_UP:
			_ajustar_n(1)
			return true
		KEY_A, KEY_LEFT:
			_ajustar_f(-1)
			return true
		KEY_D, KEY_RIGHT:
			_ajustar_f(1)
			return true
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			cerrar_panel()
			return true
	return false


func _procesar_mundo(delta: float) -> void:
	if iman_oscilante != null and not get_tree().paused:
		_tiempo_iman += delta * VALORES_F[idx_f] * 3.5
		iman_oscilante.position.x = sin(_tiempo_iman) * 20.0


func _ajustar_n(d: int) -> void:
	idx_n = clampi(idx_n + d, 0, VALORES_N.size() - 1)
	_actualizar_estado(true)


func _ajustar_f(d: int) -> void:
	idx_f = clampi(idx_f + d, 0, VALORES_F.size() - 1)
	_actualizar_estado(true)


func _calcular_fem() -> float:
	return float(VALORES_N[idx_n]) * VALORES_F[idx_f] * flujo_base_wb


func _actualizar_estado(animar: bool) -> void:
	var n := VALORES_N[idx_n]
	var f := VALORES_F[idx_f]
	var fem := _calcular_fem()
	var era_ok := completado
	completado = is_equal_approx(fem, valor_objetivo)
	var col: Color = COLOR_VERDE if completado else (COLOR_ROJO if fem > valor_objetivo else COLOR_AMARILLO)

	if lbl_hud_estado != null:
		lbl_hud_estado.text = "OBJETIVO: %.1f V   |   ACTUAL: %.1f V" % [valor_objetivo, fem]
		lbl_hud_estado.add_theme_color_override("font_color", col)
		actualizar_barra(barra_fem, fem, valor_objetivo * 1.6, col)
		lbl_n_val.text = "N = %d esp" % n
		lbl_f_val.text = "f = %.1f Hz" % f
		lbl_formula.text = "ε = %d × %.1f Hz × %.1f Wb = %.1f V" % [n, f, flujo_base_wb, fem]
		lbl_formula.add_theme_color_override("font_color", col)

	if compuerta_body != null:
		var destino := _pos_compuerta_cerrada - Vector2(0, 112) if completado else _pos_compuerta_cerrada
		if animar and era_ok != completado and is_inside_tree():
			var tw := create_tween()
			tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_property(compuerta_body, "position", destino, 0.45)
		else:
			compuerta_body.position = destino
		if compuerta_col != null:
			compuerta_col.set_deferred("disabled", completado)

	if puente_col != null:
		puente_col.set_deferred("disabled", not completado)
	if puente_sprite != null:
		puente_sprite.modulate = Color(0.35, 1.0, 0.65, 1.0) if completado else Color(0.8, 0.45, 0.3, 0.35)

	if lbl_estado_mundo != null:
		lbl_estado_mundo.text = "GENERADOR ACTIVO (%.1f V)" % valor_objetivo if completado else "GENERADOR FARADAY (Meta: %.1f V)" % valor_objetivo
		lbl_estado_mundo.add_theme_color_override("font_color", COLOR_VERDE if completado else COLOR_AMARILLO)
