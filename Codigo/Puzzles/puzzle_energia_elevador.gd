extends "res://Codigo/Puzzles/puzzle_base.gd"

# ==============================================================================
# PUZZLE PREFAB: ENERGÍA ALMACENADA — PLATAFORMA ELEVADORA (U = ½ · κ · C0 · V²)
# - Terminal en (0, 0) + PlataformaElevadora (AnimatableBody2D en Capa 5 Suelo)
#   + BarreraDielectrica visibles en el editor 2D.
# - Expone distancia_elevador, velocidad_elevador y valor_objetivo en Inspector.
# ==============================================================================

const C0_BASE: float = 2.0
const VOLTAJES: Array[float] = [2.0, 4.0, 6.0, 8.0, 10.0, 12.0]
const NOMBRES_K: Array[String] = ["AIRE (κ=1)", "VIDRIO (κ=2)", "CERÁMICA (κ=4)"]
const CONSTANTES_K: Array[float] = [1.0, 2.0, 4.0]

@export var valor_objetivo: float = 144.0
@export var objetivo_aleatorio: bool = true
@export var distancia_elevador: float = 174.0
@export var velocidad_elevador: float = 1.15

var idx_k: int = 0
var idx_v: int = 1
var elevador_activo: bool = false
var _tiempo_mov: float = 0.0
var _pos_elevador_base: Vector2 = Vector2(69, -6)

@onready var elevador_body: AnimatableBody2D = $PlataformaElevadora
@onready var barrera_body: StaticBody2D = $BarreraDielectrica
@onready var barrera_col: CollisionShape2D = $BarreraDielectrica/CollisionShape2D
@onready var riel_guia: Line2D = $RielGuia
@onready var lbl_estado_mundo: Label = $LblEstadoElevador

# UI
var lbl_hud_estado: Label
var barra_u: ProgressBar
var lbl_formula: Label
var lbl_v_val: Label
var botones_k: Array[Button] = []


func _inicializar_puzzle() -> void:
	titulo_panel = "PLATAFORMA ELEVADORA — ENERGÍA U = ½ · C · V²"
	if lbl_titulo_ui != null:
		lbl_titulo_ui.text = titulo_panel
	if elevador_body != null:
		_pos_elevador_base = elevador_body.position
	if riel_guia != null:
		riel_guia.points = PackedVector2Array([
			_pos_elevador_base + Vector2(0, 8),
			_pos_elevador_base - Vector2(0, distancia_elevador + 8),
		])

	if objetivo_aleatorio:
		var k_w: float = CONSTANTES_K[randi_range(0, CONSTANTES_K.size() - 1)]
		var v_w: float = VOLTAJES[randi_range(1, VOLTAJES.size() - 1)]
		valor_objetivo = 0.5 * (k_w * C0_BASE) * v_w * v_w

	idx_k = randi_range(0, CONSTANTES_K.size() - 1)
	idx_v = randi_range(0, VOLTAJES.size() - 1)
	var intentos := 0
	while intentos < 30 and is_equal_approx(_calcular_u(), valor_objetivo):
		idx_k = randi_range(0, CONSTANTES_K.size() - 1)
		idx_v = randi_range(0, VOLTAJES.size() - 1)
		intentos += 1

	elevador_activo = false
	_actualizar_estado()


