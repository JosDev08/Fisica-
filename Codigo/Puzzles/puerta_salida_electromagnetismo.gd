extends "res://Codigo/Puzzles/puzzle_base.gd"

# ==============================================================================
# PUERTA DE SALIDA MAESTRA — ELECTROMAGNETISMO EN 2 FASES
# - Fase 1 (Ampère): B = 0.0025 · N1 · I1  -> Meta: 1.50 T
# - Fase 2 (Resonancia): P = B · N2 · f    -> Meta: 180.0 kW
# - Prefab autocontenido: Consola (0,0) + CompuertaMaestra (Capa 5) + Portal (Capa 1)
# ==============================================================================

const F1_ESPIRAS: Array[int] = [100, 150, 200, 250, 300]
const F1_CORRIENTES: Array[float] = [2.0, 3.0, 4.0, 5.0, 6.0]
const F1_FACTOR: float = 0.0025

const F2_ESPIRAS: Array[int] = [20, 30, 40, 50, 60]
const F2_FRECUENCIAS: Array[float] = [1.0, 2.0, 3.0, 4.0, 5.0]

@export var ruta_siguiente_escena: String = "res://Escenas/Escena_4.tscn"
@export var valor_objetivo_fase1: float = 1.50
@export var valor_objetivo_fase2: float = 180.0
@export var objetivo_aleatorio: bool = true
@export var requiere_archivos_clasificados: bool = true

const MSG_ACCESO_DENEGADO := "¡ACCESO DENEGADO! Debes recuperar los archivos del estante antes de avanzar"

var fase_actual: int = 1
var fase_1_ok: bool = false
var fase_2_ok: bool = false
var puerta_abierta: bool = false
var idx_a: int = 1
var idx_b: int = 1
var _transicion_lanzada: bool = false
var _pos_puerta_cerrada: Vector2 = Vector2(220, -56)

@onready var puerta_body: StaticBody2D = $CompuertaMaestra
@onready var puerta_col: CollisionShape2D = $CompuertaMaestra/CollisionShape2D
@onready var puerta_sprite: Sprite2D = $CompuertaMaestra/Sprite2D
@onready var portal_area: Area2D = $PortalSalida
@onready var lbl_estado_puerta: Label = $LblEstadoPuerta

# UI
var lbl_fase: Label
var lbl_hud_estado: Label
var barra_reactor: ProgressBar
var lbl_formula: Label
var lbl_a_val: Label
var lbl_b_val: Label
var lbl_alerta_archivos_ui: Label
var btn_accion: Button

var _canvas_alerta: CanvasLayer = null
var _panel_alerta: PanelContainer = null
var _tween_alerta: Tween = null


func generar_problema() -> void:
	if objetivo_aleatorio:
		var candidatas_f1: Array[float] = []
		for n1 in F1_ESPIRAS:
			for i1 in F1_CORRIENTES:
				var b_c: float = float(n1) * i1 * F1_FACTOR
				if b_c >= 0.75 and is_zero_approx(fmod(round(b_c * 1000.0), 50.0)):
					if not candidatas_f1.has(b_c):
						candidatas_f1.append(b_c)
		if not candidatas_f1.is_empty():
			valor_objetivo_fase1 = candidatas_f1[randi() % candidatas_f1.size()]

		var n2_w: int = F2_ESPIRAS[randi_range(1, F2_ESPIRAS.size() - 1)]
		var f2_w: float = F2_FRECUENCIAS[randi_range(1, F2_FRECUENCIAS.size() - 1)]
		valor_objetivo_fase2 = valor_objetivo_fase1 * float(n2_w) * f2_w

	fase_actual = 1
	fase_1_ok = false
	fase_2_ok = false
	puerta_abierta = false
	idx_a = randi() % F1_ESPIRAS.size()
	idx_b = randi() % F1_CORRIENTES.size()
	var intentos := 0
	while intentos < 30 and is_equal_approx(_valor_actual(), valor_objetivo_fase1):
		idx_a = randi() % F1_ESPIRAS.size()
		idx_b = randi() % F1_CORRIENTES.size()
		intentos += 1


