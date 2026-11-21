extends "res://Codigo/Puzzles/puzzle_base.gd"

# ==============================================================================
# PUZZLE PREFAB: CAPACITORES EN SERIE / PARALELO (PUENTE RETRÁCTIL)
# - Terminal en (0, 0) + PuenteRetractil (Capa 5 Suelo, 464x20) integrado.
# - Serie: C_eq = (C1·C2)/(C1+C2)  |  Paralelo: C_eq = C1 + C2
# ==============================================================================

const PARES_CAPACITORES: Array = [
	[6.0, 12.0],
	[4.0, 12.0],
	[10.0, 10.0],
	[6.0, 3.0],
	[12.0, 24.0],
]

@export var c1_uf: float = 6.0
@export var c2_uf: float = 12.0
@export var valor_objetivo: float = 18.0
@export var requiere_paralelo: bool = true
@export var objetivo_aleatorio: bool = true

var en_paralelo: bool = false
var puente_activo: bool = false

@onready var puente_body: StaticBody2D = $PuenteRetractil
@onready var puente_col: CollisionShape2D = $PuenteRetractil/CollisionShape2D
@onready var puente_sprite: Sprite2D = $PuenteRetractil/Sprite2D
@onready var cable_linea: Line2D = $CableConexion
@onready var lbl_estado_mundo: Label = $LblEstadoPuente

# UI
var lbl_hud_estado: Label
var barra_ceq: ProgressBar
var lbl_formula: Label
var btn_serie: Button
var btn_paralelo: Button
var btn_activar: Button


func generar_problema() -> void:
	if objetivo_aleatorio:
		var par: Array = PARES_CAPACITORES[randi() % PARES_CAPACITORES.size()]
		c1_uf = float(par[0])
		c2_uf = float(par[1])
		requiere_paralelo = (randi() % 2 == 1)
		valor_objetivo = (c1_uf + c2_uf) if requiere_paralelo else ((c1_uf * c2_uf) / (c1_uf + c2_uf))

	en_paralelo = not requiere_paralelo
	puente_activo = false


func _inicializar_puzzle() -> void:
	titulo_panel = "BANCO DE CAPACITORES — SERIE / PARALELO"
	if lbl_titulo_ui != null:
		lbl_titulo_ui.text = titulo_panel
	_actualizar_estado()


func _construir_contenido_panel(vbox: VBoxContainer) -> void:
	var lbl_ref := Label.new()
	lbl_ref.text = "Serie: C_eq = (C₁·C₂)/(C₁+C₂)   |   Paralelo: C_eq = C₁ + C₂"
	lbl_ref.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_ref.add_theme_font_size_override("font_size", 12)
	lbl_ref.add_theme_color_override("font_color", COLOR_CIAN)
	vbox.add_child(lbl_ref)

	lbl_hud_estado = Label.new()
	lbl_hud_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_hud_estado.add_theme_font_size_override("font_size", 16)
	vbox.add_child(lbl_hud_estado)

	barra_ceq = ProgressBar.new()
	barra_ceq.custom_minimum_size = Vector2(0, 18)
	barra_ceq.show_percentage = false
	vbox.add_child(barra_ceq)

	lbl_formula = Label.new()
	lbl_formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_formula.add_theme_font_size_override("font_size", 14)
	vbox.add_child(lbl_formula)

	var hb_modos := HBoxContainer.new()
	hb_modos.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_modos.add_theme_constant_override("separation", 14)
	vbox.add_child(hb_modos)

	btn_serie = Button.new()
	btn_serie.text = "[1 / ←] CONEXIÓN EN SERIE"
	btn_serie.custom_minimum_size = Vector2(230, 40)
	btn_serie.focus_mode = Control.FOCUS_NONE
	btn_serie.pressed.connect(func(): _elegir_modo(false))
	hb_modos.add_child(btn_serie)

	btn_paralelo = Button.new()
	btn_paralelo.text = "[2 / →] CONEXIÓN EN PARALELO"
	btn_paralelo.custom_minimum_size = Vector2(230, 40)
	btn_paralelo.focus_mode = Control.FOCUS_NONE
	btn_paralelo.pressed.connect(func(): _elegir_modo(true))
	hb_modos.add_child(btn_paralelo)

	btn_activar = Button.new()
	btn_activar.text = "CONFIRMAR Y EXTENDER PUENTE  [Enter / Espacio]"
	btn_activar.custom_minimum_size = Vector2(0, 42)
	btn_activar.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_activar, COLOR_VERDE)
	btn_activar.pressed.connect(_confirmar_puente)
	vbox.add_child(btn_activar)


