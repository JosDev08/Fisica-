extends CanvasLayer

# ==============================================================================
# TRANSMISIÓN / NOTA OBLIGATORIA DEL CIENTÍFICO (res://Escenas/UI/NotaCientifico.tscn)
# - CanvasLayer en layer = 90 con process_mode = PROCESS_MODE_ALWAYS.
# - Se abre automáticamente al iniciar el nivel y pausa el juego y el temporizador
#   (get_tree().paused = true) hasta que el jugador confirma la lectura.
# - Efecto máquina de escribir rápido, cajas resaltadas de Fórmulas Clave,
#   botón "REPETIR AUDIO" y botón grande "ENTENDIDO / INICIAR MISIÓN".
# - Carga de audio .mp3 100% segura (verifica ResourceLoader.exists / FileAccess.file_exists).
# ==============================================================================

signal transmision_cerrada

const COLOR_FONDO_PANEL := Color(0.04, 0.08, 0.14, 0.97)
const COLOR_CIAN := Color(0.24, 0.89, 1.0)
const COLOR_ORO := Color(0.99, 0.84, 0.30)
const COLOR_VERDE := Color(0.22, 0.94, 0.54)
const COLOR_ROJO := Color(1.0, 0.30, 0.36)
const COLOR_TEXTO := Color(0.90, 0.95, 1.0)

const TEX_RETRATO := "res://assets/ui/retrato_dr_vance.svg"
const TEX_SELLO := "res://assets/ui/sello_clasificado.svg"
const TEX_RADIO := "res://assets/ui/icono_radio_transmision.svg"
const TEX_FONDO_DOSSIER := "res://assets/ui/fondo_dossier_terminal.svg"
const BUS_RADIO := "RadioCientifico"
const RUTA_RADIO_BEEP := "res://assets/audio/voces/radio_beep.wav"
const PITCH_RADIO := 1.0

@export var codigo_nivel: String = "NIVEL 01 — LABORATORIO CENTRAL"
@export var titulo_tema: String = "INFORME DE FÍSICA"
@export var subtitulo_mision: String = "Revisa las leyes físicas antes de iniciar la operación."
@export var formulas_clave: PackedStringArray = PackedStringArray()
@export_multiline var texto_explicacion: String = ""
@export_multiline var alerta_mision: String = ""
@export var alerta_es_victoria: bool = false
@export var ruta_audio_voz: String = ""
@export var texto_boton_iniciar: String = "ENTENDIDO / INICIAR MISIÓN"
@export var velocidad_escritura: float = 95.0
@export var abrir_al_iniciar: bool = true

var _abierta: bool = false
var _modal_registrado: bool = false
var _stream_voz: AudioStream = null
var _stream_beep: AudioStream = null
var _secuencia_audio_id: int = 0
var _caracteres_mostrados: float = 0.0
var _escritura_terminada: bool = false
var _tiempo_pulso: float = 0.0

var _audio_voz: AudioStreamPlayer
var _audio_beep: AudioStreamPlayer
var _panel_dossier: PanelContainer
var _ico_radio: TextureRect
var _lbl_estado_audio: Label
var _lbl_explicacion: Label
var _btn_repetir: Button
var _btn_iniciar: Button


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("nota_cientifico")

	_asegurar_bus_radio_cientifico()

	_audio_voz = get_node_or_null("AudioVoz") as AudioStreamPlayer
	if _audio_voz == null:
		_audio_voz = AudioStreamPlayer.new()
		_audio_voz.name = "AudioVoz"
		add_child(_audio_voz)
	_audio_voz.process_mode = Node.PROCESS_MODE_ALWAYS
	_audio_voz.bus = BUS_RADIO
	_audio_voz.pitch_scale = PITCH_RADIO

	_audio_beep = get_node_or_null("AudioRadioBeep") as AudioStreamPlayer
	if _audio_beep == null:
		_audio_beep = AudioStreamPlayer.new()
		_audio_beep.name = "AudioRadioBeep"
		add_child(_audio_beep)
	_audio_beep.process_mode = Node.PROCESS_MODE_ALWAYS
	_audio_beep.bus = BUS_RADIO
	_audio_beep.pitch_scale = 1.0
	if ResourceLoader.exists(RUTA_RADIO_BEEP) or FileAccess.file_exists(RUTA_RADIO_BEEP):
		_stream_beep = GameManager.cargar_audio_seguro(RUTA_RADIO_BEEP)

	_construir_ui()
	_cargar_audio_voz()

	if abrir_al_iniciar:
		abrir_transmision()
	else:
		visible = false


