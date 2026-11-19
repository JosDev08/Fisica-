extends CanvasLayer

# ==============================================================================
# HUD COMPETITIVO DE NIVEL Y MENÚ DE PAUSA (res://Escenas/HUD.tscn)
# - Temporizador de cuenta regresiva (rojo y parpadeante bajo 15s)
# - Contador de Monedas de Rayo
# - Barra de Vida dinámica + Iconos de las 3 mejoras equipadas
# - Menú de Pausa por tecla ESC y botón en esquina superior derecha
# ==============================================================================

const COLOR_FONDO_PANEL := Color(0.04, 0.08, 0.14, 0.88)
const COLOR_CIAN := Color(0.24, 0.88, 1.0)
const COLOR_ORO := Color(0.98, 0.82, 0.28)
const COLOR_ROJO := Color(1.0, 0.26, 0.30)
const COLOR_VERDE := Color(0.24, 0.94, 0.52)

@onready var barra_vida: ProgressBar = %BarraVida
@onready var lbl_vida: Label = %LblVida
@onready var lbl_tiempo: Label = %LblTiempo
@onready var lbl_bonus_tiempo: Label = %LblBonusTiempo
@onready var lbl_monedas: Label = %LblMonedas
@onready var btn_pausa: Button = %BtnPausa
@onready var lbl_toast_checkpoint: Label = %LblToastCheckpoint

@onready var slot_jugger: PanelContainer = %SlotJugger
@onready var slot_stamin: PanelContainer = %SlotStamin
@onready var slot_double: PanelContainer = %SlotDouble
@onready var ico_jugger: TextureRect = %IcoJugger
@onready var ico_stamin: TextureRect = %IcoStamin
@onready var ico_double: TextureRect = %IcoDouble

@onready var overlay_pausa: Control = %OverlayPausa
@onready var panel_pausa: PanelContainer = %PanelPausa
@onready var lbl_resumen_pausa: Label = %LblResumenPausa
@onready var btn_reanudar: Button = %BtnReanudar
@onready var btn_menu_principal: Button = %BtnMenuPrincipal

var _pausa_abierta: bool = false
var _tiempo_alerta_fase: float = 0.0
var _en_alerta_tiempo: bool = false
var _tween_bonus: Tween = null
var _tween_toast: Tween = null


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud_juego")

	_estilizar_hud()
	overlay_pausa.visible = false
	lbl_bonus_tiempo.modulate.a = 0.0
	lbl_toast_checkpoint.modulate.a = 0.0

	btn_pausa.pressed.connect(_alternar_pausa)
	btn_reanudar.pressed.connect(_cerrar_pausa)
	btn_menu_principal.pressed.connect(_on_volver_menu_pressed)

	GameManager.monedas_cambiadas.connect(_on_monedas_cambiadas)
	GameManager.vida_cambiada.connect(_on_vida_cambiada)
	GameManager.tiempo_cambiado.connect(_on_tiempo_cambiado)
	GameManager.tiempo_agregado.connect(_on_tiempo_agregado)
	GameManager.mejoras_cambiadas.connect(_on_mejoras_cambiadas)
	GameManager.checkpoint_guardado.connect(_on_checkpoint_guardado)
	GameManager.jugador_murio.connect(_on_jugador_murio)

	# Sincronizar valores iniciales
	_on_monedas_cambiadas(GameManager.monedas_rayo)
	_on_vida_cambiada(GameManager.vida_actual, GameManager.obtener_vida_maxima())
	_on_tiempo_cambiado(GameManager.tiempo_restante)
	_on_mejoras_cambiadas(GameManager.mejoras)


func _process(delta: float) -> void:
	if _en_alerta_tiempo and not _pausa_abierta and not GameManager.jugador_muerto:
		_tiempo_alerta_fase += delta * 10.0
		var pulso: float = 0.35 + 0.65 * (0.5 + 0.5 * sin(_tiempo_alerta_fase))
		lbl_tiempo.modulate = Color(1.0, 0.25, 0.28, pulso)
	else:
		lbl_tiempo.modulate = Color.WHITE


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.jugador_muerto:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var kc: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if kc == KEY_ESCAPE:
		if _pausa_abierta:
			_cerrar_pausa()
			get_viewport().set_input_as_handled()
		elif _puede_abrir_pausa():
			_abrir_pausa()
			get_viewport().set_input_as_handled()


func _puede_abrir_pausa() -> bool:
	if GameManager.jugador_muerto:
		return false
	if GameManager.hay_modal_interactivo_abierto():
		return false
	if get_tree().paused:
		return false
	return true


func _alternar_pausa() -> void:
	if _pausa_abierta:
		_cerrar_pausa()
	elif _puede_abrir_pausa():
		_abrir_pausa()


func _abrir_pausa() -> void:
	_pausa_abierta = true
	overlay_pausa.visible = true
	var perks_count: int = 0
	for v in GameManager.mejoras.values():
		if bool(v):
			perks_count += 1
	lbl_resumen_pausa.text = "Monedas de Rayo: %d   |   Mejoras Activas: %d / 3" % [
		GameManager.monedas_rayo, perks_count
	]
	GameManager.establecer_pausa(true)


func _cerrar_pausa() -> void:
	_pausa_abierta = false
	overlay_pausa.visible = false
	GameManager.establecer_pausa(false)


func _on_volver_menu_pressed() -> void:
	_pausa_abierta = false
	overlay_pausa.visible = false
	GameManager.volver_al_menu_principal()


