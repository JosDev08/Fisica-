extends CanvasLayer

# ==============================================================================
# PANTALLA DE VICTORIA FINAL (res://Escenas/UI/PantallaVictoria.tscn)
# - CanvasLayer en layer = 100 con process_mode = PROCESS_MODE_ALWAYS.
# - Inicia oculta (visible = false) y aparece con fade-in suave tras el despegue
#   del helicóptero de extracción en Escena_4.tscn.
# - Muestra estadísticas finales desde GameManager y reproduce victoria.wav.
# ==============================================================================

const COLOR_FONDO := Color("#060B18")
const COLOR_CIAN := Color("#00F0FF")
const COLOR_ORO := Color("#FFD600")
const COLOR_VERDE := Color("#2CF28A")
const COLOR_TEXTO := Color(0.90, 0.96, 1.0)

const RUTA_AUDIO_VICTORIA := "res://assets/audio/victoria.wav"
const TEX_MEDALLA := "res://assets/ui/medalla_victoria.svg"
const TEX_RAYO := "res://assets/ui/rayo_neon.svg"
const TEX_MONEDA := "res://assets/objetos/moneda_rayo.svg"
const TEX_SELLO := "res://assets/ui/sello_clasificado.svg"

var _mostrada: bool = false
var _modal_registrado: bool = false

var _fondo_overlay: ColorRect
var _panel_victoria: PanelContainer
var _lbl_monedas_val: Label
var _lbl_mejoras_val: Label
var _lbl_archivos_val: Label
var _btn_jugar_nuevo: Button
var _btn_menu_principal: Button
var _audio_victoria: AudioStreamPlayer


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pantalla_victoria")
	visible = false

	_audio_victoria = get_node_or_null("AudioVictoria") as AudioStreamPlayer
	if _audio_victoria == null:
		_audio_victoria = AudioStreamPlayer.new()
		_audio_victoria.name = "AudioVictoria"
		add_child(_audio_victoria)
	_audio_victoria.process_mode = Node.PROCESS_MODE_ALWAYS

	_construir_ui()