func _al_abrir_panel() -> void:
	_actualizar_estado()


func _procesar_tecla_panel(kc: int) -> bool:
	match kc:
		KEY_1, KEY_KP_1, KEY_A, KEY_LEFT:
			_elegir_modo(false)
			return true
		KEY_2, KEY_KP_2, KEY_D, KEY_RIGHT:
			_elegir_modo(true)
			return true
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_confirmar_puente()
			return true
	return false


func _calcular_ceq() -> float:
	if en_paralelo:
		return c1_uf + c2_uf
	return (c1_uf * c2_uf) / maxf(0.001, c1_uf + c2_uf)


func _elegir_modo(paralelo: bool) -> void:
	en_paralelo = paralelo
	_actualizar_estado()


func _confirmar_puente() -> void:
	var ceq := _calcular_ceq()
	puente_activo = is_equal_approx(ceq, valor_objetivo)
	_actualizar_estado()
	if puente_activo:
		cerrar_panel()


func _actualizar_estado() -> void:
	var ceq := _calcular_ceq()
	var en_meta := is_equal_approx(ceq, valor_objetivo)
	var col: Color = COLOR_VERDE if (en_meta or puente_activo) else COLOR_AMARILLO

	if lbl_hud_estado != null:
		lbl_hud_estado.text = "OBJETIVO: %.1f µF   |   ACTUAL: %.1f µF" % [valor_objetivo, ceq]
		lbl_hud_estado.add_theme_color_override("font_color", col)
		actualizar_barra(barra_ceq, ceq, maxf(c1_uf + c2_uf, valor_objetivo * 1.3), col)

		if en_paralelo:
			lbl_formula.text = "PARALELO:  C_eq = %.0f µF + %.0f µF = %.1f µF" % [c1_uf, c2_uf, ceq]
		else:
			lbl_formula.text = "SERIE:  C_eq = (%.0f × %.0f) / (%.0f + %.0f) = %.1f µF" % [c1_uf, c2_uf, c1_uf, c2_uf, ceq]
		lbl_formula.add_theme_color_override("font_color", col)

		estilizar_boton(btn_serie, COLOR_AMARILLO if not en_paralelo else Color(0.42, 0.48, 0.56))
		estilizar_boton(btn_paralelo, COLOR_CIAN if en_paralelo else Color(0.42, 0.48, 0.56))

	if puente_col != null:
		puente_col.set_deferred("disabled", not puente_activo)
	if puente_sprite != null:
		puente_sprite.modulate = Color(0.3, 1.0, 0.65, 1.0) if puente_activo else Color(1.0, 0.45, 0.25, 0.28)
	if cable_linea != null:
		cable_linea.default_color = Color(0.25, 1.0, 0.55, 0.95) if puente_activo else Color(0.9, 0.3, 0.25, 0.85)
	if lbl_estado_mundo != null:
		lbl_estado_mundo.text = "PUENTE EXTENDIDO (%.1f µF)" % valor_objetivo if puente_activo else "PUENTE RETRAÍDO (Meta: %.1f µF)" % valor_objetivo
		lbl_estado_mundo.add_theme_color_override("font_color", COLOR_VERDE if puente_activo else COLOR_ROJO)
