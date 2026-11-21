extends "res://Codigo/Puzzles/puzzle_base.gd"

# ==============================================================================
# PUERTA DE SALIDA DE NIVEL — LEY DE OHM (V = I × R)
# - Prefab autocontenido: Terminal + Compuerta física (Capa 5) + Portal (Capa 1).
# - Al resolver V = I × R, abre la compuerta y permite pasar al siguiente nivel
#   (ruta_siguiente_escena), guardando checkpoint automático en GameManager.
# ==============================================================================

@export var ruta_siguiente_escena: String = "res://Escenas/escena_02.tscn"
@export var valor_objetivo: int = 24
@export var objetivo_aleatorio: bool = true
@export var corriente_min: int = 1
@export var corriente_max: int = 10
@export var resistencia_min: int = 1
@export var resistencia_max: int = 20

var corriente_val: int = 2
var resistencia_val: int = 4
var puerta_abierta: bool = false
var _transicion_lanzada: bool = false

@onready var compuerta_body: StaticBody2D = $CompuertaSalida
@onready var compuerta_col: CollisionShape2D = $CompuertaSalida/CollisionShape2D
@onready var compuerta_sprite: Sprite2D = $CompuertaSalida/Sprite2D
@onready var portal_area: Area2D = $PortalSalida
@onready var lbl_estado_puerta: Label = $LblEstadoPuerta

# UI
var lbl_hud_estado: Label
var barra_v: ProgressBar
var lbl_formula: Label
var lbl_i_val: Label
var lbl_r_val: Label
var lbl_feedback: Label
var btn_verificar: Button
var btn_siguiente: Button


func generar_problema() -> void:
	if objetivo_aleatorio:
		var i_win := randi_range(maxi(2, corriente_min), corriente_max)
		var r_win := randi_range(maxi(2, resistencia_min), resistencia_max)
		valor_objetivo = i_win * r_win

	corriente_val = randi_range(corriente_min, corriente_max)
	resistencia_val = randi_range(resistencia_min, resistencia_max)
	var intentos := 0
	while intentos < 40 and (corriente_val * resistencia_val == valor_objetivo):
		corriente_val = randi_range(corriente_min, corriente_max)
		resistencia_val = randi_range(resistencia_min, resistencia_max)
		intentos += 1


func _inicializar_puzzle() -> void:
	titulo_panel = "COMPUERTA DE SALIDA — LEY DE OHM (V = I × R)"
	if lbl_titulo_ui != null:
		lbl_titulo_ui.text = titulo_panel

	if portal_area != null:
		portal_area.collision_layer = 0
		portal_area.collision_mask = 1
		portal_area.monitoring = true
		if not portal_area.body_entered.is_connected(_on_portal_entered):
			portal_area.body_entered.connect(_on_portal_entered)

	_actualizar_estado()


func _construir_contenido_panel(vbox: VBoxContainer) -> void:
	var lbl_ref := Label.new()
	lbl_ref.text = "V = I × R   (Energiza la compuerta con el voltaje exacto para abrir la salida)"
	lbl_ref.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_ref.add_theme_font_size_override("font_size", 12)
	lbl_ref.add_theme_color_override("font_color", COLOR_CIAN)
	vbox.add_child(lbl_ref)

	lbl_hud_estado = Label.new()
	lbl_hud_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_hud_estado.add_theme_font_size_override("font_size", 16)
	vbox.add_child(lbl_hud_estado)

	barra_v = ProgressBar.new()
	barra_v.custom_minimum_size = Vector2(0, 18)
	barra_v.show_percentage = false
	vbox.add_child(barra_v)

	lbl_formula = Label.new()
	lbl_formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_formula.add_theme_font_size_override("font_size", 14)
	vbox.add_child(lbl_formula)

	# Corriente I
	var hb_i := HBoxContainer.new()
	hb_i.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_i.add_theme_constant_override("separation", 12)
	vbox.add_child(hb_i)

	var btn_im := Button.new()
	btn_im.text = "◀ [Q / ↓] -Corriente"
	btn_im.custom_minimum_size = Vector2(150, 34)
	btn_im.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_im, COLOR_CIAN)
	btn_im.pressed.connect(func(): _ajustar_i(-1))
	hb_i.add_child(btn_im)

	lbl_i_val = Label.new()
	lbl_i_val.custom_minimum_size = Vector2(120, 0)
	lbl_i_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_i_val.add_theme_font_size_override("font_size", 15)
	hb_i.add_child(lbl_i_val)

	var btn_ip := Button.new()
	btn_ip.text = "+Corriente [W / ↑] ▶"
	btn_ip.custom_minimum_size = Vector2(150, 34)
	btn_ip.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_ip, COLOR_CIAN)
	btn_ip.pressed.connect(func(): _ajustar_i(1))
	hb_i.add_child(btn_ip)

	# Resistencia R
	var hb_r := HBoxContainer.new()
	hb_r.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_r.add_theme_constant_override("separation", 12)
	vbox.add_child(hb_r)

	var btn_rm := Button.new()
	btn_rm.text = "◀ [A / ←] -Resistencia"
	btn_rm.custom_minimum_size = Vector2(150, 34)
	btn_rm.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_rm, COLOR_AMARILLO)
	btn_rm.pressed.connect(func(): _ajustar_r(-1))
	hb_r.add_child(btn_rm)

	lbl_r_val = Label.new()
	lbl_r_val.custom_minimum_size = Vector2(120, 0)
	lbl_r_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_r_val.add_theme_font_size_override("font_size", 15)
	hb_r.add_child(lbl_r_val)

	var btn_rp := Button.new()
	btn_rp.text = "+Resistencia [D / →] ▶"
	btn_rp.custom_minimum_size = Vector2(150, 34)
	btn_rp.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_rp, COLOR_AMARILLO)
	btn_rp.pressed.connect(func(): _ajustar_r(1))
	hb_r.add_child(btn_rp)

	lbl_feedback = Label.new()
	lbl_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_feedback.add_theme_font_size_override("font_size", 13)
	vbox.add_child(lbl_feedback)

	var hb_acc := HBoxContainer.new()
	hb_acc.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_acc.add_theme_constant_override("separation", 12)
	vbox.add_child(hb_acc)

	btn_verificar = Button.new()
	btn_verificar.text = "ENERGIZAR COMPUERTA  [Enter]"
	btn_verificar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_verificar.custom_minimum_size = Vector2(0, 42)
	btn_verificar.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_verificar, COLOR_VERDE)
	btn_verificar.pressed.connect(_verificar_circuito)
	hb_acc.add_child(btn_verificar)

	btn_siguiente = Button.new()
	btn_siguiente.text = "AVANZAR DE NIVEL ▶"
	btn_siguiente.custom_minimum_size = Vector2(190, 42)
	btn_siguiente.focus_mode = Control.FOCUS_NONE
	btn_siguiente.disabled = true
	estilizar_boton(btn_siguiente, COLOR_CIAN, true)
	btn_siguiente.pressed.connect(_cargar_siguiente_nivel)
	hb_acc.add_child(btn_siguiente)


