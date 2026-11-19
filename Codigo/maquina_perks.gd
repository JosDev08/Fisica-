extends Area2D

# ==============================================================================
# MÁQUINA EXPENDEDORA DE MEJORAS BALANCEADAS (res://Escenas/MaquinaPerks.tscn)
# Area2D con collision_mask = 1 (Capa 1: Jugador) y detección directa de KEY_E.
# Permite comprar únicamente las 3 mejoras de partida (Jugger-Nog, Stamin-Up,
# Double Tap) con mouse o teclado en un CanvasLayer limpio.
# ==============================================================================

const COLOR_FONDO := Color(0.04, 0.07, 0.13, 0.96)
const COLOR_CIAN := Color(0.24, 0.88, 1.0)
const COLOR_ORO := Color(0.98, 0.82, 0.28)
const COLOR_VERDE := Color(0.24, 0.94, 0.55)
const COLOR_ROJO := Color(1.0, 0.34, 0.36)

@onready var lbl_prompt: Label = $PromptInteractuar

var _jugador_cerca: bool = false
var _panel_abierto: bool = false
var _tecla_e_prev: bool = false
var _indice_sel: int = 0
var _catalogo: Array[Dictionary] = []

# Nodos de UI en CanvasLayer
var _canvas_ui: CanvasLayer
var _panel_tienda: PanelContainer
var _lbl_monedas_ui: Label
var _lbl_feedback: Label
var _tarjetas: Array[PanelContainer] = []
var _botones_compra: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	collision_layer = 0
	collision_mask = 1 # Capa 1: Jugador
	monitoring = true
	monitorable = true

	if lbl_prompt != null:
		lbl_prompt.text = "[E] Interactuar"
		lbl_prompt.visible = false
		lbl_prompt.add_to_group("texto_mundo_flotante")

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	_catalogo = GameManager.obtener_catalogo_mejoras()
	_construir_ui()

	GameManager.monedas_cambiadas.connect(func(_c): _actualizar_ui())
	GameManager.mejoras_cambiadas.connect(func(_m): _actualizar_ui())


func _process(_delta: float) -> void:
	if GameManager.jugador_muerto:
		if _panel_abierto:
			_cerrar_tienda()
		return

	# Comprobación continua de proximidad por seguridad física
	var detectado: bool = false
	if monitoring:
		for b in get_overlapping_bodies():
			if _es_jugador(b):
				detectado = true
				break
	_jugador_cerca = detectado

	if lbl_prompt != null:
		lbl_prompt.visible = _jugador_cerca and not _panel_abierto

	# Detección directa de tecla física KEY_E
	var e_actual: bool = Input.is_physical_key_pressed(KEY_E)
	if e_actual and not _tecla_e_prev:
		if _panel_abierto:
			_cerrar_tienda()
		elif _jugador_cerca and not get_tree().paused and not GameManager.hay_modal_interactivo_abierto():
			_abrir_tienda()
	_tecla_e_prev = e_actual


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.jugador_muerto:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	var kc: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode

	if _panel_abierto:
		match kc:
			KEY_ESCAPE, KEY_E:
				_tecla_e_prev = true
				_cerrar_tienda()
				get_viewport().set_input_as_handled()
			KEY_UP, KEY_W, KEY_LEFT, KEY_A:
				_seleccionar_tarjeta((_indice_sel - 1 + _catalogo.size()) % _catalogo.size())
				get_viewport().set_input_as_handled()
			KEY_DOWN, KEY_S, KEY_RIGHT, KEY_D:
				_seleccionar_tarjeta((_indice_sel + 1) % _catalogo.size())
				get_viewport().set_input_as_handled()
			KEY_1, KEY_KP_1:
				_seleccionar_tarjeta(0)
				_intentar_comprar(0)
				get_viewport().set_input_as_handled()
			KEY_2, KEY_KP_2:
				_seleccionar_tarjeta(1)
				_intentar_comprar(1)
				get_viewport().set_input_as_handled()
			KEY_3, KEY_KP_3:
				_seleccionar_tarjeta(2)
				_intentar_comprar(2)
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_intentar_comprar(_indice_sel)
				get_viewport().set_input_as_handled()
	elif _jugador_cerca and kc == KEY_E and not get_tree().paused and not GameManager.hay_modal_interactivo_abierto():
		_tecla_e_prev = true
		_abrir_tienda()
		get_viewport().set_input_as_handled()


func _es_jugador(body: Node) -> bool:
	if body == null:
		return false
	return body.is_in_group("jugador") or body.name == "Jugador" or body.name == "CharacterBody2D"