func esta_abierta() -> bool:
	return _abierta


func abrir_transmision() -> void:
	if _abierta:
		return
	_abierta = true
	visible = true

	if not _modal_registrado:
		_modal_registrado = true
		GameManager.registrar_modal_abierto(true)
	get_tree().paused = true

	# Reiniciar efecto máquina de escribir rápido
	_caracteres_mostrados = 0.0
	_escritura_terminada = texto_explicacion.is_empty()
	if _lbl_explicacion != null:
		_lbl_explicacion.text = texto_explicacion
		_lbl_explicacion.visible_characters = -1 if _escritura_terminada else 0

	# Animación limpia de entrada (compatible con árbol pausado)
	if _panel_dossier != null and is_inside_tree():
		_panel_dossier.modulate.a = 0.0
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(_panel_dossier, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_reproducir_audio_voz(false)


func cerrar_transmision() -> void:
	if not _abierta:
		return
	_abierta = false
	visible = false

	_secuencia_audio_id += 1
	if _audio_beep != null and _audio_beep.playing:
		_audio_beep.stop()
	if _audio_voz != null and _audio_voz.playing:
		_audio_voz.stop()

	get_tree().paused = false
	# Liberar el modal en diferido para evitar que el clic dispare un proyectil
	call_deferred("_liberar_modal_diferido")
	transmision_cerrada.emit()


func _liberar_modal_diferido() -> void:
	if _modal_registrado:
		_modal_registrado = false
		GameManager.registrar_modal_abierto(false)


func _process(delta: float) -> void:
	if not _abierta:
		return

	# Garantizar que el juego y el temporizador permanezcan pausados mientras la nota esté abierta
	if not get_tree().paused:
		get_tree().paused = true

	_tiempo_pulso += delta * 5.0
	if _ico_radio != null:
		var a: float = 0.65 + 0.35 * sin(_tiempo_pulso)
		_ico_radio.modulate = Color(1.0, 1.0, 1.0, a)

	if not _escritura_terminada and _lbl_explicacion != null:
		var total: int = texto_explicacion.length()
		_caracteres_mostrados += delta * maxf(25.0, velocidad_escritura)
		var visibles: int = mini(total, int(_caracteres_mostrados))
		_lbl_explicacion.visible_characters = visibles
		if visibles >= total:
			_escritura_terminada = true
			_lbl_explicacion.visible_characters = -1


func _unhandled_input(event: InputEvent) -> void:
	if not _abierta:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var kc: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if kc == KEY_ESCAPE:
			# Transmisión obligatoria: bloquear ESC para que no abra pausa ni omita la nota
			get_viewport().set_input_as_handled()
		elif kc == KEY_R:
			_on_repetir_audio_pressed()
			get_viewport().set_input_as_handled()
		elif kc in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			if not _escritura_terminada:
				_completar_texto_inmediato()
			else:
				cerrar_transmision()
			get_viewport().set_input_as_handled()


func _completar_texto_inmediato() -> void:
	_escritura_terminada = true
	if _lbl_explicacion != null:
		_lbl_explicacion.visible_characters = -1


func _cargar_audio_voz() -> void:
	_stream_voz = null
	if ruta_audio_voz.is_empty():
		_actualizar_estado_audio("MODO LECTURA — SIN AUDIO CONFIGURADO", Color(0.68, 0.80, 0.92))
		return

	# Verificación estricta antes de cargar para garantizar 0 errores si no existe el .mp3
	if ResourceLoader.exists(ruta_audio_voz) or FileAccess.file_exists(ruta_audio_voz):
		_stream_voz = GameManager.cargar_audio_seguro(ruta_audio_voz)

	if _stream_voz != null:
		_audio_voz.stream = _stream_voz
		_actualizar_estado_audio("AUDIO DE RADIO DISPONIBLE (%s)" % ruta_audio_voz.get_file(), COLOR_VERDE)
	else:
		_actualizar_estado_audio("MODO TEXTO — Voz pendiente (%s)" % ruta_audio_voz.get_file(), COLOR_ORO)


func _asegurar_bus_radio_cientifico() -> void:
	if AudioServer.get_bus_index(BUS_RADIO) != -1:
		return
	var idx: int = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, BUS_RADIO)
	AudioServer.set_bus_send(idx, "Master")

	var filtro_hp := AudioEffectHighPassFilter.new()
	filtro_hp.cutoff_hz = 220.0
	AudioServer.add_bus_effect(idx, filtro_hp)

	var filtro_lp := AudioEffectLowPassFilter.new()
	filtro_lp.cutoff_hz = 4500.0
	AudioServer.add_bus_effect(idx, filtro_lp)