func _al_abrir_panel() -> void:
	lbl_feedback.text = ""
	_actualizar_estado()


func _procesar_tecla_panel(kc: int) -> bool:
	match kc:
		KEY_Q, KEY_DOWN:
			_ajustar_i(-1)
			return true
		KEY_W, KEY_UP:
			_ajustar_i(1)
			return true
		KEY_A, KEY_LEFT:
			_ajustar_r(-1)
			return true
		KEY_D, KEY_RIGHT:
			_ajustar_r(1)
			return true
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if puerta_abierta:
				_cargar_siguiente_nivel()
			else:
				_verificar_circuito()
			return true
	return false


func _ajustar_i(d: int) -> void:
	corriente_val = clampi(corriente_val + d, corriente_min, corriente_max)
	_actualizar_estado()


func _ajustar_r(d: int) -> void:
	resistencia_val = clampi(resistencia_val + d, resistencia_min, resistencia_max)
	_actualizar_estado()


func _verificar_circuito() -> void:
	var v: int = corriente_val * resistencia_val
	if v == valor_objetivo:
		_abrir_compuerta()
		lbl_feedback.text = "¡COMPUERTA ABIERTA! Cruza la puerta o pulsa AVANZAR DE NIVEL."
		lbl_feedback.add_theme_color_override("font_color", COLOR_VERDE)
	else:
		lbl_feedback.text = "Voltaje actual: %d V (Se requieren exactamente %d V)." % [v, valor_objetivo]
		lbl_feedback.add_theme_color_override("font_color", COLOR_ROJO)


func _abrir_compuerta() -> void:
	if puerta_abierta:
		return
	puerta_abierta = true
	if compuerta_col != null:
		compuerta_col.set_deferred("disabled", true)
	if compuerta_sprite != null and is_inside_tree():
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(compuerta_sprite, "position:y", compuerta_sprite.position.y - 105.0, 0.45)
		tw.parallel().tween_property(compuerta_sprite, "modulate", Color(0.4, 1.0, 0.65, 0.45), 0.45)
	_actualizar_estado()


func _actualizar_estado() -> void:
	var v: int = corriente_val * resistencia_val
	var exacto: bool = (v == valor_objetivo)
	var col: Color = COLOR_VERDE if (exacto or puerta_abierta) else (COLOR_ROJO if v > valor_objetivo else COLOR_AMARILLO)

	if lbl_hud_estado != null:
		lbl_hud_estado.text = "OBJETIVO: %d V   |   ACTUAL: %d V" % [valor_objetivo, v]
		lbl_hud_estado.add_theme_color_override("font_color", col)
		actualizar_barra(barra_v, float(v), float(valor_objetivo) * 1.5, col)
		lbl_i_val.text = "I = %d A" % corriente_val
		lbl_r_val.text = "R = %d Ω" % resistencia_val
		lbl_formula.text = "V = I × R = %d A × %d Ω = %d V" % [corriente_val, resistencia_val, v]
		lbl_formula.add_theme_color_override("font_color", col)
		btn_siguiente.disabled = not puerta_abierta
		estilizar_boton(btn_siguiente, COLOR_VERDE if puerta_abierta else COLOR_CIAN, not puerta_abierta)

	if lbl_estado_puerta != null:
		if puerta_abierta:
			lbl_estado_puerta.text = "SALIDA ABIERTA — CRUZA EL PORTAL"
			lbl_estado_puerta.add_theme_color_override("font_color", COLOR_VERDE)
		else:
			lbl_estado_puerta.text = "SALIDA BLOQUEADA (Meta: %d V)" % valor_objetivo
			lbl_estado_puerta.add_theme_color_override("font_color", COLOR_AMARILLO)


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
