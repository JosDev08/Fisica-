extends Area2D

# ==============================================================================
# ESTANTE DE ARCHIVOS CLASIFICADOS (res://Escenas/Objetos/EstanteArchivos.tscn)
# - Area2D con monitoring = true y collision_mask = 1 (Capa 1: Jugador).
# - Muestra cartel flotante "[E] Recuperar Archivos Clasificados" y se activa
#   directamente con la tecla física KEY_E.
# - Al interactuar:
#   * Marca archivos_recuperados = true en GameManager y en la escena actual.
#   * Cambia visualmente el estante a estado vacío/recogido.
#   * Muestra notificación táctica en pantalla:
#       "¡ARCHIVOS RECUPERADOS! Salida desbloqueada"
#   * Reproduce res://assets/audio/voces/voz_nivel_3_archivos.mp3 si existe.
# ==============================================================================

signal archivos_recogidos

const TEX_CON_ARCHIVOS := "res://assets/objetos/estante_archivos.svg"
const TEX_VACIO := "res://assets/objetos/estante_archivos_vacio.svg"
const COLOR_VERDE := Color(0.24, 0.95, 0.54)
const COLOR_ORO := Color(0.99, 0.86, 0.32)

@export var ruta_audio_confirmacion: String = "res://assets/audio/voces/voz_nivel_3_archivos.mp3"

var archivos_recuperados: bool = false
var _jugador_cerca: bool = false
var _tecla_e_prev: bool = false
var _tiempo_brillo: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var brillo_carpeta: Polygon2D = get_node_or_null("BrilloCarpeta") as Polygon2D
@onready var lbl_prompt: Label = $PromptInteractuar
@onready var lbl_estado: Label = get_node_or_null("LblEstadoEstante") as Label
@onready var audio_player: AudioStreamPlayer = get_node_or_null("AudioConfirmacion") as AudioStreamPlayer

var _tex_lleno_res: Texture2D = null
var _tex_vacio_res: Texture2D = null
var _canvas_notif: CanvasLayer = null
var _panel_notif: PanelContainer = null
var _tween_notif: Tween = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 # Capa 1: Jugador
	monitoring = true
	monitorable = true
	add_to_group("estante_archivos")

	if ResourceLoader.exists(TEX_CON_ARCHIVOS):
		_tex_lleno_res = load(TEX_CON_ARCHIVOS) as Texture2D
	if ResourceLoader.exists(TEX_VACIO):
		_tex_vacio_res = load(TEX_VACIO) as Texture2D

	if lbl_prompt != null:
		lbl_prompt.text = "[E] Recuperar Archivos Clasificados"
		lbl_prompt.visible = false
		lbl_prompt.add_to_group("texto_mundo_flotante")

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	if audio_player == null:
		audio_player = AudioStreamPlayer.new()
		audio_player.name = "AudioConfirmacion"
		add_child(audio_player)
	audio_player.process_mode = Node.PROCESS_MODE_ALWAYS

	_construir_notificacion_tactica()
	_aplicar_estado_visual()


func _process(delta: float) -> void:
	if GameManager.jugador_muerto:
		return

	if not archivos_recuperados and brillo_carpeta != null:
		_tiempo_brillo += delta * 4.2
		var pulso: float = 0.22 + 0.22 * (0.5 + 0.5 * sin(_tiempo_brillo))
		brillo_carpeta.color = Color(1.0, 0.88, 0.35, pulso)
		brillo_carpeta.position.y = -62.0 + sin(_tiempo_brillo) * 2.0

	var detectado: bool = false
	if monitoring:
		for b in get_overlapping_bodies():
			if _es_jugador(b):
				detectado = true
				break
	_jugador_cerca = detectado

	if lbl_prompt != null:
		lbl_prompt.visible = _jugador_cerca and not archivos_recuperados and not get_tree().paused

	# Detección directa de tecla física KEY_E
	var e_actual: bool = Input.is_physical_key_pressed(KEY_E)
	if e_actual and not _tecla_e_prev:
		if _jugador_cerca and not archivos_recuperados and not get_tree().paused and not GameManager.hay_modal_interactivo_abierto():
			_recuperar_archivos()
	_tecla_e_prev = e_actual


