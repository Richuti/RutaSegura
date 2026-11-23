# ==========================================================
#  Mapa del campus UAM - Edificios A, B y C
#  Basado en el mapa oficial de Rutas de Evacuación.
#  Coordenadas en METROS (aproximadas del mapa; medir en sitio
#  y ajustar). x = horizontal del mapa, z = vertical del mapa,
#  y = altura (cada planta de B y C mide ALTURA_PLANTA).
# ==========================================================
class_name Campus
extends RefCounted

const ALTURA_PLANTA := 3.6
const FACTOR_ESCALERA := 1.5   # bajar escaleras "cuesta" más que caminar plano

# Edificios navegables: nombre, letra, color de la letra (como en el mapa),
# x1, z1, x2, z2 (huella), altura de paredes, número de plantas
const EDIFICIOS = [
	["Edificio A", "A", Color("#E8743B"), 0.0, 0.0, 30.0, 26.0, 7.5, 2],
	["Edificio B", "B", Color("#7B5CD6"), 0.0, 30.0, 12.0, 90.0, 10.8, 3],
	["Edificio C", "C", Color("#4F6BD8"), 19.0, 30.0, 30.0, 90.0, 10.8, 3],
]

# Edificios vecinos (contexto visual): letra, huella, altura, plantas, nombre
const CONTEXTO = [
	["K", -40.0, 5.0, -27.0, 19.0, 4.5, 1, "Cafetería"],
	["M", 15.0, 100.0, 31.0, 116.0, 5.0, 1],
	["F", -47.0, 98.0, -35.0, 110.0, 5.0, 1],
	["G", -31.0, 98.0, -20.0, 110.0, 5.0, 1],
]

# Aulas (vista interior): x1, z1, x2, z2. Dejan libres los pasillos.
const AULAS = [
	# Edificio A
	[0.0, 0.0, 6.6, 11.2], [6.6, 0.0, 13.2, 11.2],
	[16.8, 0.0, 23.4, 14.8], [23.4, 0.0, 30.0, 14.8],
	[0.0, 14.8, 4.2, 26.0],
	[7.8, 14.8, 15.2, 26.0], [15.2, 14.8, 22.6, 26.0], [22.6, 14.8, 30.0, 26.0],
	# Edificio B (los extremos z 30-38.6 y 81.4-90 son las escaleras)
	[0.0, 39.6, 4.2, 47.0], [0.0, 47.0, 4.2, 58.2], [0.0, 61.8, 4.2, 70.0], [0.0, 70.0, 4.2, 80.4],
	[7.8, 38.6, 12.0, 49.0], [7.8, 49.0, 12.0, 58.2], [7.8, 61.8, 12.0, 70.0], [7.8, 70.0, 12.0, 81.4],
	# Edificio C
	[19.0, 39.6, 22.7, 47.0], [19.0, 47.0, 22.7, 58.2], [19.0, 61.8, 22.7, 70.0], [19.0, 70.0, 22.7, 80.4],
	[26.3, 38.6, 30.0, 49.0], [26.3, 49.0, 30.0, 58.2], [26.3, 61.8, 30.0, 70.0], [26.3, 70.0, 30.0, 81.4],
]

# Escaleras (cajas de escalera con descanso a media altura), pegadas al
# lado oeste para dejar libre el pasillo: letra, x del centro de la escalera,
# z en el borde del piso, z del descanso, nombre
const ESCALERAS = [
	["B", 3.0, 38.0, 32.0, "Norte"], ["B", 3.0, 82.0, 88.0, "Sur"],
	["C", 21.5, 38.0, 32.0, "Norte"], ["C", 21.5, 82.0, 88.0, "Sur"],
]
const SEPARACION_TRAMOS := 1.25   # distancia del centro a cada tramo de la escalera

# Puente entre B y C (planta 2) con escalera que baja al patio
const PUENTE_Y := 3.6
const PUENTE_Z := 60.0
const PUENTE_X1 := 12.0
const PUENTE_X2 := 19.0
const PUENTE_ESCALERA = [Vector3(15.5, 3.6, 61.6), Vector3(15.5, 0.0, 67.5)]

# Puertas: posición en la pared y hacia dónde mira
const PUERTAS = [
	[Vector3(15, 0, 0), Vector3(0, 0, -1)],
	[Vector3(0, 0, 13), Vector3(-1, 0, 0)],
	[Vector3(0, 0, 60), Vector3(-1, 0, 0)],
	[Vector3(6, 0, 90), Vector3(0, 0, 1)],
	[Vector3(12, 0, 60), Vector3(1, 0, 0)],
	[Vector3(19, 0, 60), Vector3(-1, 0, 0)],
	[Vector3(24.5, 0, 90), Vector3(0, 0, 1)],
	[Vector3(12, 3.6, 60), Vector3(1, 0, 0)],
	[Vector3(19, 3.6, 60), Vector3(-1, 0, 0)],
]