func _inicializar_puzzle() -> void:
	titulo_panel = "REACTOR MAESTRO — COMPUERTA FINAL"
	if lbl_titulo_ui != null:
		lbl_titulo_ui.text = titulo_panel
	if puerta_body != null:
		_pos_puerta_cerrada = puerta_body.position

	if portal_area != null:
		portal_area.collision_layer = 0
		portal_area.collision_mask = 1
		portal_area.monitoring = true
		if not portal_area.body_entered.is_connected(_on_portal_entered):
			portal_area.body_entered.connect(_on_portal_entered)

	_construir_banner_alerta()
	if not GameManager.archivos_recuperados_cambiados.is_connected(_on_archivos_cambiados):
		GameManager.archivos_recuperados_cambiados.connect(_on_archivos_cambiados)

	_actualizar_estado()


func _construir_contenido_panel(vbox: VBoxContainer) -> void:
	lbl_fase = Label.new()
	lbl_fase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_fase.add_theme_font_size_override("font_size", 13)
	lbl_fase.add_theme_color_override("font_color", COLOR_CIAN)
	vbox.add_child(lbl_fase)

	lbl_hud_estado = Label.new()
	lbl_hud_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_hud_estado.add_theme_font_size_override("font_size", 16)
	vbox.add_child(lbl_hud_estado)

	barra_reactor = ProgressBar.new()
	barra_reactor.custom_minimum_size = Vector2(0, 18)
	barra_reactor.show_percentage = false
	vbox.add_child(barra_reactor)

	lbl_formula = Label.new()
	lbl_formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_formula.add_theme_font_size_override("font_size", 14)
	vbox.add_child(lbl_formula)

	# Parámetro A (Espiras N1 / N2)
	var hb_a := HBoxContainer.new()
	hb_a.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_a.add_theme_constant_override("separation", 12)
	vbox.add_child(hb_a)

	var btn_am := Button.new()
	btn_am.text = "◀ [1 / S] -Espiras"
	btn_am.custom_minimum_size = Vector2(150, 34)
	btn_am.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_am, COLOR_CIAN)
	btn_am.pressed.connect(func(): _ajustar_a(-1))
	hb_a.add_child(btn_am)

	lbl_a_val = Label.new()
	lbl_a_val.custom_minimum_size = Vector2(160, 0)
	lbl_a_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_a_val.add_theme_font_size_override("font_size", 15)
	hb_a.add_child(lbl_a_val)

	var btn_ap := Button.new()
	btn_ap.text = "+Espiras [2 / W] ▶"
	btn_ap.custom_minimum_size = Vector2(150, 34)
	btn_ap.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_ap, COLOR_CIAN)
	btn_ap.pressed.connect(func(): _ajustar_a(1))
	hb_a.add_child(btn_ap)

	# Parámetro B (Corriente I1 / Frecuencia f)
	var hb_b := HBoxContainer.new()
	hb_b.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_b.add_theme_constant_override("separation", 12)
	vbox.add_child(hb_b)

	var btn_bm := Button.new()
	btn_bm.text = "◀ [A / ←] Reducir"
	btn_bm.custom_minimum_size = Vector2(150, 34)
	btn_bm.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_bm, COLOR_AMARILLO)
	btn_bm.pressed.connect(func(): _ajustar_b(-1))
	hb_b.add_child(btn_bm)

	lbl_b_val = Label.new()
	lbl_b_val.custom_minimum_size = Vector2(160, 0)
	lbl_b_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_b_val.add_theme_font_size_override("font_size", 15)
	hb_b.add_child(lbl_b_val)

	var btn_bp := Button.new()
	btn_bp.text = "Aumentar [D / →] ▶"
	btn_bp.custom_minimum_size = Vector2(150, 34)
	btn_bp.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_bp, COLOR_AMARILLO)
	btn_bp.pressed.connect(func(): _ajustar_b(1))
	hb_b.add_child(btn_bp)

	lbl_alerta_archivos_ui = Label.new()
	lbl_alerta_archivos_ui.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_alerta_archivos_ui.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_alerta_archivos_ui.add_theme_font_size_override("font_size", 12)
	vbox.add_child(lbl_alerta_archivos_ui)

	btn_accion = Button.new()
	btn_accion.text = "SINCRONIZAR FASE  [Enter]"
	btn_accion.custom_minimum_size = Vector2(0, 42)
	btn_accion.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_accion, COLOR_VERDE)
	btn_accion.pressed.connect(_ejecutar_accion)
	vbox.add_child(btn_accion)