func mostrar_victoria() -> void:
	if _mostrada:
		return
	_mostrada = true

	_actualizar_estadisticas()
	visible = true

	if not _modal_registrado:
		_modal_registrado = true
		GameManager.registrar_modal_abierto(true)
	GameManager.temporizador_activo = false
	get_tree().paused = true

	# Efecto de aparición suave (fade-in) compatible con árbol pausado
	if _fondo_overlay != null and is_inside_tree():
		_fondo_overlay.modulate.a = 0.0
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(_fondo_overlay, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_reproducir_sonido_victoria()


func _unhandled_input(event: InputEvent) -> void:
	if not _mostrada:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if kc == KEY_ESCAPE:
			# Evitar que ESC abra el menú de pausa encima de la pantalla de victoria
			get_viewport().set_input_as_handled()


func _actualizar_estadisticas() -> void:
	if _lbl_monedas_val != null:
		_lbl_monedas_val.text = "%d Monedas de Rayo" % GameManager.monedas_rayo

	if _lbl_mejoras_val != null:
		var activas: int = 0
		var detalle: Array[String] = []
		if GameManager.nivel_vida > 0:
			activas += 1
			detalle.append("Vida Nv.%d" % GameManager.nivel_vida)
		if GameManager.nivel_velocidad > 0:
			activas += 1
			detalle.append("Vel. Nv.%d" % GameManager.nivel_velocidad)
		if GameManager.nivel_danio > 0:
			activas += 1
			detalle.append("Daño Nv.%d" % GameManager.nivel_danio)

		if activas == 0:
			_lbl_mejoras_val.text = "0 / 3 equipadas (Sin mejoras)"
		else:
			_lbl_mejoras_val.text = "%d / 3 equipadas  (%s)" % [activas, " • ".join(detalle)]

	if _lbl_archivos_val != null:
		_lbl_archivos_val.text = "RECUPERADOS (100%)"


func _reproducir_sonido_victoria() -> void:
	if _audio_victoria == null:
		return
	if ResourceLoader.exists(RUTA_AUDIO_VICTORIA) or FileAccess.file_exists(RUTA_AUDIO_VICTORIA):
		var stream := GameManager.cargar_audio_seguro(RUTA_AUDIO_VICTORIA)
		if stream != null:
			_audio_victoria.stop()
			_audio_victoria.stream = stream
			_audio_victoria.play(0.0)


func _on_jugar_de_nuevo_pressed() -> void:
	if _audio_victoria != null and _audio_victoria.playing:
		_audio_victoria.stop()
	_mostrada = false
	visible = false
	if _modal_registrado:
		_modal_registrado = false
		GameManager.registrar_modal_abierto(false)
	GameManager.nueva_partida(true)


func _on_menu_principal_pressed() -> void:
	if _audio_victoria != null and _audio_victoria.playing:
		_audio_victoria.stop()
	_mostrada = false
	visible = false
	if _modal_registrado:
		_modal_registrado = false
		GameManager.registrar_modal_abierto(false)

	GameManager.temporizador_activo = false
	GameManager.jugador_muerto = false
	GameManager.en_pausa = false
	get_tree().paused = false

	var ruta_menu: String = str(ProjectSettings.get_setting("application/run/main_scene", GameManager.ESCENA_MENU_PRINCIPAL))
	if ruta_menu.is_empty() or not ResourceLoader.exists(ruta_menu):
		ruta_menu = GameManager.ESCENA_MENU_PRINCIPAL
	if ResourceLoader.exists(ruta_menu):
		get_tree().change_scene_to_file(ruta_menu)


func _construir_ui() -> void:
	_fondo_overlay = ColorRect.new()
	_fondo_overlay.name = "FondoVictoria"
	_fondo_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fondo_overlay.color = Color(0.01, 0.03, 0.08, 0.84)
	_fondo_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fondo_overlay)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fondo_overlay.add_child(centro)

	# Panel exterior con borde cian neón (#00F0FF)
	_panel_victoria = PanelContainer.new()
	_panel_victoria.name = "PanelVictoria"
	_panel_victoria.custom_minimum_size = Vector2(740, 0)
	_panel_victoria.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_victoria.add_theme_stylebox_override("panel", _crear_caja(Color(COLOR_FONDO.r, COLOR_FONDO.g, COLOR_FONDO.b, 0.97), COLOR_CIAN, 3, 6))
	centro.add_child(_panel_victoria)

	# Marco interior dorado (#FFD600) estilo pixel art eléctrico
	var marco_dorado := PanelContainer.new()
	marco_dorado.add_theme_stylebox_override("panel", _crear_caja(Color(0.03, 0.06, 0.13, 0.98), COLOR_ORO, 2, 22))
	_panel_victoria.add_child(marco_dorado)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	marco_dorado.add_child(vbox)

	# ------------------------------------------------------------------
	# 1. MEDALLA + TÍTULO PRINCIPAL + SUBTÍTULO
	# ------------------------------------------------------------------
	var fila_titulo := HBoxContainer.new()
	fila_titulo.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_titulo.add_theme_constant_override("separation", 16)
	vbox.add_child(fila_titulo)

	var ico_medalla := TextureRect.new()
	ico_medalla.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ico_medalla.custom_minimum_size = Vector2(78, 78)
	ico_medalla.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ico_medalla.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(TEX_MEDALLA):
		ico_medalla.texture = load(TEX_MEDALLA) as Texture2D
	fila_titulo.add_child(ico_medalla)

	var col_titulos := VBoxContainer.new()
	col_titulos.alignment = BoxContainer.ALIGNMENT_CENTER
	col_titulos.add_theme_constant_override("separation", 4)
	fila_titulo.add_child(col_titulos)

	var lbl_titulo := Label.new()
	lbl_titulo.text = "¡MISIÓN CUMPLIDA!"
	lbl_titulo.add_theme_font_size_override("font_size", 32)
	lbl_titulo.add_theme_color_override("font_color", COLOR_ORO)
	lbl_titulo.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_titulo.add_theme_constant_override("outline_size", 6)
	col_titulos.add_child(lbl_titulo)

	var lbl_subtitulo := Label.new()
	lbl_subtitulo.text = "EXTRACCIÓN EXITOSA — ARCHIVOS CLASIFICADOS A SALVO"
	lbl_subtitulo.add_theme_font_size_override("font_size", 14)
	lbl_subtitulo.add_theme_color_override("font_color", COLOR_CIAN)
	lbl_subtitulo.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_subtitulo.add_theme_constant_override("outline_size", 4)
	col_titulos.add_child(lbl_subtitulo)

	# Línea divisoria luminosa
	var linea_div := ColorRect.new()
	linea_div.custom_minimum_size = Vector2(0, 2)
	linea_div.color = Color(COLOR_CIAN.r, COLOR_CIAN.g, COLOR_CIAN.b, 0.55)
	vbox.add_child(linea_div)

	# ------------------------------------------------------------------
	# 2. TEXTO NARRATIVO BREVE
	# ------------------------------------------------------------------
	var caja_narrativa := PanelContainer.new()
	caja_narrativa.add_theme_stylebox_override("panel", _crear_caja(Color(0.04, 0.09, 0.17, 0.95), Color(0.20, 0.55, 0.78, 0.85), 2, 12))
	vbox.add_child(caja_narrativa)

	var lbl_narrativa := Label.new()
	lbl_narrativa.text = "Has superado todas las defensas de la base aplicando Electrostática, Electrodinámica, Capacitores y Electromagnetismo. El Laboratorio Central ha recibido los datos."
	lbl_narrativa.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_narrativa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_narrativa.add_theme_font_size_override("font_size", 14)
	lbl_narrativa.add_theme_color_override("font_color", COLOR_TEXTO)
	caja_narrativa.add_child(lbl_narrativa)

	# ------------------------------------------------------------------
	# 3. PANEL DE ESTADÍSTICAS FINALES (GameManager)
	# ------------------------------------------------------------------
	var caja_stats := PanelContainer.new()
	caja_stats.add_theme_stylebox_override("panel", _crear_caja(Color(0.03, 0.07, 0.14, 0.96), COLOR_ORO.darkened(0.15), 2, 14))
	vbox.add_child(caja_stats)

	var vbox_stats := VBoxContainer.new()
	vbox_stats.add_theme_constant_override("separation", 8)
	caja_stats.add_child(vbox_stats)

	var lbl_stats_head := Label.new()
	lbl_stats_head.text = "⚡ RESUMEN DE OPERACIÓN — LABORATORIO CENTRAL"
	lbl_stats_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_stats_head.add_theme_font_size_override("font_size", 13)
	lbl_stats_head.add_theme_color_override("font_color", COLOR_ORO)
	lbl_stats_head.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_stats_head.add_theme_constant_override("outline_size", 3)
	vbox_stats.add_child(lbl_stats_head)

	_lbl_monedas_val = _agregar_fila_stat(vbox_stats, TEX_MONEDA, "Monedas de Rayo recolectadas:", "0", COLOR_ORO)
	_lbl_mejoras_val = _agregar_fila_stat(vbox_stats, TEX_RAYO, "Mejoras equipadas:", "0 / 3", COLOR_CIAN)
	_lbl_archivos_val = _agregar_fila_stat(vbox_stats, TEX_SELLO, "Archivos Secretos:", "RECUPERADOS (100%)", COLOR_VERDE)

	# ------------------------------------------------------------------
	# 4. BOTONES INTERACTIVOS: JUGAR DE NUEVO / MENÚ PRINCIPAL
	# ------------------------------------------------------------------
	var fila_botones := HBoxContainer.new()
	fila_botones.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_botones.add_theme_constant_override("separation", 18)
	vbox.add_child(fila_botones)

	_btn_jugar_nuevo = Button.new()
	_btn_jugar_nuevo.text = "⚡  JUGAR DE NUEVO"
	_btn_jugar_nuevo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_jugar_nuevo.custom_minimum_size = Vector2(260, 48)
	_btn_jugar_nuevo.focus_mode = Control.FOCUS_NONE
	_btn_jugar_nuevo.add_theme_font_size_override("font_size", 16)
	_estilizar_boton(_btn_jugar_nuevo, COLOR_VERDE)
	_btn_jugar_nuevo.pressed.connect(_on_jugar_de_nuevo_pressed)
	fila_botones.add_child(_btn_jugar_nuevo)

	_btn_menu_principal = Button.new()
	_btn_menu_principal.text = "MENÚ PRINCIPAL"
	_btn_menu_principal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_menu_principal.custom_minimum_size = Vector2(260, 48)
	_btn_menu_principal.focus_mode = Control.FOCUS_NONE
	_btn_menu_principal.add_theme_font_size_override("font_size", 16)
	_estilizar_boton(_btn_menu_principal, COLOR_CIAN)
	_btn_menu_principal.pressed.connect(_on_menu_principal_pressed)
	fila_botones.add_child(_btn_menu_principal)


