# ==========================================================
#  Mapa del campus UAM - Edificios A, B y C
#  Basado en el mapa oficial de Rutas de Evacuación (el ESTE está
#  arriba: x = sur, z = oeste; ver geo.gd) y en los contornos de
#  OpenStreetMap: A es una franja de ~11 m de fondo y B y C miden
#  ~73 m de largo; el bloque completo mide 88 x 30 m.
#  Coordenadas en METROS (afinar midiendo en sitio).
#  y = altura (cada planta de B y C mide ALTURA_PLANTA).
# ==========================================================
class_name Campus
extends RefCounted

const ALTURA_PLANTA := 3.6
const FACTOR_ESCALERA := 1.5   # bajar escaleras "cuesta" más que caminar plano

# Edificios navegables: nombre, letra, color de la letra (como en el mapa),
# x1, z1, x2, z2 (huella), altura de paredes, número de plantas
const EDIFICIOS = [
	["Edificio A", "A", Color("#E8743B"), 0.0, 0.0, 30.0, 11.0, 7.5, 2],
	["Edificio B", "B", Color("#7B5CD6"), 0.0, 15.0, 12.0, 88.0, 10.8, 3],
	["Edificio C", "C", Color("#4F6BD8"), 19.0, 15.0, 30.0, 88.0, 10.8, 3],
]

# Pasarela techada entre A y B (planta baja): x1, x2, z1, z2
const PASARELA = [3.0, 9.0, 11.0, 15.0]

# Edificios vecinos (contexto visual): letra, huella x1, z1, x2, z2, altura,
# plantas, nombre. Huellas tomadas de OpenStreetMap y comparadas con el cartel
# oficial. Ninguna ruta puede atravesarlos (lo revisa la auditoría).
# N tiene forma de L: se arma con dos cajas (la segunda sin letra).
const CONTEXTO = [
	["K", -34.7, 9.8, -10.4, 30.3, 4.5, 1, "Cafetería"],
	["E", -76.0, 72.2, -5.7, 83.8, 7.5, 2],
	["F", -50.0, 92.4, -27.5, 108.9, 5.0, 1],
	["G", -25.0, 91.4, -4.8, 108.5, 5.0, 1],
	["M", 1.8, 96.9, 27.8, 115.7, 5.0, 1],
	["H", 30.6, 97.0, 41.0, 130.7, 5.0, 1],
	["J", 54.6, 13.0, 63.5, 29.0, 5.0, 1],
	["D", 52.9, 30.8, 63.9, 43.5, 5.0, 1],
	["N", 75.0, 17.5, 92.2, 82.4, 7.5, 2],
	["", 51.0, 60.0, 75.0, 82.4, 7.5, 2],
]

# Aulas (vista interior): x1, z1, x2, z2. Dejan libres los pasillos.
const AULAS = [
	# Edificio A: una fila de aulas al este (z 0-7.4) y el pasillo al oeste
	# (z 7.4-11). El vestíbulo de la entrada este (x 13.2-16.8) queda libre.
	[0.0, 0.0, 6.6, 7.4], [6.6, 0.0, 13.2, 7.4],
	[16.8, 0.0, 23.4, 7.4], [23.4, 0.0, 30.0, 7.4],
	# Edificio B (los extremos z 15-23.6 y 79.4-88 son las escaleras)
	[0.0, 24.9, 4.2, 34.6], [0.0, 34.6, 4.2, 49.2], [0.0, 53.8, 4.2, 64.5], [0.0, 64.5, 4.2, 78.1],
	[7.8, 23.6, 12.0, 37.2], [7.8, 37.2, 12.0, 49.2], [7.8, 53.8, 12.0, 64.5], [7.8, 64.5, 12.0, 79.4],
	# Edificio C
	[19.0, 24.9, 22.7, 34.6], [19.0, 34.6, 22.7, 49.2], [19.0, 53.8, 22.7, 64.5], [19.0, 64.5, 22.7, 78.1],
	[26.3, 23.6, 30.0, 37.2], [26.3, 37.2, 30.0, 49.2], [26.3, 53.8, 30.0, 64.5], [26.3, 64.5, 30.0, 79.4],
]

# Escaleras (cajas de escalera con descanso a media altura), pegadas al
# lado norte para dejar libre el pasillo: letra, x del centro de la escalera,
# z en el borde del piso, z del descanso, nombre
const ESCALERAS = [
	["B", 3.0, 23.0, 17.0, "Este"], ["B", 3.0, 80.0, 86.0, "Oeste"],
	["C", 21.5, 23.0, 17.0, "Este"], ["C", 21.5, 80.0, 86.0, "Oeste"],
]
const SEPARACION_TRAMOS := 1.25   # distancia del centro a cada tramo de la escalera

# Puente entre B y C (planta 2) con escalera que baja al patio
const PUENTE_Y := 3.6
const PUENTE_Z := 51.5
const PUENTE_X1 := 12.0
const PUENTE_X2 := 19.0
const PUENTE_ESCALERA = [Vector3(15.5, 3.6, 53.1), Vector3(15.5, 0.0, 59.0)]

# Puertas: posición en la pared y hacia dónde mira
const PUERTAS = [
	[Vector3(15, 0, 0), Vector3(0, 0, -1)],
	[Vector3(0, 0, 9.2), Vector3(-1, 0, 0)],
	[Vector3(0, 0, 51.5), Vector3(-1, 0, 0)],
	[Vector3(6, 0, 88), Vector3(0, 0, 1)],
	[Vector3(12, 0, 51.5), Vector3(1, 0, 0)],
	[Vector3(19, 0, 51.5), Vector3(-1, 0, 0)],
	[Vector3(24.5, 0, 88), Vector3(0, 0, 1)],
	[Vector3(12, 3.6, 51.5), Vector3(1, 0, 0)],
	[Vector3(19, 3.6, 51.5), Vector3(-1, 0, 0)],
]

