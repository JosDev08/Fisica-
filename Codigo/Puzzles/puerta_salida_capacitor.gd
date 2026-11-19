extends "res://Codigo/Puzzles/puzzle_base.gd"

# ==============================================================================
# PUERTA DE SALIDA DE NIVEL — EQUILIBRIO DE CARGA (Q = C · V)
# - Prefab autocontenido: Terminal + CompuertaCapacitor (Capa 5) + Portal (Capa 1).
# - Al equilibrar Q = C · V, abre la compuerta y permite avanzar al siguiente nivel.
# ==============================================================================

const OPCIONES_C: Array[float] = [5.0, 10.0, 12.0, 15.0, 20.0]
const OPCIONES_V: Array[float] = [2.0, 4.0, 6.0, 8.0, 10.0, 12.0]

@export var ruta_siguiente_escena: String = "res://Escenas/escena_03.tscn"
@export var valor_objetivo: float = 120.0
@export var objetivo_aleatorio: bool = true

var idx_c: int = 1
var idx_v: int = 2
var puerta_abierta: bool = false
var _transicion_lanzada: bool = false

@onready var compuerta_body: StaticBody2D = $CompuertaCapacitor
@onready var compuerta_col: CollisionShape2D = $CompuertaCapacitor/CollisionShape2D
@onready var compuerta_sprite: Sprite2D = $CompuertaCapacitor/Sprite2D
@onready var portal_area: Area2D = $PortalSalida
@onready var lbl_estado_puerta: Label = $LblEstadoPuerta

# UI
var lbl_hud_estado: Label
var barra_q: ProgressBar
var lbl_formula: Label
var lbl_c_val: Label
var lbl_v_val: Label
var btn_avanzar: Button


func _inicializar_puzzle() -> void:
	titulo_panel = "COMPUERTA CAPACITOR — CARGA Q = C · V"
	if lbl_titulo_ui != null:
		lbl_titulo_ui.text = titulo_panel

	if objetivo_aleatorio:
		var c_w: float = OPCIONES_C[randi_range(0, OPCIONES_C.size() - 1)]
		var v_w: float = OPCIONES_V[randi_range(1, OPCIONES_V.size() - 1)]
		valor_objetivo = c_w * v_w

	idx_c = randi_range(0, OPCIONES_C.size() - 1)
	idx_v = randi_range(0, OPCIONES_V.size() - 1)
	var intentos := 0
	while intentos < 30 and is_equal_approx(_calcular_q(), valor_objetivo):
		idx_c = randi_range(0, OPCIONES_C.size() - 1)
		idx_v = randi_range(0, OPCIONES_V.size() - 1)
		intentos += 1

	if portal_area != null:
		portal_area.collision_layer = 0
		portal_area.collision_mask = 1
		portal_area.monitoring = true
		if not portal_area.body_entered.is_connected(_on_portal_entered):
			portal_area.body_entered.connect(_on_portal_entered)

	_actualizar_estado(false)


func _construir_contenido_panel(vbox: VBoxContainer) -> void:
	var lbl_ref := Label.new()
	lbl_ref.text = "Q = C × V   (Iguala la carga eléctrica exacta en µC para desbloquear la salida)"
	lbl_ref.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_ref.add_theme_font_size_override("font_size", 12)
	lbl_ref.add_theme_color_override("font_color", COLOR_CIAN)
	vbox.add_child(lbl_ref)

	lbl_hud_estado = Label.new()
	lbl_hud_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_hud_estado.add_theme_font_size_override("font_size", 16)
	vbox.add_child(lbl_hud_estado)

	barra_q = ProgressBar.new()
	barra_q.custom_minimum_size = Vector2(0, 18)
	barra_q.show_percentage = false
	vbox.add_child(barra_q)

	lbl_formula = Label.new()
	lbl_formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_formula.add_theme_font_size_override("font_size", 14)
	vbox.add_child(lbl_formula)

	# Capacitancia C
	var hb_c := HBoxContainer.new()
	hb_c.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_c.add_theme_constant_override("separation", 12)
	vbox.add_child(hb_c)

	var btn_cm := Button.new()
	btn_cm.text = "◀ [1 / S] -C (µF)"
	btn_cm.custom_minimum_size = Vector2(150, 34)
	btn_cm.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_cm, COLOR_CIAN)
	btn_cm.pressed.connect(func(): _ajustar_c(-1))
	hb_c.add_child(btn_cm)

	lbl_c_val = Label.new()
	lbl_c_val.custom_minimum_size = Vector2(130, 0)
	lbl_c_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_c_val.add_theme_font_size_override("font_size", 15)
	hb_c.add_child(lbl_c_val)

	var btn_cp := Button.new()
	btn_cp.text = "+C (µF) [2 / W] ▶"
	btn_cp.custom_minimum_size = Vector2(150, 34)
	btn_cp.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_cp, COLOR_CIAN)
	btn_cp.pressed.connect(func(): _ajustar_c(1))
	hb_c.add_child(btn_cp)

	# Voltaje V
	var hb_v := HBoxContainer.new()
	hb_v.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_v.add_theme_constant_override("separation", 12)
	vbox.add_child(hb_v)

	var btn_vm := Button.new()
	btn_vm.text = "◀ [A / ←] -V (V)"
	btn_vm.custom_minimum_size = Vector2(150, 34)
	btn_vm.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_vm, COLOR_AMARILLO)
	btn_vm.pressed.connect(func(): _ajustar_v(-1))
	hb_v.add_child(btn_vm)

	lbl_v_val = Label.new()
	lbl_v_val.custom_minimum_size = Vector2(130, 0)
	lbl_v_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_v_val.add_theme_font_size_override("font_size", 15)
	hb_v.add_child(lbl_v_val)

	var btn_vp := Button.new()
	btn_vp.text = "+V (V) [D / →] ▶"
	btn_vp.custom_minimum_size = Vector2(150, 34)
	btn_vp.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_vp, COLOR_AMARILLO)
	btn_vp.pressed.connect(func(): _ajustar_v(1))
	hb_v.add_child(btn_vp)

	var hb_acc := HBoxContainer.new()
	hb_acc.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_acc.add_theme_constant_override("separation", 12)
	vbox.add_child(hb_acc)

	var btn_conf := Button.new()
	btn_conf.text = "APLICAR Y VOLVER  [Enter]"
	btn_conf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_conf.custom_minimum_size = Vector2(0, 40)
	btn_conf.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_conf, COLOR_VERDE)
	btn_conf.pressed.connect(cerrar_panel)
	hb_acc.add_child(btn_conf)

	btn_avanzar = Button.new()
	btn_avanzar.text = "AVANZAR DE NIVEL ▶"
	btn_avanzar.custom_minimum_size = Vector2(190, 40)
	btn_avanzar.focus_mode = Control.FOCUS_NONE
	btn_avanzar.disabled = true
	estilizar_boton(btn_avanzar, COLOR_CIAN, true)
	btn_avanzar.pressed.connect(_cargar_siguiente_nivel)
	hb_acc.add_child(btn_avanzar)


