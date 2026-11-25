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
        ciudades = []

        for v in self.vertexs:
            if v.neig and v not in ciudades:
                ciudades.append(v)

            for vecino, peso in v.neig:
                if vecino not in ciudades:
                    ciudades.append(vecino)

        n = len(ciudades)
        matriz = [[0] * n for _ in range(n)]

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

    def explorar(self, actual: Vertex, meta, camino: list, distancia: float, evacuando: bool) -> None:
        if self.mejor_distancia != -1 and distancia >= self.mejor_distancia:
            return

        llegamos = actual.segura if evacuando else actual is meta
        if llegamos:
            self.mejor_camino = camino.copy()
            self.mejor_distancia = distancia
            return

        for vecino, peso in actual.neig:
            if vecino in camino:
                continue
            if evacuando and not permitido_evacuar(actual, vecino):
                continue
            camino.append(vecino)
            self.explorar(vecino, meta, camino, distancia + peso, evacuando)
            camino.pop()

    def buscarCamino(self, origen: str, destino: str, evacuando: bool) -> bool:
        inicio = self.buscar(origen)
        meta = self.buscar(destino) if not evacuando else None
        if inicio is None or (not evacuando and meta is None):
            print("  Lugar no encontrado.")
            return False
        self.mejor_camino = []
        self.mejor_distancia = -1
        self.explorar(inicio, meta, [inicio], 0, evacuando)
        if self.mejor_distancia == -1:
            print("  No hay ruta disponible.")
            return False
        return True

    def rutaMasCorta(self, origen: str, destino: str) -> None:
        if not self.buscarCamino(origen, destino, False):
            return
        nombres = [v.city for v in self.mejor_camino]
        print("  Ruta: " + " -> ".join(nombres))
        print(f"  Distancia total: {self.mejor_distancia:g} m")

    def evacuar(self, origen: str) -> None:
        if not self.buscarCamino(origen, "", True):
            return
        zona_segura = self.mejor_camino[-1]
        nombres = [v.city for v in self.mejor_camino]
        print(f"  ¡EVACUACIÓN! Zona segura más cercana: {zona_segura.city}")
        print("  Ruta: " + " -> ".join(nombres))
        print(f"  Distancia: {self.mejor_distancia:g} m")


def zona(v: Vertex) -> str:
    nombre = v.city
    if "Salida" in nombre:
        return ""
    if len(nombre) > 1 and nombre[0] in "ABC" and (nombre[1] == " " or nombre[1].isdigit()):
        return nombre[0]
    return ""


