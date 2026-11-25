class Vertex:
    def __init__(self, city: str, segura: bool = False):
        self.city = city          
        self.segura = segura     
        self.neig = []           


class Graph:
    def __init__(self):
        self.vertexs: list[Vertex] = []

    def insertVertex(self, city: str, segura: bool = False) -> bool:
        for v in self.vertexs:
            if v.city.lower() == city.lower():
                return False
        new = Vertex(city, segura)
        self.vertexs.append(new)
        return True

    def link(self, origen: str, destino: str, peso: float) -> bool:
        vertice_origen = None
        vertice_destino = None

        for v in self.vertexs:
            if v.city.lower() == origen.lower():
                vertice_origen = v
            if v.city.lower() == destino.lower():
                vertice_destino = v

        if vertice_origen is None or vertice_destino is None:
            return False

        vertice_origen.neig.append((vertice_destino, peso))
        return True

    def printMatrix(self, ancho: int = 12) -> None:
        # Obtener lugares que participan en conexiones.
        ciudades = []

        for v in self.vertexs:
            if v.neig and v not in ciudades:
                ciudades.append(v)

            for vecino, peso in v.neig:
                if vecino not in ciudades:
                    ciudades.append(vecino)

        n = len(ciudades)
        matriz = [[0] * n for _ in range(n)]

        # Llenar matriz con los pesos.
        for i in range(n):
            for vecino, peso in ciudades[i].neig:
                for j in range(n):
                    if ciudades[j] is vecino:
                        matriz[i][j] = peso
                        break

        print(f"{'':{ancho}}", end="")
        for v in ciudades:
            print(f"{v.city[:ancho-1]:{ancho}}", end="")
        print()

        for i in range(n):
            print(f"{ciudades[i].city[:ancho-1]:{ancho}}", end="")
            for peso in matriz[i]:
                print(f"{peso:<{ancho}g}", end="")
            print()

    def buscar(self, city: str):
        for v in self.vertexs:
            if v.city.lower() == city.lower():
                return v
        return None

    def linkDoble(self, a: str, b: str, peso: float) -> bool:
        return self.link(a, b, peso) and self.link(b, a, peso)

    def printLugares(self) -> None:
        for i, v in enumerate(self.vertexs, 1):
            marca = "  [ZONA SEGURA]" if v.segura else ""
            print(f"{i:2}. {v.city}{marca}")

    def dijkstra(self, origen: str, permitido=None):
        """Distancia mínima desde 'origen' a todos los lugares.
        'permitido(a, b)' (opcional) decide si se puede usar la arista a -> b."""
        inicio = self.buscar(origen)
        if inicio is None:
            return None, None

        INF = float("inf")
        dist = {v: INF for v in self.vertexs}
        previo = {v: None for v in self.vertexs}
        visitado = {v: False for v in self.vertexs}
        dist[inicio] = 0

        for _ in range(len(self.vertexs)):
            actual = None
            for v in self.vertexs:
                if not visitado[v] and (actual is None or dist[v] < dist[actual]):
                    actual = v
            if actual is None or dist[actual] == INF:
                break
            visitado[actual] = True

            for vecino, peso in actual.neig:
                if permitido is not None and not permitido(actual, vecino):
                    continue
                if dist[actual] + peso < dist[vecino]:
                    dist[vecino] = dist[actual] + peso
                    previo[vecino] = actual

        return dist, previo

    def reconstruir(self, previo, destino: Vertex) -> list[str]:
        camino = []
        actual = destino
        while actual is not None:
            camino.insert(0, actual.city)
            actual = previo[actual]
        return camino

    def rutaMasCorta(self, origen: str, destino: str) -> None:
        dist, previo = self.dijkstra(origen)
        fin = self.buscar(destino)
        if dist is None or fin is None:
            print("  Lugar no encontrado.")
            return
        if dist[fin] == float("inf"):
            print("  No hay ruta disponible.")
            return
        camino = self.reconstruir(previo, fin)
        print("  Ruta: " + " -> ".join(camino))
        print(f"  Distancia total: {dist[fin]:g} m")

    def evacuar(self, origen: str) -> None:
        dist, previo = self.dijkstra(origen, permitido_evacuar)
        if dist is None:
            print("  Lugar no encontrado.")
            return
        mejor = None
        for v in self.vertexs:
            if v.segura and (mejor is None or dist[v] < dist[mejor]):
                mejor = v
        if mejor is None or dist[mejor] == float("inf"):
            print("  No hay zona segura alcanzable.")
            return
        camino = self.reconstruir(previo, mejor)
        print(f"  ¡EVACUACIÓN! Zona segura más cercana: {mejor.city}")
        print("  Ruta: " + " -> ".join(camino))
        print(f"  Distancia: {dist[mejor]:g} m")

