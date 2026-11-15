extends Node2D

# ==============================================================================
# TRAMO 1 (NIVEL 3): RECORRIDO INICIAL, CHECKPOINTS Y ELECTROIMÁN MULTIVARIABLE
# Escena: res://Escenas/escena_03.tscn
# - Expande el Tramo 1 desde x = -1280 con plataformas medidas para Jugador.tscn
#   (SPEED = 220, JUMP_VELOCITY = -450), cables de energía en el fondo y sistema
#   de Checkpoints + recuperación automática ante caídas o derrota.
# - Consola multivariable en PanelContainer (alfa ~0.95) sobre CanvasLayer (layer = 10):
#   calibra Sentido de Corriente (Polos N/S), Espiras (N) y Corriente (I) para
#   estabilizar B = 1.20 T sin sobrecarga magnética.
# ==============================================================================

const POS_INICIO_JUGADOR := Vector2(-1160, -40)
const POS_TERMINAL := Vector2(330, -32)
const POS_ELECTROIMAN := Vector2(472, -165)
const POS_PUENTE_ALINEADO := Vector2(472, 8)
const POS_PUENTE_CAIDO := Vector2(472, 68)
const POS_BARRERA := Vector2(396, -56)

const CAMPO_META_TESLAS: float = 1.20
const CAMPO_MAX_SEGURO: float = 1.25
const OPCIONES_ESPIRAS: Array[int] = [100, 150, 200, 250, 300]
const OPCIONES_CORRIENTE: Array[float] = [2.0, 4.0, 6.0, 8.0, 10.0]

var idx_espiras: int = 1      # 150 espiras por defecto
var idx_corriente: int = 1    # 4.0 A por defecto -> B = 0.60 T
# sentido_corriente: 1 = Horario (Polo N abajo, repulsión), -1 = Antihorario (Polo S abajo, atracción)
var sentido_corriente: int = 1

var puente_alineado: bool = false
var sobrecarga_magnetica: bool = false
var jugador_cerca: bool = false
var panel_abierto: bool = false
var jugador_ref: CharacterBody2D = null
var area_terminal_ref: Area2D = null
var _tecla_e_prev: bool = false
var tiempo_anim: float = 0.0
var fase_ui: float = 0.0

# Sistema de Checkpoints y rescate
var ultimo_checkpoint_pos: Vector2 = POS_INICIO_JUGADOR
var indice_checkpoint_activo: int = 0
var _timer_reaparicion: float = 0.0
var _luces_checkpoint: Array[ColorRect] = []
var _labels_checkpoint: Array[Label] = []

# Nodos del mundo
var cable_tramo1: Line2D
var luces_tramo1: Array[ColorRect] = []
var electroiman_sprite: Sprite2D
var lbl_polo_sup: Label
var lbl_polo_inf: Label
var puente_body: StaticBody2D
var puente_col: CollisionShape2D
var puente_sprite: Sprite2D
var puente_aux_body: StaticBody2D
var puente_aux_col: CollisionShape2D
var puente_aux_sprite: Sprite2D
var barrera_body: StaticBody2D
var barrera_col: CollisionShape2D
var barrera_visual: Polygon2D
var lbl_prompt: Label
var lbl_estado_mundo: Label

# Nodos de UI (CanvasLayer layer = 10)
var canvas_ui: CanvasLayer
var panel_contenedor: PanelContainer
var lbl_hud_estado: Label
var barra_campo: ProgressBar
var lienzo_simulacion: Control
var linea_cable_ui_izq: Line2D
var linea_cable_ui_der: Line2D
var lineas_flujo_ui: Array[Line2D] = []
var espiras_visuales_ui: Array[ColorRect] = []
var pulsos_ui: Array[ColorRect] = []
var bloque_polo_sup_ui: ColorRect
var bloque_polo_inf_ui: ColorRect
var lbl_polo_inf_ui: Label
var bloque_puente_ui: ColorRect
var lbl_puente_ui: Label
var lbl_formula_ui: Label
var btn_horario: Button
var btn_antihorario: Button
var lbl_val_n: Label
var lbl_val_i: Label
var btn_confirmar: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_asegurar_input_interactuar()
	_construir_cables_y_checkpoints()
	_crear_electroiman_y_puente()
	_crear_terminal()
	_crear_ui()
	_actualizar_electroiman(true)

func _asegurar_input_interactuar() -> void:
	if not InputMap.has_action("interactuar"):
		InputMap.add_action("interactuar")
	var tiene_e := false
	for ev in InputMap.action_get_events("interactuar"):
		if ev is InputEventKey and ev.physical_keycode == KEY_E:
			tiene_e = true
			break
	if not tiene_e:
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_E
		InputMap.action_add_event("interactuar", ev)