# Aberturas en los muros (puertas + pasarela A-B): por aquí se puede cruzar la pared
const ABERTURAS_EXTRA = [
	[Vector3(6, 0, 26), Vector3(0, 0, 1)],
	[Vector3(6, 0, 30), Vector3(0, 0, -1)],
]
const ANCHO_PUERTA := 2.4
const ALTO_PUERTA := 2.7


static func aberturas() -> Array:
	var lista := []
	lista.append_array(PUERTAS)
	lista.append_array(ABERTURAS_EXTRA)
	return lista


# Puntos de planta baja y exteriores: nombre, posición
const PUNTOS = [
	["A - Entrada Norte",   Vector3(15, 0, 1)],
	["A - Pasillo Central", Vector3(15, 0, 13)],
	["A - Pasillo Oeste",   Vector3(6, 0, 13)],
	["A - Salida Oeste",    Vector3(-2, 0, 13)],
	["A - Extremo Sur",     Vector3(6, 0, 25)],
	["B - Extremo Norte",   Vector3(6, 0, 31)],
	["B - Pasillo Central", Vector3(6, 0, 60)],
	["B - Salida Oeste",    Vector3(-2, 0, 60)],
	["B - Extremo Sur",     Vector3(6, 0, 89)],
	["B - Salida Sur",      Vector3(6, 0, 91.5)],
	["Patio B-C",           Vector3(15.5, 0, 60)],
	["C - Extremo Norte",   Vector3(24.5, 0, 31)],
	["C - Pasillo Central", Vector3(24.5, 0, 60)],
	["C - Extremo Sur",     Vector3(24.5, 0, 89)],
	["C - Salida Sur",      Vector3(24.5, 0, 93)],
	["Sendero Sur B-C",     Vector3(15.5, 0, 95)],
	["Cafetería",           Vector3(-30, 0, 21)],
]

# Zonas de seguridad (círculo verde con check en el mapa oficial)
const ZONAS_SEGURAS = [
	["Plaza Central Rubén Darío", Vector3(-35, 0, 45)],
	["Punto de Reunión Sur",      Vector3(-15, 0, 116)],
]

# Pasillos de planta baja y exteriores (se caminan en ambos sentidos)
const PASILLOS = [
	["A - Entrada Norte",   "A - Pasillo Central"],
	["A - Pasillo Central", "A - Pasillo Oeste"],
	["A - Pasillo Oeste",   "A - Salida Oeste"],
	["A - Pasillo Oeste",   "A - Extremo Sur"],
	["A - Salida Oeste",    "Plaza Central Rubén Darío"],
	["A - Extremo Sur",     "B - Extremo Norte"],
	["B - Extremo Norte",   "B - Pasillo Central"],
	["B - Pasillo Central", "B - Salida Oeste"],
	["B - Salida Oeste",    "Plaza Central Rubén Darío"],
	["B - Pasillo Central", "B - Extremo Sur"],
	["B - Extremo Sur",     "B - Salida Sur"],
	["B - Salida Sur",      "Punto de Reunión Sur"],
	["B - Pasillo Central", "Patio B-C"],
	["Patio B-C",           "C - Pasillo Central"],
	["C - Extremo Norte",   "C - Pasillo Central"],
	["C - Pasillo Central", "C - Extremo Sur"],
	["C - Extremo Sur",     "C - Salida Sur"],
	["C - Salida Sur",      "Sendero Sur B-C"],
	["B - Salida Sur",      "Sendero Sur B-C"],
	["Sendero Sur B-C",     "Punto de Reunión Sur"],
	["Patio B-C",           "Sendero Sur B-C"],
	["A - Salida Oeste",    "Cafetería"],
	["Cafetería",           "Plaza Central Rubén Darío"],
]


