# Auditoría automática: grafo, geometría de rutas y simulación de navegación.
# Uso: godot --headless --path . res://tests/auditoria.tscn
extends Node

var errores: Array[String] = []
var avisos: Array[String] = []


func _err(t: String) -> void:
	errores.append(t)


func _ready() -> void:
	var main = load("res://main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main.cerrar_bienvenida()
	var mapa: Graph = main.mapa

	# ---------- 1. Grafo ----------
	for v in mapa.vertexs:
		if v.neig.is_empty():
			_err("Vértice sin aristas: " + v.city)
		for par in v.neig:
			var w: Vertex = par[0]
			if mapa.peso_entre(w, v) != par[1]:
				_err("Arista sin regreso o peso distinto: %s -> %s" % [v.city, w.city])
			if par[1] <= 0:
				_err("Peso <= 0: %s -> %s" % [v.city, w.city])
	var r0 := mapa.dijkstra(mapa.vertexs[0].city)
	for v in mapa.vertexs:
		if r0.dist[v] == INF:
			_err("Vértice inalcanzable: " + v.city)

	# ---------- 2. Geometría de las aristas ----------
	var puertas := []
	for p in Campus.aberturas():
		puertas.append(p[0])
	for e in mapa.aristas():
		var a: Vertex = e[0]
		var b: Vertex = e[1]
		var pa := Vector2(a.pos.x, a.pos.z)
		var pb := Vector2(b.pos.x, b.pos.z)
		var plano: bool = absf(a.pos.y - b.pos.y) < 0.1
		# a) paredes de edificios navegables: cruzar solo por puertas
		if plano:
			for ed in Campus.EDIFICIOS:
				var r := Rect2(ed[3], ed[4], ed[5] - ed[3], ed[6] - ed[4])
				for cruce in _cruces(pa, pb, r):
					var ok := false
					for pu in puertas:
						if absf(pu.y - a.pos.y) < 0.5 and Vector2(pu.x, pu.z).distance_to(cruce) < Campus.ANCHO_PUERTA / 2.0 - 0.3:
							ok = true
					if not ok:
						_err("Atraviesa la pared de %s en %s: %s / %s" % [ed[0], cruce, a.city, b.city])
		# b) aulas: ninguna arista debe pasar por dentro de un aula
		for au in Campus.AULAS:
			var r := Rect2(au[0] + 0.3, au[1] + 0.3, au[2] - au[0] - 0.6, au[3] - au[1] - 0.6)
			if _segmento_toca(pa, pb, r):
				_err("Pasa por dentro de un aula %s: %s / %s" % [au, a.city, b.city])
		# c) edificios de contexto: nunca
		for c in Campus.CONTEXTO:
			var r := Rect2(c[1], c[2], c[3] - c[1], c[4] - c[2])
			if _segmento_toca(pa, pb, r):
				_err("Atraviesa el edificio %s: %s / %s" % [c[0], a.city, b.city])

	# ---------- 3. Simulación desde cada punto ----------
	var origenes := []
	for v in mapa.vertexs:
		if not v.segura and not Campus.es_escalera(v):
			origenes.append(v.city)
	var n_ok := 0
	for o in origenes:
		main.terminar()
		main.bloquear("")
		main.seleccionar_origen(o)
		main.emergencia()
		if main.nav.is_empty():
			_err("Sin ruta de evacuación desde " + o)
			continue
		var cam0: Array = main.nav.camino
		for i in cam0.size() - 1:
			if not Campus.permitido_evacuar(cam0[i], cam0[i + 1]):
				_err("Evacuación desde %s vuelve a entrar o cruza de edificio: %s -> %s" % [o, cam0[i].city, cam0[i + 1].city])
		var pasos: Array = main._pasos(main.nav.camino)
		for p in pasos:
			if p.titulo.contains("Escalera") or p.titulo.contains("nan") or p.titulo.contains("Tu ubicación"):
				_err("Paso con texto raro desde %s: %s" % [o, p.titulo])
		var it := 0
		while not main.nav.fin and it < 4000:
			main._process(0.05)
			it += 1
			for t in [main.banner_dist.text, main.banner_instr.text, main.banner_hacia.text, main.nav_eta.text]:
				if t.contains("nan") or t.contains("inf") or t.contains("Escalera"):
					_err("Banner raro desde %s: %s" % [o, t])
		if not main.nav.fin:
			_err("La navegación no termina desde " + o)
		else:
			n_ok += 1

	# ---------- 4. Bloqueo a mitad de camino (recálculo) ----------
	var n_rec := 0
	for o in origenes:
		main.terminar()
		main.bloquear("")
		main.seleccionar_origen(o)
		main.emergencia()
		if main.nav.is_empty():
			continue
		for k in 10:
			main._process(0.05)
		if main.nav.fin:
			continue
		var tr: Dictionary = main.nav.tramos[mini(main.nav.tramos.size() - 1, 1)]
		var cam: Array = main.nav.camino
		var clave := Graph.clave(cam[tr.desde].city, cam[tr.desde + 1].city)
		if cam[tr.desde].city == "Tu ubicación":
			continue
		main.bloquear(clave)
		var it := 0
		while not main.nav.is_empty() and not main.nav.fin and it < 4000:
			main._process(0.05)
			it += 1
		if not main.nav.is_empty() and not main.nav.fin:
			_err("Tras recalcular no termina desde %s (bloqueo %s)" % [o, clave])
		n_rec += 1
	main.bloquear("")

	# ---------- 5. Rutas normales (vista previa + vamos) ----------
	var n_rutas := 0
	for o in origenes:
		for d in origenes:
			if o == d:
				continue
			main.terminar()
			main.seleccionar_origen(o)
			main.ver_ruta(d)
			if main.vista_previa.is_empty():
				_err("Sin ruta %s -> %s" % [o, d])
			n_rutas += 1

	# ---------- 5b. La ruta dibujada (con curvas) tampoco atraviesa paredes ----------
	var n_curvas := 0
	for o in origenes:
		for d in origenes:
			if o == d:
				continue
			var r := mapa.rutaMasCorta(o, d)
			var pts: Array = main.escena._suavizar(r.camino)[0]
			for i in pts.size() - 1:
				var a3: Vector3 = pts[i]
				var b3: Vector3 = pts[i + 1]
				if absf(a3.y - b3.y) > 0.05:
					continue
				for ed in Campus.EDIFICIOS:
					var rr := Rect2(ed[3], ed[4], ed[5] - ed[3], ed[6] - ed[4])
					for cruce in _cruces(Vector2(a3.x, a3.z), Vector2(b3.x, b3.z), rr):
						var ok := false
						for pu in puertas:
							if absf(pu.y - (a3.y - 0.3)) < 0.5 and Vector2(pu.x, pu.z).distance_to(cruce) < Campus.ANCHO_PUERTA / 2.0 - 0.2:
								ok = true
						if not ok:
							n_curvas += 1
							if n_curvas <= 5:
								_err("La curva de la ruta %s -> %s cruza la pared de %s en %s" % [o, d, ed[0], cruce])
	print("Curvas que cruzan paredes: %d" % n_curvas)

	# ---------- 6. Calidad de las instrucciones ----------
	var vueltas := 0
	var cortos := 0
	var sube := 0
	for o in origenes:
		for d in origenes:
			if o == d:
				continue
			var r := mapa.rutaMasCorta(o, d)
			var tramos: Array = main._tramos(r.camino)
			for t in tramos.size():
				if t > 0 and t < tramos.size() - 1 and tramos[t].largo < 3.0:
					cortos += 1
					if cortos <= 5:
						avisos.append("Tramo muy corto (%.1f m) en %s -> %s" % [tramos[t].largo, o, d])
			for p in main._pasos(r.camino):
				if p.titulo.contains("vuelta"):
					vueltas += 1
					if vueltas <= 5:
						avisos.append("'Da la vuelta' en %s -> %s: %s" % [o, d, p.titulo])
				if p.titulo.begins_with("Sube"):
					sube += 1
	if sube == 0:
		_err("Ninguna ruta usa 'Sube las escaleras'")
	print("Avisos de calidad: vueltas=%d  tramos<3m=%d  subidas=%d" % [vueltas, cortos, sube])
	for a2 in avisos:
		print("  ! ", a2)

	print("==== AUDITORÍA ====")
	print("Vértices: %d   Aristas: %d" % [mapa.vertexs.size(), mapa.aristas().size()])
	print("Evacuaciones simuladas completas: %d / %d" % [n_ok, origenes.size()])
	print("Recalculos probados: %d   Rutas probadas: %d" % [n_rec, n_rutas])
	print("Errores: %d" % errores.size())
	for e in errores:
		print("  ✗ ", e)
	get_tree().quit()


# Puntos donde el segmento cruza el borde del rectángulo
func _cruces(a: Vector2, b: Vector2, r: Rect2) -> Array:
	var esquinas := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var out := []
	for i in 4:
		var p = Geometry2D.segment_intersects_segment(a, b, esquinas[i], esquinas[(i + 1) % 4])
		if p != null:
			out.append(p)
	return out


func _segmento_toca(a: Vector2, b: Vector2, r: Rect2) -> bool:
	if r.has_point(a) or r.has_point(b):
		return true
	return not _cruces(a, b, r).is_empty()
