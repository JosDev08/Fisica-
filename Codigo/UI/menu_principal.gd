extends Control

# ==============================================================================
# PANTALLA PRINCIPAL Y DE CARGA — "ELECTRIC RUNNER"
# Escena: res://Escenas/UI/MenuPrincipal.tscn
# - Título pixel art animado con Tween (flotación + brillo eléctrico)
# - Fondo de laboratorio cibernético en capas, cuadrícula de circuitos animada,
#   bobinas Tesla vectoriales y partículas CPUParticles2D de chispas eléctricas
# - Botones estilizados interactivos: JUGAR, CONTINUAR y SALIR
# - Audio chill en bucle suave (-6 dB) si existe pista en res://assets/musica/
# - Pantalla de carga animada (0% -> 100%) con barra de voltaje, chispas y
#   consejo breve de física antes de entrar al nivel
# ==============================================================================

const COLOR_CIAN := Color("#00F0FF")
const COLOR_VOLTAJE := Color("#FFD600")
const COLOR_BORDE_OSCURO := Color("#060B18")
const COLOR_SALIR := Color("#FF4D6D")
const COLOR_VERDE := Color("#2CF28A")
const COLOR_GRID := Color(0.0, 0.72, 0.92, 0.14)
const COLOR_GRID_SUB := Color(0.0, 0.55, 0.78, 0.06)

const VOLUMEN_MUSICA_DB: float = -6.0
const DURACION_CARGA_SEG: float = 1.45

const RUTAS_MUSICA_CANDIDATAS: Array[String] = [
	"res://assets/Musica/Pantalla menu.mp3",
	"res://assets/musica/musica_carga.mp3",
	"res://assets/musica/musica_carga.wav",
	"res://assets/musica/musica_carga.ogg",
	"res://assets/musica/menu.mp3",
	"res://assets/musica/menu.wav",
	"res://assets/musica/menu.ogg",
]

const CONSEJOS_FISICA: Array[String] = [
	"Ley de Ohm (V = I · R): al aumentar la resistencia en un circuito, la corriente eléctrica disminuye para un mismo voltaje.",
	"Ley de Coulomb: las cargas eléctricas del mismo signo se repelen y las de signo opuesto se atraen con fuerza proporcional a 1/r².",
	"Capacitores en paralelo: sus capacitancias se suman directamente (C_eq = C₁ + C₂), permitiendo almacenar mayor carga al mismo voltaje.",
	"Capacitores en serie: la capacitancia equivalente es siempre menor que la del capacitor más pequeño (1/C_eq = 1/C₁ + 1/C₂).",
	"Ley de Inducción de Faraday: un flujo magnético variable en el tiempo induce una fuerza electromotriz (voltaje) en una bobina.",
	"Potencia eléctrica (P = V · I = I² · R): duplicar la corriente en una resistencia cuadruplica el calor disipado.",
	"Ley de Kirchhoff de voltajes: la suma algebraica de las diferencias de potencial alrededor de cualquier malla cerrada es cero.",
	"Campo eléctrico (E = F / q): indica la fuerza que experimentaría una carga positiva de prueba colocada en ese punto del espacio.",
]

@onready var capa_circuitos: Control = %CapaCircuitosAnimados
@onready var bobina_izq: TextureRect = %BobinaIzquierda
@onready var bobina_der: TextureRect = %BobinaDerecha
@onready var particulas_cian: CPUParticles2D = %ParticulasChispasCian
@onready var particulas_oro: CPUParticles2D = %ParticulasChispasOro

@onready var bloque_titulo: VBoxContainer = %BloqueTitulo
@onready var rayo_izq: TextureRect = %RayoIzq
@onready var rayo_der: TextureRect = %RayoDer
@onready var panel_principal: PanelContainer = %PanelPrincipal

@onready var btn_jugar: Button = %BtnJugar
@onready var btn_continuar: Button = %BtnContinuar
@onready var btn_salir: Button = %BtnSalir
@onready var lbl_estado_guardado: Label = %LblEstadoGuardado

