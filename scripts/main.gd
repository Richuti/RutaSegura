# ==========================================================
#  RutasSeguras - App Android (Godot 4.5)
#  Fase 1: Edificios A y B en 3D + navegación estilo Waze con voz
#  La ruta y cada indicación salen del GRAFO (graph.gd).
# ==========================================================
extends Node3D

const VELOCIDAD_CAMINAR := 1.4   # m/s (tiempo estimado real)
const VEL_SIMULACION := 4.0      # m/s (demo acelerada)
const AJUSTES := "user://ajustes.cfg"

var mapa: Graph
var escena: Escena3D
var origen := ""
var bloqueados: Array = []
var nav := {}
var vista_previa := {}
var modo := ""

# ---- Voz ----
var voz := ""
var voz_activa := true
var aviso_tramo := -1
var aviso_ahora := -1

# ---- Interfaz ----
var raiz: Control
var arriba: VBoxContainer
var abajo: VBoxContainer
var tarjeta: PanelContainer
var op_origen: OptionButton
var op_destino: OptionButton
var op_bloqueo: OptionButton
var chip_bloqueo: PanelContainer
var controles: VBoxContainer
var btn_voz: Button
var btn_mas: Button
var btn_vista: Button
var btn_menos: Button
var btn_centrar: Button
var cercanas: VBoxContainer
var cercanas_fila: HBoxContainer
var pista: PanelContainer
var btn_sos: Button
var sos_estilo: StyleBoxFlat
var hoja_ruta: PanelContainer
var hr_eta: Label
var hr_sub: Label
var hr_destino: Label
var hr_tag: PanelContainer
var hr_pasos: VBoxContainer
var hr_grafo: Label
var hr_toggle: Button
var hr_detalle: VBoxContainer
var hr_n_pasos := 0
var banner: VBoxContainer
var banner_caja: PanelContainer
var banner_tile: PanelContainer
var banner_icono: Icono
var banner_dist: Label
var banner_instr: Label
var banner_hacia: Label
var chip_luego: PanelContainer
var luego_icono: Icono
var luego_txt: Label
var barra_nav: PanelContainer
var plantas_ui: PanelContainer
var plantas_items: Array = []
var nav_eta: Label
var nav_sub: Label
var nav_progreso: ProgressBar
var menu_reporte: PopupMenu
var hoja_llegada: PanelContainer
var llegada_sub: Label
var toast: PanelContainer
var toast_txt: Label
var toast_tween: Tween
var vineta: ColorRect
var vineta_tween: Tween
var bienvenida: Control

# ---- Sismos ----
var alerta: AlertaSismo
var sismo_ui: Control
var sismo_info: Label
var sismo_cuenta: Label
var sismo_tween: Tween
var evacuar_al_ubicar := false

# GPS: el teléfono dice en qué parte del campus estás; tú dices el piso
var gps: Gps
var gps_seguir := true        # la ubicación la da el GPS (false = la marcaste a mano)
var ubic := {}                # tu ubicación GPS ajustada al grafo: pos, a, b, xz, precision
var edificio_actual := ""
var planta_actual := 1
var planta_confirmada := true
var _edif_candidato := ""
var _edif_cuenta := 0
var _dir_gps := Vector3(0, 0, 1)
var _lecturas: Array = []     # últimas lecturas GPS [tiempo, lat, lon, precisión]
var accion_tras_planta := ""
var calib := {}               # calibración del GPS en curso
var chip_gps: Button
var chip_gps_punto: Icono
var hoja_planta: Control
var planta_titulo: Label
var planta_letra: Label
var planta_tile: PanelContainer
var planta_botones: HBoxContainer
var hoja_gps: Control
var gps_titulo: Label
var gps_detalle: Label
var gps_acciones: VBoxContainer
var aviso_calib: PanelContainer
var aviso_calib_txt: Label
var btn_escalera: Button


func _ready() -> void:
	mapa = Campus.crear_campus()
	print("== Matriz de adyacencia: Edificios A y B ==")
	mapa.printMatrix()

	escena = Escena3D.new()
	add_child(escena)
	escena.construir(mapa)
	escena.sobre_ui = _sobre_ui
	escena.toque.connect(_al_tocar_mapa)
	_cargar_ajustes()
	_crear_ui()
	alerta = AlertaSismo.new()
	add_child(alerta)
	alerta.sismo.connect(_al_sismo)
	gps = Gps.new()
	add_child(gps)
	gps.posicion.connect(_al_gps)
	gps.estado_cambio.connect(func(_e): _actualizar_chip_gps())
	_actualizar_chip_gps()
	_preparar_voz()
	_modo("explorar")
	var cfg := ConfigFile.new()
	if cfg.load(AJUSTES) != OK or not cfg.get_value("app", "bienvenida_vista", false):
		mostrar_bienvenida()


# ==========================================================
#  Acciones
# ==========================================================
func seleccionar_origen(nombre: String) -> void:
	# Marcaste tu ubicación a mano: se deja de seguir el GPS
	if gps_seguir and gps and gps.estado == "ok":
		mostrar_toast("Ubicación manual. Toca «GPS» arriba para volver a usarlo")
	gps_seguir = false
	_actualizar_chip_gps()
	origen = nombre
	for i in op_origen.item_count:
		if op_origen.get_item_text(i) == nombre:
			op_origen.selected = i
	var v := mapa.buscar(nombre)
	escena.limpiar_ruta()
	if v:
		escena.poner_usuario(v.pos, Vector3(0, 0, 1), true)
	vista_previa = {}
	_modo("explorar")
	if evacuar_al_ubicar:
		evacuar_al_ubicar = false
		emergencia.call_deferred()


func emergencia() -> void:
	if _usar_gps():
		# El GPS sabe el edificio, no el piso: si no lo sabemos, se pregunta primero
		if not planta_confirmada:
			accion_tras_planta = "emergencia"
			_preguntar_planta()
			return
		var rg := _ruta_desde_ubic("")
		if rg.is_empty():
			mostrar_toast("No hay ruta disponible. Busca otra salida.")
			_hablar("No hay ruta disponible. Busca otra salida.", true)
			return
		_vibrar(350)
		_iniciar_navegacion(rg.camino, Estilo.ROJO, true)
		return
	if origen == "":
		mostrar_toast("Primero dinos dónde estás: toca el mapa")
		op_origen.show_popup()
		return
	var r := mapa.evacuar(origen, bloqueados, Campus.permitido_evacuar)
	if r.is_empty():
		mostrar_toast("No hay ruta disponible. Busca otra salida.")
		_hablar("No hay ruta disponible. Busca otra salida.", true)
		return
	_vibrar(350)
	_iniciar_navegacion(r.camino, Estilo.ROJO, true)


func ver_ruta(destino: String = "") -> void:
	if destino != "":
		for i in op_destino.item_count:
			if op_destino.get_item_text(i) == destino:
				op_destino.selected = i
	var i_dest := op_destino.selected
	if origen == "" and not _usar_gps():
		mostrar_toast("Elige dónde estás")
		return
	if i_dest <= 0:
		mostrar_toast("Elige a dónde vas")
		return
	var r := _ruta_desde_ubic(op_destino.get_item_text(i_dest)) if _usar_gps() else mapa.rutaMasCorta(origen, op_destino.get_item_text(i_dest), bloqueados)
	if r.is_empty():
		mostrar_toast("No hay ruta disponible con ese pasillo cerrado")
		return
	vista_previa = r
	escena.mostrar_ruta(r.camino, Estilo.AZUL)
	escena.encuadrar(r.camino)
	_llenar_hoja_ruta(r.camino, r.distancia)
	_modo("vista_previa")


func vamos() -> void:
	if not vista_previa.is_empty():
		_iniciar_navegacion(vista_previa.camino, Estilo.AZUL, false)


# Todas las aristas de una escalera (para bloquearla completa)
func _claves_escalera(letra: String, lado: String) -> String:
	var claves := []
	for e in mapa.aristas():
		for v in [e[0], e[1]]:
			if Campus.es_escalera(v) and v.city.begins_with(letra) and v.city.contains("Escalera " + lado):
				var k := Graph.clave(e[0].city, e[1].city)
				if not claves.has(k):
					claves.append(k)
	return ";".join(claves)


func bloquear(clave: String) -> void:
	bloqueados = [] if clave == "" else Array(clave.split(";"))
	var a: Vertex = null
	var b: Vertex = null
	for e in mapa.aristas():
		if not bloqueados.is_empty() and Graph.clave(e[0].city, e[1].city) == bloqueados[0]:
			a = e[0]
			b = e[1]
	escena.marcar_bloqueo(a, b)
	var activo := clave != ""
	chip_bloqueo.add_theme_stylebox_override("panel", _estilo_chip(Color("#FDECEC") if activo else Color.WHITE))
	if not nav.is_empty() and not nav.fin:
		_recalcular()
		return
	if activo:
		mostrar_toast("Pasillo cerrado: la ruta se recalcula")
	_actualizar_cercanas()
	if not vista_previa.is_empty():
		ver_ruta()


func terminar() -> void:
	nav = {}
	vista_previa = {}
	if voz != "":
		DisplayServer.tts_stop()
	escena.limpiar_ruta()
	escena.vista_general()
	if _usar_gps():
		escena.poner_usuario(ubic.pos, _dir_gps)
	elif origen != "":
		escena.poner_usuario(mapa.buscar(origen).pos)
	_modo("explorar")


func _al_tocar_mapa(p: Vector3) -> void:
	if not calib.is_empty():
		_punto_calibracion(Vector2(p.x, p.z))
		return
	if modo != "explorar" and modo != "vista_previa":
		return
	# ¿Tocaste una zona segura? -> ruta hacia ella
	for v in mapa.vertexs:
		if v.segura and Vector2(p.x - v.pos.x, p.z - v.pos.z).length() < 12.0:
			if origen != "":
				ver_ruta(v.city)
			else:
				mostrar_toast("Primero marca dónde estás")
			return
	# Si no, el punto del grafo más cercano es tu ubicación
	var mejor: Vertex = null
	var dmin := 16.0
	for v in mapa.vertexs:
		var d := Vector2(p.x - v.pos.x, p.z - v.pos.z).length()
		if not v.segura and not Campus.es_escalera(v) and d < dmin:
			dmin = d
			mejor = v
	if mejor:
		seleccionar_origen(mejor.city)
		_vibrar(40)
		mostrar_toast("Estás en " + mejor.city)


# ==========================================================
#  Sismo: alerta automática (feed USGS) o simulacro
# ==========================================================
const ESPERA_SISMO := 15   # segundos para cubrirse antes de evacuar

func _al_sismo(mag: float, lugar: String, dist: float) -> void:
	if not nav.is_empty() and nav.get("emergencia", false):
		return
	if bienvenida:
		cerrar_bienvenida()
	nav = {}
	vista_previa = {}
	escena.limpiar_ruta()
	_modo("explorar")
	var lugar_es := lugar.replace(" of ", " de ").replace(" km N ", " km al norte ").replace(" km S ", " km al sur ") \
		.replace(" km E ", " km al este ").replace(" km W ", " km al oeste ").replace(" km SW ", " km al suroeste ") \
		.replace(" km SE ", " km al sureste ").replace(" km NW ", " km al noroeste ").replace(" km NE ", " km al noreste ")
	sismo_info.text = "Magnitud %.1f  ·  a %d km de la UAM\n%s" % [mag, roundi(dist), lugar_es]
	sismo_ui.visible = true
	sismo_ui.modulate.a = 0.0
	create_tween().tween_property(sismo_ui, "modulate:a", 1.0, 0.25)
	_vibrar(1200)
	_hablar("Alerta de sismo. Agáchate, cúbrete y sujétate. Aléjate de las ventanas. Cuando pare el movimiento, te guiaré a la zona segura.", true)
	if sismo_tween:
		sismo_tween.kill()
	sismo_tween = create_tween()
	sismo_tween.tween_method(func(x: float): sismo_cuenta.text = "Te guío a la zona segura en %d s" % ceili(x), float(ESPERA_SISMO), 0.0, ESPERA_SISMO)
	sismo_tween.tween_callback(salir_sismo)


