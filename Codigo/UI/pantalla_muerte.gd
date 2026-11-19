extends CanvasLayer

# ==============================================================================
# PANTALLA DE MUERTE (res://Escenas/PantallaMuerte.tscn)
# CanvasLayer en layer = 100 (por encima del HUD y efectos de cámara) y
# process_mode = PROCESS_MODE_ALWAYS para responder aunque el árbol esté pausado.
# ==============================================================================

const COLOR_ROJO := Color(1.0, 0.28, 0.32)
const COLOR_VERDE := Color(0.24, 0.95, 0.55)
const COLOR_ORO := Color(0.98, 0.82, 0.28)

@onready var panel_muerte: PanelContainer = %PanelMuerte
@onready var lbl_motivo: Label = %LblMotivo
@onready var lbl_checkpoint: Label = %LblCheckpoint
@onready var btn_reaparecer: Button = %BtnReaparecer
@onready var btn_menu: Button = %BtnMenu


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pantalla_muerte")
	visible = false

	_aplicar_estilos()
	btn_reaparecer.pressed.connect(_on_reaparecer_pressed)
	btn_menu.pressed.connect(_on_menu_pressed)
	GameManager.jugador_murio.connect(_on_jugador_murio)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if kc in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_R]:
			get_viewport().set_input_as_handled()
			_on_reaparecer_pressed()
		elif kc == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_menu_pressed()


func _on_jugador_murio(motivo: String) -> void:
	lbl_motivo.text = motivo if not motivo.is_empty() else "HAS CAÍDO"
	var nivel := GameManager.obtener_nombre_nivel(GameManager.checkpoint_escena)
	lbl_checkpoint.text = "Último checkpoint: %s\nConservarás tus Monedas de Rayo y mejoras de partida." % nivel

	# En caídas al vacío o fin de tiempo mostrar de inmediato; en combate breve pausa de animación
	var motivo_mayus := motivo.to_upper()
	var mostrar_inmediato := motivo_mayus.contains("VACÍO") or motivo_mayus.contains("VACIO") or motivo_mayus.contains("TIEMPO")
	if not mostrar_inmediato and is_inside_tree():
		await get_tree().create_timer(0.45, true).timeout
		if not GameManager.jugador_muerto:
			return

	visible = true
	get_tree().paused = true


func _on_reaparecer_pressed() -> void:
	visible = false
	GameManager.reaparecer_en_checkpoint()


func _on_menu_pressed() -> void:
	visible = false
	GameManager.volver_al_menu_principal()


func _aplicar_estilos() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.03, 0.05, 0.96)
	sb.border_color = COLOR_ROJO
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(28)
	panel_muerte.add_theme_stylebox_override("panel", sb)

	_estilizar_boton(btn_reaparecer, COLOR_VERDE)
	_estilizar_boton(btn_menu, COLOR_ORO)


func _estilizar_boton(btn: Button, color: Color) -> void:
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = color.darkened(0.75)
	sb_n.border_color = color
	sb_n.set_border_width_all(2)
	sb_n.set_corner_radius_all(0)
	sb_n.set_content_margin_all(12)

	var sb_h := sb_n.duplicate() as StyleBoxFlat
	sb_h.bg_color = color.darkened(0.56)
	sb_h.border_color = color.lightened(0.2)

	var sb_p := sb_n.duplicate() as StyleBoxFlat
	sb_p.bg_color = color.darkened(0.42)
	sb_p.border_color = Color.WHITE

	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_p)
	btn.add_theme_stylebox_override("focus", sb_h)
	btn.add_theme_color_override("font_color", color.lightened(0.35))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