func _construir_cables_y_checkpoints() -> void:
	# Cable guía de energía a lo largo de todo el Tramo 1
	cable_tramo1 = Line2D.new()
	cable_tramo1.width = 5.0
	cable_tramo1.z_index = -2
	cable_tramo1.default_color = Color(0.85, 0.22, 0.25, 0.85)
	cable_tramo1.points = PackedVector2Array([
		Vector2(-1220, 20),
		Vector2(-915, -14),
		Vector2(-755, -48),
		Vector2(-600, -14),
		Vector2(-480, 12),
		Vector2(330, 12),
		Vector2(330, -32),
		Vector2(330, -165),
		Vector2(472, -165),
		Vector2(560, 12),
		Vector2(760, 12)
	])
	add_child(cable_tramo1)

	var pts_luces: Array[Vector2] = [
		Vector2(-1100, 16), Vector2(-915, -18), Vector2(-755, -52),
		Vector2(-350, 8), Vector2(180, 8), Vector2(600, 8)
	]
	for p in pts_luces:
		var luz := ColorRect.new()
		luz.size = Vector2(10, 10)
		luz.position = p - Vector2(5, 5)
		luz.color = Color(0.95, 0.25, 0.3, 0.9)
		luz.z_index = -1
		luz.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(luz)
		luces_tramo1.append(luz)

	# 3 Puntos de Control (Checkpoints) distribuidos en los 3 tramos del nivel
	_crear_checkpoint(1, Vector2(760, 0), "CHECKPOINT 01")
	_crear_checkpoint(2, Vector2(2490, 0), "CHECKPOINT 02")
	_crear_checkpoint(3, Vector2(3150, 0), "CHECKPOINT 03")

func _crear_checkpoint(idx: int, pos: Vector2, titulo_cp: String) -> void:
	var area := Area2D.new()
	area.name = "Checkpoint_%d" % idx
	area.position = pos
	area.monitoring = true
	area.monitorable = false
	area.collision_layer = 0
	area.collision_mask = 1
	add_child(area)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(64, 96)
	col.shape = rect
	col.position = Vector2(0, -48)
	area.add_child(col)

	var poste := ColorRect.new()
	poste.position = Vector2(-5, -68)
	poste.size = Vector2(10, 68)
	poste.color = Color(0.16, 0.24, 0.34, 0.95)
	poste.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(poste)

	var luz := ColorRect.new()
	luz.position = Vector2(-12, -80)
	luz.size = Vector2(24, 14)
	luz.color = Color(0.9, 0.3, 0.3, 0.95)
	luz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(luz)
	_luces_checkpoint.append(luz)

	var lbl := Label.new()
	lbl.text = titulo_cp
	lbl.position = Vector2(-65, -102)
	lbl.size = Vector2(130, 20)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_to_group("texto_mundo_nivel3")
	area.add_child(lbl)
	_labels_checkpoint.append(lbl)

	area.body_entered.connect(func(body: Node2D):
		if body is CharacterBody2D or body.is_in_group("jugador"):
			_activar_checkpoint(idx, pos + Vector2(0, -42), body as CharacterBody2D)
	)

func _activar_checkpoint(idx: int, spawn_pos: Vector2, body: CharacterBody2D) -> void:
	ultimo_checkpoint_pos = spawn_pos
	if idx > indice_checkpoint_activo:
		indice_checkpoint_activo = idx
	if body and "vida_actual" in body:
		body.vida_actual = 100
	for i in range(_luces_checkpoint.size()):
		var activo := (i + 1) <= indice_checkpoint_activo
		_luces_checkpoint[i].color = Color(0.2, 1.0, 0.55, 1.0) if activo else Color(0.9, 0.3, 0.3, 0.95)
		if activo and i == idx - 1:
			_labels_checkpoint[i].text = "✓ CHECKPOINT %02d" % idx
			_labels_checkpoint[i].add_theme_color_override("font_color", Color(0.25, 1.0, 0.58))

func _verificar_rescate_jugador(delta: float) -> void:
	if not is_instance_valid(jugador_ref):
		var root := get_tree().current_scene if get_tree() else null
		if root:
			jugador_ref = root.get_node_or_null("CharacterBody2D") as CharacterBody2D
	if not is_instance_valid(jugador_ref):
		return

	var cayo_al_vacio := jugador_ref.global_position.y > 315.0
	var murio := ("esta_muerto" in jugador_ref and bool(jugador_ref.esta_muerto))
	if cayo_al_vacio or murio:
		_timer_reaparicion += delta
		if cayo_al_vacio or _timer_reaparicion >= 0.55:
			_timer_reaparicion = 0.0
			jugador_ref.global_position = ultimo_checkpoint_pos
			jugador_ref.velocity = Vector2.ZERO
			if "vida_actual" in jugador_ref:
				jugador_ref.vida_actual = 100
			if "esta_muerto" in jugador_ref:
				jugador_ref.esta_muerto = false
			var anim := jugador_ref.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			if anim:
				anim.play("Reposo")
	else:
		_timer_reaparicion = 0.0