func _al_abrir_panel() -> void:
	_actualizar_estado()


func _procesar_tecla_panel(kc: int) -> bool:
	match kc:
		KEY_1, KEY_KP_1, KEY_S, KEY_DOWN:
			_ajustar_a(-1)
			return true
		KEY_2, KEY_KP_2, KEY_W, KEY_UP:
			_ajustar_a(1)
			return true
		KEY_A, KEY_LEFT:
			_ajustar_b(-1)
			return true
		KEY_D, KEY_RIGHT:
			_ajustar_b(1)
			return true
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_ejecutar_accion()
			return true
	return false


func _valor_actual() -> float:
	if fase_actual == 1:
		return float(F1_ESPIRAS[idx_a]) * F1_CORRIENTES[idx_b] * F1_FACTOR
	return valor_objetivo_fase1 * float(F2_ESPIRAS[idx_a]) * F2_FRECUENCIAS[idx_b]


func _ajustar_a(d: int) -> void:
	var max_i := (F1_ESPIRAS.size() - 1) if fase_actual == 1 else (F2_ESPIRAS.size() - 1)
	idx_a = clampi(idx_a + d, 0, max_i)
	_evaluar()


func _ajustar_b(d: int) -> void:
	var max_i := (F1_CORRIENTES.size() - 1) if fase_actual == 1 else (F2_FRECUENCIAS.size() - 1)
	idx_b = clampi(idx_b + d, 0, max_i)
	_evaluar()


func _evaluar() -> void:
	var val := _valor_actual()
	if fase_actual == 1 and is_equal_approx(val, valor_objetivo_fase1):
		fase_1_ok = true
	elif fase_actual == 2 and is_equal_approx(val, valor_objetivo_fase2):
		fase_2_ok = true
		if _tiene_archivos_requeridos() and not puerta_abierta:
			_abrir_compuerta()
		elif not _tiene_archivos_requeridos():
			_mostrar_aviso_acceso_denegado()
	_actualizar_estado()


func _ejecutar_accion() -> void:
	if puerta_abierta or fase_2_ok:
		if not _tiene_archivos_requeridos():
			_mostrar_aviso_acceso_denegado()
			_actualizar_estado()
			return
		if not puerta_abierta:
			_abrir_compuerta()
		_cargar_siguiente_nivel()
		return
	var val := _valor_actual()
	if fase_actual == 1:
		if fase_1_ok or is_equal_approx(val, valor_objetivo_fase1):
			fase_1_ok = true
			fase_actual = 2
			idx_a = randi() % F2_ESPIRAS.size()
			idx_b = randi() % F2_FRECUENCIAS.size()
			var intentos := 0
			while intentos < 30 and is_equal_approx(_valor_actual(), valor_objetivo_fase2):
				idx_a = randi() % F2_ESPIRAS.size()
				idx_b = randi() % F2_FRECUENCIAS.size()
				intentos += 1
			_actualizar_estado()
	else:
		if is_equal_approx(val, valor_objetivo_fase2):
			fase_2_ok = true
			if _tiene_archivos_requeridos():
				_abrir_compuerta()
			else:
				_mostrar_aviso_acceso_denegado()
			_actualizar_estado()