func salir_sismo() -> void:
	if sismo_tween:
		sismo_tween.kill()
	if not sismo_ui.visible:
		return
	sismo_ui.visible = false
	if origen != "" or _usar_gps():
		emergencia()
	else:
		evacuar_al_ubicar = true
		_hablar("Toca el mapa para marcar dónde estás y te guiaré a la zona segura.", true)
		mostrar_toast("Toca el mapa para marcar dónde estás")


func _crear_alerta_sismo() -> void:
	sismo_ui = Control.new()
	sismo_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	sismo_ui.visible = false
	raiz.add_child(sismo_ui)
	var fondo := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color("#E5383B"))
	grad.set_color(1, Color("#8E1520"))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_to = Vector2(0.3, 1)
	fondo.texture = gt
	fondo.stretch_mode = TextureRect.STRETCH_SCALE
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	sismo_ui.add_child(fondo)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(lado, 44)
	m.add_theme_constant_override("margin_top", 110)
	m.add_theme_constant_override("margin_bottom", 56)
	sismo_ui.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	m.add_child(v)
	var icono := PanelContainer.new()
	icono.add_theme_stylebox_override("panel", Estilo.caja(Color(1, 1, 1, 0.16), 40, false))
	icono.custom_minimum_size = Vector2(120, 120)
	icono.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var ic := Icono.new("alerta", Color.WHITE, 120)
	ic.escala = 0.6
	icono.add_child(ic)
	v.add_child(icono)
	v.add_child(_espacio(34))
	v.add_child(Estilo.texto("ALERTA DE SISMO", 52, Estilo.F_EXTRA, Color.WHITE))
	sismo_info = Estilo.texto("", 25, Estilo.F_MEDIA, Color(1, 1, 1, 0.85))
	sismo_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sismo_info)
	v.add_child(_espacio(40))

	var tarjeta_s := PanelContainer.new()
	tarjeta_s.add_theme_stylebox_override("panel", Estilo.caja(Color.WHITE, 30, true, 28))
	v.add_child(tarjeta_s)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 18)
	tarjeta_s.add_child(tv)
	tv.add_child(Estilo.texto("Mientras tiembla:", 24, Estilo.F_NEGRITA, Estilo.TENUE))
	for f in [["1", "Agáchate"], ["2", "Cúbrete la cabeza"], ["3", "Sujétate hasta que pare"]]:
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 18)
		var n := PanelContainer.new()
		n.add_theme_stylebox_override("panel", Estilo.caja(Color("#FDECEC"), 26, false))
		n.custom_minimum_size = Vector2(52, 52)
		var nl := Estilo.texto(f[0], 24, Estilo.F_EXTRA, Estilo.ROJO)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		n.add_child(nl)
		fila.add_child(n)
		var t := Estilo.texto(f[1], 30, Estilo.F_EXTRA)
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fila.add_child(t)
		tv.add_child(fila)
	var nota := Estilo.texto("Aléjate de ventanas. No corras ni uses el ascensor.", 21, Estilo.F_MEDIA, Estilo.TENUE)
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(nota)

	var resto := Control.new()
	resto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(resto)
	sismo_cuenta = Estilo.texto("", 22, Estilo.F_NEGRITA, Color.WHITE)
	sismo_cuenta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sismo_cuenta)
	v.add_child(_espacio(14))
	var btn := Estilo.boton("Ya paró: ir a la zona segura", Color.WHITE, Estilo.ROJO, 28, 30)
	btn.custom_minimum_size = Vector2(0, 104)
	btn.pressed.connect(salir_sismo)
	v.add_child(btn)
	v.add_child(_espacio(14))
	var fuente := Estilo.texto("Fuente: USGS (sismos confirmados). Mantén activadas también las alertas de sismo de Android.", 17, Estilo.F_MEDIA, Color(1, 1, 1, 0.6))
	fuente.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fuente.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(fuente)


# ==========================================================
#  Indicaciones (salen del grafo)
#  En cada vértice de la ruta se compara la arista que llega
#  con la que sale: el ángulo y el lado dan la maniobra.
# ==========================================================
func _giro(a: Vector3, b: Vector3, c: Vector3) -> Dictionary:
	# Arista inclinada = escaleras (cambia de planta)
	if absf(c.y - b.y) > 0.5:
		if absf(b.y - a.y) > 0.5:
			return {"tipo": "escaleras", "texto": "Sigue " + ("bajando" if c.y < b.y else "subiendo") + " las escaleras", "continua": true}
		return {"tipo": "escaleras", "texto": ("Baja" if c.y < b.y else "Sube") + " las escaleras"}
	if absf(b.y - a.y) > 0.5:
		# Saliendo de las escaleras: se calcula el giro con la dirección del último tramo
		var g := _giro(Vector3(a.x, b.y, a.z), b, c)
		if g.tipo == "recto":
			return {"tipo": "recto", "texto": "Al bajar, sigue de frente"}
		return {"tipo": g.tipo, "texto": "Al bajar, " + _min(g.texto)}
	var d1 := Vector2(b.x - a.x, b.z - a.z).normalized()
	var d2 := Vector2(c.x - b.x, c.z - b.z).normalized()
	var ang := rad_to_deg(acos(clampf(d1.dot(d2), -1.0, 1.0)))
	var cruz := d1.x * d2.y - d1.y * d2.x   # < 0 izquierda, > 0 derecha
	if ang < 25:
		return {"tipo": "recto", "texto": "Sigue recto"}
	if ang > 150:
		return {"tipo": "vuelta", "texto": "Da la vuelta"}
	var lado := "izquierda" if cruz < 0 else "derecha"
	if ang < 60:
		return {"tipo": "leve_" + lado, "texto": "Gira levemente a la " + lado}
	return {"tipo": lado, "texto": "Gira a la " + lado}


# ---- Tramos: agrupan las aristas de la ruta en instrucciones ----
# Las aristas de una escalera (tramos, descansos y la llegada a ella) se
# juntan en UNA sola instrucción: "Baja las escaleras hasta la planta baja".
func _tramos(camino: Array) -> Array:
	var lista := []
	for i in camino.size() - 1:
		var esc: bool = Campus.es_escalera(camino[i]) or Campus.es_escalera(camino[i + 1])
		var l: float = camino[i].pos.distance_to(camino[i + 1].pos)
		if esc and not lista.is_empty() and lista[-1].escalera:
			lista[-1].hasta = i
			lista[-1].largo += l
		elif not esc and not lista.is_empty() and not lista[-1].escalera \
				and _giro(camino[i - 1].pos, camino[i].pos, camino[i + 1].pos).tipo == "recto":
			# tramos rectos seguidos = una sola instrucción
			lista[-1].hasta = i
			lista[-1].largo += l
		else:
			lista.append({"desde": i, "hasta": i, "escalera": esc, "largo": l})
	# Un tramo de menos de 3 m justo antes de una escalera se une a ella
	# (evita "en 2 metros, gira…" al entrar por una puerta)
	var t := lista.size() - 2
	while t >= 0:
		if not lista[t].escalera and lista[t].largo < 3.0 and lista[t + 1].escalera:
			lista[t + 1].desde = lista[t].desde
			lista[t + 1].largo += lista[t].largo
			lista.remove_at(t)
		t -= 1
	# ...y uno de menos de 3 m justo después de la escalera también
	t = 1
	while t < lista.size() - 1:
		if not lista[t].escalera and lista[t].largo < 3.0 and lista[t - 1].escalera:
			lista[t - 1].hasta = lista[t].hasta
			lista[t - 1].largo += lista[t].largo
			lista.remove_at(t)
		else:
			t += 1
	return lista


# Maniobra al terminar el tramo t
func _maniobra(camino: Array, tramos: Array, t: int) -> Dictionary:
	if t >= tramos.size() - 1:
		var fin: Vertex = camino[-1]
		return {"tipo": "llegada", "texto": "Llegas a " + fin.city, "hacia": fin.city}
	var sig: Dictionary = tramos[t + 1]
	if sig.escalera:
		var a: Vertex = camino[sig.desde]
		var b: Vertex = camino[sig.hasta + 1]
		var verbo := "Baja" if b.pos.y < a.pos.y else "Sube"
		var destino := _nombre_planta(Campus.planta_de(b))
		return {"tipo": "escaleras", "texto": verbo + " las escaleras", "hacia": "hasta " + destino}
	var fin_t: int = tramos[t].hasta
	var g := _giro(camino[fin_t].pos, camino[fin_t + 1].pos, camino[sig.desde + 1].pos)
	if tramos[t].escalera:
		var bajo: bool = camino[tramos[t].desde].pos.y > camino[fin_t + 1].pos.y
		g.texto = ("Al bajar, " if bajo else "Al subir, ") + _min(g.texto)
	g["hacia"] = "hacia " + camino[sig.hasta + 1].city
	return g


func _pasos(camino: Array) -> Array:
	var tramos := _tramos(camino)
	var lista := []
	for t in tramos.size():
		var tr: Dictionary = tramos[t]
		var fin: Vertex = camino[tr.hasta + 1]
		var titulo := ""
		var tipo := "recto"
		if tr.escalera:
			var ini: Vertex = camino[tr.desde]
			titulo = ("Baja" if fin.pos.y < ini.pos.y else "Sube") + " las escaleras hasta " + _nombre_planta(Campus.planta_de(fin))
			tipo = "escaleras"
		elif t == 0:
			titulo = "Sal hacia " + fin.city
		else:
			var m := _maniobra(camino, tramos, t - 1)
			titulo = m.texto + " hacia " + fin.city
			tipo = m.tipo
		lista.append({"tipo": tipo, "titulo": titulo, "metros": roundf(tr.largo)})
	var ultimo: Vertex = camino[-1]
	lista.append({"tipo": "llegada", "titulo": "Llegas a " + ultimo.city, "metros": -1.0})
	return lista


func _maniobras(camino: Array, color: Color) -> Array:
	var tramos := _tramos(camino)
	var total := 0.0
	for tr in tramos:
		total += tr.largo
	var items := []
	var acum := 0.0
	for t in tramos.size() - 1:
		acum += tramos[t].largo
		var m := _maniobra(camino, tramos, t)
		if m.tipo != "recto":
			items.append([camino[tramos[t].hasta + 1].pos, m.tipo, color, acum / total])
	return items


func _zonas_cercanas() -> Array:
	var r := mapa.dijkstra(origen, bloqueados, Campus.permitido_evacuar)
	var lista := []
	if r.is_empty():
		return lista
	for v in mapa.vertexs:
		if v.segura and r.dist[v] < INF:
			lista.append([v, r.dist[v]])
	lista.sort_custom(func(a, b): return a[1] < b[1])
	return lista


# ==========================================================
#  Navegación (simulada sobre la ruta del grafo)
# ==========================================================
func _iniciar_navegacion(camino: Array, color: Color, es_emergencia: bool, anunciar: bool = true) -> void:
	var largos: Array[float] = []
	for i in camino.size() - 1:
		largos.append(camino[i].pos.distance_to(camino[i + 1].pos))
	var total := 0.0
	for l in largos:
		total += l
	nav = {"camino": camino, "largos": largos, "total": total, "i": 0, "t": 0.0,
		"color": color, "fin": false, "emergencia": es_emergencia, "tramos": _tramos(camino),
		"gps": _usar_gps(), "fuera": -1.0, "esc_avisada": -1}
	aviso_tramo = -1
	aviso_ahora = -1
	escena.mostrar_ruta(camino, color)
	escena.marcar_maniobras(_maniobras(camino, color))
	banner_tile.add_theme_stylebox_override("panel", Estilo.caja(color, 22, false))
	nav_eta.add_theme_color_override("font_color", color.darkened(0.1))
	_estilo_progreso(color)
	_modo("navegar")

	var dest: Vertex = camino[-1]
	if not anunciar:
		pass
	elif es_emergencia:
		_hablar("Emergencia. Te llevo a la zona segura más cercana: %s. Son %d metros." % [_para_voz(dest.city), roundi(total)], true)
	else:
		_hablar("Iniciando ruta hacia %s." % _para_voz(dest.city), true)
	_actualizar_nav()