func _construir_contenido_panel(vbox: VBoxContainer) -> void:
	var lbl_ref := Label.new()
	lbl_ref.text = "C = κ · C₀ (C₀ = 2 F)   |   U = ½ · C · V²"
	lbl_ref.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_ref.add_theme_font_size_override("font_size", 12)
	lbl_ref.add_theme_color_override("font_color", COLOR_CIAN)
	vbox.add_child(lbl_ref)

	lbl_hud_estado = Label.new()
	lbl_hud_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_hud_estado.add_theme_font_size_override("font_size", 16)
	vbox.add_child(lbl_hud_estado)

	barra_u = ProgressBar.new()
	barra_u.custom_minimum_size = Vector2(0, 18)
	barra_u.show_percentage = false
	vbox.add_child(barra_u)

	lbl_formula = Label.new()
	lbl_formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_formula.add_theme_font_size_override("font_size", 14)
	vbox.add_child(lbl_formula)

	# Dieléctricos
	var hb_k := HBoxContainer.new()
	hb_k.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_k.add_theme_constant_override("separation", 10)
	vbox.add_child(hb_k)

	botones_k.clear()
	for i in range(NOMBRES_K.size()):
		var btn := Button.new()
		btn.text = "[%d] %s" % [i + 1, NOMBRES_K[i]]
		btn.custom_minimum_size = Vector2(165, 38)
		btn.focus_mode = Control.FOCUS_NONE
		var idx_local := i
		btn.pressed.connect(func():
			idx_k = idx_local
			_actualizar_estado()
		)
		hb_k.add_child(btn)
		botones_k.append(btn)

	# Voltaje V
	var hb_v := HBoxContainer.new()
	hb_v.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_v.add_theme_constant_override("separation", 12)
	vbox.add_child(hb_v)

	var btn_vm := Button.new()
	btn_vm.text = "◀ [A / ←] -Voltaje"
	btn_vm.custom_minimum_size = Vector2(150, 36)
	btn_vm.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_vm, COLOR_AMARILLO)
	btn_vm.pressed.connect(func(): _ajustar_v(-1))
	hb_v.add_child(btn_vm)

	lbl_v_val = Label.new()
	lbl_v_val.custom_minimum_size = Vector2(130, 0)
	lbl_v_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_v_val.add_theme_font_size_override("font_size", 16)
	hb_v.add_child(lbl_v_val)

	var btn_vp := Button.new()
	btn_vp.text = "+Voltaje [D / →] ▶"
	btn_vp.custom_minimum_size = Vector2(150, 36)
	btn_vp.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_vp, COLOR_AMARILLO)
	btn_vp.pressed.connect(func(): _ajustar_v(1))
	hb_v.add_child(btn_vp)

	var btn_ok := Button.new()
	btn_ok.text = "APLICAR Y VOLVER AL NIVEL  [Enter / E]"
	btn_ok.custom_minimum_size = Vector2(0, 42)
	btn_ok.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_ok, COLOR_VERDE)
	btn_ok.pressed.connect(cerrar_panel)
	vbox.add_child(btn_ok)


func _al_abrir_panel() -> void:
	_actualizar_estado()


func _procesar_tecla_panel(kc: int) -> bool:
	match kc:
		KEY_1, KEY_KP_1:
			idx_k = 0
			_actualizar_estado()
			return true
		KEY_2, KEY_KP_2:
			idx_k = 1
			_actualizar_estado()
			return true
		KEY_3, KEY_KP_3:
			idx_k = 2
			_actualizar_estado()
			return true
		KEY_A, KEY_LEFT:
			_ajustar_v(-1)
			return true
		KEY_D, KEY_RIGHT:
			_ajustar_v(1)
			return true
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			cerrar_panel()
			return true
	return false


func _procesar_mundo(delta: float) -> void:
	if elevador_activo and not get_tree().paused and elevador_body != null:
		_tiempo_mov += delta * velocidad_elevador
		var factor: float = 0.5 - 0.5 * cos(_tiempo_mov)
		elevador_body.position.y = lerpf(_pos_elevador_base.y, _pos_elevador_base.y - distancia_elevador, factor)


func _ajustar_v(d: int) -> void:
	idx_v = clampi(idx_v + d, 0, VOLTAJES.size() - 1)
	_actualizar_estado()


func _calcular_u() -> float:
	var c := CONSTANTES_K[idx_k] * C0_BASE
	var v := VOLTAJES[idx_v]
	return 0.5 * c * v * v


func _actualizar_estado() -> void:
	var k := CONSTANTES_K[idx_k]
	var c := k * C0_BASE
	var v := VOLTAJES[idx_v]
	var u := _calcular_u()
	elevador_activo = is_equal_approx(u, valor_objetivo)
	var col: Color = COLOR_VERDE if elevador_activo else (COLOR_ROJO if u > valor_objetivo else COLOR_AMARILLO)

	if lbl_hud_estado != null:
		lbl_hud_estado.text = "OBJETIVO: %.1f J   |   ACTUAL: %.1f J" % [valor_objetivo, u]
		lbl_hud_estado.add_theme_color_override("font_color", col)
		actualizar_barra(barra_u, u, valor_objetivo * 1.5, col)
		lbl_v_val.text = "V = %.0f V" % v
		lbl_formula.text = "U = ½ × (%.0f × 2 F) × (%.0f V)² = %.1f J" % [k, v, u]
		lbl_formula.add_theme_color_override("font_color", col)

		for i in range(botones_k.size()):
			estilizar_boton(botones_k[i], COLOR_CIAN if i == idx_k else Color(0.42, 0.48, 0.56))

	if barrera_body != null:
		barrera_body.visible = not elevador_activo
		if barrera_col != null:
			barrera_col.set_deferred("disabled", elevador_activo)

	if lbl_estado_mundo != null:
		lbl_estado_mundo.text = "ELEVADOR ACTIVO (%.1f J)" % valor_objetivo if elevador_activo else "ELEVADOR APAGADO (Meta: %.1f J)" % valor_objetivo
		lbl_estado_mundo.add_theme_color_override("font_color", COLOR_VERDE if elevador_activo else COLOR_AMARILLO)