func _al_abrir_panel() -> void:
	_actualizar_estado(false)


func _procesar_tecla_panel(kc: int) -> bool:
	match kc:
		KEY_1, KEY_KP_1, KEY_S, KEY_DOWN:
			_ajustar_c(-1)
			return true
		KEY_2, KEY_KP_2, KEY_W, KEY_UP:
			_ajustar_c(1)
			return true
		KEY_A, KEY_LEFT:
			_ajustar_v(-1)
			return true
		KEY_D, KEY_RIGHT:
			_ajustar_v(1)
			return true
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if puerta_abierta:
				_cargar_siguiente_nivel()
			else:
				cerrar_panel()
			return true
	return false


func _calcular_q() -> float:
	return OPCIONES_C[idx_c] * OPCIONES_V[idx_v]


func _ajustar_c(d: int) -> void:
	idx_c = clampi(idx_c + d, 0, OPCIONES_C.size() - 1)
	_actualizar_estado(true)


func _ajustar_v(d: int) -> void:
	idx_v = clampi(idx_v + d, 0, OPCIONES_V.size() - 1)
	_actualizar_estado(true)


func _actualizar_estado(animar: bool) -> void:
	var c := OPCIONES_C[idx_c]
	var v := OPCIONES_V[idx_v]
	var q := _calcular_q()
	var era_abierta := puerta_abierta
	puerta_abierta = is_equal_approx(q, valor_objetivo)
	var col: Color = COLOR_VERDE if puerta_abierta else (COLOR_ROJO if q > valor_objetivo else COLOR_AMARILLO)

	if lbl_hud_estado != null:
		lbl_hud_estado.text = "OBJETIVO: %.1f µC   |   ACTUAL: %.1f µC" % [valor_objetivo, q]
		lbl_hud_estado.add_theme_color_override("font_color", col)
		actualizar_barra(barra_q, q, valor_objetivo * 1.5, col)
		lbl_c_val.text = "C = %.0f µF" % c
		lbl_v_val.text = "V = %.0f V" % v
		lbl_formula.text = "Q = C × V = %.0f µF × %.0f V = %.1f µC" % [c, v, q]
		lbl_formula.add_theme_color_override("font_color", col)
		btn_avanzar.disabled = not puerta_abierta
		estilizar_boton(btn_avanzar, COLOR_VERDE if puerta_abierta else COLOR_CIAN, not puerta_abierta)

	if compuerta_col != null:
		compuerta_col.set_deferred("disabled", puerta_abierta)
	if compuerta_sprite != null:
		if puerta_abierta:
			if animar and not era_abierta and is_inside_tree():
				var tw := create_tween()
				tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
				tw.tween_property(compuerta_sprite, "position", Vector2(0, -110), 0.4)
				tw.parallel().tween_property(compuerta_sprite, "modulate", Color(0.4, 1.0, 0.7, 0.45), 0.4)
			else:
				compuerta_sprite.position = Vector2(0, -110)
				compuerta_sprite.modulate = Color(0.4, 1.0, 0.7, 0.45)
		else:
			compuerta_sprite.position = Vector2.ZERO
			compuerta_sprite.modulate = Color.WHITE

	if lbl_estado_puerta != null:
		lbl_estado_puerta.text = "PUERTA ABIERTA — AVANZA" if puerta_abierta else "PUERTA BLOQUEADA (Meta: %.1f µC)" % valor_objetivo
		lbl_estado_puerta.add_theme_color_override("font_color", COLOR_VERDE if puerta_abierta else COLOR_ROJO)


func _on_portal_entered(body: Node2D) -> void:
	if puerta_abierta and not _transicion_lanzada and es_jugador(body):
		_cargar_siguiente_nivel()


func _cargar_siguiente_nivel() -> void:
	if _transicion_lanzada:
		return
	_transicion_lanzada = true
	if panel_abierto:
		cerrar_panel()
	get_tree().paused = false
	GameManager.completar_meta_nivel(ruta_siguiente_escena, global_position)
	if not ruta_siguiente_escena.is_empty() and ResourceLoader.exists(ruta_siguiente_escena):
		get_tree().change_scene_to_file(ruta_siguiente_escena)