def zona(v: Vertex) -> str:
    nombre = v.city
    if "Salida" in nombre:
        return ""
    if len(nombre) > 1 and nombre[0] in "ABC" and (nombre[1] == " " or nombre[1].isdigit()):
        return nombre[0]
    return ""


def permitido_evacuar(a: Vertex, b: Vertex) -> bool:
    za, zb = zona(a), zona(b)
    if za == "" and zb != "":
        return False
    if za != "" and zb != "" and za != zb:
        return False
    return True

lugares = [
    "A - Entrada Este",
    "A - Pasillo Central",
    "A - Pasillo Norte",
    "A - Salida Norte",
    "A - Extremo Oeste",
    "B - Extremo Este",
    "B - Pasillo Central",
    "B - Salida Norte",
    "B - Extremo Oeste",
    "B - Salida Oeste",
    "Patio B-C",
    "C - Extremo Este",
    "C - Pasillo Central",
    "C - Extremo Oeste",
    "C - Salida Oeste",
    "Sendero Oeste B-C",
    "Cafetería",
    "B2 - Extremo Este",
    "B2 - Pasillo Central",
    "B2 - Extremo Oeste",
    "B3 - Extremo Este",
    "B3 - Pasillo Central",
    "B3 - Extremo Oeste",
    "C2 - Extremo Este",
    "C2 - Pasillo Central",
    "C2 - Extremo Oeste",
    "C3 - Extremo Este",
    "C3 - Pasillo Central",
    "C3 - Extremo Oeste",
    "Puente B-C",
    "Puente B-C - Escalera (arriba)",
    "Puente B-C - Escalera (abajo)",
    "B1 - Escalera Este (inicio)",
    "B1 - Escalera Este (descanso a)",
    "B1 - Escalera Este (descanso b)",
    "B2 - Escalera Este (llegada)",
    "B2 - Escalera Este (inicio)",
    "B2 - Escalera Este (descanso a)",
    "B2 - Escalera Este (descanso b)",
    "B3 - Escalera Este (llegada)",
    "B1 - Escalera Oeste (inicio)",
    "B1 - Escalera Oeste (descanso a)",
    "B1 - Escalera Oeste (descanso b)",
    "B2 - Escalera Oeste (llegada)",
    "B2 - Escalera Oeste (inicio)",
    "B2 - Escalera Oeste (descanso a)",
    "B2 - Escalera Oeste (descanso b)",
    "B3 - Escalera Oeste (llegada)",
    "C1 - Escalera Este (inicio)",
    "C1 - Escalera Este (descanso a)",
    "C1 - Escalera Este (descanso b)",
    "C2 - Escalera Este (llegada)",
    "C2 - Escalera Este (inicio)",
    "C2 - Escalera Este (descanso a)",
    "C2 - Escalera Este (descanso b)",
    "C3 - Escalera Este (llegada)",
    "C1 - Escalera Oeste (inicio)",
    "C1 - Escalera Oeste (descanso a)",
    "C1 - Escalera Oeste (descanso b)",
    "C2 - Escalera Oeste (llegada)",
    "C2 - Escalera Oeste (inicio)",
    "C2 - Escalera Oeste (descanso a)",
    "C2 - Escalera Oeste (descanso b)",
    "C3 - Escalera Oeste (llegada)",
]
zonas_seguras = [
    "Plaza Central Rubén Darío",
    "Punto de Reunión Oeste",
]
pasillos = [
    ("A - Entrada Este", "A - Pasillo Central", 12),
    ("A - Pasillo Central", "A - Pasillo Norte", 9),
    ("A - Pasillo Norte", "A - Salida Norte", 8),
    ("A - Pasillo Norte", "A - Extremo Oeste", 12),
    ("A - Salida Norte", "Plaza Central Rubén Darío", 46),
    ("A - Salida Norte", "Cafetería", 29),
    ("A - Extremo Oeste", "B - Extremo Este", 6),
    ("B - Extremo Este", "B - Pasillo Central", 29),
    ("B - Extremo Este", "B1 - Escalera Este (inicio)", 7),
    ("B - Pasillo Central", "B - Salida Norte", 8),
    ("B - Pasillo Central", "B - Extremo Oeste", 29),
    ("B - Pasillo Central", "Patio B-C", 10),
    ("B - Pasillo Central", "B1 - Escalera Este (inicio)", 22),
    ("B - Pasillo Central", "B1 - Escalera Oeste (inicio)", 22),
    ("B - Salida Norte", "Plaza Central Rubén Darío", 36),
    ("B - Extremo Oeste", "B - Salida Oeste", 3),
    ("B - Extremo Oeste", "B1 - Escalera Oeste (inicio)", 7),
    ("B - Salida Oeste", "Punto de Reunión Oeste", 32),
    ("B - Salida Oeste", "Sendero Oeste B-C", 10),
    ("Patio B-C", "C - Pasillo Central", 9),
    ("Patio B-C", "Sendero Oeste B-C", 35),
    ("Patio B-C", "Puente B-C - Escalera (abajo)", 8),
    ("C - Extremo Este", "C - Pasillo Central", 29),
    ("C - Extremo Este", "C1 - Escalera Este (inicio)", 7),
    ("C - Pasillo Central", "C - Extremo Oeste", 29),
    ("C - Pasillo Central", "C1 - Escalera Este (inicio)", 22),
    ("C - Pasillo Central", "C1 - Escalera Oeste (inicio)", 22),
    ("C - Extremo Oeste", "C - Salida Oeste", 4),
    ("C - Extremo Oeste", "C1 - Escalera Oeste (inicio)", 7),
    ("C - Salida Oeste", "Sendero Oeste B-C", 9),
    ("Sendero Oeste B-C", "Punto de Reunión Oeste", 37),
    ("Sendero Oeste B-C", "Puente B-C - Escalera (abajo)", 28),
    ("Cafetería", "Plaza Central Rubén Darío", 25),
    ("B2 - Extremo Este", "B2 - Pasillo Central", 21),
    ("B2 - Extremo Este", "B2 - Escalera Este (llegada)", 4),
    ("B2 - Extremo Este", "B2 - Escalera Este (inicio)", 2),
    ("B2 - Pasillo Central", "B2 - Extremo Oeste", 21),
    ("B2 - Pasillo Central", "Puente B-C", 10),
    ("B2 - Extremo Oeste", "B2 - Escalera Oeste (llegada)", 4),
    ("B2 - Extremo Oeste", "B2 - Escalera Oeste (inicio)", 2),
    ("B3 - Extremo Este", "B3 - Pasillo Central", 21),
    ("B3 - Extremo Este", "B3 - Escalera Este (llegada)", 4),
    ("B3 - Pasillo Central", "B3 - Extremo Oeste", 21),
    ("B3 - Extremo Oeste", "B3 - Escalera Oeste (llegada)", 4),
    ("C2 - Extremo Este", "C2 - Pasillo Central", 21),
    ("C2 - Extremo Este", "C2 - Escalera Este (llegada)", 4),
    ("C2 - Extremo Este", "C2 - Escalera Este (inicio)", 2),
    ("C2 - Pasillo Central", "C2 - Extremo Oeste", 21),
    ("C2 - Pasillo Central", "Puente B-C", 9),
    ("C2 - Extremo Oeste", "C2 - Escalera Oeste (llegada)", 4),
    ("C2 - Extremo Oeste", "C2 - Escalera Oeste (inicio)", 2),
    ("C3 - Extremo Este", "C3 - Pasillo Central", 21),
    ("C3 - Extremo Este", "C3 - Escalera Este (llegada)", 4),
    ("C3 - Pasillo Central", "C3 - Extremo Oeste", 21),
    ("C3 - Extremo Oeste", "C3 - Escalera Oeste (llegada)", 4),
    ("Puente B-C", "Puente B-C - Escalera (arriba)", 2),
    ("Puente B-C - Escalera (arriba)", "Puente B-C - Escalera (abajo)", 10),
    ("B1 - Escalera Este (inicio)", "B1 - Escalera Este (descanso a)", 9),
    ("B1 - Escalera Este (descanso a)", "B1 - Escalera Este (descanso b)", 3),
    ("B1 - Escalera Este (descanso b)", "B2 - Escalera Este (llegada)", 9),
    ("B2 - Escalera Este (inicio)", "B2 - Escalera Este (descanso a)", 9),
    ("B2 - Escalera Este (descanso a)", "B2 - Escalera Este (descanso b)", 3),
    ("B2 - Escalera Este (descanso b)", "B3 - Escalera Este (llegada)", 9),
    ("B1 - Escalera Oeste (inicio)", "B1 - Escalera Oeste (descanso a)", 9),
    ("B1 - Escalera Oeste (descanso a)", "B1 - Escalera Oeste (descanso b)", 3),
    ("B1 - Escalera Oeste (descanso b)", "B2 - Escalera Oeste (llegada)", 9),
    ("B2 - Escalera Oeste (inicio)", "B2 - Escalera Oeste (descanso a)", 9),
    ("B2 - Escalera Oeste (descanso a)", "B2 - Escalera Oeste (descanso b)", 3),
    ("B2 - Escalera Oeste (descanso b)", "B3 - Escalera Oeste (llegada)", 9),
    ("C1 - Escalera Este (inicio)", "C1 - Escalera Este (descanso a)", 9),
    ("C1 - Escalera Este (descanso a)", "C1 - Escalera Este (descanso b)", 3),
    ("C1 - Escalera Este (descanso b)", "C2 - Escalera Este (llegada)", 9),
    ("C2 - Escalera Este (inicio)", "C2 - Escalera Este (descanso a)", 9),
    ("C2 - Escalera Este (descanso a)", "C2 - Escalera Este (descanso b)", 3),
    ("C2 - Escalera Este (descanso b)", "C3 - Escalera Este (llegada)", 9),
    ("C1 - Escalera Oeste (inicio)", "C1 - Escalera Oeste (descanso a)", 9),
    ("C1 - Escalera Oeste (descanso a)", "C1 - Escalera Oeste (descanso b)", 3),
    ("C1 - Escalera Oeste (descanso b)", "C2 - Escalera Oeste (llegada)", 9),
    ("C2 - Escalera Oeste (inicio)", "C2 - Escalera Oeste (descanso a)", 9),
    ("C2 - Escalera Oeste (descanso a)", "C2 - Escalera Oeste (descanso b)", 3),
    ("C2 - Escalera Oeste (descanso b)", "C3 - Escalera Oeste (llegada)", 9),
]