func _on_body_entered(body: Node2D) -> void:
	if _es_jugador(body):
		_jugador_cerca = true
		if lbl_prompt != null and not _panel_abierto:
			lbl_prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if _es_jugador(body):
		_jugador_cerca = false
		if lbl_prompt != null:
			lbl_prompt.visible = false


func _abrir_tienda() -> void:
	_panel_abierto = true
	_canvas_ui.visible = true
	if lbl_prompt != null:
		lbl_prompt.visible = false
	_lbl_feedback.text = "Selecciona una mejora con clic o teclado [W/S, 1-3, Enter]."
	_lbl_feedback.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	GameManager.registrar_modal_abierto(true)
	get_tree().paused = true
	_actualizar_ui()


func _cerrar_tienda() -> void:
	if not _panel_abierto:
		return
	_panel_abierto = false
	_canvas_ui.visible = false
	GameManager.registrar_modal_abierto(false)
	get_tree().paused = false
	if lbl_prompt != null:
		lbl_prompt.visible = _jugador_cerca


func _seleccionar_tarjeta(idx: int) -> void:
	if _catalogo.is_empty():
		return
	_indice_sel = clampi(idx, 0, _catalogo.size() - 1)
	_actualizar_ui()


func _intentar_comprar(idx: int) -> void:
	if idx < 0 or idx >= _catalogo.size():
		return
	var id_mejora: String = str(_catalogo[idx]["id"])
	var resultado: Dictionary = GameManager.comprar_mejora(id_mejora)
	_lbl_feedback.text = str(resultado.get("mensaje", ""))
	if bool(resultado.get("ok", false)):
		_lbl_feedback.add_theme_color_override("font_color", COLOR_VERDE)
	else:
		_lbl_feedback.add_theme_color_override("font_color", COLOR_ROJO)
	_actualizar_ui()


func _actualizar_ui() -> void:
	if _canvas_ui == null:
		return
	_lbl_monedas_ui.text = "⚡ %d MONEDAS" % GameManager.monedas_rayo

	for i in range(_catalogo.size()):
		var info: Dictionary = _catalogo[i]
		var id_m: String = str(info["id"])
		var costo: int = int(info["costo"])
		var color_m: Color = info["color"]
		var equipada: bool = GameManager.tiene_mejora(id_m)
		var alcanzable: bool = GameManager.monedas_rayo >= costo
		var seleccionada: bool = (i == _indice_sel)

		var tarjeta := _tarjetas[i]
		var sb_card := StyleBoxFlat.new()
		sb_card.set_corner_radius_all(0)
		sb_card.set_border_width_all(3 if seleccionada else 2)
		sb_card.set_content_margin_all(12)
		if equipada:
			sb_card.bg_color = Color(0.06, 0.18, 0.12, 0.96)
			sb_card.border_color = COLOR_VERDE if seleccionada else COLOR_VERDE.darkened(0.25)
		elif seleccionada:
			sb_card.bg_color = color_m.darkened(0.76)
			sb_card.border_color = color_m
		else:
			sb_card.bg_color = Color(0.06, 0.10, 0.17, 0.94)
			sb_card.border_color = Color(0.24, 0.34, 0.46, 0.9)
		tarjeta.add_theme_stylebox_override("panel", sb_card)

		var btn := _botones_compra[i]
		if equipada:
			btn.text = "EQUIPADO"
			btn.disabled = true
			_estilizar_boton(btn, COLOR_VERDE, true)
		elif alcanzable:
			btn.text = "COMPRAR [%d ⚡]" % costo
			btn.disabled = false
			_estilizar_boton(btn, color_m, false)
		else:
			btn.text = "FALTAN [%d ⚡]" % costo
			btn.disabled = true
			_estilizar_boton(btn, Color(0.45, 0.50, 0.58), true)