static func crear_campus() -> Graph:
	var mapa := Graph.new()
	for p in PUNTOS:
		mapa.insertVertex(p[0], false, p[1])
	for z in ZONAS_SEGURAS:
		mapa.insertVertex(z[0], true, z[1])
	for p in PASILLOS:
		_unir(mapa, p[0], p[1])

	# Plantas altas de B y C: pasillo por planta
	for e in [["B", 6.0], ["C", 24.5]]:
		var letra: String = e[0]
		var x: float = e[1]
		for planta in [2, 3]:
			var y: float = (planta - 1) * ALTURA_PLANTA
			var n := "%s%d - Extremo Norte" % [letra, planta]
			var c := "%s%d - Pasillo Central" % [letra, planta]
			var s := "%s%d - Extremo Sur" % [letra, planta]
			mapa.insertVertex(n, false, Vector3(x, y, 38.6))
			mapa.insertVertex(c, false, Vector3(x, y, 60))
			mapa.insertVertex(s, false, Vector3(x, y, 81.4))
			_unir(mapa, n, c)
			_unir(mapa, c, s)

	# Puente B-C en planta 2 y su escalera al patio
	mapa.insertVertex("Puente B-C", false, Vector3(15.5, PUENTE_Y, PUENTE_Z))
	mapa.insertVertex("Puente B-C - Escalera (arriba)", false, PUENTE_ESCALERA[0])
	mapa.insertVertex("Puente B-C - Escalera (abajo)", false, PUENTE_ESCALERA[1])
	_unir(mapa, "B2 - Pasillo Central", "Puente B-C")
	_unir(mapa, "Puente B-C", "C2 - Pasillo Central")
	_unir(mapa, "Puente B-C", "Puente B-C - Escalera (arriba)")
	_unir(mapa, "Puente B-C - Escalera (arriba)", "Puente B-C - Escalera (abajo)")
	_unir(mapa, "Puente B-C - Escalera (abajo)", "Patio B-C")
	_unir(mapa, "Puente B-C - Escalera (abajo)", "Sendero Sur B-C")

	# Escaleras: cada cambio de planta = tramo + descanso + tramo (como en la vida real).
	# Cada tramo es una arista inclinada; el descanso es una arista plana.
	for esc in ESCALERAS:
		var letra: String = esc[0]
		var x: float = esc[1]
		var z_piso: float = esc[2]
		var z_desc: float = esc[3]
		var lado: String = esc[4]
		var dx := SEPARACION_TRAMOS
		for planta in [1, 2]:
			var y0: float = (planta - 1) * ALTURA_PLANTA
			var y1: float = planta * ALTURA_PLANTA
			var ym: float = (y0 + y1) / 2.0
			var base := "%s%d - Escalera %s" % [letra, planta, lado]
			var abajo := base + " (inicio)"
			var desc_a := base + " (descanso a)"
			var desc_b := base + " (descanso b)"
			var arriba := "%s%d - Escalera %s (llegada)" % [letra, planta + 1, lado]
			mapa.insertVertex(abajo, false, Vector3(x + dx, y0, z_piso))
			mapa.insertVertex(desc_a, false, Vector3(x + dx, ym, z_desc))
			mapa.insertVertex(desc_b, false, Vector3(x - dx, ym, z_desc))
			mapa.insertVertex(arriba, false, Vector3(x - dx, y1, z_piso))
			_unir(mapa, abajo, desc_a)
			_unir(mapa, desc_a, desc_b)
			_unir(mapa, desc_b, arriba)
			# Conexión con el pasillo de cada planta
			_unir(mapa, _extremo(letra, planta, lado), abajo)
			if planta == 1:
				_unir(mapa, "%s - Pasillo Central" % letra, abajo)
			_unir(mapa, arriba, _extremo(letra, planta + 1, lado))
	return mapa


# Peso = distancia en metros (redondeada). En escaleras se multiplica.
static func _unir(mapa: Graph, a: String, b: String) -> void:
	var va := mapa.buscar(a)
	var vb := mapa.buscar(b)
	var d := va.pos.distance_to(vb.pos)
	if absf(va.pos.y - vb.pos.y) > 0.5:
		d *= FACTOR_ESCALERA
	mapa.linkDoble(a, b, roundf(d))


static func _extremo(letra: String, planta: int, lado: String) -> String:
	if planta == 1:
		return "%s - Extremo %s" % [letra, lado]
	return "%s%d - Extremo %s" % [letra, planta, lado]


# ¿En qué edificio está un punto? ("" = afuera: patio, puente, senderos, zonas)
static func zona(v: Vertex) -> String:
	for e in EDIFICIOS:
		if Rect2(e[3], e[4], e[5] - e[3], e[6] - e[4]).has_point(Vector2(v.pos.x, v.pos.z)):
			return e[1]
	return ""


# Regla de evacuación sobre las aristas DIRIGIDAS del grafo:
#  - una vez afuera, no se vuelve a entrar a un edificio (afuera -> adentro: prohibida)
#  - no se cruza de un edificio a otro (pasarela A-B en una evacuación: prohibida)
static func permitido_evacuar(a: Vertex, b: Vertex) -> bool:
	var za := zona(a)
	var zb := zona(b)
	if za == "" and zb != "":
		return false
	if za != "" and zb != "" and za != zb:
		return false
	return true


static func es_escalera(v: Vertex) -> bool:
	return v.city.contains("Escalera")


static func planta_de(v: Vertex) -> int:
	return roundi(v.pos.y / ALTURA_PLANTA) + 1


# ¿En qué edificio estás según el GPS? (x, z en metros del mapa)
# Con histéresis: para salir del edificio actual hay que alejarse 3 m del
# muro y para entrar a otro hay que estar 1 m adentro (el GPS "tiembla").
static func edificio_xz(p: Vector2, actual: String = "") -> String:
	var orden := EDIFICIOS.duplicate()
	orden.sort_custom(func(a, b): return a[1] == actual and b[1] != actual)
	for e in orden:
		var r := Rect2(e[3], e[4], e[5] - e[3], e[6] - e[4])
		r = r.grow(3.0) if e[1] == actual else r.grow(-1.0)
		if r.has_point(p):
			return e[1]
	return ""


# Plantas que tiene el grafo en cada edificio (A solo tiene planta baja mapeada)
static func plantas_de(letra: String) -> int:
	return 3 if letra in ["B", "C"] else 1