# Aberturas en los muros (puertas + pasarela A-B): por aquí se puede cruzar la pared
const ABERTURAS_EXTRA = [
	[Vector3(6, 0, 11), Vector3(0, 0, 1)],
	[Vector3(6, 0, 15), Vector3(0, 0, -1)],
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
	["A - Entrada Este",    Vector3(15, 0, 1)],
	["A - Pasillo Central", Vector3(15, 0, 9.2)],
	["A - Pasillo Norte",   Vector3(6, 0, 9.2)],
	["A - Salida Norte",    Vector3(-2, 0, 9.2)],
	["B - Extremo Este",    Vector3(6, 0, 16)],
	["B - Pasillo Central", Vector3(6, 0, 51.5)],
	["B - Salida Norte",    Vector3(-2, 0, 51.5)],
	["B - Extremo Oeste",   Vector3(6, 0, 87)],
	["B - Salida Oeste",    Vector3(6, 0, 89.5)],
	["Patio B-C",           Vector3(15.5, 0, 51.5)],
	["C - Extremo Este",    Vector3(24.5, 0, 16)],
	["C - Pasillo Central", Vector3(24.5, 0, 51.5)],
	["C - Extremo Oeste",   Vector3(24.5, 0, 87)],
	["C - Salida Oeste",    Vector3(24.5, 0, 91)],
	["Sendero Oeste B-C",   Vector3(15.5, 0, 93)],
	["Cafetería",           Vector3(-8, 0, 32)],     # esquina de K hacia A y la plaza
	# Paso entre G y M hacia el punto de reunión y la cancha
	["Paso G-M",            Vector3(-1.5, 0, 95)],
	["Paso G-M Oeste",      Vector3(-1.5, 0, 112)],
	# Calle frente a A y camino al parqueo de N
	["Frente Edificio A",   Vector3(15, 0, -6)],
	["Esquina Noreste de A", Vector3(-6, 0, -6)],   # rodea A por fuera hacia la plaza
	["Esquina J",           Vector3(70, 0, -6)],
	["Calle Este de N",     Vector3(70, 0, 15)],
	["Entrada Parqueo N",   Vector3(100, 0, 15)],
]

# Zonas de seguridad (círculo verde con check en el mapa oficial)
const ZONAS_SEGURAS = [
	["Plaza Central Rubén Darío", Vector3(-26, 0, 50)],
	["Punto de Reunión Oeste",    Vector3(-16, 0, 118)],
	["Cancha de Fútbol",          Vector3(15, 0, 198)],
	["Zona Segura Parqueo N",     Vector3(108, 0, 50)],
]

# Pasillos de planta baja y exteriores (se caminan en ambos sentidos)
const PASILLOS = [
	["A - Entrada Este",   "A - Pasillo Central"],
	["A - Pasillo Central", "A - Pasillo Norte"],
	["A - Pasillo Norte",   "A - Salida Norte"],
	["A - Pasillo Norte",   "B - Extremo Este"],   # por la pasarela techada
	["B - Extremo Este",   "B - Pasillo Central"],
	["B - Pasillo Central", "B - Salida Norte"],
	["B - Salida Norte",    "Plaza Central Rubén Darío"],
	["B - Pasillo Central", "B - Extremo Oeste"],
	["B - Extremo Oeste",     "B - Salida Oeste"],
	["B - Salida Oeste",      "Paso G-M"],
	["B - Pasillo Central", "Patio B-C"],
	["Patio B-C",           "C - Pasillo Central"],
	["C - Extremo Este",   "C - Pasillo Central"],
	["C - Pasillo Central", "C - Extremo Oeste"],
	["C - Extremo Oeste",     "C - Salida Oeste"],
	["C - Salida Oeste",      "Sendero Oeste B-C"],
	["B - Salida Oeste",      "Sendero Oeste B-C"],
	["Sendero Oeste B-C",     "Paso G-M"],
	["Paso G-M",              "Paso G-M Oeste"],
	["Paso G-M Oeste",        "Punto de Reunión Oeste"],
	["Paso G-M Oeste",        "Cancha de Fútbol"],
	["A - Entrada Este",      "Frente Edificio A"],
	["Frente Edificio A",     "Esquina Noreste de A"],
	["Esquina Noreste de A",  "A - Salida Norte"],
	["Frente Edificio A",     "Esquina J"],
	["Esquina J",             "Calle Este de N"],
	["Calle Este de N",       "Entrada Parqueo N"],
	["Entrada Parqueo N",     "Zona Segura Parqueo N"],
	["Patio B-C",           "Sendero Oeste B-C"],
	["A - Salida Norte",    "Cafetería"],
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
			var n := "%s%d - Extremo Este" % [letra, planta]
			var c := "%s%d - Pasillo Central" % [letra, planta]
			var s := "%s%d - Extremo Oeste" % [letra, planta]
			mapa.insertVertex(n, false, Vector3(x, y, 23.6))
			mapa.insertVertex(c, false, Vector3(x, y, PUENTE_Z))
			mapa.insertVertex(s, false, Vector3(x, y, 79.4))
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
	_unir(mapa, "Puente B-C - Escalera (abajo)", "Sendero Oeste B-C")

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


# Plantas físicas. El grafo de A, por ahora, solo cubre planta baja.
static func plantas_de(letra: String) -> int:
	for e in EDIFICIOS:
		if e[1] == letra:
			return e[8]
	return 1