func _construir_ui() -> void:
	_canvas_ui = CanvasLayer.new()
	_canvas_ui.name = "CanvasMaquinaPerks"
	_canvas_ui.layer = 15
	_canvas_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas_ui.visible = false
	add_child(_canvas_ui)

	var fondo := ColorRect.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.01, 0.03, 0.07, 0.75)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas_ui.add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.add_child(centro)

	_panel_tienda = PanelContainer.new()
	_panel_tienda.custom_minimum_size = Vector2(640, 0)
	_panel_tienda.add_theme_stylebox_override("panel", _crear_caja(COLOR_FONDO, COLOR_CIAN, 3, 22))
	centro.add_child(_panel_tienda)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_panel_tienda.add_child(vbox)

	# Encabezado: Título + Monedas + Botón cerrar
	var hbox_top := HBoxContainer.new()
	hbox_top.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox_top)

	var lbl_titulo := Label.new()
	lbl_titulo.text = "EXPENDEDORA DE MEJORAS"
	lbl_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_titulo.add_theme_font_size_override("font_size", 22)
	lbl_titulo.add_theme_color_override("font_color", COLOR_CIAN)
	lbl_titulo.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_titulo.add_theme_constant_override("outline_size", 4)
	hbox_top.add_child(lbl_titulo)

	_lbl_monedas_ui = Label.new()
	_lbl_monedas_ui.text = "⚡ 0 MONEDAS"
	_lbl_monedas_ui.add_theme_font_size_override("font_size", 17)
	_lbl_monedas_ui.add_theme_color_override("font_color", COLOR_ORO)
	_lbl_monedas_ui.add_theme_color_override("font_outline_color", Color.BLACK)
	_lbl_monedas_ui.add_theme_constant_override("outline_size", 4)
	hbox_top.add_child(_lbl_monedas_ui)

	var btn_x := Button.new()
	btn_x.text = "[X] Cerrar"
	btn_x.focus_mode = Control.FOCUS_NONE
	_estilizar_boton(btn_x, COLOR_ROJO, false)
	btn_x.pressed.connect(_cerrar_tienda)
	hbox_top.add_child(btn_x)

	var lbl_sub := Label.new()
	lbl_sub.text = "Las mejoras compradas se conservan durante toda la partida activa."
	lbl_sub.add_theme_font_size_override("font_size", 12)
	lbl_sub.add_theme_color_override("font_color", Color(0.72, 0.84, 0.96))
	vbox.add_child(lbl_sub)

	# Tarjetas de las 3 mejoras balanceadas
	_tarjetas.clear()
	_botones_compra.clear()
	for i in range(_catalogo.size()):
		var info: Dictionary = _catalogo[i]
		var card := PanelContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		var idx_local: int = i
		card.mouse_entered.connect(func(): _seleccionar_tarjeta(idx_local))
		vbox.add_child(card)
		_tarjetas.append(card)

		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 14)
		card.add_child(fila)

		var ico := TextureRect.new()
		ico.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ico.custom_minimum_size = Vector2(44, 44)
		ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var tex := load(str(info["icono"])) as Texture2D
		if tex != null:
			ico.texture = tex
		fila.add_child(ico)

		var textos := VBoxContainer.new()
		textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		textos.add_theme_constant_override("separation", 3)
		fila.add_child(textos)

		var lbl_nom := Label.new()
		lbl_nom.text = "[%d] %s  —  %s" % [i + 1, str(info["nombre"]), str(info["subtitulo"])]
		lbl_nom.add_theme_font_size_override("font_size", 16)
		lbl_nom.add_theme_color_override("font_color", info["color"].lightened(0.25))
		textos.add_child(lbl_nom)

		var lbl_desc := Label.new()
		lbl_desc.text = str(info["descripcion"])
		lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_desc.add_theme_font_size_override("font_size", 12)
		lbl_desc.add_theme_color_override("font_color", Color(0.86, 0.92, 0.98))
		textos.add_child(lbl_desc)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 42)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 13)
		btn.mouse_entered.connect(func(): _seleccionar_tarjeta(idx_local))
		btn.pressed.connect(func():
			_seleccionar_tarjeta(idx_local)
			_intentar_comprar(idx_local)
		)
		fila.add_child(btn)
		_botones_compra.append(btn)

	_lbl_feedback = Label.new()
	_lbl_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_feedback.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_lbl_feedback)

	var lbl_atajos := Label.new()
	lbl_atajos.text = "Controles: [W/S / ↑↓] Elegir   •   [1/2/3 / Enter / Clic] Comprar   •   [E / ESC] Salir"
	lbl_atajos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_atajos.add_theme_font_size_override("font_size", 11)
	lbl_atajos.add_theme_color_override("font_color", Color(0.60, 0.74, 0.88))
	vbox.add_child(lbl_atajos)


func _crear_caja(fondo: Color, borde: Color, grosor: int, margen: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.border_color = borde
	sb.set_border_width_all(grosor)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(margen)
	return sb


func _estilizar_boton(btn: Button, color: Color, deshabilitado: bool) -> void:
	var sb_n := _crear_caja(color.darkened(0.75), color, 2, 8)
	var sb_h := _crear_caja(color.darkened(0.55), color.lightened(0.2), 2, 8)
	var sb_p := _crear_caja(color.darkened(0.40), Color.WHITE, 2, 8)
	if deshabilitado:
		sb_n.bg_color = color.darkened(0.82)
		sb_n.border_color = color.darkened(0.35)
	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_p)
	btn.add_theme_stylebox_override("disabled", sb_n)
	btn.add_theme_stylebox_override("focus", sb_h)
	btn.add_theme_color_override("font_color", color.lightened(0.35))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", color.lightened(0.15))