func _crear_electroiman_y_puente() -> void:
	var nodo_iman := Node2D.new()
	nodo_iman.position = POS_ELECTROIMAN
	add_child(nodo_iman)

	electroiman_sprite = Sprite2D.new()
	var tex_iman := load("res://assets/nivel_3/electroiman_gigante.svg") as Texture2D
	if tex_iman:
		electroiman_sprite.texture = tex_iman
	nodo_iman.add_child(electroiman_sprite)

	lbl_polo_sup = Label.new()
	lbl_polo_sup.position = Vector2(-55, -36)
	lbl_polo_sup.size = Vector2(110, 22)
	lbl_polo_sup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_polo_sup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_polo_sup.add_theme_font_size_override("font_size", 11)
	lbl_polo_sup.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_polo_sup.add_theme_constant_override("outline_size", 4)
	lbl_polo_sup.add_to_group("texto_mundo_nivel3")
	nodo_iman.add_child(lbl_polo_sup)

	lbl_polo_inf = Label.new()
	lbl_polo_inf.position = Vector2(-70, 22)
	lbl_polo_inf.size = Vector2(140, 22)
	lbl_polo_inf.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_polo_inf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_polo_inf.add_theme_font_size_override("font_size", 12)
	lbl_polo_inf.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_polo_inf.add_theme_constant_override("outline_size", 4)
	lbl_polo_inf.add_to_group("texto_mundo_nivel3")
	nodo_iman.add_child(lbl_polo_inf)

	# Puente Metálico Principal (x = 400..544) en Capa 5 (Suelo = 16)
	puente_body = StaticBody2D.new()
	puente_body.name = "PuenteMetalico"
	puente_body.position = POS_PUENTE_CAIDO
	puente_body.rotation_degrees = 32.0
	puente_body.collision_layer = 16
	puente_body.collision_mask = 1
	add_child(puente_body)

	puente_col = CollisionShape2D.new()
	var rect_p := RectangleShape2D.new()
	rect_p.size = Vector2(160, 22)
	puente_col.shape = rect_p
	puente_col.disabled = true
	puente_body.add_child(puente_col)

	puente_sprite = Sprite2D.new()
	var tex_puente := load("res://assets/nivel_3/puente_metalico.svg") as Texture2D
	if tex_puente:
		puente_sprite.texture = tex_puente
	puente_body.add_child(puente_sprite)

	var lbl_norte_puente := Label.new()
	lbl_norte_puente.text = "Puente [Polo N]"
	lbl_norte_puente.position = Vector2(-65, -26)
	lbl_norte_puente.size = Vector2(130, 18)
	lbl_norte_puente.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_norte_puente.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_norte_puente.add_theme_font_size_override("font_size", 10)
	lbl_norte_puente.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
	lbl_norte_puente.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_norte_puente.add_theme_constant_override("outline_size", 3)
	lbl_norte_puente.add_to_group("texto_mundo_nivel3")
	puente_body.add_child(lbl_norte_puente)

	# Pasarela Magnética Secundaria sincronizada (x = 896..1344, y = 8)
	puente_aux_body = StaticBody2D.new()
	puente_aux_body.name = "PasarelaMagneticaAux"
	puente_aux_body.position = Vector2(1120, 8)
	puente_aux_body.collision_layer = 16
	puente_aux_body.collision_mask = 1
	add_child(puente_aux_body)

	puente_aux_col = CollisionShape2D.new()
	var rect_aux := RectangleShape2D.new()
	rect_aux.size = Vector2(456, 20)
	puente_aux_col.shape = rect_aux
	puente_aux_body.add_child(puente_aux_col)

	puente_aux_sprite = Sprite2D.new()
	if tex_puente:
		puente_aux_sprite.texture = tex_puente
		puente_aux_sprite.scale = Vector2(2.85, 1.0)
	puente_aux_body.add_child(puente_aux_sprite)

	# Barrera de contención mientras el puente está caído
	barrera_body = StaticBody2D.new()
	barrera_body.position = POS_BARRERA
	barrera_body.collision_layer = 16
	barrera_body.collision_mask = 1
	add_child(barrera_body)

	barrera_col = CollisionShape2D.new()
	var rect_b := RectangleShape2D.new()
	rect_b.size = Vector2(14, 112)
	barrera_col.shape = rect_b
	barrera_body.add_child(barrera_col)

	barrera_visual = Polygon2D.new()
	barrera_visual.polygon = PackedVector2Array([
		Vector2(-5, -56), Vector2(5, -56), Vector2(5, 56), Vector2(-5, 56)
	])
	barrera_visual.color = Color(1.0, 0.3, 0.25, 0.8)
	barrera_body.add_child(barrera_visual)

	lbl_estado_mundo = Label.new()
	lbl_estado_mundo.position = Vector2(POS_PUENTE_ALINEADO.x - 130, -42)
	lbl_estado_mundo.size = Vector2(260, 28)
	lbl_estado_mundo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_estado_mundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_estado_mundo.add_theme_font_size_override("font_size", 11)
	lbl_estado_mundo.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_estado_mundo.add_theme_constant_override("outline_size", 3)
	lbl_estado_mundo.add_to_group("texto_mundo_nivel3")
	add_child(lbl_estado_mundo)