@onready var overlay_carga: Control = %OverlayCarga
@onready var capa_efectos_carga: Control = %CapaEfectosCarga
@onready var panel_carga: PanelContainer = %PanelCarga
@onready var lbl_destino_carga: Label = %LblDestinoCarga
@onready var barra_voltaje: ProgressBar = %BarraVoltaje
@onready var chispas_barra_carga: CPUParticles2D = %ChispasBarraCarga
@onready var lbl_porcentaje: Label = %LblPorcentaje
@onready var lbl_voltaje_kv: Label = %LblVoltajeKV
@onready var caja_consejo: PanelContainer = %CajaConsejo
@onready var lbl_consejo_fisica: Label = %LblConsejoFisica

@onready var musica_fondo: AudioStreamPlayer = %MusicaFondo

var _tiempo_anim: float = 0.0
var _puede_continuar: bool = false
var _indice_seleccion: int = 0
var _pulsos_circuito: Array[Dictionary] = []
var _tweens_botones: Dictionary = {}

# Estado de pantalla de carga
var _cargando_escena: bool = false
var _ruta_destino_carga: String = ""
var _progreso_visual: float = 0.0
var _tiempo_carga: float = 0.0
var _carga_threaded_iniciada: bool = false
var _transicion_disparada: bool = false
var _barra_fill_style: StyleBoxFlat = null


func _ready() -> void:
	get_tree().paused = false
	randomize()

	_generar_pulsos_circuito()
	_aplicar_estilos_pixel()
	_actualizar_estado_guardado()
	_conectar_senales()
	_configurar_audio_chill()

	overlay_carga.visible = false
	overlay_carga.modulate.a = 0.0
	chispas_barra_carga.emitting = false

	_seleccionar_indice(1 if _puede_continuar else 0, false)
	call_deferred("_post_layout_init")


func _post_layout_init() -> void:
	_actualizar_limites_particulas()
	_actualizar_pivotes_botones()
	_iniciar_animaciones_titulo()
	_iniciar_animaciones_bobinas()
	_actualizar_escala_botones()


func _conectar_senales() -> void:
	resized.connect(_on_resized)
	capa_circuitos.draw.connect(_dibujar_circuitos_animados)
	capa_efectos_carga.draw.connect(_dibujar_efectos_carga)

	btn_jugar.pressed.connect(_on_jugar_pressed)
	btn_continuar.pressed.connect(_on_continuar_pressed)
	btn_salir.pressed.connect(_on_salir_pressed)

	btn_jugar.mouse_entered.connect(func(): _seleccionar_indice(0, true))
	btn_continuar.mouse_entered.connect(func():
		if _puede_continuar:
			_seleccionar_indice(1, true)
	)
	btn_salir.mouse_entered.connect(func(): _seleccionar_indice(2, true))

	btn_jugar.resized.connect(_actualizar_pivotes_botones)
	btn_continuar.resized.connect(_actualizar_pivotes_botones)
	btn_salir.resized.connect(_actualizar_pivotes_botones)


func _on_resized() -> void:
	_actualizar_limites_particulas()
	_actualizar_pivotes_botones()


func _actualizar_limites_particulas() -> void:
	var centro := size * 0.5
	var extents := Vector2(maxf(size.x * 0.5, 320.0), maxf(size.y * 0.5, 180.0))
	if particulas_cian != null:
		particulas_cian.position = centro
		particulas_cian.emission_rect_extents = extents
	if particulas_oro != null:
		particulas_oro.position = centro
		particulas_oro.emission_rect_extents = extents


func _actualizar_pivotes_botones() -> void:
	for btn in [btn_jugar, btn_continuar, btn_salir]:
		if btn != null:
			btn.pivot_offset = btn.size * 0.5


func _process(delta: float) -> void:
	_tiempo_anim += delta
	_actualizar_pulsos_circuito(delta)
	capa_circuitos.queue_redraw()

	if _cargando_escena:
		_actualizar_pantalla_carga(delta)
		capa_efectos_carga.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _cargando_escena:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	var kc: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if kc in [KEY_UP, KEY_W]:
		_mover_seleccion(-1)
		get_viewport().set_input_as_handled()
	elif kc in [KEY_DOWN, KEY_S]:
		_mover_seleccion(1)
		get_viewport().set_input_as_handled()
	elif kc in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_activar_boton_actual()
		get_viewport().set_input_as_handled()
	elif kc == KEY_ESCAPE:
		_seleccionar_indice(2, true)
		get_viewport().set_input_as_handled()