func _unhandled_input(event: InputEvent) -> void:
	if archivos_recuperados or GameManager.jugador_muerto or not _jugador_cerca:
		return
	if get_tree().paused or GameManager.hay_modal_interactivo_abierto():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if kc == KEY_E:
			_tecla_e_prev = true
			_recuperar_archivos()
			get_viewport().set_input_as_handled()


func _es_jugador(body: Node) -> bool:
	if body == null:
		return false
	if body.is_in_group("jugador") or body.name == "Jugador" or body.name == "CharacterBody2D":
		return true
	if body is CollisionObject2D:
		return (((body as CollisionObject2D).collision_layer & 1) != 0)
	return false


func _on_body_entered(body: Node2D) -> void:
	if _es_jugador(body):
		_jugador_cerca = true
		if lbl_prompt != null and not archivos_recuperados:
			lbl_prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if _es_jugador(body):
		_jugador_cerca = false
		if lbl_prompt != null:
			lbl_prompt.visible = false


func _recuperar_archivos() -> void:
	if archivos_recuperados:
		return
	archivos_recuperados = true

	# Marcar tanto en GameManager como en la escena actual
	GameManager.marcar_archivos_recuperados(true)
	if get_parent() != null:
		get_parent().set_meta("archivos_recuperados", true)

	_aplicar_estado_visual()
	_mostrar_notificacion_tactica("¡ARCHIVOS RECUPERADOS! Salida desbloqueada")
	_reproducir_audio_confirmacion()
	archivos_recogidos.emit()


func _aplicar_estado_visual() -> void:
	if sprite != null:
		if archivos_recuperados and _tex_vacio_res != null:
			sprite.texture = _tex_vacio_res
		elif _tex_lleno_res != null:
			sprite.texture = _tex_lleno_res

	if brillo_carpeta != null:
		brillo_carpeta.visible = not archivos_recuperados

	if lbl_prompt != null:
		lbl_prompt.visible = _jugador_cerca and not archivos_recuperados

	if lbl_estado != null:
		if archivos_recuperados:
			lbl_estado.text = "✓ ARCHIVOS RECUPERADOS"
			lbl_estado.add_theme_color_override("font_color", COLOR_VERDE)
		else:
			lbl_estado.text = "★ ARCHIVOS CLASIFICADOS"
			lbl_estado.add_theme_color_override("font_color", COLOR_ORO)


func _reproducir_audio_confirmacion() -> void:
	if ruta_audio_confirmacion.is_empty() or audio_player == null:
		return
	# Verificación segura antes de cargar para evitar cualquier error si el .mp3 no existe aún
	if ResourceLoader.exists(ruta_audio_confirmacion) or FileAccess.file_exists(ruta_audio_confirmacion):
		var stream := GameManager.cargar_audio_seguro(ruta_audio_confirmacion)
		if stream != null:
			audio_player.stop()
			audio_player.stream = stream
			audio_player.play()


func _construir_notificacion_tactica() -> void:
	_canvas_notif = CanvasLayer.new()
	_canvas_notif.name = "CanvasNotifArchivos"
	_canvas_notif.layer = 85
	_canvas_notif.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas_notif)

	var cont_top := MarginContainer.new()
	cont_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	cont_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cont_top.add_theme_constant_override("margin_top", 78)
	_canvas_notif.add_child(cont_top)

	var centro := CenterContainer.new()
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cont_top.add_child(centro)

	_panel_notif = PanelContainer.new()
	_panel_notif.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_notif.modulate.a = 0.0
	_panel_notif.visible = false

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.16, 0.10, 0.96)
	sb.border_color = COLOR_VERDE
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	_panel_notif.add_theme_stylebox_override("panel", sb)
	centro.add_child(_panel_notif)

	var lbl := Label.new()
	lbl.name = "LblNotif"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.75, 1.0, 0.85))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	_panel_notif.add_child(lbl)


func _mostrar_notificacion_tactica(texto: String) -> void:
	if _panel_notif == null:
		return
	var lbl := _panel_notif.get_node_or_null("LblNotif") as Label
	if lbl != null:
		lbl.text = "📁  " + texto
	_panel_notif.visible = true
	_panel_notif.modulate.a = 1.0

	if _tween_notif != null:
		_tween_notif.kill()
	_tween_notif = create_tween()
	_tween_notif.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween_notif.tween_interval(3.0)
	_tween_notif.tween_property(_panel_notif, "modulate:a", 0.0, 0.8)
	_tween_notif.tween_callback(func(): _panel_notif.visible = false)