func _recalcular() -> void:
	var camino: Array = nav.camino
	var a: Vertex = camino[nav.i]
	var b: Vertex = camino[nav.i + 1]
	var dest: Vertex = camino[-1]
	var aqui: Vector3 = a.pos.lerp(b.pos, nav.t / nav.largos[nav.i])
	mostrar_toast("Pasillo cerrado. Recalculando…")
	_vibrar(200)
	_hablar("Pasillo cerrado. Recalculando ruta.", true)

	# Estás entre 'a' y 'b': se prueba seguir hacia 'b' o dar la vuelta hacia 'a'
	# (si tu tramo está cerrado, solo puedes regresar) y se elige la más corta.
	var opciones := [[a, aqui.distance_to(a.pos)]]
	if not bloqueados.has(Graph.clave(a.city, b.city)):
		opciones.append([b, aqui.distance_to(b.pos)])
	var mejor := {}
	var mejor_total := INF
	for op in opciones:
		var v: Vertex = op[0]
		var r := mapa.evacuar(v.city, bloqueados, Campus.permitido_evacuar) if nav.emergencia else mapa.rutaMasCorta(v.city, dest.city, bloqueados)
		if not r.is_empty() and r.distancia + op[1] < mejor_total:
			mejor_total = r.distancia + op[1]
			mejor = r
	if mejor.is_empty():
		_hablar("No hay ruta disponible. Busca otra salida.", true)
		return
	# Vértice temporal con tu posición actual (no se inserta en el grafo)
	var tu := Vertex.new("Tu ubicación", false, aqui)
	var nuevo: Array = [tu]
	nuevo.append_array(mejor.camino)
	_iniciar_navegacion(nuevo, nav.color, nav.emergencia, false)


func _process(delta: float) -> void:
	if nav.is_empty() or nav.fin:
		return
	if nav.gps:
		return   # con GPS avanzas tú: ver _avance_gps()
	nav.t += VEL_SIMULACION * delta
	while not nav.fin and nav.t >= nav.largos[nav.i]:
		nav.t -= nav.largos[nav.i]
		nav.i += 1
		if nav.i >= nav.largos.size():
			nav.fin = true
	_actualizar_nav()


func _actualizar_nav() -> void:
	var camino: Array = nav.camino
	var ultimo: Vertex = camino[-1]
	# Avance total y posición sobre la ruta suavizada (curvas en los giros)
	var recorrido := 0.0
	if nav.fin:
		recorrido = nav.total
	else:
		for k in nav.i:
			recorrido += nav.largos[k]
		recorrido += nav.t
	var f: float = recorrido / nav.total
	var info := escena.posicion_en(f)
	var pos: Vector3 = info[0]
	var dir: Vector3 = info[1]
	var tramos: Array = nav.tramos
	var t := 0
	while t < tramos.size() - 1 and nav.i > tramos[t].hasta:
		t += 1
	var en_escalera: bool = not nav.fin and tramos[t].escalera and (Campus.es_escalera(camino[nav.i]) or Campus.es_escalera(camino[nav.i + 1]))
	escena.progreso_ruta(f)
	escena.poner_usuario(pos, dir)
	escena.seguir(pos, dir, en_escalera)
	_actualizar_corte(pos, en_escalera)

	if nav.fin:
		btn_escalera.visible = false
		_llegada(ultimo)
		return

	# Distancia que falta para terminar este tramo
	var falta: float = nav.largos[nav.i] - nav.t
	for k in range(nav.i + 1, tramos[t].hasta + 1):
		falta += nav.largos[k]
	var resta: float = nav.total - recorrido
	var m := _maniobra(camino, tramos, t)

	var esperar_esc: bool = nav.gps and tramos[t].escalera
	btn_escalera.visible = esperar_esc
	if esperar_esc:
		var p_fin := Campus.planta_de(camino[tramos[t].hasta + 1])
		btn_escalera.text = "Ya estoy en " + ("planta baja" if p_fin == 1 else "planta %d" % p_fin)
		if nav.esc_avisada != t:
			nav.esc_avisada = t
			_hablar.call_deferred("Cuando llegues a %s, toca el botón: ya estoy en %s." % [_nombre_planta(p_fin), "planta baja" if p_fin == 1 else "planta %d" % p_fin])
	if tramos[t].escalera:
		var planta := roundi(pos.y / Campus.ALTURA_PLANTA) + 1
		var fin: Vertex = camino[tramos[t].hasta + 1]
		banner_icono.poner("escaleras")
		banner_dist.text = "Planta baja" if planta == 1 else "Planta %d" % planta
		banner_instr.text = ("Bajando" if fin.pos.y < pos.y - 0.2 else "Subiendo") + " las escaleras"
		if absf(fin.pos.y - pos.y) < 0.2:
			banner_instr.text = "Sal de las escaleras"
		banner_hacia.text = "hasta " + _nombre_planta(Campus.planta_de(fin))
		luego_icono.poner(m.tipo)
		luego_txt.text = ("sigue " + m.hacia) if m.tipo == "recto" else _min(m.texto.replace("Al bajar, ", "").replace("Al subir, ", ""))
		chip_luego.visible = true
	else:
		banner_dist.text = "%d m" % ceili(falta)
		banner_icono.poner(m.tipo)
		banner_instr.text = "Llegas a tu destino" if m.tipo == "llegada" else m.texto
		banner_hacia.text = m.hacia
		if t + 1 < tramos.size():
			var m2 := _maniobra(camino, tramos, t + 1)
			luego_icono.poner(m2.tipo)
			luego_txt.text = _min(m2.texto) + ((" " + m2.hacia) if m2.tipo == "escaleras" else "")
			chip_luego.visible = true
		else:
			chip_luego.visible = false

	# Indicador de plantas mientras falta bajar/subir escaleras
	var ultima_esc := -1
	for k in tramos.size():
		if tramos[k].escalera:
			ultima_esc = k
	plantas_ui.visible = t <= ultima_esc
	if plantas_ui.visible:
		_marcar_planta(roundi(pos.y / Campus.ALTURA_PLANTA) + 1, nav.color)

	nav_eta.text = _tiempo(resta / VELOCIDAD_CAMINAR)
	nav_sub.text = "%d m  ·  %s" % [ceili(resta), ultimo.city]
	nav_progreso.value = 100.0 * f
	_avisos_de_voz(t, falta, m, camino, tramos)


# Locución estilo Waze: aviso al empezar cada tramo y "ahora" al llegar a la maniobra
func _avisos_de_voz(t: int, falta: float, m: Dictionary, camino: Array, tramos: Array) -> void:
	if aviso_tramo != t:
		aviso_tramo = t
		var frase := ""
		var tr: Dictionary = tramos[t]
		if tr.escalera:
			if t == 0:
				var fin: Vertex = camino[tr.hasta + 1]
				frase = "%s las escaleras hasta %s." % [("Baja" if fin.pos.y < camino[0].pos.y else "Sube"), _nombre_planta(Campus.planta_de(fin))]
		elif t == 0:
			frase = "Camina %d metros hacia %s." % [roundi(falta), _para_voz(camino[tr.hasta + 1].city)]
			if m.tipo != "recto" and m.tipo != "llegada":
				frase += " Luego, %s %s." % [_min(m.texto), _para_voz(m.hacia)]
		elif m.tipo == "llegada":
			frase = "En %d metros llegas a %s." % [roundi(falta), _para_voz(camino[-1].city)]
		elif m.tipo == "escaleras":
			frase = "En %d metros, %s %s." % [roundi(falta), _min(m.texto), m.hacia]
		elif m.tipo != "recto":
			frase = "En %d metros, %s %s." % [roundi(falta), _min(m.texto), _para_voz(m.hacia)]
		if frase != "":
			_hablar(frase)
			_vibrar(60)
	if aviso_ahora != t and falta < 5.0 and m.tipo != "recto" and m.tipo != "llegada":
		aviso_ahora = t
		var txt: String = m.texto.replace("Al bajar, ", "").replace("Al subir, ", "")
		txt = txt.left(1).to_upper() + txt.substr(1)
		if m.tipo == "escaleras":
			txt += " " + m.hacia
		_hablar(txt + " ahora.", true)
		_vibrar(120)


func _llegada(destino: Vertex) -> void:
	if modo == "llegada":
		return
	banner_tile.add_theme_stylebox_override("panel", Estilo.caja(Estilo.VERDE, 22, false))
	banner_icono.poner("llegada")
	banner_dist.text = "Llegaste"
	banner_instr.text = destino.city
	banner_hacia.text = "Zona segura" if destino.segura else "Destino"
	chip_luego.visible = false
	llegada_sub.text = destino.city + ("  ·  Zona segura" if destino.segura else "")
	_modo("llegada")
	_vibrar(400)
	if destino.segura:
		_hablar("Llegaste a %s. Estás en una zona segura. Mantente aquí y sigue las indicaciones de los brigadistas." % _para_voz(destino.city), true)
	else:
		_hablar("Llegaste a %s." % _para_voz(destino.city), true)


# Planta a la que llevan las escaleras que empiezan en el vértice i
func _planta_destino(camino: Array, i: int) -> int:
	var k := i
	while k + 1 < camino.size() and absf(camino[k + 1].pos.y - camino[k].pos.y) > 0.5:
		k += 1
	return Campus.planta_de(camino[k])


func _nombre_planta(p: int) -> String:
	return "la planta baja" if p == 1 else "la planta %d" % p


# Minúscula solo en la primera letra (para no estropear nombres propios)
func _min(t: String) -> String:
	return t.left(1).to_lower() + t.substr(1)


func _tiempo(seg: float) -> String:
	var s := ceili(seg)
	return "%d s" % s if s < 60 else "%d min %02d s" % [s / 60, s % 60]


# ==========================================================
#  Voz y vibración
# ==========================================================
func _preparar_voz() -> void:
	if not OS.get_name() in ["Android", "iOS", "Windows", "macOS"]:
		return
	var preferidas := []
	for v in DisplayServer.tts_get_voices():
		var lang := String(v.get("language", ""))
		if lang.begins_with("es"):
			# Preferir español latinoamericano
			var lat := lang.contains("419") or lang.contains("MX") or lang.contains("US") or lang.contains("NI")
			if lat:
				preferidas.push_front(v.id)
			else:
				preferidas.append(v.id)
	if preferidas.is_empty():
		var es := DisplayServer.tts_get_voices_for_language("es")
		if es.size() > 0:
			preferidas.append(es[0])
	if not preferidas.is_empty():
		voz = preferidas[0]


func _hablar(texto: String, interrumpir: bool = false) -> void:
	print("VOZ: ", texto)
	if voz == "" or not voz_activa:
		return
	DisplayServer.tts_speak(texto, voz, 100, 1.0, 1.05, 0, interrumpir)


func _para_voz(nombre: String) -> String:
	# "B - Pasillo Central" -> "Pasillo Central del edificio B"
	if nombre.begins_with("hacia "):
		return "hacia " + _para_voz(nombre.substr(6))
	var partes := nombre.split(" - ")
	if partes.size() == 2 and partes[0].length() == 1:
		return "%s del edificio %s" % [partes[1], partes[0]]
	if partes.size() == 2 and partes[0].length() == 2:
		return "%s del edificio %s, planta %s" % [partes[1], partes[0][0], partes[0][1]]
	return nombre.replace("B-C", "entre B y C")


func alternar_vista() -> void:
	_poner_vista(not escena.primera_persona)
	mostrar_toast("Vista en primera persona" if escena.primera_persona else "Vista de mapa")


func _poner_vista(primera: bool) -> void:
	escena.set_primera_persona(primera)
	(btn_vista.get_child(0) as Icono).poner("mapa" if primera else "persona")
	if not nav.is_empty():
		# Se redibuja la ruta con el ancho de la vista elegida
		escena.mostrar_ruta(nav.camino, nav.color)
		escena.marcar_maniobras(_maniobras(nav.camino, nav.color))
		_actualizar_nav()