func _on_jugador_murio(_motivo: String) -> void:
	if _pausa_abierta:
		_pausa_abierta = false
		overlay_pausa.visible = false


func _on_monedas_cambiadas(cantidad: int) -> void:
	lbl_monedas.text = str(cantidad)


func _on_vida_cambiada(actual: int, maxima: int) -> void:
	barra_vida.max_value = maxf(1.0, float(maxima))
	barra_vida.value = clampf(float(actual), 0.0, float(maxima))
	lbl_vida.text = "%d / %d HP" % [maxi(0, actual), maxima]

	var ratio: float = float(actual) / maxf(1.0, float(maxima))
	var fill := StyleBoxFlat.new()
	fill.set_corner_radius_all(0)
	if ratio > 0.55:
		fill.bg_color = COLOR_VERDE
	elif ratio > 0.25:
		fill.bg_color = COLOR_ORO
	else:
		fill.bg_color = COLOR_ROJO
	barra_vida.add_theme_stylebox_override("fill", fill)


func _on_tiempo_cambiado(segundos: float) -> void:
	var total_seg: int = maxi(0, int(ceil(segundos)))
	var mins: int = total_seg / 60
	var segs: int = total_seg % 60
	lbl_tiempo.text = "%02d:%02d" % [mins, segs]

	_en_alerta_tiempo = segundos <= 15.0 and segundos > 0.0
	if segundos <= 15.0:
		lbl_tiempo.add_theme_color_override("font_color", COLOR_ROJO)
	else:
		lbl_tiempo.add_theme_color_override("font_color", Color(0.82, 0.96, 1.0))
		lbl_tiempo.modulate = Color.WHITE


func _on_tiempo_agregado(segundos: float) -> void:
	lbl_bonus_tiempo.text = "+%ds" % int(round(segundos))
	lbl_bonus_tiempo.modulate = Color(0.35, 1.0, 0.95, 1.0)
	if _tween_bonus != null:
		_tween_bonus.kill()
	_tween_bonus = create_tween()
	_tween_bonus.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween_bonus.tween_interval(0.55)
	_tween_bonus.tween_property(lbl_bonus_tiempo, "modulate:a", 0.0, 0.65)


func _on_mejoras_cambiadas(mejoras: Dictionary) -> void:
	_actualizar_slot_mejora(slot_jugger, ico_jugger, bool(mejoras.get("jugger_nog", false)), Color(0.95, 0.26, 0.34))
	_actualizar_slot_mejora(slot_stamin, ico_stamin, bool(mejoras.get("stamin_up", false)), Color(0.98, 0.80, 0.22))
	_actualizar_slot_mejora(slot_double, ico_double, bool(mejoras.get("double_tap", false)), Color(1.0, 0.48, 0.16))


func _actualizar_slot_mejora(slot: PanelContainer, icono: TextureRect, activo: bool, color_borde: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(4)
	if activo:
		sb.bg_color = color_borde.darkened(0.75)
		sb.border_color = color_borde
		icono.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		sb.bg_color = Color(0.05, 0.08, 0.13, 0.72)
		sb.border_color = Color(0.22, 0.28, 0.36, 0.7)
		icono.modulate = Color(0.38, 0.42, 0.50, 0.45)
	slot.add_theme_stylebox_override("panel", sb)


func _on_checkpoint_guardado(_escena: String, _posicion: Vector2) -> void:
	lbl_toast_checkpoint.text = "CHECKPOINT GUARDADO"
	lbl_toast_checkpoint.modulate = Color(0.35, 1.0, 0.62, 1.0)
	if _tween_toast != null:
		_tween_toast.kill()
	_tween_toast = create_tween()
	_tween_toast.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween_toast.tween_interval(1.6)
	_tween_toast.tween_property(lbl_toast_checkpoint, "modulate:a", 0.0, 0.8)


func _estilizar_hud() -> void:
	for panel in [%PanelIzquierdo, %PanelCentro, %PanelDerecho]:
		if panel is PanelContainer:
			panel.add_theme_stylebox_override("panel", _crear_caja(COLOR_FONDO_PANEL, Color(0.22, 0.65, 0.85, 0.85), 2, 8))

	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.08, 0.11, 0.17, 0.95)
	sb_bg.border_color = Color(0.24, 0.34, 0.46, 0.9)
	sb_bg.set_border_width_all(1)
	sb_bg.set_corner_radius_all(0)
	barra_vida.add_theme_stylebox_override("background", sb_bg)

	panel_pausa.add_theme_stylebox_override("panel", _crear_caja(Color(0.04, 0.08, 0.14, 0.96), COLOR_CIAN, 3, 24))
	_estilizar_boton(btn_pausa, COLOR_CIAN, 6)
	_estilizar_boton(btn_reanudar, COLOR_VERDE, 10)
	_estilizar_boton(btn_menu_principal, COLOR_ORO, 10)


func _crear_caja(fondo: Color, borde: Color, grosor: int, margen: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.border_color = borde
	sb.set_border_width_all(grosor)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(margen)
	return sb


func _estilizar_boton(btn: Button, color: Color, margen: int) -> void:
	var sb_n := _crear_caja(color.darkened(0.75), color, 2, margen)
	var sb_h := _crear_caja(color.darkened(0.58), color.lightened(0.2), 2, margen)
	var sb_p := _crear_caja(color.darkened(0.45), Color.WHITE, 2, margen)
	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_p)
	btn.add_theme_stylebox_override("focus", sb_h)
	btn.add_theme_color_override("font_color", color.lightened(0.4))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