func _crear_terminal() -> void:
	var area := Area2D.new()
	area_terminal_ref = area
	area.name = "TerminalElectroiman"
	area.position = POS_TERMINAL
	area.monitoring = true
	area.monitorable = true
	area.collision_layer = 0
	area.collision_mask = 1
	add_child(area)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(120, 120)
	col.shape = rect
	area.add_child(col)

	var spr := Sprite2D.new()
	var tex := load("res://assets/nivel_3/panel_magnetico.svg") as Texture2D
	if tex:
		spr.texture = tex
	area.add_child(spr)

	var btn_mundo := Button.new()
	btn_mundo.flat = true
	btn_mundo.position = Vector2(-36, -36)
	btn_mundo.size = Vector2(72, 72)
	btn_mundo.focus_mode = Control.FOCUS_NONE
	btn_mundo.pressed.connect(_abrir_panel)
	area.add_child(btn_mundo)

	lbl_prompt = Label.new()
	lbl_prompt.text = "[E] Interactuar"
	lbl_prompt.position = Vector2(-80, -60)
	lbl_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_prompt.add_theme_font_size_override("font_size", 13)
	lbl_prompt.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	lbl_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_prompt.add_theme_constant_override("outline_size", 3)
	lbl_prompt.visible = false
	lbl_prompt.add_to_group("texto_mundo_nivel3")
	area.add_child(lbl_prompt)

	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _crear_estilo_boton(activo: bool, col: Color) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	if activo:
		st.bg_color = col.darkened(0.62)
		st.border_color = col
		st.set_border_width_all(2)
	else:
		st.bg_color = Color(0.09, 0.13, 0.2, 0.95)
		st.border_color = Color(0.28, 0.36, 0.48, 0.85)
		st.set_border_width_all(1)
	st.set_corner_radius_all(6)
	st.set_content_margin_all(6)
	return st

