extends Control

# ==============================================================================
# PANTALLA PRINCIPAL / DE CARGA (res://Escenas/UI/MenuPrincipal.tscn)
# Interfaz pixel art pulida con 2 botones principales: Jugar y Continuar.
# ==============================================================================

const COLOR_FONDO := Color(0.03, 0.06, 0.11, 1.0)
const COLOR_GRID := Color(0.08, 0.18, 0.28, 0.42)
const COLOR_CIAN := Color(0.22, 0.88, 1.0, 1.0)
const COLOR_ORO := Color(0.98, 0.80, 0.25, 1.0)
const COLOR_VERDE := Color(0.24, 0.94, 0.56, 1.0)

@onready var btn_jugar: Button = %BtnJugar
@onready var btn_continuar: Button = %BtnContinuar
@onready var lbl_estado_guardado: Label = %LblEstadoGuardado

var _tiempo_anim: float = 0.0
var _puede_continuar: bool = false
var _indice_seleccion: int = 0
var _chispas: Array[Dictionary] = []


func _ready() -> void:
	get_tree().paused = false
	_generar_chispas()
	_aplicar_estilos_pixel()
	_actualizar_estado_guardado()

	btn_jugar.pressed.connect(_on_jugar_pressed)
	btn_continuar.pressed.connect(_on_continuar_pressed)

	btn_jugar.mouse_entered.connect(func(): _seleccionar_indice(0))
	btn_continuar.mouse_entered.connect(func():
		if _puede_continuar:
			_seleccionar_indice(1)
	)

	_seleccionar_indice(1 if _puede_continuar else 0)


func _process(delta: float) -> void:
	_tiempo_anim += delta
	for c in _chispas:
		c["y"] = float(c["y"]) - float(c["vel"]) * delta
		if float(c["y"]) < -8.0:
			c["y"] = size.y + 8.0
			c["x"] = randf() * maxf(size.x, 1152.0)
	queue_redraw()