func alternar_voz() -> void:
	voz_activa = not voz_activa
	if not voz_activa and voz != "":
		DisplayServer.tts_stop()
	(btn_voz.get_child(0) as Icono).poner("voz" if voz_activa else "voz_off", Estilo.TINTA if voz_activa else Estilo.TENUE)
	mostrar_toast("Voz activada" if voz_activa else "Voz silenciada")
	if voz_activa and voz == "":
		mostrar_toast("Este dispositivo no tiene voz en español")
	_guardar_ajuste("voz_activa", voz_activa)


func _vibrar(ms: int) -> void:
	if OS.get_name() in ["Android", "iOS"]:
		Input.vibrate_handheld(ms)


func _cargar_ajustes() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(AJUSTES) == OK:
		voz_activa = cfg.get_value("app", "voz_activa", true)
		Geo.cargar(cfg)


func _guardar_ajuste(clave: String, valor) -> void:
	var cfg := ConfigFile.new()
	cfg.load(AJUSTES)
	cfg.set_value("app", clave, valor)
	cfg.save(AJUSTES)


# ==========================================================
#  Interfaz
# ==========================================================
func _modo(m: String) -> void:
	var antes := modo
	modo = m
	var visibles := {
		tarjeta: m in ["explorar", "vista_previa"],
		chip_bloqueo.get_parent(): m == "explorar",
		btn_sos: m == "explorar",
		cercanas: m == "explorar",
		hoja_ruta: m == "vista_previa",
		banner: m in ["navegar", "llegada"],
		barra_nav: m == "navegar",
		hoja_llegada: m == "llegada",
		plantas_ui: false,
		controles: m in ["explorar", "navegar"],
	}
	for c in visibles:
		var ver: bool = visibles[c]
		if ver and not c.visible and antes != "":
			_aparecer(c)
		c.visible = ver
	if m == "explorar":
		chip_luego.visible = false
		_actualizar_cercanas()
	escena.etiquetas(m == "explorar")
	for b in [btn_mas, btn_menos, btn_centrar]:
		b.visible = m == "explorar"
	btn_vista.visible = m == "navegar"
	if m != "navegar" and escena.primera_persona:
		_poner_vista(false)
	_actualizar_corte()
	_vineta(m == "navegar" and nav.get("emergencia", false))


# Edificios que se muestran "por dentro": donde estás y por donde pasa la ruta
func _actualizar_corte(pos_usuario = null, en_escalera: bool = false) -> void:
	var cortes := {}
	if escena.primera_persona and not en_escalera:
		# Desde adentro se ve el edificio completo: la losa de arriba hace de techo
		escena.cortar_edificios(cortes)
		return
	var puntos: Array = []
	if not nav.is_empty():
		puntos = nav.camino
	elif not vista_previa.is_empty() and modo == "vista_previa":
		puntos = vista_previa.camino
	elif _usar_gps():
		puntos = [Vertex.new("Tu ubicación", false, ubic.pos)]
	elif origen != "":
		puntos = [mapa.buscar(origen)]
	for v in puntos:
		var i := escena.edificio_en(v.pos)
		if i >= 0 and not cortes.has(i):
			cortes[i] = 1
	# En el edificio donde estás se muestra tu planta
	var aqui: Vector3 = Vector3(-999, 0, -999)
	if pos_usuario != null:
		aqui = pos_usuario
	elif _usar_gps():
		aqui = ubic.pos
	elif origen != "":
		aqui = mapa.buscar(origen).pos
	var i_aqui := escena.edificio_en(aqui)
	if i_aqui >= 0:
		cortes[i_aqui] = roundi(aqui.y / Campus.ALTURA_PLANTA) + 1
	escena.cortar_edificios(cortes)


func _aparecer(c: Control) -> void:
	c.modulate.a = 0.0
	c.scale = Vector2(0.97, 0.97)
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween().set_parallel()
	tw.tween_property(c, "modulate:a", 1.0, 0.22)
	tw.tween_property(c, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _vineta(activa: bool) -> void:
	vineta.visible = activa
	if vineta_tween:
		vineta_tween.kill()
	if activa:
		var mat := vineta.material as ShaderMaterial
		vineta_tween = create_tween().set_loops()
		vineta_tween.tween_method(func(x): mat.set_shader_parameter("fuerza", x), 0.2, 0.45, 0.8).set_trans(Tween.TRANS_SINE)
		vineta_tween.tween_method(func(x): mat.set_shader_parameter("fuerza", x), 0.45, 0.2, 0.8).set_trans(Tween.TRANS_SINE)


func _sobre_ui(pos: Vector2) -> bool:
	if bienvenida and bienvenida.visible:
		return true
	if sismo_ui and sismo_ui.visible:
		return true
	for c in [tarjeta, chip_bloqueo, controles, btn_sos, cercanas, hoja_ruta, banner_caja, chip_luego, barra_nav, hoja_llegada, toast, plantas_ui]:
		if c.is_visible_in_tree() and c.get_global_rect().grow(6).has_point(pos):
			return true
	return false


func _crear_ui() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)
	raiz = Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = Estilo.tema()
	capa.add_child(raiz)

	# Viñeta roja de emergencia (bordes que laten)
	vineta = ColorRect.new()
	vineta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vineta.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float fuerza = 0.4;
void fragment() {
	vec2 uv = UV - 0.5;
	float d = length(uv * vec2(1.25, 1.0));
	float v = smoothstep(0.32, 0.78, d);
	COLOR = vec4(0.9, 0.13, 0.15, v * fuerza);
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	vineta.material = sm
	vineta.visible = false
	raiz.add_child(vineta)

	arriba = VBoxContainer.new()
	arriba.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arriba.add_theme_constant_override("separation", 14)
	raiz.add_child(arriba)
	arriba.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 22)
	arriba.offset_top = 46

	abajo = VBoxContainer.new()
	abajo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	abajo.alignment = BoxContainer.ALIGNMENT_END
	abajo.add_theme_constant_override("separation", 16)
	raiz.add_child(abajo)
	abajo.grow_vertical = Control.GROW_DIRECTION_BEGIN
	abajo.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 22)
	abajo.offset_bottom = -34

	_crear_tarjeta_busqueda()
	_crear_banner()
	_crear_controles()
	_crear_toast()
	_crear_cercanas()
	_crear_sos()
	_crear_hoja_ruta()
	_crear_barra_nav()
	_crear_hoja_llegada()
	_crear_indicador_plantas()
	_crear_alerta_sismo()
	_crear_hoja_planta()
	_crear_hoja_gps()


# ---------------- Bienvenida ----------------
func mostrar_bienvenida() -> void:
	if bienvenida:
		bienvenida.queue_free()
	bienvenida = Control.new()
	bienvenida.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(bienvenida)

	var fondo := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color("#0F8F7A"))
	grad.set_color(1, Color("#0B4F5C"))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0.4, 1)
	fondo.texture = gt
	fondo.stretch_mode = TextureRect.STRETCH_SCALE
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	bienvenida.add_child(fondo)

	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(lado, 48)
	m.add_theme_constant_override("margin_top", 120)
	m.add_theme_constant_override("margin_bottom", 56)
	bienvenida.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	m.add_child(v)

	var logo := PanelContainer.new()
	logo.add_theme_stylebox_override("panel", Estilo.caja(Color.WHITE, 46, true))
	logo.custom_minimum_size = Vector2(150, 150)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var esc := Icono.new("escudo", Estilo.TEAL, 150)
	esc.escala = 0.62
	logo.add_child(esc)
	v.add_child(logo)
	v.add_child(_espacio(46))

	var titulo := HBoxContainer.new()
	titulo.add_theme_constant_override("separation", 14)
	titulo.add_child(Estilo.texto("RutasSeguras", 62, Estilo.F_EXTRA, Color.WHITE))
	var uam := Estilo.chip("UAM", Color.WHITE, Estilo.TEAL, 26)
	uam.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titulo.add_child(uam)
	v.add_child(titulo)
	var lema := Estilo.texto("Nunca te pierdas en el campus.\nY en una emergencia, llega seguro.", 28, Estilo.F_MEDIA, Color(1, 1, 1, 0.86))
	v.add_child(lema)
	v.add_child(_espacio(56))

	for f in [["ir", "Rutas paso a paso", "Como Waze, dentro de la universidad"],
			["escudo", "Zona segura más cercana", "Un toque y te guía en una emergencia"],
			["voz", "Te guía con voz", "Sin tener que mirar la pantalla"]]:
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 22)
		var c := PanelContainer.new()
		c.add_theme_stylebox_override("panel", Estilo.caja(Color(1, 1, 1, 0.14), 22, false))
		c.custom_minimum_size = Vector2(76, 76)
		var ic := Icono.new(f[0], Color.WHITE, 76)
		ic.escala = 0.55
		c.add_child(ic)
		fila.add_child(c)
		var tv := VBoxContainer.new()
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.add_theme_constant_override("separation", 0)
		tv.add_child(Estilo.texto(f[1], 27, Estilo.F_NEGRITA, Color.WHITE))
		tv.add_child(Estilo.texto(f[2], 21, Estilo.F_MEDIA, Color(1, 1, 1, 0.7)))
		fila.add_child(tv)
		v.add_child(fila)
		v.add_child(_espacio(26))

	var resto := Control.new()
	resto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(resto)
	var btn := Estilo.boton("Comenzar", Color.WHITE, Estilo.TEAL, 32, 30)
	btn.custom_minimum_size = Vector2(0, 104)
	btn.pressed.connect(cerrar_bienvenida)
	v.add_child(btn)
	v.add_child(_espacio(18))
	var pie := Estilo.texto("Programación Estructurada  ·  Estructura de datos: Grafos", 19, Estilo.F_MEDIA, Color(1, 1, 1, 0.55))
	pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(pie)


func cerrar_bienvenida() -> void:
	if not bienvenida:
		return
	_guardar_ajuste("bienvenida_vista", true)
	var b := bienvenida
	var tw := b.create_tween()
	tw.tween_property(b, "modulate:a", 0.0, 0.35)
	tw.tween_callback(b.queue_free)
	bienvenida = null
	_hablar("Bienvenido a RutasSeguras. Toca el mapa para marcar dónde estás.")


func _espacio(alto: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, alto)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