func _reproducir_audio_voz(desde_boton: bool) -> void:
	if _stream_voz == null and not ruta_audio_voz.is_empty():
		_cargar_audio_voz()

	if _stream_voz != null and _audio_voz != null:
		_asegurar_bus_radio_cientifico()
		_secuencia_audio_id += 1
		var mi_secuencia: int = _secuencia_audio_id

		if _audio_beep != null:
			_audio_beep.stop()
		_audio_voz.stop()
		_audio_voz.bus = BUS_RADIO
		_audio_voz.pitch_scale = PITCH_RADIO
		_audio_voz.stream = _stream_voz
		_actualizar_estado_audio("REPRODUCIENDO TRANSMISIÓN DE RADIO...", COLOR_VERDE)

		# Pitido táctico de apertura de comunicador antes de hablar
		if _stream_beep == null and (ResourceLoader.exists(RUTA_RADIO_BEEP) or FileAccess.file_exists(RUTA_RADIO_BEEP)):
			_stream_beep = GameManager.cargar_audio_seguro(RUTA_RADIO_BEEP)
		if _stream_beep != null and _audio_beep != null and is_inside_tree():
			_audio_beep.bus = BUS_RADIO
			_audio_beep.stream = _stream_beep
			_audio_beep.play(0.0)
			await get_tree().create_timer(0.26, true).timeout
			if not is_inside_tree() or not _abierta or mi_secuencia != _secuencia_audio_id:
				return

		_audio_voz.play(0.0)
	elif desde_boton:
		_actualizar_estado_audio("Coloca %s en res://assets/audio/voces/" % ruta_audio_voz.get_file(), COLOR_ORO)


func _on_repetir_audio_pressed() -> void:
	_reproducir_audio_voz(true)


func _actualizar_estado_audio(texto: String, color: Color) -> void:
	if _lbl_estado_audio != null:
		_lbl_estado_audio.text = texto
		_lbl_estado_audio.add_theme_color_override("font_color", color)


