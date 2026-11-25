# ==========================================================
#  RutasSeguras - Indicaciones estilo Waze
#  Funciones sin estado que convierten una ruta del grafo (lista de
#  vértices) en instrucciones: giros, tramos, pasos y textos de voz.
#  Las usan main.gd (navegación y voz) y las pruebas.
# ==========================================================
class_name Indicaciones
extends RefCounted


# En cada vértice de la ruta se compara la arista que llega
# con la que sale: el ángulo y el lado dan la maniobra.
static func giro(a: Vector3, b: Vector3, c: Vector3) -> Dictionary:
	# Arista inclinada = escaleras (cambia de planta)
	if absf(c.y - b.y) > 0.5:
		if absf(b.y - a.y) > 0.5:
			return {"tipo": "escaleras", "texto": "Sigue " + ("bajando" if c.y < b.y else "subiendo") + " las escaleras", "continua": true}
		return {"tipo": "escaleras", "texto": ("Baja" if c.y < b.y else "Sube") + " las escaleras"}
	if absf(b.y - a.y) > 0.5:
		# Saliendo de las escaleras: se calcula el giro con la dirección del último tramo
		var g := giro(Vector3(a.x, b.y, a.z), b, c)
		if g.tipo == "recto":
			return {"tipo": "recto", "texto": "Al bajar, sigue de frente"}
		return {"tipo": g.tipo, "texto": "Al bajar, " + minuscula(g.texto)}
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
static func tramos(camino: Array) -> Array:
	var lista := []
	for i in camino.size() - 1:
		var esc: bool = Campus.es_escalera(camino[i]) or Campus.es_escalera(camino[i + 1])
		var l: float = camino[i].pos.distance_to(camino[i + 1].pos)
		if esc and not lista.is_empty() and lista[-1].escalera:
			lista[-1].hasta = i
			lista[-1].largo += l
		elif not esc and not lista.is_empty() and not lista[-1].escalera \
				and giro(camino[i - 1].pos, camino[i].pos, camino[i + 1].pos).tipo == "recto":
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
static func maniobra(camino: Array, tramos: Array, t: int) -> Dictionary:
	if t >= tramos.size() - 1:
		var fin: Vertex = camino[-1]
		return {"tipo": "llegada", "texto": "Llegas a " + fin.city, "hacia": fin.city}
	var sig: Dictionary = tramos[t + 1]
	if sig.escalera:
		var a: Vertex = camino[sig.desde]
		var b: Vertex = camino[sig.hasta + 1]
		var verbo := "Baja" if b.pos.y < a.pos.y else "Sube"
		var destino := nombre_planta(Campus.planta_de(b))
		return {"tipo": "escaleras", "texto": verbo + " las escaleras", "hacia": "hasta " + destino}
	var fin_t: int = tramos[t].hasta
	var g := giro(camino[fin_t].pos, camino[fin_t + 1].pos, camino[sig.desde + 1].pos)
	if tramos[t].escalera:
		var bajo: bool = camino[tramos[t].desde].pos.y > camino[fin_t + 1].pos.y
		g.texto = ("Al bajar, " if bajo else "Al subir, ") + minuscula(g.texto)
	g["hacia"] = "hacia " + camino[sig.hasta + 1].city
	return g


static func pasos(camino: Array) -> Array:
	var tramos := tramos(camino)
	var lista := []
	for t in tramos.size():
		var tr: Dictionary = tramos[t]
		var fin: Vertex = camino[tr.hasta + 1]
		var titulo := ""
		var tipo := "recto"
		if tr.escalera:
			var ini: Vertex = camino[tr.desde]
			titulo = ("Baja" if fin.pos.y < ini.pos.y else "Sube") + " las escaleras hasta " + nombre_planta(Campus.planta_de(fin))
			tipo = "escaleras"
		elif t == 0:
			titulo = "Sal hacia " + fin.city
		else:
			var m := maniobra(camino, tramos, t - 1)
			titulo = m.texto + " hacia " + fin.city
			tipo = m.tipo
		lista.append({"tipo": tipo, "titulo": titulo, "metros": roundf(tr.largo)})
	var ultimo: Vertex = camino[-1]
	lista.append({"tipo": "llegada", "titulo": "Llegas a " + ultimo.city, "metros": -1.0})
	return lista


static func maniobras(camino: Array, color: Color) -> Array:
	var tramos := tramos(camino)
	var total := 0.0
	for tr in tramos:
		total += tr.largo
	var items := []
	var acum := 0.0
	for t in tramos.size() - 1:
		acum += tramos[t].largo
		var m := maniobra(camino, tramos, t)
		if m.tipo != "recto":
			items.append([camino[tramos[t].hasta + 1].pos, m.tipo, color, acum / total])
	return items


# Planta a la que llevan las escaleras que empiezan en el vértice i
static func planta_destino(camino: Array, i: int) -> int:
	var k := i
	while k + 1 < camino.size() and absf(camino[k + 1].pos.y - camino[k].pos.y) > 0.5:
		k += 1
	return Campus.planta_de(camino[k])


static func nombre_planta(p: int) -> String:
	return "la planta baja" if p == 1 else "la planta %d" % p


# Minúscula solo en la primera letra (para no estropear nombres propios)
static func minuscula(t: String) -> String:
	return t.left(1).to_lower() + t.substr(1)


static func tiempo(seg: float) -> String:
	var s := ceili(seg)
	return "%d s" % s if s < 60 else "%d min %02d s" % [s / 60, s % 60]


static func para_voz(nombre: String) -> String:
	# "B - Pasillo Central" -> "Pasillo Central del edificio B"
	if nombre.begins_with("hacia "):
		return "hacia " + para_voz(nombre.substr(6))
	var partes := nombre.split(" - ")
	if partes.size() == 2 and partes[0].length() == 1:
		return "%s del edificio %s" % [partes[1], partes[0]]
	if partes.size() == 2 and partes[0].length() == 2:
		return "%s del edificio %s, planta %s" % [partes[1], partes[0][0], partes[0][1]]
	return nombre.replace("B-C", "entre B y C")