# ---------------- Tarjeta de búsqueda ----------------
func _crear_tarjeta_busqueda() -> void:
	tarjeta = PanelContainer.new()
	var sb := Estilo.caja(Color.WHITE, 30, true)
	sb.content_margin_left = 24
	sb.content_margin_right = 18
	sb.content_margin_top = 20
	sb.content_margin_bottom = 14
	tarjeta.add_theme_stylebox_override("panel", sb)
	arriba.add_child(tarjeta)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	tarjeta.add_child(v)

	var marca := HBoxContainer.new()
	marca.add_theme_constant_override("separation", 10)
	marca.add_child(Estilo.texto("RutasSeguras", 30, Estilo.F_EXTRA))
	var uam := Estilo.chip("UAM", Estilo.TEAL, Color.WHITE, 18)
	uam.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marca.add_child(uam)
	var esp := Control.new()
	esp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	marca.add_child(esp)
	# Estado del GPS (toca para ver opciones: planta, calibrar, usar GPS)
	chip_gps = Button.new()
	chip_gps.flat = true
	chip_gps.focus_mode = Control.FOCUS_NONE
	chip_gps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip_gps.custom_minimum_size = Vector2(0, 44)
	chip_gps.add_theme_font_override("font", Estilo.F_NEGRITA)
	chip_gps.add_theme_font_size_override("font_size", 19)
	chip_gps.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	chip_gps_punto = Icono.new("punto", Estilo.TENUE, 26)
	chip_gps_punto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip_gps.pressed.connect(_abrir_hoja_gps)
	marca.add_child(chip_gps_punto)
	marca.add_child(chip_gps)
	v.add_child(marca)
	var m1 := MarginContainer.new()
	m1.add_theme_constant_override("margin_top", 8)
	m1.add_theme_constant_override("margin_bottom", 2)
	m1.add_child(Estilo.separador())
	v.add_child(m1)

	var fila1 := HBoxContainer.new()
	fila1.add_theme_constant_override("separation", 14)
	fila1.add_child(Icono.new("punto", Estilo.AZUL, 34))
	op_origen = _opciones("¿Dónde estás?", 27)
	for p in mapa.vertexs:
		if not p.segura and not Campus.es_escalera(p):
			op_origen.add_item(p.city)
	op_origen.item_selected.connect(func(i):
		if i > 0:
			seleccionar_origen(op_origen.get_item_text(i)))
	fila1.add_child(op_origen)
	v.add_child(fila1)

	var m2 := MarginContainer.new()
	m2.add_theme_constant_override("margin_left", 48)
	m2.add_child(Estilo.separador())
	v.add_child(m2)

	var fila2 := HBoxContainer.new()
	fila2.add_theme_constant_override("separation", 14)
	fila2.add_child(Icono.new("pin", Estilo.ROJO, 34))
	op_destino = _opciones("¿A dónde vas?", 27)
	for p in mapa.vertexs:
		if not Campus.es_escalera(p):
			op_destino.add_item(p.city)
	fila2.add_child(op_destino)
	var ir := Estilo.boton_icono("ir", Estilo.TEAL, Color.WHITE, 66, false)
	ir.pressed.connect(func(): ver_ruta())
	fila2.add_child(ir)
	v.add_child(fila2)

	var fila_chip := HBoxContainer.new()
	fila_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arriba.add_child(fila_chip)
	chip_bloqueo = PanelContainer.new()
	chip_bloqueo.add_theme_stylebox_override("panel", _estilo_chip(Color.WHITE))
	fila_chip.add_child(chip_bloqueo)
	var hc := HBoxContainer.new()
	hc.add_theme_constant_override("separation", 8)
	chip_bloqueo.add_child(hc)
	hc.add_child(Icono.new("alerta", Estilo.AMBAR, 30))
	op_bloqueo = _opciones("Reportar pasillo bloqueado", 21)
	op_bloqueo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	op_bloqueo.custom_minimum_size = Vector2(0, 46)
	op_bloqueo.set_item_metadata(0, "")
	for e in mapa.aristas():
		if Campus.es_escalera(e[0]) or Campus.es_escalera(e[1]):
			continue
		op_bloqueo.add_item("%s  /  %s" % [e[0].city, e[1].city])
		op_bloqueo.set_item_metadata(op_bloqueo.item_count - 1, Graph.clave(e[0].city, e[1].city))
	for esc in Campus.ESCALERAS:
		op_bloqueo.add_item("Escalera %s del edificio %s" % [esc[4], esc[0]])
		op_bloqueo.set_item_metadata(op_bloqueo.item_count - 1, _claves_escalera(esc[0], esc[4]))
	op_bloqueo.add_item("Quitar bloqueo")
	op_bloqueo.set_item_metadata(op_bloqueo.item_count - 1, "")
	op_bloqueo.item_selected.connect(func(i):
		var k: String = op_bloqueo.get_item_metadata(i)
		if k == "":
			op_bloqueo.selected = 0
		bloquear(k))
	hc.add_child(op_bloqueo)

	# Simulacro de sismo (para practicar y para la demostración)
	var chip_sim := Button.new()
	chip_sim.add_theme_stylebox_override("normal", _estilo_chip(Color.WHITE))
	chip_sim.add_theme_stylebox_override("hover", _estilo_chip(Color("#FFF4F4")))
	chip_sim.add_theme_stylebox_override("pressed", _estilo_chip(Color("#FDECEC")))
	chip_sim.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	chip_sim.text = "Simulacro"
	chip_sim.icon = Estilo.textura_lineas(40, [[Vector2(0.15, 0.55), Vector2(0.3, 0.55)], [Vector2(0.3, 0.55), Vector2(0.4, 0.25)],
		[Vector2(0.4, 0.25), Vector2(0.55, 0.8)], [Vector2(0.55, 0.8), Vector2(0.68, 0.4)], [Vector2(0.68, 0.4), Vector2(0.75, 0.55)],
		[Vector2(0.75, 0.55), Vector2(0.88, 0.55)]], 3.6, Estilo.ROJO)
	chip_sim.add_theme_font_override("font", Estilo.F_NEGRITA)
	chip_sim.add_theme_font_size_override("font_size", 21)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		chip_sim.add_theme_color_override(c, Estilo.TINTA)
	chip_sim.custom_minimum_size = Vector2(0, 58)
	chip_sim.pressed.connect(func(): alerta.simular())
	fila_chip.add_theme_constant_override("separation", 12)
	fila_chip.add_child(chip_sim)


func _estilo_chip(fondo: Color) -> StyleBoxFlat:
	var sb := Estilo.caja(fondo, 40, true)
	sb.shadow_size = 14
	sb.content_margin_left = 16
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _opciones(placeholder: String, tam: int) -> OptionButton:
	var op := OptionButton.new()
	op.custom_minimum_size = Vector2(0, 62)
	op.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	op.fit_to_longest_item = false
	op.clip_text = true
	op.add_theme_font_size_override("font_size", tam)
	op.add_theme_font_override("font", Estilo.F_NEGRITA)
	op.add_item(placeholder)
	op.selected = 0
	return op


func _crear_controles() -> void:
	controles = VBoxContainer.new()
	controles.add_theme_constant_override("separation", 14)
	raiz.add_child(controles)
	controles.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	controles.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 22)
	controles.offset_top -= 60
	controles.offset_bottom -= 60
	btn_voz = Estilo.boton_icono("voz" if voz_activa else "voz_off", Color.WHITE, Estilo.TINTA if voz_activa else Estilo.TENUE, 74)
	btn_voz.pressed.connect(alternar_voz)
	controles.add_child(btn_voz)
	# Primera persona / vista de mapa (solo durante la navegación)
	btn_vista = Estilo.boton_icono("persona", Color.WHITE, Estilo.AZUL, 74)
	btn_vista.pressed.connect(alternar_vista)
	controles.add_child(btn_vista)
	btn_mas = Estilo.boton_icono("mas", Color.WHITE, Estilo.TINTA, 74)
	btn_mas.pressed.connect(func(): escena.zoom(0.8))
	controles.add_child(btn_mas)
	btn_menos = Estilo.boton_icono("menos", Color.WHITE, Estilo.TINTA, 74)
	btn_menos.pressed.connect(func(): escena.zoom(1.25))
	controles.add_child(btn_menos)
	btn_centrar = Estilo.boton_icono("centrar", Color.WHITE, Estilo.AZUL, 74)
	btn_centrar.pressed.connect(func():
		if not nav.is_empty():
			return
		if gps.estado == "ok" and not ubic.is_empty():
			if not gps_seguir:
				usar_gps()
			escena.enfocar(ubic.pos)
		else:
			escena.vista_general())
	controles.add_child(btn_centrar)


func _crear_toast() -> void:
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	abajo.add_child(c)
	toast = PanelContainer.new()
	var sb := Estilo.caja(Color(Estilo.NOCHE, 0.94), 30, true)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	toast.add_theme_stylebox_override("panel", sb)
	toast.visible = false
	toast_txt = Estilo.texto("", 22, Estilo.F_NEGRITA, Color.WHITE)
	toast.add_child(toast_txt)
	c.add_child(toast)


func mostrar_toast(t: String) -> void:
	toast_txt.text = t
	toast.visible = true
	toast.modulate.a = 0.0
	if toast_tween:
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_property(toast, "modulate:a", 1.0, 0.2)
	toast_tween.tween_interval(2.4)
	toast_tween.tween_property(toast, "modulate:a", 0.0, 0.35)
	toast_tween.tween_callback(func(): toast.visible = false)


# ---------------- Zonas seguras cercanas ----------------
func _crear_cercanas() -> void:
	cercanas = VBoxContainer.new()
	cercanas.add_theme_constant_override("separation", 10)
	abajo.add_child(cercanas)
	pista = PanelContainer.new()
	var sb := Estilo.caja(Color.WHITE, 30, true)
	sb.shadow_size = 14
	sb.content_margin_left = 20
	sb.content_margin_right = 24
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	pista.add_theme_stylebox_override("panel", sb)
	pista.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var hp := HBoxContainer.new()
	hp.add_theme_constant_override("separation", 12)
	hp.add_child(Icono.new("punto", Estilo.AZUL, 30))
	hp.add_child(Estilo.texto("Toca el mapa para marcar dónde estás", 21, Estilo.F_NEGRITA))
	pista.add_child(hp)
	cercanas.add_child(pista)
	cercanas_fila = HBoxContainer.new()
	cercanas_fila.add_theme_constant_override("separation", 14)
	cercanas.add_child(cercanas_fila)


func _actualizar_cercanas() -> void:
	for c in cercanas_fila.get_children():
		c.queue_free()
	pista.visible = origen == ""
	cercanas_fila.visible = origen != ""
	if origen == "":
		return
	var lista := _zonas_cercanas()
	for k in lista.size():
		var z: Vertex = lista[k][0]
		var metros: float = lista[k][1]
		var tarjeta_z := PanelContainer.new()
		tarjeta_z.add_theme_stylebox_override("panel", Estilo.caja(Color.WHITE, 26, true, 18))
		tarjeta_z.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tarjeta_z.add_child(v)
		var cab := HBoxContainer.new()
		cab.add_theme_constant_override("separation", 8)
		cab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cab.add_child(Icono.new("escudo", Estilo.VERDE, 30))
		if k == 0:
			var ch := Estilo.chip("MÁS CERCANA", Color("#E4F4E8"), Estilo.VERDE, 14)
			ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cab.add_child(ch)
		v.add_child(cab)
		var nombre := Estilo.texto(z.city, 20, Estilo.F_NEGRITA)
		nombre.clip_text = true
		v.add_child(nombre)
		v.add_child(Estilo.texto("%s  ·  %s m" % [_tiempo(metros / VELOCIDAD_CAMINAR), Graph.fmt(metros)], 22, Estilo.F_EXTRA, Estilo.VERDE))
		var zona_nombre := z.city
		tarjeta_z.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
				ver_ruta(zona_nombre))
		cercanas_fila.add_child(tarjeta_z)


# ---------------- Botón SOS ----------------
func _crear_sos() -> void:
	btn_sos = Button.new()
	btn_sos.custom_minimum_size = Vector2(0, 132)
	sos_estilo = Estilo.caja(Estilo.ROJO, 34, true)
	sos_estilo.shadow_color = Color(Estilo.ROJO, 0.45)
	for s in ["normal", "hover"]:
		btn_sos.add_theme_stylebox_override(s, sos_estilo)
	var presionado := Estilo.caja(Estilo.ROJO.darkened(0.15), 34, true)
	btn_sos.add_theme_stylebox_override("pressed", presionado)
	btn_sos.add_theme_stylebox_override("hover_pressed", presionado)
	btn_sos.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn_sos.pressed.connect(emergencia)
	abajo.add_child(btn_sos)

	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 22)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
	h.offset_left = 28
	h.offset_right = -28
	btn_sos.add_child(h)
	var circulo := PanelContainer.new()
	circulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circulo.add_theme_stylebox_override("panel", Estilo.caja(Color.WHITE, 40, false))
	circulo.custom_minimum_size = Vector2(80, 80)
	circulo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var esc := Icono.new("escudo", Estilo.ROJO, 80)
	esc.escala = 0.62
	circulo.add_child(esc)
	h.add_child(circulo)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.add_child(Estilo.texto("EMERGENCIA", 36, Estilo.F_EXTRA, Color.WHITE))
	v.add_child(Estilo.texto("Te llevo a la zona segura más cercana", 21, Estilo.F_MEDIA, Color(1, 1, 1, 0.88)))
	h.add_child(v)

	var tw := create_tween().set_loops()
	tw.tween_method(func(x): sos_estilo.shadow_size = int(x); btn_sos.queue_redraw(), 10.0, 34.0, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(x): sos_estilo.shadow_size = int(x); btn_sos.queue_redraw(), 34.0, 10.0, 0.9).set_trans(Tween.TRANS_SINE)


