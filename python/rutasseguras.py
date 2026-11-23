# ==========================================================
#  RutasSeguras - Versión en Python (consola)
#  Estructura de Datos: GRAFO DIRIGIDO Y PONDERADO
#  Misma estructura vista en clase: Vertex (city, neig) y
#  Graph (vertexs, insertVertex, link, printMatrix).
#  Vértices = lugares del campus UAM (edificios A, B y C con sus
#  plantas, escaleras, puente B-C, cafetería y zonas seguras).
#  Pesos = distancia en metros (en escaleras x1.5).
#  Son los MISMOS datos que usa la app de Godot.
# ==========================================================

class Vertex:
    def __init__(self, city: str, segura: bool = False):
        self.city = city          # nombre del lugar del campus
        self.segura = segura      # True si es zona segura de evacuación
        self.neig = []            # lista de (Vertex, peso)


class Graph:
    def __init__(self):
        self.vertexs: list[Vertex] = []

    # ---------- Métodos vistos en clase ----------
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

        # Imprimir encabezados.
        print(f"{'':{ancho}}", end="")
        for v in ciudades:
            print(f"{v.city[:ancho-1]:{ancho}}", end="")
        print()

        # Imprimir matriz.
        for i in range(n):
            print(f"{ciudades[i].city[:ancho-1]:{ancho}}", end="")
            for peso in matriz[i]:
                print(f"{peso:<{ancho}g}", end="")
            print()

    # ---------- Métodos nuevos del proyecto ----------
    def buscar(self, city: str):
        for v in self.vertexs:
            if v.city.lower() == city.lower():
                return v
        return None

    def linkDoble(self, a: str, b: str, peso: float) -> bool:
        # Los pasillos se pueden caminar en ambos sentidos.
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
            # Elegir el no visitado con menor distancia.
            actual = None
            for v in self.vertexs:
                if not visitado[v] and (actual is None or dist[v] < dist[actual]):
                    actual = v
            if actual is None or dist[actual] == INF:
                break
            visitado[actual] = True

            # Relajar aristas.
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
        # Regla de evacuación: no volver a entrar a un edificio ni cruzar a otro
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


# ==========================================================
#  Zonas: ¿en qué edificio está un lugar? ("" = afuera)
#  "B2 - Pasillo Central" -> "B";  "Patio B-C" -> ""
# ==========================================================
def zona(v: Vertex) -> str:
    nombre = v.city
    if "Salida" in nombre:
        return ""
    if len(nombre) > 1 and nombre[0] in "ABC" and (nombre[1] == " " or nombre[1].isdigit()):
        return nombre[0]
    return ""


def permitido_evacuar(a: Vertex, b: Vertex) -> bool:
    # Una vez afuera no se vuelve a entrar; no se cruza de un edificio a otro.
    za, zb = zona(a), zona(b)
    if za == "" and zb != "":
        return False
    if za != "" and zb != "" and za != zb:
        return False
    return True