func _abrir_compuerta() -> void:
	if puerta_abierta:
		return
	puerta_abierta = true
	if puerta_col != null:
		puerta_col.set_deferred("disabled", true)
	if puerta_sprite != null:
		puerta_sprite.modulate = Color(0.4, 1.0, 0.65, 0.85)
	if puerta_body != null and is_inside_tree():
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(puerta_body, "position", _pos_puerta_cerrada - Vector2(0, 116), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_actualizar_estado()


func _tiene_archivos_requeridos() -> bool:
	if not requiere_archivos_clasificados:
		return true
	return GameManager.tiene_archivos_recuperados()


func _on_archivos_cambiados(recuperados: bool) -> void:
	if recuperados and fase_2_ok and not puerta_abierta:
		_abrir_compuerta()
	_actualizar_estado()


func _actualizar_estado() -> void:
	var val := _valor_actual()
	var archivos_ok := _tiene_archivos_requeridos()

	if lbl_alerta_archivos_ui != null:
		if archivos_ok:
			lbl_alerta_archivos_ui.text = "📁 ARCHIVOS CLASIFICADOS: RECUPERADOS ✓ (Acceso autorizado)"
			lbl_alerta_archivos_ui.add_theme_color_override("font_color", COLOR_VERDE)
		else:
			lbl_alerta_archivos_ui.text = "⚠ ACCESO DENEGADO SIN ARCHIVOS — Recupéralos del estante [E] antes de cruzar"
			lbl_alerta_archivos_ui.add_theme_color_override("font_color", COLOR_ROJO)

	if fase_actual == 1:
		var en_meta := is_equal_approx(val, valor_objetivo_fase1)
		var col: Color = COLOR_VERDE if en_meta else (COLOR_ROJO if val > valor_objetivo_fase1 + 0.02 else COLOR_AMARILLO)
		if lbl_fase != null:
			lbl_fase.text = "FASE 1 / 2: CONFINAMIENTO MAGNÉTICO (B = 0.0025 × N₁ × I₁)"
			lbl_hud_estado.text = "OBJETIVO: %.2f T   |   ACTUAL: %.2f T" % [valor_objetivo_fase1, val]
			lbl_hud_estado.add_theme_color_override("font_color", col)
			actualizar_barra(barra_reactor, val, valor_objetivo_fase1 * 1.6, col)
			lbl_a_val.text = "N₁ = %d esp" % F1_ESPIRAS[idx_a]
			lbl_b_val.text = "I₁ = %.1f A" % F1_CORRIENTES[idx_b]
			lbl_formula.text = "B = 0.0025 × %d × %.1f A = %.2f T" % [F1_ESPIRAS[idx_a], F1_CORRIENTES[idx_b], val]
			lbl_formula.add_theme_color_override("font_color", col)
			btn_accion.text = "AVANZAR A FASE 2/2  [Enter]" if en_meta else "CALIBRA %.2f T PARA CONTINUAR" % valor_objetivo_fase1
	else:
		var en_meta := is_equal_approx(val, valor_objetivo_fase2) or fase_2_ok or puerta_abierta
		var col: Color = COLOR_VERDE if en_meta else (COLOR_ROJO if val > valor_objetivo_fase2 + 2.0 else COLOR_AMARILLO)
		if lbl_fase != null:
			lbl_fase.text = "FASE 2 / 2: RESONANCIA (P = %.2f T × N₂ × f)" % valor_objetivo_fase1
			lbl_hud_estado.text = "OBJETIVO: %.1f kW   |   ACTUAL: %.1f kW" % [valor_objetivo_fase2, val]
			lbl_hud_estado.add_theme_color_override("font_color", col)
			actualizar_barra(barra_reactor, val, valor_objetivo_fase2 * 1.6, col)
			lbl_a_val.text = "N₂ = %d esp" % F2_ESPIRAS[idx_a]
			lbl_b_val.text = "f = %.1f Hz" % F2_FRECUENCIAS[idx_b]
			lbl_formula.text = "P = %.2f × %d × %.1f Hz = %.1f kW" % [valor_objetivo_fase1, F2_ESPIRAS[idx_a], F2_FRECUENCIAS[idx_b], val]
			lbl_formula.add_theme_color_override("font_color", col)
			if puerta_abierta and archivos_ok:
				btn_accion.text = "ENTRAR AL SIGUIENTE NIVEL ▶  [Enter]"
			elif fase_2_ok and not archivos_ok:
				btn_accion.text = "🔒 FALTAN LOS ARCHIVOS DEL ESTANTE"
			else:
				btn_accion.text = "CALIBRA %.1f kW PARA ABRIR" % valor_objetivo_fase2

	if lbl_estado_puerta != null:
		if puerta_abierta and archivos_ok:
			lbl_estado_puerta.text = "COMPUERTA MAESTRA ABIERTA — AVANZA"
			lbl_estado_puerta.add_theme_color_override("font_color", COLOR_VERDE)
		elif fase_2_ok and not archivos_ok:
			lbl_estado_puerta.text = "🔒 ACCESO DENEGADO: RECUPERA LOS ARCHIVOS DEL ESTANTE"
			lbl_estado_puerta.add_theme_color_override("font_color", COLOR_ROJO)
		elif fase_1_ok:
			lbl_estado_puerta.text = "FASE 1 LISTA — CALIBRA FASE 2"
			lbl_estado_puerta.add_theme_color_override("font_color", COLOR_CIAN)
		elif not archivos_ok:
			lbl_estado_puerta.text = "COMPUERTA BLOQUEADA (2 FASES + ARCHIVOS DEL ESTANTE)"
			lbl_estado_puerta.add_theme_color_override("font_color", COLOR_AMARILLO)
		else:
			lbl_estado_puerta.text = "ARCHIVOS OK ✓ — CALIBRA COMPUERTA (2 FASES)"
			lbl_estado_puerta.add_theme_color_override("font_color", COLOR_CIAN)


func _on_portal_entered(body: Node2D) -> void:
	if not es_jugador(body) or _transicion_lanzada:
		return
	if not _tiene_archivos_requeridos():
		_mostrar_aviso_acceso_denegado()
		return
	if puerta_abierta:
		_cargar_siguiente_nivel()


func _cargar_siguiente_nivel() -> void:
	if _transicion_lanzada:
		return
	if not _tiene_archivos_requeridos():
		_mostrar_aviso_acceso_denegado()
		return
	_transicion_lanzada = true
	if panel_abierto:
		cerrar_panel()
	get_tree().paused = false
	GameManager.completar_meta_nivel(ruta_siguiente_escena, global_position)
	if not ruta_siguiente_escena.is_empty() and ResourceLoader.exists(ruta_siguiente_escena):
		get_tree().change_scene_to_file(ruta_siguiente_escena)


func _construir_banner_alerta() -> void:
	_canvas_alerta = CanvasLayer.new()
	_canvas_alerta.name = "CanvasAlertaArchivos"
	_canvas_alerta.layer = 85
	_canvas_alerta.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas_alerta)

	var cont_top := MarginContainer.new()
	cont_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	cont_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cont_top.add_theme_constant_override("margin_top", 78)
	_canvas_alerta.add_child(cont_top)

	var centro := CenterContainer.new()
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cont_top.add_child(centro)

	_panel_alerta = PanelContainer.new()
	_panel_alerta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_alerta.visible = false
	_panel_alerta.modulate.a = 0.0

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.24, 0.04, 0.07, 0.96)
	sb.border_color = COLOR_ROJO
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	_panel_alerta.add_theme_stylebox_override("panel", sb)
	centro.add_child(_panel_alerta)

	var lbl := Label.new()
	lbl.name = "LblAlerta"
	lbl.text = "⚠  " + MSG_ACCESO_DENEGADO
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.80, 0.82))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	_panel_alerta.add_child(lbl)


func _mostrar_aviso_acceso_denegado() -> void:
	if _panel_alerta == null:
		return
	var lbl := _panel_alerta.get_node_or_null("LblAlerta") as Label
	if lbl != null:
		lbl.text = "⚠  " + MSG_ACCESO_DENEGADO
	_panel_alerta.visible = true
	_panel_alerta.modulate.a = 1.0

	if _tween_alerta != null:
		_tween_alerta.kill()
	_tween_alerta = create_tween()
	_tween_alerta.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween_alerta.tween_interval(3.2)
	_tween_alerta.tween_property(_panel_alerta, "modulate:a", 0.0, 0.7)
	_tween_alerta.tween_callback(func(): _panel_alerta.visible = false)