func _construir_ui() -> void:
	# Capa oscura bloqueadora de clics
	var fondo_oscuro := ColorRect.new()
	fondo_oscuro.name = "FondoOscuro"
	fondo_oscuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo_oscuro.color = Color(0.01, 0.03, 0.07, 0.84)
	fondo_oscuro.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fondo_oscuro)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo_oscuro.add_child(centro)

	# Contenedor principal estilo Dossier Clasificado / Terminal Científica
	_panel_dossier = PanelContainer.new()
	_panel_dossier.name = "PanelDossier"
	_panel_dossier.custom_minimum_size = Vector2(830, 0)
	_panel_dossier.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_dossier.add_theme_stylebox_override("panel", _crear_caja(COLOR_FONDO_PANEL, COLOR_CIAN, 3, 0))
	centro.add_child(_panel_dossier)

	# Fondo SVG tipo terminal científica dentro del panel
	var capa_fondo_svg := TextureRect.new()
	capa_fondo_svg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	capa_fondo_svg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	capa_fondo_svg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	capa_fondo_svg.stretch_mode = TextureRect.STRETCH_SCALE
	capa_fondo_svg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa_fondo_svg.modulate = Color(1.0, 1.0, 1.0, 0.85)
	if ResourceLoader.exists(TEX_FONDO_DOSSIER):
		capa_fondo_svg.texture = load(TEX_FONDO_DOSSIER) as Texture2D
	_panel_dossier.add_child(capa_fondo_svg)

	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 22)
	margen.add_theme_constant_override("margin_right", 22)
	margen.add_theme_constant_override("margin_top", 16)
	margen.add_theme_constant_override("margin_bottom", 18)
	_panel_dossier.add_child(margen)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margen.add_child(vbox)

	# ------------------------------------------------------------------
	# 1. CABECERA DE TRANSMISIÓN + SELLO "EXPEDIENTE CLASIFICADO"
	# ------------------------------------------------------------------
	var barra_cabecera := HBoxContainer.new()
	barra_cabecera.add_theme_constant_override("separation", 10)
	vbox.add_child(barra_cabecera)

	_ico_radio = TextureRect.new()
	_ico_radio.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ico_radio.custom_minimum_size = Vector2(34, 34)
	_ico_radio.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ico_radio.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(TEX_RADIO):
		_ico_radio.texture = load(TEX_RADIO) as Texture2D
	barra_cabecera.add_child(_ico_radio)

	var lbl_cabecera := Label.new()
	lbl_cabecera.text = "TRANSMISIÓN ENTRANTE — DR. VANCE (LABORATORIO CENTRAL)"
	lbl_cabecera.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_cabecera.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_cabecera.add_theme_font_size_override("font_size", 15)
	lbl_cabecera.add_theme_color_override("font_color", COLOR_CIAN)
	lbl_cabecera.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_cabecera.add_theme_constant_override("outline_size", 4)
	barra_cabecera.add_child(lbl_cabecera)

	# Sello de "EXPEDIENTE CLASIFICADO"
	var caja_sello := PanelContainer.new()
	caja_sello.add_theme_stylebox_override("panel", _crear_caja(Color(0.24, 0.04, 0.07, 0.95), COLOR_ROJO, 2, 6))
	barra_cabecera.add_child(caja_sello)

	var hbox_sello := HBoxContainer.new()
	hbox_sello.add_theme_constant_override("separation", 6)
	caja_sello.add_child(hbox_sello)

	var ico_sello := TextureRect.new()
	ico_sello.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ico_sello.custom_minimum_size = Vector2(22, 22)
	ico_sello.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ico_sello.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(TEX_SELLO):
		ico_sello.texture = load(TEX_SELLO) as Texture2D
	hbox_sello.add_child(ico_sello)

	var lbl_sello := Label.new()
	lbl_sello.text = "EXPEDIENTE CLASIFICADO"
	lbl_sello.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_sello.add_theme_font_size_override("font_size", 11)
	lbl_sello.add_theme_color_override("font_color", Color(1.0, 0.62, 0.66))
	lbl_sello.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_sello.add_theme_constant_override("outline_size", 3)
	hbox_sello.add_child(lbl_sello)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# ------------------------------------------------------------------
	# 2. RETRATO DEL CIENTÍFICO + TÍTULO DEL TEMA Y ESTADO DE RADIO
	# ------------------------------------------------------------------
	var fila_identidad := HBoxContainer.new()
	fila_identidad.add_theme_constant_override("separation", 16)
	vbox.add_child(fila_identidad)

	var marco_retrato := PanelContainer.new()
	marco_retrato.add_theme_stylebox_override("panel", _crear_caja(Color(0.03, 0.07, 0.12, 0.98), COLOR_CIAN, 2, 4))
	fila_identidad.add_child(marco_retrato)

	var tex_retrato := TextureRect.new()
	tex_retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex_retrato.custom_minimum_size = Vector2(84, 84)
	tex_retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(TEX_RETRATO):
		tex_retrato.texture = load(TEX_RETRATO) as Texture2D
	marco_retrato.add_child(tex_retrato)

	var col_titulo := VBoxContainer.new()
	col_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_titulo.alignment = BoxContainer.ALIGNMENT_CENTER
	col_titulo.add_theme_constant_override("separation", 4)
	fila_identidad.add_child(col_titulo)

	var lbl_codigo := Label.new()
	lbl_codigo.text = codigo_nivel
	lbl_codigo.add_theme_font_size_override("font_size", 12)
	lbl_codigo.add_theme_color_override("font_color", COLOR_ORO)
	col_titulo.add_child(lbl_codigo)

	var lbl_tema := Label.new()
	lbl_tema.text = titulo_tema
	lbl_tema.add_theme_font_size_override("font_size", 21)
	lbl_tema.add_theme_color_override("font_color", Color.WHITE)
	lbl_tema.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_tema.add_theme_constant_override("outline_size", 4)
	col_titulo.add_child(lbl_tema)

	var lbl_sub := Label.new()
	lbl_sub.text = subtitulo_mision
	lbl_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_sub.add_theme_font_size_override("font_size", 12)
	lbl_sub.add_theme_color_override("font_color", Color(0.74, 0.88, 0.98))
	col_titulo.add_child(lbl_sub)

	_lbl_estado_audio = Label.new()
	_lbl_estado_audio.add_theme_font_size_override("font_size", 11)
	col_titulo.add_child(_lbl_estado_audio)

	# ------------------------------------------------------------------
	# 3. CAJAS RESALTADAS DE FÓRMULAS CLAVE
	# ------------------------------------------------------------------
	if not formulas_clave.is_empty():
		var caja_formulas := PanelContainer.new()
		caja_formulas.add_theme_stylebox_override("panel", _crear_caja(Color(0.05, 0.12, 0.21, 0.96), COLOR_ORO, 2, 10))
		vbox.add_child(caja_formulas)

		var vbox_f := VBoxContainer.new()
		vbox_f.add_theme_constant_override("separation", 6)
		caja_formulas.add_child(vbox_f)

		var lbl_f_head := Label.new()
		lbl_f_head.text = "⚡ FÓRMULAS CLAVE DEL SECTOR"
		lbl_f_head.add_theme_font_size_override("font_size", 12)
		lbl_f_head.add_theme_color_override("font_color", COLOR_ORO)
		lbl_f_head.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl_f_head.add_theme_constant_override("outline_size", 3)
		vbox_f.add_child(lbl_f_head)

		var grid_f := GridContainer.new()
		grid_f.columns = 2 if formulas_clave.size() >= 2 else 1
		grid_f.add_theme_constant_override("h_separation", 10)
		grid_f.add_theme_constant_override("v_separation", 6)
		vbox_f.add_child(grid_f)

		for formula in formulas_clave:
			var pill := PanelContainer.new()
			pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pill.add_theme_stylebox_override("panel", _crear_caja(Color(0.03, 0.08, 0.15, 0.96), COLOR_CIAN.darkened(0.15), 1, 7))
			grid_f.add_child(pill)

			var lbl_eq := Label.new()
			lbl_eq.text = formula
			lbl_eq.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl_eq.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl_eq.add_theme_font_size_override("font_size", 14)
			lbl_eq.add_theme_color_override("font_color", Color(0.68, 0.97, 1.0))
			lbl_eq.add_theme_color_override("font_outline_color", Color.BLACK)
			lbl_eq.add_theme_constant_override("outline_size", 3)
			pill.add_child(lbl_eq)

	# ------------------------------------------------------------------
	# 4. EXPLICACIÓN INTUITIVA (CON EFECTO MÁQUINA DE ESCRIBIR RÁPIDO)
	# ------------------------------------------------------------------
	var caja_texto := PanelContainer.new()
	caja_texto.add_theme_stylebox_override("panel", _crear_caja(Color(0.03, 0.06, 0.11, 0.95), Color(0.22, 0.44, 0.64, 0.9), 2, 12))
	caja_texto.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and not _escritura_terminada:
			_completar_texto_inmediato()
	)
	vbox.add_child(caja_texto)

	_lbl_explicacion = Label.new()
	_lbl_explicacion.text = texto_explicacion
	_lbl_explicacion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_explicacion.custom_minimum_size = Vector2(0, 86)
	_lbl_explicacion.add_theme_font_size_override("font_size", 14)
	_lbl_explicacion.add_theme_color_override("font_color", COLOR_TEXTO)
	caja_texto.add_child(_lbl_explicacion)

	# ------------------------------------------------------------------
	# 5. ALERTA CRÍTICA DE MISIÓN (OPCIONAL — NIVEL 3 / NIVEL 4)
	# ------------------------------------------------------------------
	if not alerta_mision.is_empty():
		var color_alerta: Color = COLOR_VERDE if alerta_es_victoria else COLOR_ROJO
		var fondo_alerta: Color = Color(0.05, 0.18, 0.11, 0.95) if alerta_es_victoria else Color(0.24, 0.05, 0.08, 0.95)
		var caja_alerta := PanelContainer.new()
		caja_alerta.add_theme_stylebox_override("panel", _crear_caja(fondo_alerta, color_alerta, 2, 10))
		vbox.add_child(caja_alerta)

		var lbl_alerta := Label.new()
		lbl_alerta.text = alerta_mision
		lbl_alerta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_alerta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_alerta.add_theme_font_size_override("font_size", 13)
		lbl_alerta.add_theme_color_override("font_color", color_alerta.lightened(0.4))
		lbl_alerta.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl_alerta.add_theme_constant_override("outline_size", 3)
		caja_alerta.add_child(lbl_alerta)

	# ------------------------------------------------------------------
	# 6. BOTONES: REPETIR AUDIO + BOTÓN GRANDE ENTENDIDO / INICIAR MISIÓN
	# ------------------------------------------------------------------
	var fila_botones := HBoxContainer.new()
	fila_botones.add_theme_constant_override("separation", 14)
	vbox.add_child(fila_botones)

	_btn_repetir = Button.new()
	_btn_repetir.text = "🔊 REPETIR AUDIO  [R]"
	_btn_repetir.custom_minimum_size = Vector2(220, 46)
	_btn_repetir.focus_mode = Control.FOCUS_NONE
	_btn_repetir.add_theme_font_size_override("font_size", 13)
	_estilizar_boton(_btn_repetir, COLOR_CIAN)
	_btn_repetir.pressed.connect(_on_repetir_audio_pressed)
	fila_botones.add_child(_btn_repetir)

	_btn_iniciar = Button.new()
	_btn_iniciar.text = "▶  " + texto_boton_iniciar
	_btn_iniciar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_iniciar.custom_minimum_size = Vector2(360, 46)
	_btn_iniciar.focus_mode = Control.FOCUS_NONE
	_btn_iniciar.add_theme_font_size_override("font_size", 16)
	_estilizar_boton(_btn_iniciar, COLOR_VERDE)
	_btn_iniciar.pressed.connect(cerrar_transmision)
	fila_botones.add_child(_btn_iniciar)

	var lbl_tip := Label.new()
	lbl_tip.text = "Juego y temporizador en pausa hasta confirmar  •  [Enter / Espacio] Completar texto / Iniciar  •  [R] Repetir audio"
	lbl_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_tip.add_theme_font_size_override("font_size", 11)
	lbl_tip.add_theme_color_override("font_color", Color(0.58, 0.72, 0.86))
	vbox.add_child(lbl_tip)


func _crear_caja(fondo: Color, borde: Color, grosor: int, margen: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.border_color = borde
	sb.set_border_width_all(grosor)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(margen)
	return sb


func _estilizar_boton(btn: Button, color: Color) -> void:
	var sb_n := _crear_caja(color.darkened(0.74), color, 2, 10)
	var sb_h := _crear_caja(color.darkened(0.54), color.lightened(0.25), 2, 10)
	var sb_p := _crear_caja(color.darkened(0.38), Color.WHITE, 2, 10)
	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_p)
	btn.add_theme_stylebox_override("focus", sb_h)
	btn.add_theme_color_override("font_color", color.lightened(0.45))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