func _draw() -> void:
	# Fondo principal nocturno pixel-lab
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_FONDO, true)

	# Cuadrícula técnica pixelada con desplazamiento sutil
	var paso: float = 32.0
	var offset_y: float = fmod(_tiempo_anim * 12.0, paso)
	var x: float = 0.0
	while x < size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), COLOR_GRID, 1.0)
		x += paso
	var y: float = offset_y - paso
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), COLOR_GRID, 1.0)
		y += paso

	# Chispas pixeladas ascendentes
	for c in _chispas:
		var parpadeo: float = 0.45 + 0.55 * sin(_tiempo_anim * float(c["freq"]) + float(c["fase"]))
		var col: Color = c["color"]
		col.a = parpadeo * 0.75
		var s: float = float(c["tam"])
		draw_rect(Rect2(floor(float(c["x"])), floor(float(c["y"])), s, s), col, true)

	# Marco perimetral retro pixel art
	draw_rect(Rect2(12, 12, maxf(0.0, size.x - 24.0), maxf(0.0, size.y - 24.0)), Color(0.16, 0.45, 0.65, 0.55), false, 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var kc: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if kc in [KEY_UP, KEY_W]:
		_seleccionar_indice(0)
		get_viewport().set_input_as_handled()
	elif kc in [KEY_DOWN, KEY_S]:
		if _puede_continuar:
			_seleccionar_indice(1)
		get_viewport().set_input_as_handled()
	elif kc in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		if _indice_seleccion == 1 and _puede_continuar:
			_on_continuar_pressed()
		else:
			_on_jugar_pressed()
		get_viewport().set_input_as_handled()


func _generar_chispas() -> void:
	_chispas.clear()
	for i in range(28):
		_chispas.append({
			"x": randf() * 1280.0,
			"y": randf() * 720.0,
			"vel": randf_range(16.0, 44.0),
			"tam": 4.0 if (i % 3 == 0) else 2.0,
			"freq": randf_range(2.0, 5.0),
			"fase": randf() * TAU,
			"color": COLOR_ORO if (i % 4 == 0) else COLOR_CIAN,
		})


func _actualizar_estado_guardado() -> void:
	GameManager.cargar_partida()
	_puede_continuar = GameManager.existe_partida_guardada()
	btn_continuar.disabled = not _puede_continuar

	if _puede_continuar:
		var nombre_nivel := GameManager.obtener_nombre_nivel(GameManager.checkpoint_escena)
		var perks_activos: int = 0
		for v in GameManager.mejoras.values():
			if bool(v):
				perks_activos += 1
		lbl_estado_guardado.text = "CHECKPOINT: %s  |  RAYOS: %d  |  MEJORAS: %d/3" % [
			nombre_nivel, GameManager.monedas_rayo, perks_activos
		]
		lbl_estado_guardado.add_theme_color_override("font_color", COLOR_VERDE)
	else:
		lbl_estado_guardado.text = "Sin partida guardada — Presiona JUGAR para iniciar en el Nivel 1"
		lbl_estado_guardado.add_theme_color_override("font_color", Color(0.62, 0.72, 0.84))


func _seleccionar_indice(idx: int) -> void:
	_indice_seleccion = clampi(idx, 0, 1)
	if _indice_seleccion == 1 and not _puede_continuar:
		_indice_seleccion = 0
	btn_jugar.text = "▶  JUGAR  ◀" if _indice_seleccion == 0 else "JUGAR"
	if _puede_continuar:
		btn_continuar.text = "▶  CONTINUAR  ◀" if _indice_seleccion == 1 else "CONTINUAR"
	else:
		btn_continuar.text = "CONTINUAR (SIN CHECKPOINT)"
	_actualizar_resaltado_botones()


func _actualizar_resaltado_botones() -> void:
	_estilizar_boton(btn_jugar, COLOR_CIAN, _indice_seleccion == 0, false)
	_estilizar_boton(btn_continuar, COLOR_ORO, _indice_seleccion == 1 and _puede_continuar, not _puede_continuar)


func _aplicar_estilos_pixel() -> void:
	var panel_principal := %PanelPrincipal as PanelContainer
	if panel_principal != null:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.09, 0.16, 0.96)
		sb.border_color = COLOR_CIAN
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(0)
		sb.content_margin_left = 34
		sb.content_margin_right = 34
		sb.content_margin_top = 26
		sb.content_margin_bottom = 26
		sb.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
		sb.shadow_size = 0
		sb.shadow_offset = Vector2(6, 6)
		panel_principal.add_theme_stylebox_override("panel", sb)

	var caja_titulo := %CajaTitulo as PanelContainer
	if caja_titulo != null:
		var sb_t := StyleBoxFlat.new()
		sb_t.bg_color = Color(0.03, 0.06, 0.11, 0.98)
		sb_t.border_color = COLOR_ORO
		sb_t.set_border_width_all(2)
		sb_t.set_corner_radius_all(0)
		sb_t.content_margin_left = 20
		sb_t.content_margin_right = 20
		sb_t.content_margin_top = 14
		sb_t.content_margin_bottom = 14
		caja_titulo.add_theme_stylebox_override("panel", sb_t)


func _estilizar_boton(btn: Button, color: Color, resaltado: bool, deshabilitado: bool) -> void:
	if btn == null:
		return
	var sb_norm := StyleBoxFlat.new()
	sb_norm.set_corner_radius_all(0)
	sb_norm.set_border_width_all(3 if resaltado else 2)
	sb_norm.content_margin_top = 12
	sb_norm.content_margin_bottom = 12
	sb_norm.content_margin_left = 20
	sb_norm.content_margin_right = 20

	if deshabilitado:
		sb_norm.bg_color = Color(0.08, 0.10, 0.14, 0.85)
		sb_norm.border_color = Color(0.25, 0.30, 0.38, 0.8)
	elif resaltado:
		sb_norm.bg_color = color.darkened(0.68)
		sb_norm.border_color = color
	else:
		sb_norm.bg_color = Color(0.07, 0.12, 0.20, 0.96)
		sb_norm.border_color = color.darkened(0.35)

	var sb_hover := sb_norm.duplicate() as StyleBoxFlat
	if not deshabilitado:
		sb_hover.bg_color = color.darkened(0.56)
		sb_hover.border_color = color.lightened(0.2)

	var sb_press := sb_norm.duplicate() as StyleBoxFlat
	if not deshabilitado:
		sb_press.bg_color = color.darkened(0.45)
		sb_press.border_color = Color.WHITE

	btn.add_theme_stylebox_override("normal", sb_norm)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_press)
	btn.add_theme_stylebox_override("disabled", sb_norm)
	btn.add_theme_stylebox_override("focus", sb_hover)

	btn.add_theme_color_override("font_color", Color.WHITE if resaltado else color.lightened(0.3))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.52, 0.62))


func _on_jugar_pressed() -> void:
	GameManager.nueva_partida()


func _on_continuar_pressed() -> void:
	if _puede_continuar:
		GameManager.continuar_partida()
