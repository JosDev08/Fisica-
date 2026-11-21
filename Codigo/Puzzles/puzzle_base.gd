extends Node2D

# ==============================================================================
# CLASE BASE DE PUZZLES MODULARES (res://Codigo/Puzzles/puzzle_base.gd)
# Gestiona de forma unificada:
# - Area2D de terminal en Capa 1 (Jugador) con monitoring = true y "[E] Interactuar"
# - Activación física con KEY_E y cierre con ESC / E / botón Cerrar
# - Panel UI limpio en CanvasLayer (layer = 50, PROCESS_MODE_ALWAYS)
# - Bloqueo total de disparos del jugador mientras el panel está abierto
# ==============================================================================

const COLOR_FONDO := Color(0.04, 0.07, 0.13, 0.96)
const COLOR_CIAN := Color(0.24, 0.88, 1.0)
const COLOR_VERDE := Color(0.24, 0.95, 0.55)
const COLOR_AMARILLO := Color(0.98, 0.84, 0.30)
const COLOR_ROJO := Color(1.0, 0.34, 0.36)

@export var titulo_panel: String = "TERMINAL DE FÍSICA"
@export var texto_prompt: String = "[E] Interactuar"
@export var ancho_panel: float = 620.0

var jugador_cerca: bool = false
var panel_abierto: bool = false
var _tecla_e_prev: bool = false

var terminal_area: Area2D
var lbl_prompt: Label

var canvas_ui: CanvasLayer
var panel_ui: PanelContainer
var lbl_titulo_ui: Label
var vbox_contenido: VBoxContainer


func _ready() -> void:
	randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	generar_problema()
	_vincular_terminal()
	_construir_ui_base()
	_inicializar_puzzle()


func _vincular_terminal() -> void:
	terminal_area = get_node_or_null("TerminalArea") as Area2D
	if terminal_area != null:
		terminal_area.collision_layer = 0
		terminal_area.collision_mask = 1 # Capa 1: Jugador
		terminal_area.monitoring = true
		terminal_area.monitorable = true
		if not terminal_area.body_entered.is_connected(_on_terminal_body_entered):
			terminal_area.body_entered.connect(_on_terminal_body_entered)
		if not terminal_area.body_exited.is_connected(_on_terminal_body_exited):
			terminal_area.body_exited.connect(_on_terminal_body_exited)

		lbl_prompt = terminal_area.get_node_or_null("PromptInteractuar") as Label
		if lbl_prompt != null:
			lbl_prompt.text = texto_prompt
			lbl_prompt.visible = false
			lbl_prompt.add_to_group("texto_mundo_flotante")


func _construir_ui_base() -> void:
	canvas_ui = CanvasLayer.new()
	canvas_ui.name = "CanvasPuzzleUI"
	canvas_ui.layer = 50
	canvas_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas_ui.visible = false
	add_child(canvas_ui)

	var fondo := ColorRect.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.01, 0.03, 0.07, 0.78)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas_ui.add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.add_child(centro)

	panel_ui = PanelContainer.new()
	panel_ui.custom_minimum_size = Vector2(ancho_panel, 0)
	panel_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	panel_ui.focus_mode = Control.FOCUS_NONE
	panel_ui.add_theme_stylebox_override("panel", crear_caja(COLOR_FONDO, COLOR_CIAN, 3, 20))
	centro.add_child(panel_ui)

	vbox_contenido = VBoxContainer.new()
	vbox_contenido.add_theme_constant_override("separation", 10)
	panel_ui.add_child(vbox_contenido)

	# Cabecera común con título y botón [X] Cerrar
	var barra_top := HBoxContainer.new()
	barra_top.add_theme_constant_override("separation", 10)
	vbox_contenido.add_child(barra_top)

	lbl_titulo_ui = Label.new()
	lbl_titulo_ui.text = titulo_panel
	lbl_titulo_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_titulo_ui.add_theme_font_size_override("font_size", 18)
	lbl_titulo_ui.add_theme_color_override("font_color", COLOR_CIAN)
	lbl_titulo_ui.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_titulo_ui.add_theme_constant_override("outline_size", 4)
	barra_top.add_child(lbl_titulo_ui)

	var btn_cerrar_x := Button.new()
	btn_cerrar_x.text = "[X] Cerrar"
	btn_cerrar_x.focus_mode = Control.FOCUS_NONE
	estilizar_boton(btn_cerrar_x, COLOR_ROJO)
	btn_cerrar_x.pressed.connect(cerrar_panel)
	barra_top.add_child(btn_cerrar_x)

	_construir_contenido_panel(vbox_contenido)