func _crear_ui() -> void:
	canvas_ui = CanvasLayer.new()
	canvas_ui.layer = 10
	canvas_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas_ui.visible = false
	add_child(canvas_ui)

	var fondo := ColorRect.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.01, 0.02, 0.05, 0.72)
	fondo.mouse_filter = Control.MOUSE_FILTER_PASS
	canvas_ui.add_child(fondo)

	panel_contenedor = PanelContainer.new()
	panel_contenedor.custom_minimum_size = Vector2(600, 404)
	panel_contenedor.set_anchors_preset(Control.PRESET_CENTER)
	panel_contenedor.offset_left = -300
	panel_contenedor.offset_top = -202
	panel_contenedor.offset_right = 300
	panel_contenedor.offset_bottom = 202
	panel_contenedor.mouse_filter = Control.MOUSE_FILTER_STOP
	panel_contenedor.focus_mode = Control.FOCUS_NONE
	var style_panel := StyleBoxFlat.new()
	style_panel.bg_color = Color(0.05, 0.08, 0.14, 0.95)
	style_panel.border_color = Color(0.25, 0.85, 1.0)
	style_panel.set_border_width_all(3)
	style_panel.set_corner_radius_all(10)
	style_panel.set_content_margin_all(16)
	panel_contenedor.add_theme_stylebox_override("panel", style_panel)
	canvas_ui.add_child(panel_contenedor)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_theme_constant_override("separation", 8)
	panel_contenedor.add_child(vbox)

	# Barra superior compacta: OBJETIVO vs ACTUAL
	lbl_hud_estado = Label.new()
	lbl_hud_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_hud_estado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_hud_estado.add_theme_font_size_override("font_size", 17)
	vbox.add_child(lbl_hud_estado)

	barra_campo = ProgressBar.new()
	barra_campo.min_value = 0.0
	barra_campo.max_value = 1.80
	barra_campo.custom_minimum_size = Vector2(550, 18)
	barra_campo.show_percentage = false
	barra_campo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra_campo.focus_mode = Control.FOCUS_NONE
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.08, 0.12, 0.18, 0.95)
	sb_bg.set_corner_radius_all(5)
	barra_campo.add_theme_stylebox_override("background", sb_bg)
	vbox.add_child(barra_campo)

	# Simulación gráfica animada en tiempo real (Line2D + ColorRect)
	lienzo_simulacion = Control.new()
	lienzo_simulacion.custom_minimum_size = Vector2(560, 168)
	lienzo_simulacion.size = Vector2(560, 168)
	lienzo_simulacion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(lienzo_simulacion)

	var fondo_sim := ColorRect.new()
	fondo_sim.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo_sim.color = Color(0.03, 0.05, 0.09, 0.98)
	fondo_sim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo_simulacion.add_child(fondo_sim)

	var caja_fuente := ColorRect.new()
	caja_fuente.position = Vector2(18, 48)
	caja_fuente.size = Vector2(84, 72)
	caja_fuente.color = Color(0.11, 0.2, 0.34, 1.0)
	caja_fuente.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo_simulacion.add_child(caja_fuente)

	var lbl_fuente := Label.new()
	lbl_fuente.position = Vector2(18, 50)
	lbl_fuente.size = Vector2(84, 68)
	lbl_fuente.text = "SOLENOIDE\nB = µ·(N/L)·I"
	lbl_fuente.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_fuente.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_fuente.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_fuente.add_theme_font_size_override("font_size", 10)
	lbl_fuente.add_theme_color_override("font_color", Color(0.45, 0.92, 1.0))
	lienzo_simulacion.add_child(lbl_fuente)

	linea_cable_ui_izq = Line2D.new()
	linea_cable_ui_izq.width = 3.5
	linea_cable_ui_izq.points = PackedVector2Array([Vector2(102, 64), Vector2(228, 36)])
	lienzo_simulacion.add_child(linea_cable_ui_izq)

	linea_cable_ui_der = Line2D.new()
	linea_cable_ui_der.width = 3.5
	linea_cable_ui_der.points = PackedVector2Array([Vector2(102, 102), Vector2(228, 72)])
	lienzo_simulacion.add_child(linea_cable_ui_der)

	# Núcleo de hierro y polos del electroimán en el diagrama
	bloque_polo_sup_ui = ColorRect.new()
	bloque_polo_sup_ui.position = Vector2(236, 12)
	bloque_polo_sup_ui.size = Vector2(88, 16)
	bloque_polo_sup_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo_simulacion.add_child(bloque_polo_sup_ui)

	var nucleo_ui := ColorRect.new()
	nucleo_ui.position = Vector2(244, 28)
	nucleo_ui.size = Vector2(72, 46)
	nucleo_ui.color = Color(0.24, 0.3, 0.4, 1.0)
	nucleo_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo_simulacion.add_child(nucleo_ui)

	espiras_visuales_ui.clear()
	for i in range(5):
		var esp := ColorRect.new()
		esp.position = Vector2(238, 31 + i * 8)
		esp.size = Vector2(84, 5)
		esp.color = Color(0.95, 0.62, 0.15, 0.95)
		esp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lienzo_simulacion.add_child(esp)
		espiras_visuales_ui.append(esp)

	bloque_polo_inf_ui = ColorRect.new()
	bloque_polo_inf_ui.position = Vector2(232, 74)
	bloque_polo_inf_ui.size = Vector2(96, 20)
	bloque_polo_inf_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo_simulacion.add_child(bloque_polo_inf_ui)

	lbl_polo_inf_ui = Label.new()
	lbl_polo_inf_ui.position = Vector2(232, 74)
	lbl_polo_inf_ui.size = Vector2(96, 20)
	lbl_polo_inf_ui.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_polo_inf_ui.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_polo_inf_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_polo_inf_ui.add_theme_font_size_override("font_size", 11)
	lienzo_simulacion.add_child(lbl_polo_inf_ui)

	lineas_flujo_ui.clear()
	for i in range(5):
		var lf := Line2D.new()
		lf.width = 2.5
		lienzo_simulacion.add_child(lf)
		lineas_flujo_ui.append(lf)

	bloque_puente_ui = ColorRect.new()
	bloque_puente_ui.position = Vector2(188, 134)
	bloque_puente_ui.size = Vector2(184, 24)
	bloque_puente_ui.color = Color(0.22, 0.3, 0.42, 1.0)
	bloque_puente_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo_simulacion.add_child(bloque_puente_ui)

	var placa_n_ui := ColorRect.new()
	placa_n_ui.position = Vector2(52, 0)
	placa_n_ui.size = Vector2(80, 6)
	placa_n_ui.color = Color(0.95, 0.28, 0.28, 1.0)
	placa_n_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloque_puente_ui.add_child(placa_n_ui)

	lbl_puente_ui = Label.new()
	lbl_puente_ui.position = Vector2(0, 4)
	lbl_puente_ui.size = Vector2(184, 18)
	lbl_puente_ui.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_puente_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_puente_ui.add_theme_font_size_override("font_size", 10)
	bloque_puente_ui.add_child(lbl_puente_ui)

	pulsos_ui.clear()
	for i in range(5):
		var p := ColorRect.new()
		p.size = Vector2(7, 7)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lienzo_simulacion.add_child(p)
		pulsos_ui.append(p)

	# Operación corta debajo del diagrama
	lbl_formula_ui = Label.new()
	lbl_formula_ui.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_formula_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_formula_ui.add_theme_font_size_override("font_size", 14)
	vbox.add_child(lbl_formula_ui)

	# Selector de Sentido de Corriente ([1] vs [2])
	var hb_pol := HBoxContainer.new()
	hb_pol.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_pol.add_theme_constant_override("separation", 10)
	vbox.add_child(hb_pol)

	btn_horario = Button.new()
	btn_horario.text = "[1] I HORARIA (↻ Base NORTE)"
	btn_horario.custom_minimum_size = Vector2(248, 34)
	btn_horario.focus_mode = Control.FOCUS_NONE
	btn_horario.pressed.connect(func():
		sentido_corriente = 1
		_actualizar_electroiman(false)
	)
	hb_pol.add_child(btn_horario)

	btn_antihorario = Button.new()
	btn_antihorario.text = "[2] I ANTIHORARIA (↺ Base SUR)"
	btn_antihorario.custom_minimum_size = Vector2(248, 34)
	btn_antihorario.focus_mode = Control.FOCUS_NONE
	btn_antihorario.pressed.connect(func():
		sentido_corriente = -1
		_actualizar_electroiman(false)
	)
	hb_pol.add_child(btn_antihorario)

	# Controles multivariables: Espiras N ([W/S]) y Corriente I ([A/D]) + Activar/Cerrar
	var hb_ctrl := HBoxContainer.new()
	hb_ctrl.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_ctrl.add_theme_constant_override("separation", 6)
	vbox.add_child(hb_ctrl)

	var btn_n_menos := Button.new()
	btn_n_menos.text = "◀ -N [S/▼]"
	btn_n_menos.custom_minimum_size = Vector2(82, 34)
	btn_n_menos.focus_mode = Control.FOCUS_NONE
	btn_n_menos.pressed.connect(func(): _cambiar_espiras(-1))
	hb_ctrl.add_child(btn_n_menos)

	lbl_val_n = Label.new()
	lbl_val_n.custom_minimum_size = Vector2(78, 34)
	lbl_val_n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_val_n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_val_n.add_theme_font_size_override("font_size", 13)
	lbl_val_n.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	hb_ctrl.add_child(lbl_val_n)

	var btn_n_mas := Button.new()
	btn_n_mas.text = "[W/▲] +N ▶"
	btn_n_mas.custom_minimum_size = Vector2(82, 34)
	btn_n_mas.focus_mode = Control.FOCUS_NONE
	btn_n_mas.pressed.connect(func(): _cambiar_espiras(1))
	hb_ctrl.add_child(btn_n_mas)

	var btn_i_menos := Button.new()
	btn_i_menos.text = "◀ -I [A/◀]"
	btn_i_menos.custom_minimum_size = Vector2(80, 34)
	btn_i_menos.focus_mode = Control.FOCUS_NONE
	btn_i_menos.pressed.connect(func(): _cambiar_corriente(-1))
	hb_ctrl.add_child(btn_i_menos)

	lbl_val_i = Label.new()
	lbl_val_i.custom_minimum_size = Vector2(68, 34)
	lbl_val_i.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_val_i.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_val_i.add_theme_font_size_override("font_size", 13)
	lbl_val_i.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	hb_ctrl.add_child(lbl_val_i)

	var btn_i_mas := Button.new()
	btn_i_mas.text = "[D/▶] +I ▶"
	btn_i_mas.custom_minimum_size = Vector2(80, 34)
	btn_i_mas.focus_mode = Control.FOCUS_NONE
	btn_i_mas.pressed.connect(func(): _cambiar_corriente(1))
	hb_ctrl.add_child(btn_i_mas)

	btn_confirmar = Button.new()
	btn_confirmar.text = "OK [Enter]"
	btn_confirmar.custom_minimum_size = Vector2(76, 34)
	btn_confirmar.focus_mode = Control.FOCUS_NONE
	btn_confirmar.pressed.connect(_cerrar_panel)
	hb_ctrl.add_child(btn_confirmar)

	var btn_cerrar := Button.new()
	btn_cerrar.text = "✕ [E/Esc]"
	btn_cerrar.custom_minimum_size = Vector2(64, 34)
	btn_cerrar.focus_mode = Control.FOCUS_NONE
	btn_cerrar.pressed.connect(_cerrar_panel)
	hb_ctrl.add_child(btn_cerrar)