# ---------------- Vista previa de ruta ----------------
func _crear_hoja_ruta() -> void:
	hoja_ruta = PanelContainer.new()
	hoja_ruta.add_theme_stylebox_override("panel", Estilo.caja(Color.WHITE, 34, true, 26))
	abajo.add_child(hoja_ruta)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	hoja_ruta.add_child(v)

	var cab := HBoxContainer.new()
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 0)
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr_eta = Estilo.texto("", 50, Estilo.F_EXTRA, Estilo.AZUL)
	cv.add_child(hr_eta)
	hr_sub = Estilo.texto("", 22, Estilo.F_MEDIA, Estilo.TENUE)
	cv.add_child(hr_sub)
	cab.add_child(cv)
	var cerrar := Estilo.boton_icono("cerrar", Estilo.GRIS_BOTON, Estilo.TINTA, 64, false)
	cerrar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cerrar.pressed.connect(terminar)
	cab.add_child(cerrar)
	v.add_child(cab)

	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 10)
	hr_destino = Estilo.texto("", 24, Estilo.F_NEGRITA)
	hr_destino.clip_text = true
	hr_destino.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dh.add_child(hr_destino)
	hr_tag = Estilo.chip("ZONA SEGURA", Estilo.VERDE, Color.WHITE, 16)
	hr_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dh.add_child(hr_tag)
	v.add_child(dh)

	# Pasos plegables: por defecto solo se ve lo esencial
	hr_toggle = Button.new()
	hr_toggle.flat = true
	hr_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	hr_toggle.add_theme_font_override("font", Estilo.F_NEGRITA)
	hr_toggle.add_theme_font_size_override("font_size", 22)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		hr_toggle.add_theme_color_override(c, Estilo.AZUL)
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		hr_toggle.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	hr_toggle.pressed.connect(func():
		hr_detalle.visible = not hr_detalle.visible
		_texto_toggle())
	v.add_child(hr_toggle)

	hr_detalle = VBoxContainer.new()
	hr_detalle.add_theme_constant_override("separation", 14)
	hr_detalle.visible = false
	v.add_child(hr_detalle)
	hr_detalle.add_child(Estilo.separador())
	hr_pasos = VBoxContainer.new()
	hr_pasos.add_theme_constant_override("separation", 14)
	hr_detalle.add_child(hr_pasos)
	hr_grafo = Estilo.texto("", 18, Estilo.F_MEDIA, Estilo.TENUE)
	hr_detalle.add_child(hr_grafo)

	var btn := Estilo.boton("Vamos", Estilo.AZUL, Color.WHITE, 30, 26)
	btn.custom_minimum_size = Vector2(0, 92)
	btn.pressed.connect(vamos)
	v.add_child(btn)


func _llenar_hoja_ruta(camino: Array, metros: float) -> void:
	var fin: Vertex = camino[-1]
	hr_eta.text = _tiempo(metros / VELOCIDAD_CAMINAR)
	hr_sub.text = "%s m  ·  a pie" % Graph.fmt(metros)
	hr_destino.text = "Hacia " + fin.city
	hr_tag.visible = fin.segura
	for c in hr_pasos.get_children():
		c.queue_free()
	for p in _pasos(camino):
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 16)
		var fondo := PanelContainer.new()
		fondo.add_theme_stylebox_override("panel", Estilo.caja(Estilo.TEAL_CLARO if p.tipo == "llegada" else Estilo.GRIS_BOTON, 16, false))
		fondo.custom_minimum_size = Vector2(54, 54)
		var ic := Icono.new(p.tipo, Estilo.TEAL if p.tipo == "llegada" else Estilo.TINTA, 54)
		ic.escala = 0.62
		fondo.add_child(ic)
		fila.add_child(fondo)
		var t := Estilo.texto(p.titulo, 22, Estilo.F_NEGRITA)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fila.add_child(t)
		if p.metros >= 0:
			var m := Estilo.texto("%s m" % Graph.fmt(p.metros), 21, Estilo.F_NEGRITA, Estilo.TENUE)
			m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			fila.add_child(m)
		hr_pasos.add_child(fila)
	hr_grafo.text = "Dijkstra sobre el grafo  ·  %d vértices  ·  %d aristas" % [camino.size(), camino.size() - 1]
	hr_n_pasos = _pasos(camino).size() - 1
	hr_detalle.visible = false
	_texto_toggle()


func _texto_toggle() -> void:
	hr_toggle.text = ("Ocultar pasos  ▴" if hr_detalle.visible else "Ver %d pasos  ▾" % hr_n_pasos)


# ---------------- Navegación ----------------
func _crear_banner() -> void:
	banner = VBoxContainer.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_constant_override("separation", 10)
	arriba.add_child(banner)
	banner_caja = PanelContainer.new()
	banner_caja.add_theme_stylebox_override("panel", Estilo.caja(Estilo.NOCHE, 32, true, 20))
	banner.add_child(banner_caja)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	banner_caja.add_child(h)
	banner_tile = PanelContainer.new()
	banner_tile.custom_minimum_size = Vector2(124, 124)
	banner_tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(banner_tile)
	banner_icono = Icono.new("recto", Color.WHITE, 124)
	banner_icono.escala = 0.66
	banner_tile.add_child(banner_icono)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	banner_dist = Estilo.texto("", 52, Estilo.F_EXTRA, Color.WHITE)
	v.add_child(banner_dist)
	banner_instr = Estilo.texto("", 27, Estilo.F_NEGRITA, Color.WHITE)
	banner_instr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(banner_instr)
	banner_hacia = Estilo.texto("", 21, Estilo.F_MEDIA, Color(1, 1, 1, 0.72))
	banner_hacia.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(banner_hacia)

	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(fila)
	chip_luego = PanelContainer.new()
	var sb := Estilo.caja(Color(Estilo.NOCHE, 0.9), 24, true)
	sb.content_margin_left = 18
	sb.content_margin_right = 20
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	chip_luego.add_theme_stylebox_override("panel", sb)
	fila.add_child(chip_luego)
	var hl := HBoxContainer.new()
	hl.add_theme_constant_override("separation", 10)
	chip_luego.add_child(hl)
	hl.add_child(Estilo.texto("Luego", 20, Estilo.F_MEDIA, Color(1, 1, 1, 0.7)))
	luego_icono = Icono.new("recto", Color.WHITE, 30)
	luego_icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hl.add_child(luego_icono)
	luego_txt = Estilo.texto("", 20, Estilo.F_NEGRITA, Color.WHITE)
	hl.add_child(luego_txt)

	# Con GPS: en las escaleras confirmas cuando llegas al otro piso
	# (el GPS sabe dónde estás en el mapa, pero no a qué altura)
	btn_escalera = Estilo.boton("Ya estoy en planta baja", Estilo.VERDE, Color.WHITE, 28, 26)
	btn_escalera.custom_minimum_size = Vector2(0, 88)
	btn_escalera.visible = false
	btn_escalera.pressed.connect(_confirmar_escalera)
	banner.add_child(btn_escalera)


func _crear_barra_nav() -> void:
	barra_nav = PanelContainer.new()
	barra_nav.add_theme_stylebox_override("panel", Estilo.caja(Color.WHITE, 34, true, 24))
	abajo.add_child(barra_nav)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	barra_nav.add_child(v)
	nav_progreso = ProgressBar.new()
	nav_progreso.show_percentage = false
	nav_progreso.custom_minimum_size = Vector2(0, 8)
	v.add_child(nav_progreso)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	var cv := VBoxContainer.new()
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.add_theme_constant_override("separation", 0)
	h.add_child(cv)
	nav_eta = Estilo.texto("", 46, Estilo.F_EXTRA, Estilo.ROJO)
	cv.add_child(nav_eta)
	nav_sub = Estilo.texto("", 21, Estilo.F_MEDIA, Estilo.TENUE)
	nav_sub.clip_text = true
	cv.add_child(nav_sub)

	# Reportar un pasillo bloqueado durante la navegación (como Waze)
	var reportar := Estilo.boton_icono("alerta", Color("#FFF4D6"), Estilo.AMBAR, 84, false)
	reportar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reportar.pressed.connect(_abrir_reporte)
	h.add_child(reportar)
	var cerrar := Estilo.boton_icono("cerrar", Estilo.GRIS_BOTON, Estilo.TINTA, 84, false)
	cerrar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cerrar.pressed.connect(terminar)
	h.add_child(cerrar)

	menu_reporte = PopupMenu.new()
	menu_reporte.id_pressed.connect(func(id):
		var k: String = menu_reporte.get_item_metadata(menu_reporte.get_item_index(id))
		bloquear(k))
	raiz.add_child(menu_reporte)


func _abrir_reporte() -> void:
	menu_reporte.clear()
	var camino: Array = nav.camino
	menu_reporte.add_separator("¿Qué está bloqueado?")
	var id := 0
	for tr in nav.tramos:
		if tr.hasta < nav.i:
			continue
		var claves := []
		for k in range(tr.desde, tr.hasta + 1):
			claves.append(Graph.clave(camino[k].city, camino[k + 1].city))
		var etiqueta := ""
		if tr.escalera:
			etiqueta = "Las escaleras"
		else:
			etiqueta = "%s  /  %s" % [camino[tr.desde].city, camino[tr.hasta + 1].city]
		menu_reporte.add_item(etiqueta, id)
		menu_reporte.set_item_metadata(menu_reporte.item_count - 1, ";".join(claves))
		id += 1
	var vp := get_viewport().get_visible_rect().size
	menu_reporte.popup(Rect2i(Vector2i(30, int(vp.y * 0.45)), Vector2i(int(vp.x) - 60, 0)))


# Indicador vertical de plantas (3 · 2 · PB), como en un ascensor
func _crear_indicador_plantas() -> void:
	plantas_ui = PanelContainer.new()
	var sb := Estilo.caja(Color(Estilo.NOCHE, 0.92), 34, true)
	sb.set_content_margin_all(10)
	plantas_ui.add_theme_stylebox_override("panel", sb)
	plantas_ui.visible = false
	raiz.add_child(plantas_ui)
	plantas_ui.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 22)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	plantas_ui.add_child(v)
	for p in [3, 2, 1]:
		var c := PanelContainer.new()
		c.custom_minimum_size = Vector2(64, 64)
		var l := Estilo.texto("PB" if p == 1 else str(p), 24, Estilo.F_EXTRA, Color(1, 1, 1, 0.55))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		c.add_child(l)
		v.add_child(c)
		plantas_items.append([p, c, l])
	var ic := Icono.new("abajo", Color(1, 1, 1, 0.55), 40)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	plantas_ui.offset_top -= 40
	plantas_ui.offset_bottom -= 40


func _marcar_planta(actual: int, color: Color) -> void:
	for it in plantas_items:
		var activo: bool = it[0] == actual
		it[1].add_theme_stylebox_override("panel", Estilo.caja(color if activo else Color(0, 0, 0, 0), 32, false))
		it[2].add_theme_color_override("font_color", Color.WHITE if activo else Color(1, 1, 1, 0.5))


func _estilo_progreso(color: Color) -> void:
	nav_progreso.add_theme_stylebox_override("background", Estilo.caja(Estilo.LINEA, 4, false))
	nav_progreso.add_theme_stylebox_override("fill", Estilo.caja(color, 4, false))


func _crear_hoja_llegada() -> void:
	hoja_llegada = PanelContainer.new()
	hoja_llegada.add_theme_stylebox_override("panel", Estilo.caja(Color.WHITE, 34, true, 28))
	abajo.add_child(hoja_llegada)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	hoja_llegada.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	v.add_child(h)
	var fondo := PanelContainer.new()
	fondo.add_theme_stylebox_override("panel", Estilo.caja(Color("#E4F4E8"), 22, false))
	fondo.custom_minimum_size = Vector2(84, 84)
	var esc := Icono.new("escudo", Estilo.VERDE, 84)
	esc.escala = 0.62
	fondo.add_child(esc)
	h.add_child(fondo)
	var cv := VBoxContainer.new()
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(cv)
	cv.add_child(Estilo.texto("Estás a salvo", 36, Estilo.F_EXTRA, Estilo.VERDE))
	llegada_sub = Estilo.texto("", 21, Estilo.F_MEDIA, Estilo.TENUE)
	llegada_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(llegada_sub)
	var consejo := Estilo.texto("Mantente en la zona segura, aléjate de paredes y ventanas, y sigue las indicaciones de los brigadistas.", 22)
	consejo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(consejo)
	var listo := Estilo.boton("Listo", Estilo.TEAL, Color.WHITE, 30, 26)
	listo.custom_minimum_size = Vector2(0, 90)
	listo.pressed.connect(terminar)
	v.add_child(listo)