# ==========================================================
#  Mapa del campus UAM (generado desde la app de Godot)
# ==========================================================
lugares = [
    "A - Entrada Norte",
    "A - Pasillo Central",
    "A - Pasillo Oeste",
    "A - Salida Oeste",
    "A - Extremo Sur",
    "B - Extremo Norte",
    "B - Pasillo Central",
    "B - Salida Oeste",
    "B - Extremo Sur",
    "B - Salida Sur",
    "Patio B-C",
    "C - Extremo Norte",
    "C - Pasillo Central",
    "C - Extremo Sur",
    "C - Salida Sur",
    "Sendero Sur B-C",
    "Cafetería",
    "B2 - Extremo Norte",
    "B2 - Pasillo Central",
    "B2 - Extremo Sur",
    "B3 - Extremo Norte",
    "B3 - Pasillo Central",
    "B3 - Extremo Sur",
    "C2 - Extremo Norte",
    "C2 - Pasillo Central",
    "C2 - Extremo Sur",
    "C3 - Extremo Norte",
    "C3 - Pasillo Central",
    "C3 - Extremo Sur",
    "Puente B-C",
    "Puente B-C - Escalera (arriba)",
    "Puente B-C - Escalera (abajo)",
    "B1 - Escalera Norte (inicio)",
    "B1 - Escalera Norte (descanso a)",
    "B1 - Escalera Norte (descanso b)",
    "B2 - Escalera Norte (llegada)",
    "B2 - Escalera Norte (inicio)",
    "B2 - Escalera Norte (descanso a)",
    "B2 - Escalera Norte (descanso b)",
    "B3 - Escalera Norte (llegada)",
    "B1 - Escalera Sur (inicio)",
    "B1 - Escalera Sur (descanso a)",
    "B1 - Escalera Sur (descanso b)",
    "B2 - Escalera Sur (llegada)",
    "B2 - Escalera Sur (inicio)",
    "B2 - Escalera Sur (descanso a)",
    "B2 - Escalera Sur (descanso b)",
    "B3 - Escalera Sur (llegada)",
    "C1 - Escalera Norte (inicio)",
    "C1 - Escalera Norte (descanso a)",
    "C1 - Escalera Norte (descanso b)",
    "C2 - Escalera Norte (llegada)",
    "C2 - Escalera Norte (inicio)",
    "C2 - Escalera Norte (descanso a)",
    "C2 - Escalera Norte (descanso b)",
    "C3 - Escalera Norte (llegada)",
    "C1 - Escalera Sur (inicio)",
    "C1 - Escalera Sur (descanso a)",
    "C1 - Escalera Sur (descanso b)",
    "C2 - Escalera Sur (llegada)",
    "C2 - Escalera Sur (inicio)",
    "C2 - Escalera Sur (descanso a)",
    "C2 - Escalera Sur (descanso b)",
    "C3 - Escalera Sur (llegada)",
]
zonas_seguras = [
    "Plaza Central Rubén Darío",
    "Punto de Reunión Sur",
]
pasillos = [
    ("A - Entrada Norte", "A - Pasillo Central", 12),
    ("A - Pasillo Central", "A - Pasillo Oeste", 9),
    ("A - Pasillo Oeste", "A - Salida Oeste", 8),
    ("A - Pasillo Oeste", "A - Extremo Sur", 12),
    ("A - Salida Oeste", "Plaza Central Rubén Darío", 46),
    ("A - Salida Oeste", "Cafetería", 29),
    ("A - Extremo Sur", "B - Extremo Norte", 6),
    ("B - Extremo Norte", "B - Pasillo Central", 29),
    ("B - Extremo Norte", "B1 - Escalera Norte (inicio)", 7),
    ("B - Pasillo Central", "B - Salida Oeste", 8),
    ("B - Pasillo Central", "B - Extremo Sur", 29),
    ("B - Pasillo Central", "Patio B-C", 10),
    ("B - Pasillo Central", "B1 - Escalera Norte (inicio)", 22),
    ("B - Pasillo Central", "B1 - Escalera Sur (inicio)", 22),
    ("B - Salida Oeste", "Plaza Central Rubén Darío", 36),
    ("B - Extremo Sur", "B - Salida Sur", 3),
    ("B - Extremo Sur", "B1 - Escalera Sur (inicio)", 7),
    ("B - Salida Sur", "Punto de Reunión Sur", 32),
    ("B - Salida Sur", "Sendero Sur B-C", 10),
    ("Patio B-C", "C - Pasillo Central", 9),
    ("Patio B-C", "Sendero Sur B-C", 35),
    ("Patio B-C", "Puente B-C - Escalera (abajo)", 8),
    ("C - Extremo Norte", "C - Pasillo Central", 29),
    ("C - Extremo Norte", "C1 - Escalera Norte (inicio)", 7),
    ("C - Pasillo Central", "C - Extremo Sur", 29),
    ("C - Pasillo Central", "C1 - Escalera Norte (inicio)", 22),
    ("C - Pasillo Central", "C1 - Escalera Sur (inicio)", 22),
    ("C - Extremo Sur", "C - Salida Sur", 4),
    ("C - Extremo Sur", "C1 - Escalera Sur (inicio)", 7),
    ("C - Salida Sur", "Sendero Sur B-C", 9),
    ("Sendero Sur B-C", "Punto de Reunión Sur", 37),
    ("Sendero Sur B-C", "Puente B-C - Escalera (abajo)", 28),
    ("Cafetería", "Plaza Central Rubén Darío", 25),
    ("B2 - Extremo Norte", "B2 - Pasillo Central", 21),
    ("B2 - Extremo Norte", "B2 - Escalera Norte (llegada)", 4),
    ("B2 - Extremo Norte", "B2 - Escalera Norte (inicio)", 2),
    ("B2 - Pasillo Central", "B2 - Extremo Sur", 21),
    ("B2 - Pasillo Central", "Puente B-C", 10),
    ("B2 - Extremo Sur", "B2 - Escalera Sur (llegada)", 4),
    ("B2 - Extremo Sur", "B2 - Escalera Sur (inicio)", 2),
    ("B3 - Extremo Norte", "B3 - Pasillo Central", 21),
    ("B3 - Extremo Norte", "B3 - Escalera Norte (llegada)", 4),
    ("B3 - Pasillo Central", "B3 - Extremo Sur", 21),
    ("B3 - Extremo Sur", "B3 - Escalera Sur (llegada)", 4),
    ("C2 - Extremo Norte", "C2 - Pasillo Central", 21),
    ("C2 - Extremo Norte", "C2 - Escalera Norte (llegada)", 4),
    ("C2 - Extremo Norte", "C2 - Escalera Norte (inicio)", 2),
    ("C2 - Pasillo Central", "C2 - Extremo Sur", 21),
    ("C2 - Pasillo Central", "Puente B-C", 9),
    ("C2 - Extremo Sur", "C2 - Escalera Sur (llegada)", 4),
    ("C2 - Extremo Sur", "C2 - Escalera Sur (inicio)", 2),
    ("C3 - Extremo Norte", "C3 - Pasillo Central", 21),
    ("C3 - Extremo Norte", "C3 - Escalera Norte (llegada)", 4),
    ("C3 - Pasillo Central", "C3 - Extremo Sur", 21),
    ("C3 - Extremo Sur", "C3 - Escalera Sur (llegada)", 4),
    ("Puente B-C", "Puente B-C - Escalera (arriba)", 2),
    ("Puente B-C - Escalera (arriba)", "Puente B-C - Escalera (abajo)", 10),
    ("B1 - Escalera Norte (inicio)", "B1 - Escalera Norte (descanso a)", 9),
    ("B1 - Escalera Norte (descanso a)", "B1 - Escalera Norte (descanso b)", 3),
    ("B1 - Escalera Norte (descanso b)", "B2 - Escalera Norte (llegada)", 9),
    ("B2 - Escalera Norte (inicio)", "B2 - Escalera Norte (descanso a)", 9),
    ("B2 - Escalera Norte (descanso a)", "B2 - Escalera Norte (descanso b)", 3),
    ("B2 - Escalera Norte (descanso b)", "B3 - Escalera Norte (llegada)", 9),
    ("B1 - Escalera Sur (inicio)", "B1 - Escalera Sur (descanso a)", 9),
    ("B1 - Escalera Sur (descanso a)", "B1 - Escalera Sur (descanso b)", 3),
    ("B1 - Escalera Sur (descanso b)", "B2 - Escalera Sur (llegada)", 9),
    ("B2 - Escalera Sur (inicio)", "B2 - Escalera Sur (descanso a)", 9),
    ("B2 - Escalera Sur (descanso a)", "B2 - Escalera Sur (descanso b)", 3),
    ("B2 - Escalera Sur (descanso b)", "B3 - Escalera Sur (llegada)", 9),
    ("C1 - Escalera Norte (inicio)", "C1 - Escalera Norte (descanso a)", 9),
    ("C1 - Escalera Norte (descanso a)", "C1 - Escalera Norte (descanso b)", 3),
    ("C1 - Escalera Norte (descanso b)", "C2 - Escalera Norte (llegada)", 9),
    ("C2 - Escalera Norte (inicio)", "C2 - Escalera Norte (descanso a)", 9),
    ("C2 - Escalera Norte (descanso a)", "C2 - Escalera Norte (descanso b)", 3),
    ("C2 - Escalera Norte (descanso b)", "C3 - Escalera Norte (llegada)", 9),
    ("C1 - Escalera Sur (inicio)", "C1 - Escalera Sur (descanso a)", 9),
    ("C1 - Escalera Sur (descanso a)", "C1 - Escalera Sur (descanso b)", 3),
    ("C1 - Escalera Sur (descanso b)", "C2 - Escalera Sur (llegada)", 9),
    ("C2 - Escalera Sur (inicio)", "C2 - Escalera Sur (descanso a)", 9),
    ("C2 - Escalera Sur (descanso a)", "C2 - Escalera Sur (descanso b)", 3),
    ("C2 - Escalera Sur (descanso b)", "C3 - Escalera Sur (llegada)", 9),
]

mapa = Graph()
for l in lugares:
    mapa.insertVertex(l)
for z in zonas_seguras:
    mapa.insertVertex(z, segura=True)
for a, b, peso in pasillos:
    mapa.linkDoble(a, b, peso)


# ==========================================================
#  Menú
# ==========================================================
def pedir_lugar(pregunta: str) -> str:
    # Se puede escribir el nombre o el número de la lista (opción 1)
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
            o = pedir_lugar("  ¿Dónde estás? (incluye la planta, ej. C3 - Extremo Norte) ")
            mapa.evacuar(o)
        elif op == "0":
            print("¡Hasta luego!")
            break
        else:
            print("  Opción inválida.")


if __name__ == "__main__":
    menu()