func _process(delta: float) -> void:
	if GameManager.jugador_muerto:
		if panel_abierto:
			cerrar_panel()
		return

	if terminal_area != null and terminal_area.monitoring:
		var detectado := false
		for b in terminal_area.get_overlapping_bodies():
			if es_jugador(b):
				detectado = true
				break
		jugador_cerca = detectado
		if lbl_prompt != null:
			lbl_prompt.visible = jugador_cerca and not panel_abierto

	var e_actual: bool = Input.is_physical_key_pressed(KEY_E)
	if e_actual and not _tecla_e_prev:
		if panel_abierto:
			cerrar_panel()
		elif jugador_cerca and not get_tree().paused and not GameManager.hay_modal_interactivo_abierto():
			abrir_panel()
	_tecla_e_prev = e_actual

	if panel_abierto:
		_procesar_animacion_panel(delta)
	_procesar_mundo(delta)


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.jugador_muerto:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var kc: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode

	if panel_abierto:
		if kc == KEY_ESCAPE or kc == KEY_E:
			_tecla_e_prev = true
			cerrar_panel()
			get_viewport().set_input_as_handled()
		elif _procesar_tecla_panel(kc):
			get_viewport().set_input_as_handled()
	elif jugador_cerca and kc == KEY_E and not get_tree().paused and not GameManager.hay_modal_interactivo_abierto():
		_tecla_e_prev = true
		abrir_panel()
		get_viewport().set_input_as_handled()


func abrir_panel() -> void:
	if panel_abierto:
		return
	panel_abierto = true
	canvas_ui.visible = true
	if lbl_prompt != null:
		lbl_prompt.visible = false
	GameManager.registrar_modal_abierto(true)
	get_tree().paused = true
	_al_abrir_panel()


func cerrar_panel() -> void:
	if not panel_abierto:
		return
	panel_abierto = false
	canvas_ui.visible = false
	get_tree().paused = false
	call_deferred("_liberar_bloqueo_modal")
	if lbl_prompt != null:
		lbl_prompt.visible = jugador_cerca
	_al_cerrar_panel()


func _liberar_bloqueo_modal() -> void:
	GameManager.registrar_modal_abierto(false)


func es_jugador(body: Node) -> bool:
	if body == null:
		return false
	if body.is_in_group("jugador") or body.name == "Jugador" or body.name == "CharacterBody2D":
		return true
	if body is CollisionObject2D:
		return (((body as CollisionObject2D).collision_layer & 1) != 0)
	return false


func _on_terminal_body_entered(body: Node2D) -> void:
	if es_jugador(body):
		jugador_cerca = true
		if lbl_prompt != null and not panel_abierto:
			lbl_prompt.visible = true


func _on_terminal_body_exited(body: Node2D) -> void:
	if es_jugador(body):
		jugador_cerca = false
		if lbl_prompt != null:
			lbl_prompt.visible = false


# Métodos virtuales para sobrescribir en cada puzzle concreto
func generar_problema() -> void:
	pass

func _inicializar_puzzle() -> void:
	pass

func _construir_contenido_panel(_vbox: VBoxContainer) -> void:
	pass

func _al_abrir_panel() -> void:
	pass

func _al_cerrar_panel() -> void:
	pass

func _procesar_tecla_panel(_kc: int) -> bool:
	return false

func _procesar_animacion_panel(_delta: float) -> void:
	pass

func _procesar_mundo(_delta: float) -> void:
	pass


# Helpers visuales reutilizables estilo pixel art
func crear_caja(fondo: Color, borde: Color, grosor: int = 2, margen: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.border_color = borde
	sb.set_border_width_all(grosor)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(margen)
	return sb


func estilizar_boton(btn: Button, color: Color, deshabilitado: bool = false) -> void:
	var sb_n := crear_caja(color.darkened(0.76), color, 2, 8)
	var sb_h := crear_caja(color.darkened(0.56), color.lightened(0.2), 2, 8)
	var sb_p := crear_caja(color.darkened(0.42), Color.WHITE, 2, 8)
	if deshabilitado:
		sb_n.bg_color = color.darkened(0.84)
		sb_n.border_color = color.darkened(0.4)
	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_p)
	btn.add_theme_stylebox_override("disabled", sb_n)
	btn.add_theme_stylebox_override("focus", sb_h)
	btn.add_theme_color_override("font_color", color.lightened(0.35))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.56, 0.64))


func actualizar_barra(barra: ProgressBar, valor: float, maximo: float, color: Color) -> void:
	if barra == null:
		return
	barra.max_value = maxf(1.0, maximo)
	barra.value = clampf(valor, 0.0, barra.max_value)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.12, 0.18, 0.96)
	bg.set_corner_radius_all(0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(0)
	barra.add_theme_stylebox_override("background", bg)
	barra.add_theme_stylebox_override("fill", fill)


# Genera exactamente 4 opciones enteras únicas (1 correcta + 3 distractores) mezcladas.
func construir_opciones_int(correcta: int, distractores_cand: Array[int], min_val: int = 1, max_val: int = 999999, paso_respaldo: int = 2) -> Array[int]:
	var opciones: Array[int] = [correcta]
	for cand in distractores_cand:
		if opciones.size() >= 4:
			break
		if cand >= min_val and cand <= max_val and not opciones.has(cand):
			opciones.append(cand)

	var intento: int = 1
	while opciones.size() < 4 and intento < 50:
		var delta: int = intento * maxi(1, paso_respaldo)
		var arriba: int = correcta + delta
		var abajo: int = correcta - delta
		if arriba >= min_val and arriba <= max_val and not opciones.has(arriba):
			opciones.append(arriba)
		elif abajo >= min_val and abajo <= max_val and not opciones.has(abajo):
			opciones.append(abajo)
		intento += 1

	opciones.shuffle()
	return opciones


func indice_inicial_no_correcto(opciones: Array[int], correcta: int) -> int:
	for i in range(opciones.size()):
		if opciones[i] != correcta:
			return i
	return 0