func _agregar_fila_stat(padre: VBoxContainer, ruta_ico: String, etiqueta: String, valor_inicial: String, color_val: Color) -> Label:
	var fila_panel := PanelContainer.new()
	fila_panel.add_theme_stylebox_override("panel", _crear_caja(Color(0.05, 0.10, 0.19, 0.92), Color(0.18, 0.36, 0.54, 0.7), 1, 8))
	padre.add_child(fila_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	fila_panel.add_child(hbox)

	var ico := TextureRect.new()
	ico.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ico.custom_minimum_size = Vector2(24, 24)
	ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(ruta_ico):
		ico.texture = load(ruta_ico) as Texture2D
	hbox.add_child(ico)

	var lbl_k := Label.new()
	lbl_k.text = etiqueta
	lbl_k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_k.add_theme_font_size_override("font_size", 14)
	lbl_k.add_theme_color_override("font_color", Color(0.78, 0.89, 0.98))
	hbox.add_child(lbl_k)

	var lbl_v := Label.new()
	lbl_v.text = valor_inicial
	lbl_v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_v.add_theme_font_size_override("font_size", 14)
	lbl_v.add_theme_color_override("font_color", color_val)
	lbl_v.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_v.add_theme_constant_override("outline_size", 3)
	hbox.add_child(lbl_v)

	return lbl_v


func _crear_caja(fondo: Color, borde: Color, grosor: int, margen: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.border_color = borde
	sb.set_border_width_all(grosor)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(margen)
	return sb


func _estilizar_boton(btn: Button, color: Color) -> void:
	var sb_n := _crear_caja(color.darkened(0.76), color, 2, 10)
	var sb_h := _crear_caja(color.darkened(0.56), color.lightened(0.2), 2, 10)
	var sb_p := _crear_caja(color.darkened(0.40), Color.WHITE, 2, 10)
	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_p)
	btn.add_theme_stylebox_override("focus", sb_h)
	btn.add_theme_color_override("font_color", color.lightened(0.42))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