# ==========================================================
#  GPS: ubicación real en el campus
#  1. El GPS da latitud y longitud -> Geo las pasa a metros del mapa.
#  2. Si caes dentro de A, B o C, la app te pregunta el piso
#     (el GPS no distingue pisos).
#  3. Tu posición se "pega" a la arista más cercana del grafo en ese
#     piso y desde ahí se calcula la ruta (Dijkstra).
# ==========================================================
func _usar_gps() -> bool:
	return gps != null and gps_seguir and gps.estado == "ok" and not ubic.is_empty()


func usar_gps() -> void:
	gps_seguir = true
	_actualizar_chip_gps()
	if gps.estado == "ok":
		_al_gps(gps.lat, gps.lon, gps.precision)
		mostrar_toast("Usando tu ubicación GPS")
	else:
		mostrar_toast("Esperando señal GPS…")


func _al_gps(lat: float, lon: float, prec: float) -> void:
	var ahora := Time.get_ticks_msec() / 1000.0
	_lecturas.append([ahora, lat, lon, prec])
	while _lecturas.size() > 12:
		_lecturas.pop_front()
	var l := Geo.a_local(lat, lon)
	if not Geo.en_campus(l):
		ubic = {}
		_actualizar_chip_gps()
		return
	_actualizar_edificio(l)
	if not gps_seguir:
		_actualizar_chip_gps()
		return
	_ubicar(l, prec)


# Detecta en qué edificio estás (3 lecturas seguidas, para que un salto del GPS no cuente)
func _actualizar_edificio(l: Vector2) -> void:
	var e := Campus.edificio_xz(l, edificio_actual)
	if e == edificio_actual:
		_edif_cuenta = 0
		return
	if e != _edif_candidato:
		_edif_candidato = e
		_edif_cuenta = 0
	_edif_cuenta += 1
	if _edif_cuenta < 3 and not ubic.is_empty():
		return
	edificio_actual = e
	_edif_cuenta = 0
	var navegando: bool = not nav.is_empty() and nav.gps and not nav.fin
	if e == "" or Campus.plantas_de(e) == 1 or navegando:
		# Afuera, en A (solo planta baja mapeada) o entrando por la ruta: planta baja
		if not navegando or e == "":
			planta_actual = 1
		planta_confirmada = true
		_cerrar_hoja_planta()
	else:
		planta_actual = 1
		planta_confirmada = false
		_preguntar_planta()


func _ubicar(l: Vector2, prec: float) -> void:
	var aj := _ajustar_al_grafo(l, planta_actual, edificio_actual)
	if aj.is_empty():
		return
	aj["xz"] = l
	aj["precision"] = prec
	var antes := ubic
	ubic = aj
	if not antes.is_empty() and antes.pos.distance_to(aj.pos) > 1.5:
		_dir_gps = (aj.pos - antes.pos).normalized()
	_actualizar_chip_gps()
	if not nav.is_empty() and nav.gps and not nav.fin:
		_avance_gps(l, prec)
		return
	if modo != "explorar" and modo != "vista_previa":
		return
	# El lugar con nombre más cercano (para la tarjeta y las zonas cercanas)
	var cerca: Vertex = aj.a if aj.pos.distance_to(aj.a.pos) <= aj.pos.distance_to(aj.b.pos) else aj.b
	if cerca.city != origen:
		origen = cerca.city
		for i in op_origen.item_count:
			if op_origen.get_item_text(i) == origen:
				op_origen.selected = i
		if modo == "explorar":
			_actualizar_cercanas()
	escena.poner_usuario(aj.pos, _dir_gps, true)
	if antes.is_empty() and modo == "explorar":
		escena.enfocar(aj.pos)
	_actualizar_corte()
	if evacuar_al_ubicar and planta_confirmada:
		evacuar_al_ubicar = false
		emergencia.call_deferred()


# Punto más cercano del grafo en tu piso y tu zona (aristas planas, sin escaleras)
func _ajustar_al_grafo(l: Vector2, planta: int, edificio: String) -> Dictionary:
	var y := (planta - 1) * Campus.ALTURA_PLANTA
	var mejor := {}
	var dmin := INF
	for e in mapa.aristas():
		var a: Vertex = e[0]
		var b: Vertex = e[1]
		if Campus.es_escalera(a) or Campus.es_escalera(b):
			continue
		if absf(a.pos.y - y) > 0.5 or absf(b.pos.y - y) > 0.5:
			continue
		var za := Campus.zona(a)
		var zb := Campus.zona(b)
		if edificio != "" and za != edificio and zb != edificio:
			continue
		if edificio == "" and za != "" and zb != "":
			continue
		var q := Geometry2D.get_closest_point_to_segment(l, Vector2(a.pos.x, a.pos.z), Vector2(b.pos.x, b.pos.z))
		var d := q.distance_to(l)
		if d < dmin:
			dmin = d
			mejor = {"pos": Vector3(q.x, y, q.y), "a": a, "b": b, "dist": d}
	return mejor


# Ruta desde tu ubicación GPS: se prueba salir por cada extremo de la
# arista donde estás y se queda la más corta. destino "" = evacuar.
func _ruta_desde_ubic(destino: String) -> Dictionary:
	var aqui: Vector3 = ubic.pos
	var tu := Vertex.new("Tu ubicación", false, aqui)
	var mejor := {}
	var mejor_total := INF
	for v in [ubic.a, ubic.b]:
		if destino == "" and not Campus.permitido_evacuar(tu, v):
			continue
		var r := mapa.evacuar(v.city, bloqueados, Campus.permitido_evacuar) if destino == "" else mapa.rutaMasCorta(v.city, destino, bloqueados)
		if r.is_empty():
			continue
		var total: float = r.distancia + aqui.distance_to(v.pos)
		if total < mejor_total:
			mejor_total = total
			mejor = r
	if mejor.is_empty():
		return {}
	if aqui.distance_to(mejor.camino[0].pos) < 1.5:
		return mejor
	var camino: Array = [tu]
	camino.append_array(mejor.camino)
	return {"camino": camino, "distancia": mejor_total}


# Tramo de la ruta al que pertenece la arista k
func _tramo_de(k: int) -> int:
	var tramos: Array = nav.tramos
	for t in tramos.size():
		if k <= tramos[t].hasta:
			return t
	return tramos.size() - 1


# Navegación real: tu posición GPS se proyecta sobre la ruta (solo hacia
# adelante y sin pasar unas escaleras: esas se confirman con el botón)
func _avance_gps(l: Vector2, prec: float) -> void:
	var camino: Array = nav.camino
	var largos: Array = nav.largos
	var tramos: Array = nav.tramos
	var t := _tramo_de(nav.i)
	if tramos[t].escalera:
		_detectar_fin_escalera(t, l, prec)
		return
	# Hasta dónde se puede avanzar: el inicio de las próximas escaleras
	var k_fin: int = largos.size()
	for tt in range(t + 1, tramos.size()):
		if tramos[tt].escalera:
			k_fin = tramos[tt].desde
			break
	var mejor_k := -1
	var mejor_t := 0.0
	var dmin := INF
	var acum := 0.0
	for k in range(nav.i, k_fin):
		var a: Vertex = camino[k]
		var b: Vertex = camino[k + 1]
		var pa := Vector2(a.pos.x, a.pos.z)
		var pb := Vector2(b.pos.x, b.pos.z)
		var q := Geometry2D.get_closest_point_to_segment(l, pa, pb)
		var d := q.distance_to(l)
		var tk: float = pa.distance_to(q) * largos[k] / maxf(pa.distance_to(pb), 0.001)
		if k == nav.i:
			tk = maxf(tk, nav.t)   # no se retrocede por un salto del GPS
		if d < dmin - 0.5:
			dmin = d
			mejor_k = k
			mejor_t = tk
		acum += largos[k]
		if acum - nav.t > 70.0:
			break
	var limite := maxf(14.0, prec * 1.5)
	if mejor_k < 0 or dmin > limite:
		# Te saliste de la ruta: si sigue así 4 segundos, se recalcula
		var ahora := Time.get_ticks_msec() / 1000.0
		if nav.fuera < 0.0:
			nav.fuera = ahora
		elif ahora - nav.fuera > 4.0:
			_recalcular_gps()
		return
	nav.fuera = -1.0
	nav.i = mejor_k
	nav.t = mejor_t
	# ¿Llegaste al final de lo plano? (escaleras o destino)
	if nav.i == k_fin - 1 and nav.t >= largos[nav.i] - 3.0:
		if k_fin >= largos.size():
			nav.fin = true
		else:
			nav.i = k_fin
			nav.t = 0.0
	_actualizar_nav()


# En las escaleras el GPS no sabe el piso. Se avanza con el botón o, si te
# alejas más de 8 m de la escalera siguiendo la ruta, se asume que bajaste.
func _detectar_fin_escalera(t: int, l: Vector2, prec: float) -> void:
	var camino: Array = nav.camino
	var tramos: Array = nav.tramos
	var ini: Vertex = camino[tramos[t].desde]
	var fin_i: int = tramos[t].hasta + 1
	if fin_i >= camino.size() - 1:
		return
	var inicio := Vector2(ini.pos.x, ini.pos.z)
	var recorrido := 0.0
	for k in range(fin_i, mini(fin_i + 4, camino.size() - 1)):
		var pa := Vector2(camino[k].pos.x, camino[k].pos.z)
		var pb := Vector2(camino[k + 1].pos.x, camino[k + 1].pos.z)
		var q := Geometry2D.get_closest_point_to_segment(l, pa, pb)
		if q.distance_to(l) < maxf(10.0, prec) and recorrido + pa.distance_to(q) > 8.0 and l.distance_to(inicio) > 8.0:
			_confirmar_escalera()
			return
		recorrido += pa.distance_to(pb)


func _confirmar_escalera() -> void:
	if nav.is_empty() or nav.fin:
		return
	var t := _tramo_de(nav.i)
	if not nav.tramos[t].escalera:
		return
	var fin: int = nav.tramos[t].hasta + 1
	planta_actual = Campus.planta_de(nav.camino[fin])
	planta_confirmada = true
	if fin >= nav.largos.size():
		nav.fin = true
	else:
		nav.i = fin
		nav.t = 0.0
	_vibrar(60)
	_actualizar_nav()


func _recalcular_gps() -> void:
	if ubic.is_empty():
		return
	var dest: Vertex = nav.camino[-1]
	var r := _ruta_desde_ubic("" if nav.emergencia else dest.city)
	if r.is_empty():
		_hablar("No hay ruta disponible. Busca otra salida.", true)
		return
	mostrar_toast("Te saliste de la ruta. Recalculando…")
	_vibrar(200)
	_hablar("Recalculando ruta.", true)
	_iniciar_navegacion(r.camino, nav.color, nav.emergencia, false)