def permitido_evacuar(a: Vertex, b: Vertex) -> bool:
    za = zona(a)
    zb = zona(b)
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
    "Paso G-M",
    "Paso G-M Oeste",
    "Frente Edificio A",
    "Esquina Noreste de A",
    "Esquina J",
    "Calle Este de N",
    "Entrada Parqueo N",
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
    "Cancha de Fútbol",
    "Zona Segura Parqueo N",
]
pasillos = [
    ("A - Entrada Este", "A - Pasillo Central", 8),
    ("A - Entrada Este", "Frente Edificio A", 7),
    ("A - Pasillo Central", "A - Pasillo Norte", 9),
    ("A - Pasillo Norte", "A - Salida Norte", 8),
    ("A - Pasillo Norte", "B - Extremo Este", 7),
    ("A - Salida Norte", "Esquina Noreste de A", 16),
    ("A - Salida Norte", "Cafetería", 24),
    ("B - Extremo Este", "B - Pasillo Central", 36),
    ("B - Extremo Este", "B1 - Escalera Este (inicio)", 7),
    ("B - Pasillo Central", "B - Salida Norte", 8),
    ("B - Pasillo Central", "B - Extremo Oeste", 36),
    ("B - Pasillo Central", "Patio B-C", 10),
    ("B - Pasillo Central", "B1 - Escalera Este (inicio)", 29),
    ("B - Pasillo Central", "B1 - Escalera Oeste (inicio)", 29),
    ("B - Salida Norte", "Plaza Central Rubén Darío", 24),
    ("B - Extremo Oeste", "B - Salida Oeste", 3),
    ("B - Extremo Oeste", "B1 - Escalera Oeste (inicio)", 7),
    ("B - Salida Oeste", "Paso G-M", 9),
    ("B - Salida Oeste", "Sendero Oeste B-C", 10),
    ("Patio B-C", "C - Pasillo Central", 9),
    ("Patio B-C", "Sendero Oeste B-C", 42),
    ("Patio B-C", "Puente B-C - Escalera (abajo)", 8),
    ("C - Extremo Este", "C - Pasillo Central", 36),
    ("C - Extremo Este", "C1 - Escalera Este (inicio)", 7),
    ("C - Pasillo Central", "C - Extremo Oeste", 36),
    ("C - Pasillo Central", "C1 - Escalera Este (inicio)", 29),
    ("C - Pasillo Central", "C1 - Escalera Oeste (inicio)", 29),
    ("C - Extremo Oeste", "C - Salida Oeste", 4),
    ("C - Extremo Oeste", "C1 - Escalera Oeste (inicio)", 7),
    ("C - Salida Oeste", "Sendero Oeste B-C", 9),
    ("Sendero Oeste B-C", "Paso G-M", 17),
    ("Sendero Oeste B-C", "Puente B-C - Escalera (abajo)", 34),
    ("Cafetería", "Plaza Central Rubén Darío", 25),
    ("Paso G-M", "Paso G-M Oeste", 17),
    ("Paso G-M Oeste", "Punto de Reunión Oeste", 16),
    ("Paso G-M Oeste", "Cancha de Fútbol", 88),
    ("Frente Edificio A", "Esquina Noreste de A", 21),
    ("Frente Edificio A", "Esquina J", 55),
    ("Esquina J", "Calle Este de N", 21),
    ("Calle Este de N", "Entrada Parqueo N", 30),
    ("Entrada Parqueo N", "Zona Segura Parqueo N", 36),
    ("B2 - Extremo Este", "B2 - Pasillo Central", 28),
    ("B2 - Extremo Este", "B2 - Escalera Este (llegada)", 4),
    ("B2 - Extremo Este", "B2 - Escalera Este (inicio)", 2),
    ("B2 - Pasillo Central", "B2 - Extremo Oeste", 28),
    ("B2 - Pasillo Central", "Puente B-C", 10),
    ("B2 - Extremo Oeste", "B2 - Escalera Oeste (llegada)", 4),
    ("B2 - Extremo Oeste", "B2 - Escalera Oeste (inicio)", 2),
    ("B3 - Extremo Este", "B3 - Pasillo Central", 28),
    ("B3 - Extremo Este", "B3 - Escalera Este (llegada)", 4),
    ("B3 - Pasillo Central", "B3 - Extremo Oeste", 28),
    ("B3 - Extremo Oeste", "B3 - Escalera Oeste (llegada)", 4),
    ("C2 - Extremo Este", "C2 - Pasillo Central", 28),
    ("C2 - Extremo Este", "C2 - Escalera Este (llegada)", 4),
    ("C2 - Extremo Este", "C2 - Escalera Este (inicio)", 2),
    ("C2 - Pasillo Central", "C2 - Extremo Oeste", 28),
    ("C2 - Pasillo Central", "Puente B-C", 9),
    ("C2 - Extremo Oeste", "C2 - Escalera Oeste (llegada)", 4),
    ("C2 - Extremo Oeste", "C2 - Escalera Oeste (inicio)", 2),
    ("C3 - Extremo Este", "C3 - Pasillo Central", 28),
    ("C3 - Extremo Este", "C3 - Escalera Este (llegada)", 4),
    ("C3 - Pasillo Central", "C3 - Extremo Oeste", 28),
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