mapa = Graph()
for l in lugares:
    mapa.insertVertex(l)
for z in zonas_seguras:
    mapa.insertVertex(z, segura=True)
for a, b, peso in pasillos:
    mapa.linkDoble(a, b, peso)


def pedir_lugar(pregunta: str) -> str:
    t = input(pregunta).strip()
    if t.isdigit() and 1 <= int(t) <= len(mapa.vertexs):
        return mapa.vertexs[int(t) - 1].city
    return t


def menu():
    while True:
        print("\n========= RutasSeguras UAM =========")
        print("1. Ver lugares del campus")
        print("2. Ver matriz de adyacencia")
        print("3. Ruta más corta entre dos lugares")
        print("4. Modo EMERGENCIA (ir a zona segura)")
        print("0. Salir")
        op = input("Opción: ").strip()

        if op == "1":
            mapa.printLugares()
        elif op == "2":
            mapa.printMatrix()
        elif op == "3":
            o = pedir_lugar("  ¿Dónde estás? (nombre o número, ej. B2 - Pasillo Central) ")
            d = pedir_lugar("  ¿A dónde vas? ")
            mapa.rutaMasCorta(o, d)
        elif op == "4":
            o = pedir_lugar("  ¿Dónde estás? (incluye la planta, ej. C3 - Extremo Este) ")
            mapa.evacuar(o)
        elif op == "0":
            print("¡Hasta luego!")
            break
        else:
            print("  Opción inválida.")


if __name__ == "__main__":
    menu()