func _mover_seleccion(direccion: int) -> void:
	var indices_validos: Array[int] = [0]
	if _puede_continuar:
		indices_validos.append(1)
	indices_validos.append(2)

	var pos := indices_validos.find(_indice_seleccion)
	if pos == -1:
		pos = 0
	else:
		pos = wrapi(pos + direccion, 0, indices_validos.size())
	_seleccionar_indice(indices_validos[pos], true)


func _activar_boton_actual() -> void:
	match _indice_seleccion:
		0:
			_on_jugar_pressed()
		1:
			if _puede_continuar:
				_on_continuar_pressed()
		2:
			_on_salir_pressed()


# ==============================================================================
# ANIMACIONES DE TÍTULO Y BOBINAS CON TWEEN
# ==============================================================================
func _iniciar_animaciones_titulo() -> void:
	if bloque_titulo == null:
		return

	# Flotación vertical suave y constante
	var base_y: float = bloque_titulo.position.y
	var tween_flote := create_tween().set_loops()
	tween_flote.tween_property(bloque_titulo, "position:y", base_y - 6.0, 1.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_flote.tween_property(bloque_titulo, "position:y", base_y + 5.0, 1.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Pulso luminoso eléctrico sutil en el título
	var tween_brillo := create_tween().set_loops()
	tween_brillo.tween_property(bloque_titulo, "modulate", Color(1.16, 1.22, 1.28, 1.0), 1.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_brillo.tween_property(bloque_titulo, "modulate", Color(0.97, 0.99, 1.0, 1.0), 1.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Pulsación energética en los rayos laterales del logo
	for rayo in [rayo_izq, rayo_der]:
		if rayo != null:
			rayo.pivot_offset = rayo.size * 0.5
			var tw_r := create_tween().set_loops()
			tw_r.tween_property(rayo, "scale", Vector2(1.12, 1.12), 0.9) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw_r.tween_property(rayo, "scale", Vector2(0.95, 0.95), 0.9) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _iniciar_animaciones_bobinas() -> void:
	if bobina_izq != null:
		var tw_l := create_tween().set_loops()
		tw_l.tween_property(bobina_izq, "modulate", Color(1.22, 1.28, 1.35, 0.95), 1.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw_l.tween_property(bobina_izq, "modulate", Color(0.88, 0.94, 1.0, 0.85), 1.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if bobina_der != null:
		var tw_r := create_tween().set_loops()
		tw_r.tween_property(bobina_der, "modulate", Color(0.88, 0.94, 1.0, 0.85), 1.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw_r.tween_property(bobina_der, "modulate", Color(1.22, 1.28, 1.35, 0.95), 1.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ==============================================================================
# CUADRÍCULA DE CIRCUITOS LUMINOSOS ANIMADOS Y ARCOS ELÉCTRICOS
# ==============================================================================
func _generar_pulsos_circuito() -> void:
	_pulsos_circuito.clear()
	for i in range(18):
		_pulsos_circuito.append({
			"horizontal": (i % 2 == 0),
			"linea": randi_range(1, 18),
			"pos": randf() * 1280.0,
			"vel": randf_range(95.0, 210.0) * (1.0 if randf() > 0.5 else -1.0),
			"largo": randf_range(44.0, 110.0),
			"color": COLOR_VOLTAJE if (i % 3 == 0) else COLOR_CIAN,
		})


func _actualizar_pulsos_circuito(delta: float) -> void:
	var max_w := maxf(size.x, 1280.0)
	var max_h := maxf(size.y, 720.0)
	for p in _pulsos_circuito:
		p["pos"] = float(p["pos"]) + float(p["vel"]) * delta
		var limite := max_w if bool(p["horizontal"]) else max_h
		var largo := float(p["largo"])
		if float(p["pos"]) > limite + largo:
			p["pos"] = -largo
			p["linea"] = randi_range(1, int(maxf(4.0, (max_h if bool(p["horizontal"]) else max_w) / 48.0)))
		elif float(p["pos"]) < -largo:
			p["pos"] = limite + largo
			p["linea"] = randi_range(1, int(maxf(4.0, (max_h if bool(p["horizontal"]) else max_w) / 48.0)))


func _dibujar_circuitos_animados() -> void:
	var w: float = capa_circuitos.size.x
	var h: float = capa_circuitos.size.y
	if w <= 0.0 or h <= 0.0:
		return

	# 1. Cuadrícula tecnológica animada con desplazamiento sutil
	var paso: float = 48.0
	var offset_y: float = fmod(_tiempo_anim * 10.0, paso)
	var x: float = 0.0
	while x < w:
		capa_circuitos.draw_line(Vector2(x, 0.0), Vector2(x, h), COLOR_GRID, 1.0)
		x += paso

	var y: float = offset_y - paso
	while y < h:
		capa_circuitos.draw_line(Vector2(0.0, y), Vector2(w, y), COLOR_GRID, 1.0)
		y += paso

	# Nodos luminosos en intersecciones alternas
	var nx: float = paso
	while nx < w:
		var ny: float = offset_y
		while ny < h:
			var pulso := 0.25 + 0.75 * (0.5 + 0.5 * sin(_tiempo_anim * 2.2 + (nx + ny) * 0.015))
			var col_nodo := Color(COLOR_CIAN.r, COLOR_CIAN.g, COLOR_CIAN.b, 0.18 * pulso)
			capa_circuitos.draw_rect(Rect2(nx - 2.0, ny - 2.0, 4.0, 4.0), col_nodo, true)
			ny += paso * 2.0
		nx += paso * 2.0

	# 2. Pulsos de corriente recorriendo trazas de circuitos
	for p in _pulsos_circuito:
		var col: Color = p["color"]
		var col_traza := Color(col.r, col.g, col.b, 0.38)
		var col_cabeza := Color(col.r, col.g, col.b, 0.88)
		var largo: float = float(p["largo"])
		var pos: float = float(p["pos"])
		var coord: float = float(p["linea"]) * paso

		if bool(p["horizontal"]):
			var py: float = fmod(coord + offset_y, h)
			capa_circuitos.draw_line(Vector2(pos - largo * 0.5, py), Vector2(pos + largo * 0.5, py), col_traza, 2.0)
			capa_circuitos.draw_rect(Rect2(pos - 3.0, py - 3.0, 6.0, 6.0), col_cabeza, true)
		else:
			var px: float = fmod(coord, w)
			capa_circuitos.draw_line(Vector2(px, pos - largo * 0.5), Vector2(px, pos + largo * 0.5), col_traza, 2.0)
			capa_circuitos.draw_rect(Rect2(px - 3.0, pos - 3.0, 6.0, 6.0), col_cabeza, true)

	# 3. Arcos eléctricos sutiles sobre las bobinas Tesla laterales
	_dibujar_arco_bobina(Vector2(104.0, h - 270.0), 1.0)
	_dibujar_arco_bobina(Vector2(w - 104.0, h - 270.0), -1.0)

	# 4. Scanlines pixel art muy sutiles
	var sy: float = 0.0
	var col_scan := Color(0.0, 0.02, 0.05, 0.09)
	while sy < h:
		capa_circuitos.draw_line(Vector2(0.0, sy), Vector2(w, sy), col_scan, 1.0)
		sy += 4.0

	# 5. Marco perimetral cibernético
	capa_circuitos.draw_rect(
		Rect2(10.0, 10.0, maxf(0.0, w - 20.0), maxf(0.0, h - 20.0)),
		Color(0.0, 0.94, 1.0, 0.25),
		false,
		2.0
	)


func _dibujar_arco_bobina(origen: Vector2, lado: float) -> void:
	var intensidad := 0.5 + 0.5 * sin(_tiempo_anim * 9.5 + lado * 1.7)
	if intensidad < 0.35:
		return

	var puntos: PackedVector2Array = PackedVector2Array()
	var destino := origen + Vector2(lado * (42.0 + 18.0 * sin(_tiempo_anim * 6.0)), -34.0 + 14.0 * cos(_tiempo_anim * 5.0))
	var segmentos: int = 5
	for i in range(segmentos + 1):
		var t: float = float(i) / float(segmentos)
		var pt := origen.lerp(destino, t)
		if i > 0 and i < segmentos:
			var jitter := sin(_tiempo_anim * 28.0 + float(i) * 2.7 + lado) * 9.0
			pt.y += jitter
			pt.x += cos(_tiempo_anim * 22.0 + float(i) * 3.1) * 5.0
		puntos.append(pt)

	var col_halo := Color(COLOR_CIAN.r, COLOR_CIAN.g, COLOR_CIAN.b, 0.32 * intensidad)
	var col_core := Color(1.0, 0.96, 0.72, 0.85 * intensidad)
	capa_circuitos.draw_polyline(puntos, col_halo, 4.0)
	capa_circuitos.draw_polyline(puntos, col_core, 1.5)


func _dibujar_efectos_carga() -> void:
	var w: float = capa_efectos_carga.size.x
	var h: float = capa_efectos_carga.size.y
	if w <= 0.0 or h <= 0.0:
		return

	var paso: float = 36.0
	var offset_x: float = fmod(_tiempo_anim * 24.0, paso)
	var x: float = offset_x - paso
	while x < w:
		capa_efectos_carga.draw_line(Vector2(x, 0.0), Vector2(x, h), COLOR_GRID_SUB, 1.0)
		x += paso
	var y: float = 0.0
	while y < h:
		capa_efectos_carga.draw_line(Vector2(0.0, y), Vector2(w, y), COLOR_GRID_SUB, 1.0)
		y += paso

	capa_efectos_carga.draw_rect(
		Rect2(14.0, 14.0, maxf(0.0, w - 28.0), maxf(0.0, h - 28.0)),
		Color(COLOR_VOLTAJE.r, COLOR_VOLTAJE.g, COLOR_VOLTAJE.b, 0.25),
		false,
		2.0
	)


# ==============================================================================
# ESTADO DE GUARDADO Y BOTONES ESTILIZADOS
# ==============================================================================
func _actualizar_estado_guardado() -> void:
	GameManager.cargar_partida()
	_puede_continuar = GameManager.existe_partida_guardada()
	btn_continuar.disabled = not _puede_continuar

	if _puede_continuar:
		var nombre_nivel := GameManager.obtener_nombre_nivel(GameManager.checkpoint_escena)
		var mejoras_totales: int = GameManager.nivel_vida + GameManager.nivel_velocidad + GameManager.nivel_danio
		lbl_estado_guardado.text = "PARTIDA GUARDADA: %s  |  RAYOS: %d  |  MEJORAS: %d" % [
			nombre_nivel, GameManager.monedas_rayo, mejoras_totales
		]
		lbl_estado_guardado.add_theme_color_override("font_color", COLOR_VERDE)
		btn_continuar.modulate = Color.WHITE
	else:
		lbl_estado_guardado.text = "Sin partida guardada — Presiona JUGAR para iniciar en el Nivel 1"
		lbl_estado_guardado.add_theme_color_override("font_color", Color(0.64, 0.78, 0.90))
		btn_continuar.modulate = Color(0.66, 0.72, 0.80, 0.72)


func _seleccionar_indice(idx: int, animar_escala: bool = true) -> void:
	_indice_seleccion = clampi(idx, 0, 2)
	if _indice_seleccion == 1 and not _puede_continuar:
		_indice_seleccion = 0

	btn_jugar.text = "▶   JUGAR   ◀" if _indice_seleccion == 0 else "JUGAR"
	if _puede_continuar:
		btn_continuar.text = "▶   CONTINUAR   ◀" if _indice_seleccion == 1 else "CONTINUAR"
	else:
		btn_continuar.text = "CONTINUAR (SIN PARTIDA)"
	btn_salir.text = "▶   SALIR   ◀" if _indice_seleccion == 2 else "SALIR"

	_actualizar_resaltado_botones()
	if animar_escala:
		_actualizar_escala_botones()


func _actualizar_resaltado_botones() -> void:
	_estilizar_boton(btn_jugar, COLOR_CIAN, _indice_seleccion == 0, false)
	_estilizar_boton(btn_continuar, COLOR_VOLTAJE, _indice_seleccion == 1 and _puede_continuar, not _puede_continuar)
	_estilizar_boton(btn_salir, COLOR_SALIR, _indice_seleccion == 2, false)


func _actualizar_escala_botones() -> void:
	var pares := [
		[btn_jugar, _indice_seleccion == 0],
		[btn_continuar, _indice_seleccion == 1 and _puede_continuar],
		[btn_salir, _indice_seleccion == 2],
	]
	for par in pares:
		var btn: Button = par[0]
		var activo: bool = bool(par[1])
		if btn == null:
			continue
		btn.pivot_offset = btn.size * 0.5
		var objetivo := Vector2(1.045, 1.045) if activo else Vector2.ONE
		if _tweens_botones.has(btn):
			var prev_tw: Tween = _tweens_botones[btn]
			if is_instance_valid(prev_tw):
				prev_tw.kill()
		var tw := create_tween()
		tw.tween_property(btn, "scale", objetivo, 0.14) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tweens_botones[btn] = tw


func _aplicar_estilos_pixel() -> void:
	if panel_principal != null:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.035, 0.075, 0.145, 0.92)
		sb.border_color = COLOR_CIAN
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(0)
		sb.content_margin_left = 32
		sb.content_margin_right = 32
		sb.content_margin_top = 22
		sb.content_margin_bottom = 22
		sb.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
		sb.shadow_size = 0
		sb.shadow_offset = Vector2(6, 6)
		panel_principal.add_theme_stylebox_override("panel", sb)

	if panel_carga != null:
		var sb_c := StyleBoxFlat.new()
		sb_c.bg_color = Color(0.03, 0.07, 0.14, 0.97)
		sb_c.border_color = COLOR_CIAN
		sb_c.set_border_width_all(3)
		sb_c.set_corner_radius_all(0)
		sb_c.content_margin_left = 34
		sb_c.content_margin_right = 34
		sb_c.content_margin_top = 28
		sb_c.content_margin_bottom = 28
		sb_c.shadow_color = Color(0.0, 0.0, 0.0, 0.8)
		sb_c.shadow_size = 0
		sb_c.shadow_offset = Vector2(6, 6)
		panel_carga.add_theme_stylebox_override("panel", sb_c)

	if caja_consejo != null:
		var sb_tip := StyleBoxFlat.new()
		sb_tip.bg_color = Color(0.02, 0.05, 0.10, 0.95)
		sb_tip.border_color = Color(COLOR_VOLTAJE.r, COLOR_VOLTAJE.g, COLOR_VOLTAJE.b, 0.75)
		sb_tip.set_border_width_all(2)
		sb_tip.set_corner_radius_all(0)
		sb_tip.content_margin_left = 18
		sb_tip.content_margin_right = 18
		sb_tip.content_margin_top = 12
		sb_tip.content_margin_bottom = 12
		caja_consejo.add_theme_stylebox_override("panel", sb_tip)

	if barra_voltaje != null:
		var sb_bg := StyleBoxFlat.new()
		sb_bg.bg_color = Color(0.02, 0.04, 0.09, 1.0)
		sb_bg.border_color = COLOR_CIAN
		sb_bg.set_border_width_all(3)
		sb_bg.set_corner_radius_all(0)
		barra_voltaje.add_theme_stylebox_override("background", sb_bg)

		_barra_fill_style = StyleBoxFlat.new()
		_barra_fill_style.bg_color = COLOR_CIAN
		_barra_fill_style.border_color = COLOR_VOLTAJE
		_barra_fill_style.border_width_top = 2
		_barra_fill_style.border_width_bottom = 2
		_barra_fill_style.border_width_right = 4
		_barra_fill_style.set_corner_radius_all(0)
		barra_voltaje.add_theme_stylebox_override("fill", _barra_fill_style)


func _estilizar_boton(btn: Button, color: Color, resaltado: bool, deshabilitado: bool) -> void:
	if btn == null:
		return

	var sb_norm := StyleBoxFlat.new()
	sb_norm.set_corner_radius_all(0)
	sb_norm.set_border_width_all(3 if resaltado else 2)
	sb_norm.content_margin_top = 11
	sb_norm.content_margin_bottom = 11
	sb_norm.content_margin_left = 20
	sb_norm.content_margin_right = 20
	sb_norm.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	sb_norm.shadow_size = 0
	sb_norm.shadow_offset = Vector2(4, 4)

	if deshabilitado:
		sb_norm.bg_color = Color(0.06, 0.08, 0.12, 0.80)
		sb_norm.border_color = Color(0.24, 0.30, 0.38, 0.70)
		sb_norm.shadow_offset = Vector2(2, 2)
	elif resaltado:
		sb_norm.bg_color = color.darkened(0.68)
		sb_norm.border_color = color
		sb_norm.shadow_color = Color(color.r, color.g, color.b, 0.35)
		sb_norm.shadow_size = 6
		sb_norm.shadow_offset = Vector2(0, 0)
	else:
		sb_norm.bg_color = Color(0.06, 0.11, 0.19, 0.94)
		sb_norm.border_color = color.darkened(0.38)

	var sb_hover := sb_norm.duplicate() as StyleBoxFlat
	if not deshabilitado:
		sb_hover.bg_color = color.darkened(0.55)
		sb_hover.border_color = color.lightened(0.25)
		sb_hover.shadow_color = Color(color.r, color.g, color.b, 0.45)
		sb_hover.shadow_size = 8
		sb_hover.shadow_offset = Vector2(0, 0)

	var sb_press := sb_norm.duplicate() as StyleBoxFlat
	if not deshabilitado:
		sb_press.bg_color = color.darkened(0.42)
		sb_press.border_color = Color.WHITE
		sb_press.shadow_size = 2
		sb_press.shadow_offset = Vector2(1, 1)

	btn.add_theme_stylebox_override("normal", sb_norm)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_press)
	btn.add_theme_stylebox_override("disabled", sb_norm)
	btn.add_theme_stylebox_override("focus", sb_hover)

	btn.add_theme_color_override("font_color", Color.WHITE if resaltado else color.lightened(0.32))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", COLOR_VOLTAJE)
	btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.52, 0.62, 0.85))
	btn.add_theme_color_override("font_outline_color", COLOR_BORDE_OSCURO)
	btn.add_theme_constant_override("outline_size", 4)


# ==============================================================================
# AUDIO CHILL EN BUCLE SUAVE (-6 dB)
# ==============================================================================
func _configurar_audio_chill() -> void:
	if musica_fondo == null:
		return

	GameManager.configurar_buses_audio()
	musica_fondo.bus = &"Musica"
	musica_fondo.process_mode = Node.PROCESS_MODE_ALWAYS
	musica_fondo.autoplay = true

	var stream: AudioStream = musica_fondo.stream
	if stream == null:
		var ruta_musica := _buscar_archivo_musica()
		if not ruta_musica.is_empty():
			stream = GameManager.cargar_audio_seguro(ruta_musica)
	if stream == null:
		return

	# Habilitar bucle nativo según formato + respaldo por señal finished
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD

	musica_fondo.stream = stream
	musica_fondo.volume_db = VOLUMEN_MUSICA_DB
	if not musica_fondo.finished.is_connected(_on_musica_finished):
		musica_fondo.finished.connect(_on_musica_finished)
	if not musica_fondo.playing:
		musica_fondo.play()


func _on_musica_finished() -> void:
	if is_instance_valid(musica_fondo) and musica_fondo.stream != null and not _transicion_disparada:
		musica_fondo.play()


func _buscar_archivo_musica() -> String:
	for ruta in RUTAS_MUSICA_CANDIDATAS:
		if ResourceLoader.exists(ruta):
			return ruta

	var dir := DirAccess.open("res://assets/musica")
	if dir == null:
		return ""

	dir.list_dir_begin()
	var archivo := dir.get_next()
	while not archivo.is_empty():
		if not dir.current_is_dir():
			var ext := archivo.get_extension().to_lower()
			if ext in ["mp3", "wav", "ogg"]:
				var ruta_encontrada := "res://assets/musica/" + archivo
				if ResourceLoader.exists(ruta_encontrada):
					dir.list_dir_end()
					return ruta_encontrada
		archivo = dir.get_next()
	dir.list_dir_end()
	return ""


# ==============================================================================
# ACCIONES DE BOTONES Y PANTALLA DE CARGA ANIMADA
# ==============================================================================
func _on_jugar_pressed() -> void:
	if _cargando_escena:
		return
	var escena_destino := GameManager.nueva_partida(false)
	_iniciar_pantalla_carga(escena_destino)


func _on_continuar_pressed() -> void:
	if _cargando_escena or not _puede_continuar:
		return
	var escena_destino := GameManager.continuar_partida(false)
	_iniciar_pantalla_carga(escena_destino)


func _on_salir_pressed() -> void:
	if _cargando_escena:
		return
	get_tree().quit()


func _iniciar_pantalla_carga(ruta_destino: String) -> void:
	if ruta_destino.is_empty() or not ResourceLoader.exists(ruta_destino):
		push_error("MenuPrincipal: No se encontró la escena de destino: " + ruta_destino)
		return

	_cargando_escena = true
	_ruta_destino_carga = ruta_destino
	_progreso_visual = 0.0
	_tiempo_carga = 0.0
	_transicion_disparada = false
	_carga_threaded_iniciada = false

	btn_jugar.disabled = true
	btn_continuar.disabled = true
	btn_salir.disabled = true

	var nombre_nivel := GameManager.obtener_nombre_nivel(ruta_destino).to_upper()
	lbl_destino_carga.text = "CARGANDO SECTOR: %s" % nombre_nivel
	lbl_consejo_fisica.text = CONSEJOS_FISICA[randi() % CONSEJOS_FISICA.size()]
	barra_voltaje.value = 0.0
	lbl_porcentaje.text = "VOLTAJE: 0%"
	lbl_voltaje_kv.text = "0.0 kV / 12.0 kV"

	overlay_carga.visible = true
	overlay_carga.modulate.a = 0.0
	chispas_barra_carga.emitting = true

	var tw_fade := create_tween()
	tw_fade.tween_property(overlay_carga, "modulate:a", 1.0, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if musica_fondo != null and musica_fondo.playing:
		var tw_m := create_tween()
		tw_m.tween_property(musica_fondo, "volume_db", -18.0, DURACION_CARGA_SEG)

	if ResourceLoader.load_threaded_request(ruta_destino) == OK:
		_carga_threaded_iniciada = true


func _actualizar_pantalla_carga(delta: float) -> void:
	if _transicion_disparada:
		return

	_tiempo_carga += delta
	var t: float = clampf(_tiempo_carga / DURACION_CARGA_SEG, 0.0, 1.0)
	# Curva rápida y elegante con leve pulso eléctrico
	var curva: float = 1.0 - pow(1.0 - t, 2.3)
	_progreso_visual = clampf(curva * 100.0, 0.0, 100.0)

	barra_voltaje.value = _progreso_visual
	var pct: int = int(round(_progreso_visual))
	var kv: float = (_progreso_visual / 100.0) * 12.0
	lbl_porcentaje.text = "VOLTAJE: %d%%" % pct
	lbl_voltaje_kv.text = "%.1f kV / 12.0 kV" % kv

	# Transición de color de la barra de voltaje (cian eléctrico -> amarillo voltaje)
	if _barra_fill_style != null:
		_barra_fill_style.bg_color = COLOR_CIAN.lerp(COLOR_VOLTAJE, _progreso_visual / 100.0)

	# Posicionar las chispas en la punta activa de la barra de voltaje
	if chispas_barra_carga != null and barra_voltaje != null:
		var x_punta: float = clampf(barra_voltaje.size.x * (_progreso_visual / 100.0), 4.0, maxf(4.0, barra_voltaje.size.x - 4.0))
		chispas_barra_carga.position = Vector2(x_punta, barra_voltaje.size.y * 0.5)

	if _progreso_visual >= 100.0:
		_intentar_finalizar_carga()


func _intentar_finalizar_carga() -> void:
	if _transicion_disparada:
		return

	if _carga_threaded_iniciada:
		var estado := ResourceLoader.load_threaded_get_status(_ruta_destino_carga)
		if estado == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			lbl_porcentaje.text = "VOLTAJE: 100% — SINCRONIZANDO..."
			return
		elif estado == ResourceLoader.THREAD_LOAD_LOADED:
			var recurso := ResourceLoader.load_threaded_get(_ruta_destino_carga)
			if recurso is PackedScene:
				_transicion_disparada = true
				chispas_barra_carga.emitting = false
				get_tree().change_scene_to_packed(recurso as PackedScene)
				return

	# Respaldo seguro en caso de que el hilo no estuviera disponible
	_transicion_disparada = true
	chispas_barra_carga.emitting = false
	get_tree().change_scene_to_file(_ruta_destino_carga)