func _cambiar_espiras(delta_idx: int) -> void:
	idx_espiras = clampi(idx_espiras + delta_idx, 0, OPCIONES_ESPIRAS.size() - 1)
	_actualizar_electroiman(false)

func _cambiar_corriente(delta_idx: int) -> void:
	idx_corriente = clampi(idx_corriente + delta_idx, 0, OPCIONES_CORRIENTE.size() - 1)
	_actualizar_electroiman(false)

func _calcular_campo_b() -> float:
	var n_esp: float = float(OPCIONES_ESPIRAS[idx_espiras])
	var corr_i: float = OPCIONES_CORRIENTE[idx_corriente]
	# B = 0.001 * N * I (ej: 200 * 6.0 * 0.001 = 1.20 T; 150 * 8.0 * 0.001 = 1.20 T; 300 * 4.0 * 0.001 = 1.20 T)
	return n_esp * corr_i * 0.001

func _ocultar_textos_mundo(ocultar: bool) -> void:
	if get_tree():
		for n in get_tree().get_nodes_in_group("texto_mundo_nivel3"):
			if n is CanvasItem:
				if ocultar:
					n.visible = false
				else:
					if n == lbl_prompt:
						n.visible = jugador_cerca
					elif not n.name.begins_with("Prompt"):
						n.visible = true
	if lbl_prompt:
		lbl_prompt.visible = jugador_cerca and not ocultar
	if lbl_estado_mundo:
		lbl_estado_mundo.visible = not ocultar

func _congelar_jugador(congelar: bool) -> void:
	if not get_tree():
		return
	var root := get_tree().current_scene
	if not root:
		return
	for child in root.get_children():
		if child is CharacterBody2D and child.is_in_group("jugador"):
			child.set_physics_process(not congelar)

