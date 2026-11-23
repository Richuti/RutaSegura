# ==========================================================
#  RutasSeguras
#  Estructura de Datos: GRAFO DIRIGIDO Y PONDERADO
#  Misma estructura vista en clase (Vertex / Graph,
#  insertVertex, link, printMatrix), escrita en GDScript.
# ==========================================================
class_name Graph
extends RefCounted

var vertexs: Array[Vertex] = []


# ---------------- Métodos vistos en clase ----------------
func insertVertex(city: String, segura: bool = false, pos: Vector3 = Vector3.ZERO) -> bool:
	for v in vertexs:
		if v.city.to_lower() == city.to_lower():
			return false
	var nuevo := Vertex.new(city, segura, pos)
	vertexs.append(nuevo)
	return true


func link(origen: String, destino: String, peso: float) -> bool:
	var vertice_origen: Vertex = null
	var vertice_destino: Vertex = null

	for v in vertexs:
		if v.city.to_lower() == origen.to_lower():
			vertice_origen = v
		if v.city.to_lower() == destino.to_lower():
			vertice_destino = v

	if vertice_origen == null or vertice_destino == null:
		return false

	vertice_origen.neig.append([vertice_destino, peso])
	return true


func printMatrix(ancho: int = 16) -> void:
	# Obtener puntos que participan en conexiones.
	var ciudades: Array[Vertex] = []
	for v in vertexs:
		if not v.neig.is_empty() and not ciudades.has(v):
			ciudades.append(v)
		for par in v.neig:
			if not ciudades.has(par[0]):
				ciudades.append(par[0])

	var n := ciudades.size()
	var matriz := []
	for i in n:
		var fila := []
		fila.resize(n)
		fila.fill(0.0)
		matriz.append(fila)

	# Llenar matriz con los pesos.
	for i in n:
		for par in ciudades[i].neig:
			for j in n:
				if ciudades[j] == par[0]:
					matriz[i][j] = par[1]
					break

	# Imprimir encabezados.
	var linea := "".rpad(ancho)
	for v in ciudades:
		linea += v.city.left(ancho - 1).rpad(ancho)
	print(linea)

	# Imprimir matriz.
	for i in n:
		linea = ciudades[i].city.left(ancho - 1).rpad(ancho)
		for peso in matriz[i]:
			linea += fmt(peso).rpad(ancho)
		print(linea)


# ---------------- Métodos del proyecto ----------------
static func fmt(x: float) -> String:
	return str(int(x)) if x == int(x) else "%.1f" % x


static func clave(a: String, b: String) -> String:
	# Identificador de un pasillo sin importar el sentido.
	return a + "|" + b if a < b else b + "|" + a


func buscar(city: String) -> Vertex:
	for v in vertexs:
		if v.city.to_lower() == city.to_lower():
			return v
	return null


func linkDoble(a: String, b: String, peso: float) -> bool:
	# Un pasillo se camina en ambos sentidos: dos aristas dirigidas.
	return link(a, b, peso) and link(b, a, peso)


func aristas() -> Array:
	# Pasillos sin repetir: [[Vertex a, Vertex b, peso], ...]
	var lista := []
	var vistos := {}
	for v in vertexs:
		for par in v.neig:
			var k := clave(v.city, par[0].city)
			if not vistos.has(k):
				vistos[k] = true
				lista.append([v, par[0], par[1]])
	return lista


func peso_entre(a: Vertex, b: Vertex) -> float:
	for par in a.neig:
		if par[0] == b:
			return par[1]
	return INF


# Dijkstra: distancia mínima desde 'origen' a todos los puntos.
# 'bloqueados' = claves de pasillos cerrados (ver clave()).
# 'permitido'  = regla opcional func(a, b) -> bool para usar la arista dirigida a -> b.
func dijkstra(origen: String, bloqueados: Array = [], permitido: Callable = Callable()) -> Dictionary:
	var inicio := buscar(origen)
	if inicio == null:
		return {}

	var dist := {}
	var previo := {}
	var visitado := {}
	for v in vertexs:
		dist[v] = INF
		previo[v] = null
		visitado[v] = false
	dist[inicio] = 0.0

	for _i in vertexs.size():
		# Elegir el no visitado con menor distancia.
		var actual: Vertex = null
		for v in vertexs:
			if not visitado[v] and (actual == null or dist[v] < dist[actual]):
				actual = v
		if actual == null or dist[actual] == INF:
			break
		visitado[actual] = true

		# Relajar aristas.
		for par in actual.neig:
			var vecino: Vertex = par[0]
			if bloqueados.has(clave(actual.city, vecino.city)):
				continue
			if permitido.is_valid() and not permitido.call(actual, vecino):
				continue
			if dist[actual] + par[1] < dist[vecino]:
				dist[vecino] = dist[actual] + par[1]
				previo[vecino] = actual

	return {"dist": dist, "previo": previo}


func reconstruir(previo: Dictionary, destino: Vertex) -> Array[Vertex]:
	var camino: Array[Vertex] = []
	var actual: Vertex = destino
	while actual != null:
		camino.push_front(actual)
		actual = previo[actual]
	return camino


# Devuelve {"camino": [...], "distancia": m} o {} si no hay ruta.
func rutaMasCorta(origen: String, destino: String, bloqueados: Array = []) -> Dictionary:
	var r := dijkstra(origen, bloqueados)
	var fin := buscar(destino)
	if r.is_empty() or fin == null or r.dist[fin] == INF:
		return {}
	return {"camino": reconstruir(r.previo, fin), "distancia": r.dist[fin]}


# Ruta a la ZONA SEGURA más cercana.
func evacuar(origen: String, bloqueados: Array = [], permitido: Callable = Callable()) -> Dictionary:
	var r := dijkstra(origen, bloqueados, permitido)
	if r.is_empty():
		return {}
	var mejor: Vertex = null
	for v in vertexs:
		if v.segura and (mejor == null or r.dist[v] < r.dist[mejor]):
			mejor = v
	if mejor == null or r.dist[mejor] == INF:
		return {}
	return {"camino": reconstruir(r.previo, mejor), "distancia": r.dist[mejor]}