# ---------------- Hoja: ¿en qué planta estás? ----------------
func _crear_hoja_planta() -> void:
	hoja_planta = Control.new()
	hoja_planta.set_anchors_preset(Control.PRESET_FULL_RECT)
	hoja_planta.visible = false
	raiz.add_child(hoja_planta)
	var velo := ColorRect.new()
	velo.color = Color(0.03, 0.08, 0.1, 0.5)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	hoja_planta.add_child(velo)
	var hoja := PanelContainer.new()
	hoja.add_theme_stylebox_override("panel", Estilo.caja(Color.WHITE, 36, true, 30))
	hoja_planta.add_child(hoja)
	hoja.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 22)
	hoja.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hoja.offset_bottom = -34
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	hoja.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	v.add_child(h)
	planta_tile = PanelContainer.new()
	planta_tile.custom_minimum_size = Vector2(92, 92)
	h.add_child(planta_tile)
	planta_letra = Estilo.texto("B", 50, Estilo.F_EXTRA, Color.WHITE)
	planta_letra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	planta_letra.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	planta_tile.add_child(planta_letra)
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", 2)
	h.add_child(tv)
	planta_titulo = Estilo.texto("Estás en el Edificio B", 33, Estilo.F_EXTRA)
	tv.add_child(planta_titulo)
	tv.add_child(Estilo.texto("¿En qué planta estás?", 25, Estilo.F_MEDIA, Estilo.TENUE))
	planta_botones = HBoxContainer.new()
	planta_botones.add_theme_constant_override("separation", 14)
	v.add_child(planta_botones)
	var nota := Estilo.texto("El GPS sabe en qué edificio estás, pero no en qué piso.", 20, Estilo.F_MEDIA, Estilo.TENUE)
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nota)


func _preguntar_planta() -> void:
	if edificio_actual == "":
		return
	var datos: Array = []
	for e in Campus.EDIFICIOS:
		if e[1] == edificio_actual:
			datos = e
	planta_titulo.text = "Estás en el " + datos[0]
	planta_letra.text = edificio_actual
	planta_tile.add_theme_stylebox_override("panel", Estilo.caja(datos[2], 26, false))
	for c in planta_botones.get_children():
		c.queue_free()
	for p in range(Campus.plantas_de(edificio_actual), 0, -1):
		var activo := p == planta_actual and planta_confirmada
		var b := Estilo.boton("Planta baja" if p == 1 else "Planta %d" % p, Estilo.TEAL if activo else Color("#EEF3F4"), Color.WHITE if activo else Estilo.TINTA, 26, 24)
		b.custom_minimum_size = Vector2(0, 110)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_elegir_planta.bind(p))
		planta_botones.add_child(b)
	if not hoja_planta.visible:
		hoja_planta.visible = true
		_aparecer(hoja_planta)
		_vibrar(80)
		_hablar("Estás en el edificio %s. ¿En qué planta estás?" % edificio_actual, true)


func _elegir_planta(p: int) -> void:
	planta_actual = p
	planta_confirmada = true
	_cerrar_hoja_planta()
	mostrar_toast("%s · %s" % ["Planta baja" if p == 1 else "Planta %d" % p, "Edificio " + edificio_actual])
	if gps.estado == "ok":
		_ubicar(Geo.a_local(gps.lat, gps.lon), gps.precision)
	if accion_tras_planta == "emergencia":
		accion_tras_planta = ""
		emergencia()


func _cerrar_hoja_planta() -> void:
	if hoja_planta:
		hoja_planta.visible = false


# ---------------- Chip y hoja del GPS ----------------
func _actualizar_chip_gps() -> void:
	if chip_gps == null:
		return
	var txt := ""
	var color := Estilo.TENUE
	match gps.estado if gps else "sin_gps":
		"sin_gps":
			txt = "Sin GPS"
		"sin_permiso":
			txt = "Permitir ubicación"
			color = Estilo.AMBAR
		"apagado":
			txt = "Activa la ubicación"
			color = Estilo.AMBAR
		"buscando":
			txt = "Buscando GPS…"
		_:
			if not Geo.en_campus(Geo.a_local(gps.lat, gps.lon)):
				txt = "Fuera de la UAM"
				color = Estilo.AMBAR
			elif not gps_seguir:
				txt = "Manual · usar GPS"
				color = Estilo.AZUL
			else:
				color = Estilo.VERDE
				if edificio_actual == "":
					txt = "GPS · afuera"
				elif not planta_confirmada:
					txt = "GPS · Edif. %s · ¿piso?" % edificio_actual
					color = Estilo.AMBAR
				else:
					txt = "GPS · %s · %s" % [edificio_actual, "PB" if planta_actual == 1 else "Planta %d" % planta_actual]
	chip_gps.text = txt
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		chip_gps.add_theme_color_override(c, color)
	chip_gps_punto.poner("punto", color)


func _crear_hoja_gps() -> void:
	hoja_gps = Control.new()
	hoja_gps.set_anchors_preset(Control.PRESET_FULL_RECT)
	hoja_gps.visible = false
	raiz.add_child(hoja_gps)
	var velo := Button.new()
	velo.flat = true
	velo.focus_mode = Control.FOCUS_NONE
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.08, 0.1, 0.45)
	for k in ["normal", "hover", "pressed"]:
		velo.add_theme_stylebox_override(k, sb)
	velo.pressed.connect(func(): hoja_gps.visible = false)
	hoja_gps.add_child(velo)
	var hoja := PanelContainer.new()
	hoja.add_theme_stylebox_override("panel", Estilo.caja(Color.WHITE, 36, true, 30))
	hoja_gps.add_child(hoja)
	hoja.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 22)
	hoja.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hoja.offset_bottom = -34
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	hoja.add_child(v)
	gps_titulo = Estilo.texto("Tu ubicación", 34, Estilo.F_EXTRA)
	v.add_child(gps_titulo)
	gps_detalle = Estilo.texto("", 22, Estilo.F_MEDIA, Estilo.TENUE)
	gps_detalle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(gps_detalle)
	gps_acciones = VBoxContainer.new()
	gps_acciones.add_theme_constant_override("separation", 12)
	v.add_child(gps_acciones)

	# Aviso fijo mientras se calibra
	aviso_calib = PanelContainer.new()
	aviso_calib.add_theme_stylebox_override("panel", Estilo.caja(Estilo.NOCHE, 28, true, 22))
	aviso_calib.visible = false
	arriba.add_child(aviso_calib)
	var ha := HBoxContainer.new()
	ha.add_theme_constant_override("separation", 16)
	aviso_calib.add_child(ha)
	aviso_calib_txt = Estilo.texto("", 22, Estilo.F_NEGRITA, Color.WHITE)
	aviso_calib_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso_calib_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ha.add_child(aviso_calib_txt)
	var cancelar := Estilo.boton_icono("cerrar", Color(1, 1, 1, 0.14), Color.WHITE, 64, false)
	cancelar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cancelar.pressed.connect(func():
		calib = {}
		aviso_calib.visible = false)
	ha.add_child(cancelar)


func _abrir_hoja_gps() -> void:
	if gps.estado == "sin_permiso":
		gps.pedir_permiso()
	for c in gps_acciones.get_children():
		c.queue_free()
	var det := ""
	match gps.estado:
		"sin_gps":
			gps_titulo.text = "Este equipo no tiene GPS"
			det = "En el celular, la app te ubica sola dentro de la UAM. Aquí puedes marcar dónde estás tocando el mapa."
		"sin_permiso":
			gps_titulo.text = "Falta el permiso de ubicación"
			det = "Acepta el permiso para que la app sepa dónde estás. Si lo negaste, actívalo en Ajustes > Apps > RutasSeguras > Permisos."
		"apagado":
			gps_titulo.text = "La ubicación está apagada"
			det = "Activa «Ubicación» en el panel rápido del teléfono."
		"buscando":
			gps_titulo.text = "Buscando señal GPS…"
			det = "Dentro de los edificios la señal es más débil. Acércate a una ventana o sal un momento."
		_:
			var l := Geo.a_local(gps.lat, gps.lon)
			if not Geo.en_campus(l):
				gps_titulo.text = "Estás fuera de la UAM"
				det = "Estás a %d m del campus. Cuando llegues, la app te ubicará sola." % roundi(l.distance_to(Geo.CENTRO))
			else:
				gps_titulo.text = ("Edificio %s · %s" % [edificio_actual, "Planta baja" if planta_actual == 1 else "Planta %d" % planta_actual]) if edificio_actual != "" else "Estás afuera, en el campus"
				det = "Precisión del GPS: ±%d m." % roundi(gps.precision)
				if not ubic.is_empty() and gps_seguir:
					det += "  Cerca de: %s." % origen
				det += "\n" + ("GPS calibrado en el campus." if Geo.calibrado else "Sin calibrar: si tu punto no coincide con el mapa, calibra una vez.")
	gps_detalle.text = det
	var en_uam: bool = gps.estado == "ok" and Geo.en_campus(Geo.a_local(gps.lat, gps.lon))
	if en_uam and not gps_seguir:
		_accion_gps("Usar mi ubicación GPS", Estilo.TEAL, Color.WHITE, usar_gps)
	if en_uam and edificio_actual != "" and Campus.plantas_de(edificio_actual) > 1:
		_accion_gps("Cambiar de planta", Color("#EEF3F4"), Estilo.TINTA, _preguntar_planta)
	if gps.estado == "ok":
		_accion_gps("Calibrar GPS en el campus", Color("#EEF3F4"), Estilo.TINTA, _iniciar_calibracion)
	if Geo.calibrado:
		_accion_gps("Borrar calibración", Color("#FDECEC"), Estilo.ROJO, func():
			Geo.reiniciar()
			var cfg := ConfigFile.new()
			cfg.load(AJUSTES)
			Geo.guardar(cfg)
			cfg.save(AJUSTES)
			mostrar_toast("Calibración borrada"))
	_accion_gps("Cerrar", Color("#EEF3F4"), Estilo.TINTA, func(): pass)
	hoja_gps.visible = true
	_aparecer(hoja_gps)


func _accion_gps(texto: String, fondo: Color, color: Color, accion: Callable) -> void:
	var b := Estilo.boton(texto, fondo, color, 26, 24)
	b.custom_minimum_size = Vector2(0, 84)
	b.pressed.connect(func():
		hoja_gps.visible = false
		accion.call())
	gps_acciones.add_child(b)


# ---------------- Calibración (dos puntos conocidos) ----------------
func _iniciar_calibracion() -> void:
	calib = {"paso": 1}
	aviso_calib_txt.text = "Calibrar GPS (1 de 2): párate en un lugar que reconozcas, por ejemplo la entrada norte del Edificio A, y tócalo en el mapa."
	aviso_calib.visible = true
	_aparecer(aviso_calib)
	_hablar("Párate en un lugar que reconozcas y tócalo en el mapa.", true)


# Promedio de las lecturas de los últimos 6 segundos (pesa más la más precisa)
func _gps_promedio() -> Vector2:
	var ahora := Time.get_ticks_msec() / 1000.0
	var suma := Vector2.ZERO
	var peso := 0.0
	for r in _lecturas:
		if ahora - r[0] <= 6.0:
			var w := 1.0 / maxf(r[3], 1.0)
			suma += Vector2(r[1], r[2]) * w
			peso += w
	return suma / peso if peso > 0.0 else Vector2(gps.lat, gps.lon)


func _punto_calibracion(l: Vector2) -> void:
	if gps.estado != "ok":
		mostrar_toast("Espera la señal GPS (mejor al aire libre)")
		return
	var g := _gps_promedio()
	if calib.paso == 1:
		calib = {"paso": 2, "l1": l, "g1": g}
		Geo.calibrar_1(l, g)
		aviso_calib_txt.text = "Calibrar GPS (2 de 2): camina a otro lugar a más de 40 m, por ejemplo la salida sur del Edificio B, y tócalo en el mapa."
		_hablar("Bien. Ahora camina a otro lugar lejano y tócalo en el mapa.", true)
		_vibrar(60)
		return
	var error := Geo.calibrar_2(calib.l1, calib.g1, l, g)
	if error != "":
		mostrar_toast(error)
		return
	calib = {}
	aviso_calib.visible = false
	var cfg := ConfigFile.new()
	cfg.load(AJUSTES)
	Geo.guardar(cfg)
	cfg.save(AJUSTES)
	DisplayServer.clipboard_set(Geo.texto())
	print("GPS calibrado: ", Geo.texto())
	mostrar_toast("GPS calibrado ✓ (valores copiados)")
	_hablar("GPS calibrado.", true)
	_vibrar(120)
	if gps_seguir:
		_al_gps(gps.lat, gps.lon, gps.precision)