func _actualizar_electroiman(instantaneo: bool) -> void:
	var n_espiras: int = OPCIONES_ESPIRAS[idx_espiras]
	var corr_i: float = OPCIONES_CORRIENTE[idx_corriente]
	var campo_b: float = _calcular_campo_b()
	var estaba_alineado := puente_alineado

	sobrecarga_magnetica = campo_b > CAMPO_MAX_SEGURO
	puente_alineado = (sentido_corriente == -1) and is_equal_approx(campo_b, CAMPO_META_TESLAS)

	var col_estado: Color
	if puente_alineado:
		col_estado = Color(0.2, 1.0, 0.55)
	elif sobrecarga_magnetica or sentido_corriente == 1:
		col_estado = Color(1.0, 0.38, 0.38)
	else:
		col_estado = Color(1.0, 0.72, 0.25)

	if sentido_corriente == 1:
		lbl_polo_sup.text = "Polo SUR [S]"
		lbl_polo_sup.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0))
		lbl_polo_inf.text = "Polo NORTE [N] ↓"
		lbl_polo_inf.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	else:
		lbl_polo_sup.text = "Polo NORTE [N]"
		lbl_polo_sup.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		lbl_polo_inf.text = "Polo SUR [S] ↑"
		lbl_polo_inf.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))

	if lbl_hud_estado:
		var txt_polo := "Polo S" if sentido_corriente == -1 else "Polo N (Repulsión)"
		lbl_hud_estado.text = "OBJETIVO: 1.20 T (Polo S)   vs   ACTUAL: %.2f T (%s)" % [campo_b, txt_polo]
		lbl_hud_estado.add_theme_color_override("font_color", col_estado)

		barra_campo.value = min(campo_b, 1.80)
		var sb_fill := StyleBoxFlat.new()
		sb_fill.bg_color = col_estado
		sb_fill.set_corner_radius_all(5)
		barra_campo.add_theme_stylebox_override("fill", sb_fill)

		lbl_val_n.text = "N = %d" % n_espiras
		lbl_val_i.text = "I = %.0f A" % corr_i
		lbl_formula_ui.text = "B = 0.001 × %d esp × %.0f A = %.2f T" % [n_espiras, corr_i, campo_b]
		lbl_formula_ui.add_theme_color_override("font_color", col_estado)

		btn_horario.add_theme_stylebox_override("normal", _crear_estilo_boton(sentido_corriente == 1, Color(1.0, 0.42, 0.42)))
		btn_antihorario.add_theme_stylebox_override("normal", _crear_estilo_boton(sentido_corriente == -1, Color(0.25, 0.9, 1.0)))
		btn_confirmar.add_theme_stylebox_override("normal", _crear_estilo_boton(puente_alineado, Color(0.2, 0.98, 0.55)))

		bloque_polo_sup_ui.color = Color(0.25, 0.55, 0.95) if sentido_corriente == 1 else Color(0.95, 0.28, 0.28)
		bloque_polo_inf_ui.color = Color(0.95, 0.28, 0.28) if sentido_corriente == 1 else Color(0.25, 0.65, 1.0)
		lbl_polo_inf_ui.text = "BASE: POLO N" if sentido_corriente == 1 else "BASE: POLO S"

		for i in range(espiras_visuales_ui.size()):
			espiras_visuales_ui[i].visible = i <= idx_espiras

		var y_puente_ui := 112.0 if puente_alineado else (142.0 if sentido_corriente == 1 else 128.0)
		bloque_puente_ui.position = Vector2(188, y_puente_ui)
		lbl_puente_ui.text = "PUENTE [Polo N] — %s" % ("ALINEADO" if puente_alineado else ("SOBRECARGA" if sobrecarga_magnetica else "CAÍDO"))

		for i in range(lineas_flujo_ui.size()):
			var lf := lineas_flujo_ui[i]
			var x_lf := 244.0 + float(i) * 18.0
			lf.default_color = col_estado
			lf.points = PackedVector2Array([Vector2(x_lf, 94.0), Vector2(x_lf, y_puente_ui)])

		linea_cable_ui_izq.default_color = col_estado
		linea_cable_ui_der.default_color = col_estado

	# Actualizar cables del Tramo 1 y puente físico en Capa 5
	var col_cable_mundo := Color(0.2, 0.98, 0.55, 0.95) if puente_alineado else Color(0.85, 0.22, 0.25, 0.85)
	if cable_tramo1:
		cable_tramo1.default_color = col_cable_mundo
	for l in luces_tramo1:
		l.color = col_cable_mundo

	puente_col.set_deferred("disabled", not puente_alineado)
	barrera_col.set_deferred("disabled", puente_alineado)
	barrera_visual.visible = not puente_alineado

	if puente_alineado:
		lbl_estado_mundo.text = "🧲 PUENTE ALINEADO (B = 1.20 T)"
		lbl_estado_mundo.add_theme_color_override("font_color", Color(0.25, 1.0, 0.55))
	elif sobrecarga_magnetica:
		lbl_estado_mundo.text = "⚠️ SOBRECARGA MAGNÉTICA (%.2f T > 1.20 T)" % campo_b
		lbl_estado_mundo.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	elif sentido_corriente == 1:
		lbl_estado_mundo.text = "Repulsión N-N (%.2f T / Meta: 1.20 T Polo S)" % campo_b
		lbl_estado_mundo.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	else:
		lbl_estado_mundo.text = "Campo Insuficiente (%.2f T / 1.20 T)" % campo_b
		lbl_estado_mundo.add_theme_color_override("font_color", Color(1.0, 0.8, 0.35))

	var pos_dest := POS_PUENTE_ALINEADO if puente_alineado else POS_PUENTE_CAIDO
	var rot_dest := 0.0 if puente_alineado else 32.0
	if not instantaneo and estaba_alineado != puente_alineado and is_inside_tree():
		var tw := create_tween().set_parallel(true)
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(puente_body, "position", pos_dest, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(puente_body, "rotation_degrees", rot_dest, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		puente_body.position = pos_dest
		puente_body.rotation_degrees = rot_dest

	queue_redraw()

func _animar_ui(delta: float) -> void:
	if not panel_abierto or panel_contenedor == null or not panel_contenedor.is_visible_in_tree():
		return
	var dir := -1.0 if sentido_corriente == -1 else 1.0
	fase_ui = fmod(fase_ui + delta * 0.95 * dir + 1.0, 1.0)
	var col_p := Color(0.35, 1.0, 0.65) if puente_alineado else Color(1.0, 0.75, 0.3)
	for i in range(pulsos_ui.size()):
		var p := pulsos_ui[i]
		p.color = col_p
		var t := fmod(fase_ui + float(i) / float(pulsos_ui.size()), 1.0)
		var x_lf := 244.0 + float(i) * 18.0
		var y_puente_ui := 112.0 if puente_alineado else 132.0
		p.position = Vector2(x_lf - 3.5, lerpf(94.0, y_puente_ui - 6.0, t))

func _process(delta: float) -> void:
	tiempo_anim += delta * 3.0
	_verificar_rescate_jugador(delta)

	if area_terminal_ref and area_terminal_ref.monitoring:
		var detectado := false
		for b in area_terminal_ref.get_overlapping_bodies():
			if b is CharacterBody2D or b.is_in_group("jugador"):
				detectado = true
				jugador_ref = b as CharacterBody2D
				break
		jugador_cerca = detectado
		if not panel_abierto and lbl_prompt:
			lbl_prompt.visible = jugador_cerca

	_animar_ui(delta)
	queue_redraw()

	var e_actual: bool = Input.is_physical_key_pressed(KEY_E) or Input.is_key_pressed(KEY_E)
	if e_actual and not _tecla_e_prev:
		if panel_abierto and panel_contenedor and panel_contenedor.is_visible_in_tree():
			_cerrar_panel()
		elif jugador_cerca and not panel_abierto:
			_abrir_panel()
	_tecla_e_prev = e_actual

func _draw() -> void:
	var col_campo := Color(0.2, 0.98, 0.55, 0.9) if puente_alineado else (Color(0.35, 0.9, 1.0, 0.85) if sentido_corriente == -1 else Color(1.0, 0.4, 0.4, 0.85))
	var y_top := POS_ELECTROIMAN.y + 42.0
	var y_bot := puente_body.position.y - 12.0
	var num_lineas: int = idx_espiras + 2
	for i in range(num_lineas):
		var t := float(i) / float(max(num_lineas - 1, 1)) - 0.5
		var x_pos := POS_ELECTROIMAN.x + t * 76.0
		draw_dashed_line(Vector2(x_pos, y_top), Vector2(x_pos, y_bot), col_campo, 2.2, 6.0)
		var fase := fmod(tiempo_anim + float(i) * 0.25, 1.0)
		if sentido_corriente == 1:
			var py := lerpf(y_top + 8.0, y_bot - 6.0, fase)
			draw_line(Vector2(x_pos, py), Vector2(x_pos - 5, py - 7), col_campo, 2.4)
			draw_line(Vector2(x_pos, py), Vector2(x_pos + 5, py - 7), col_campo, 2.4)
		else:
			var py := lerpf(y_bot - 6.0, y_top + 8.0, fase)
			draw_line(Vector2(x_pos, py), Vector2(x_pos - 5, py + 7), col_campo, 2.4)
			draw_line(Vector2(x_pos, py), Vector2(x_pos + 5, py + 7), col_campo, 2.4)

func _abrir_panel() -> void:
	panel_abierto = true
	canvas_ui.visible = true
	_ocultar_textos_mundo(true)
	_congelar_jugador(true)
	if get_viewport():
		get_viewport().gui_release_focus()
	_actualizar_electroiman(true)

func _cerrar_panel() -> void:
	panel_abierto = false
	canvas_ui.visible = false
	if get_viewport():
		get_viewport().gui_release_focus()
	get_tree().paused = false
	_congelar_jugador(false)
	_ocultar_textos_mundo(false)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var kc: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode

	if panel_abierto and panel_contenedor != null and panel_contenedor.is_visible_in_tree():
		match kc:
			KEY_1, KEY_KP_1:
				sentido_corriente = 1
				_actualizar_electroiman(false)
				get_viewport().set_input_as_handled()
			KEY_2, KEY_KP_2:
				sentido_corriente = -1
				_actualizar_electroiman(false)
				get_viewport().set_input_as_handled()
			KEY_S, KEY_DOWN:
				_cambiar_espiras(-1)
				get_viewport().set_input_as_handled()
			KEY_W, KEY_UP:
				_cambiar_espiras(1)
				get_viewport().set_input_as_handled()
			KEY_A, KEY_LEFT:
				_cambiar_corriente(-1)
				get_viewport().set_input_as_handled()
			KEY_D, KEY_RIGHT:
				_cambiar_corriente(1)
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_cerrar_panel()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE, KEY_E:
				_tecla_e_prev = true
				_cerrar_panel()
				get_viewport().set_input_as_handled()
	elif not panel_abierto and jugador_cerca and kc == KEY_E:
		_tecla_e_prev = true
		_abrir_panel()
		get_viewport().set_input_as_handled()

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D or body.is_in_group("jugador"):
		jugador_cerca = true
		jugador_ref = body as CharacterBody2D
		if not panel_abierto and lbl_prompt:
			lbl_prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body == jugador_ref:
		jugador_cerca = false
		if lbl_prompt:
			lbl_prompt.visible = false
