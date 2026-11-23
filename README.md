# RutasSeguras — App Android (Godot 4.5)

Fase 1: **Edificios A, B y C** en 3D (B y C con 3 plantas). La app te lleva a la **zona de seguridad más cercana**
con indicaciones estilo Waze. Estructura de datos: **grafo dirigido y ponderado**.

## Estructura

```
project.godot        Configuración (vertical, renderer Compatibility para Android)
main.tscn            Escena principal
fonts/               Inter (licencia OFL)
scripts/
  vertex.gd          class Vertex  (city, segura, pos, neig)          <- igual que en clase
  graph.gd           class Graph   (insertVertex, link, printMatrix)   <- igual que en clase
                     + linkDoble, dijkstra, rutaMasCorta, evacuar
  campus.gd          Datos: edificios A, B, C (y vecinos K, M, F, G), aulas, puntos por planta,
                     escaleras, zonas seguras y pasillos
  escena3d.gd        Mundo 3D: edificios, árboles, parqueo, zonas seguras, ruta animada, cámara
  main.gd            Interfaz y navegación tipo Waze (indicaciones generadas desde el grafo)
  estilo.gd          Sistema visual: colores, fuente, tarjetas con sombra
  icono.gd           Íconos vectoriales (flechas de giro, escudo, pin...)
  alerta_sismo.gd    Alerta de sismos (feed público USGS) y simulacro
tests/captura.*      Prueba automática: recorre todas las pantallas y guarda capturas
tests/auditoria.*    Auditoría: grafo, rutas que atraviesan paredes/aulas, evacuación desde cada punto
tests/sismo.*        Prueba del modo sismo (lector del feed, simulacro, evacuación automática)
tests/primera.*      Capturas de la navegación en primera persona
tests/rutas.*        Lista la ruta de evacuación desde cada punto (para revisarlas a mano)
```

## Cómo usa el grafo

| Concepto del grafo | En la app |
|---|---|
| Vértice | Punto del campus (entrada, pasillo, salida, zona segura) |
| Arista (peso) | Pasillo y su distancia en metros |
| `linkDoble` | Un pasillo se camina en ambos sentidos = 2 aristas dirigidas |
| Dijkstra | Ruta más corta desde donde estás |
| `evacuar` | Dijkstra y elegir el vértice `segura = true` con menor distancia |
| Plantas | Cada planta de B y C tiene sus vértices (B2 - Pasillo Central, C3 - Extremo Sur…) |
| Escaleras | Cada cambio de planta = tramo + descanso + tramo (aristas inclinadas, peso ×1.5). En la app se agrupan en una sola instrucción: "Baja las escaleras hasta la planta baja" |
| Puente B-C | Vértice en planta 2 entre B2 y C2, con su escalera al Patio B-C |
| Regla de evacuación (grafo **dirigido**) | En una evacuación se prohíben las aristas *afuera → adentro* (no vuelves a entrar a un edificio) y *edificio X → edificio Y* (no cruzas a otro edificio). Las de *adentro → afuera* sí se permiten. Dijkstra recibe esta regla como parámetro |
| Pasillo bloqueado | Dijkstra ignora esa arista y recalcula |
| Indicaciones Waze | En cada vértice de la ruta se compara la arista que llega con la que sale (ángulo y lado) para decir "gira a la izquierda/derecha" o "sigue recto" |

`printMatrix()` imprime la matriz de adyacencia en la consola de Godot al abrir la app.

## Pantallas

0. **Bienvenida** (solo la primera vez), ícono propio y splash de arranque.
1. **Inicio**: mapa 3D, tarjeta "¿Dónde estás? / ¿A dónde vas?", reporte de pasillo bloqueado,
   tarjetas de **zonas seguras cercanas** (ordenadas con Dijkstra) y botón **EMERGENCIA**.
   Puedes **tocar el mapa** para marcar dónde estás, o tocar una zona segura para ver la ruta.
2. **Vista previa** (compacta): tiempo, distancia, destino y **Vamos**; los pasos se despliegan con "Ver pasos".
   **Escaleras**: cajas de escalera 3D reales (escalones, descanso, barandas) en los extremos de B y C,
al costado del pasillo para que el paso quede libre. **Puente B-C** en planta 2 con escalera al patio.
Al bajar, la ruta va sobre los escalones, la cámara se acerca y un indicador lateral (3 · 2 · PB)
muestra en qué planta vas.

**Vista interior**: si estás dentro de un edificio (o la ruta pasa por él), se "corta" a la altura
   de tu planta: sin techo, con aulas y pasillos visibles, para que nunca aparezcas sobre el techo.
3. **Navegación**: banner con la maniobra ("17 m - Gira levemente a la izquierda"), chip "Luego",
   marcadores 3D en cada giro, barra de progreso, vibración y voz. Los techos se ocultan para ver la ruta
   dentro del edificio. En emergencia los bordes de la pantalla laten en rojo.
   El botón ⚠ reporta un pasillo bloqueado: la app dice "Recalculando" y busca otra ruta en el grafo
   (decide si te conviene seguir o dar la vuelta).
4. **Llegada**: "Estás a salvo" e instrucciones de seguridad.

## Primera persona

Durante la navegación, el botón de la persona cambia a **vista en primera persona**: cámara a la altura
de los ojos (1,6 m) caminando por la ruta. Las puertas son aberturas reales en los muros, los pasillos
tienen techo (la losa del piso de arriba) y la ruta va pegada al piso. En las escaleras la cámara se
eleva un poco detrás de ti para que veas los tramos, y al salir vuelve a primera persona.
El botón del mapa regresa a la vista normal.

## Alerta de sismo

- La app consulta cada minuto el feed público del **USGS** (sismos confirmados, sin clave).
  Si hay un sismo de magnitud ≥ 4 a 150 km o menos de la UAM en los últimos 15 minutos, se abre sola:
  "ALERTA DE SISMO · Agáchate, cúbrete, sujétate". Tras 15 s (o al tocar "Ya paró") te guía
  automáticamente a la zona segura más cercana. Si no has marcado dónde estás, te lo pide y arranca al marcarlo.
- Botón **Simulacro** para practicar y para la demostración.
- Las alertas tempranas de Google (Android Earthquake Alerts) son del sistema operativo y no tienen API
  para apps: deben dejarse activadas en el teléfono; esta app las complementa guiándote a la salida.

## Auditoría automática

`godot --headless --path . res://tests/auditoria.tscn` revisa: aristas en ambos sentidos, grafo conectado,
ninguna arista atraviesa paredes (solo por puertas), aulas ni edificios vecinos, evacuación completa desde
cada punto, recálculo con pasillo bloqueado a mitad de camino, todas las rutas entre puntos y calidad de
las indicaciones, que ninguna evacuación vuelva a entrar a un edificio ni cruce a otro, y que la ruta dibujada (con sus curvas) solo cruce muros por el hueco de una puerta.
Resultado actual: **0 errores** (29 evacuaciones, 29 recálculos, 812 rutas, 0 curvas que crucen paredes).

## Voz (como Waze)

Usa la voz del sistema (Text-to-Speech) en español:
- Al iniciar: "Emergencia. Te llevo a la zona segura más cercana: Plaza Central Rubén Darío. Son 63 metros."
- Al empezar cada tramo: "Camina 17 metros hacia Salida Oeste del edificio A. Luego, gira levemente a la izquierda."
- Al llegar al giro: "Gira a la derecha ahora."
- Si se bloquea un pasillo: "Pasillo cerrado. Recalculando ruta."
- Al llegar: "Llegaste a Plaza Central Rubén Darío. Estás en una zona segura…"

Funciona en Android, iOS, Windows y macOS. El botón del altavoz la silencia.
En Android, si no habla: Ajustes → Accesibilidad → Salida de texto a voz → instala/elige español.

## Probar

1. Instala **Godot 4.5** y abre `project.godot`.
2. Pulsa **F5**. En la PC, arrastra con el mouse para girar y usa la rueda para el zoom.

## Instalar en Android

1. En Godot: **Editor → Manage Export Templates → Download**.
2. Instala **JDK 17** y el **Android SDK** (se puede con Android Studio). Luego, en
   **Editor → Editor Settings → Export → Android**, pon las rutas de ambos.
3. **Project → Export**: ya viene el preset **Android** (`export_presets.cfg`, con permiso de vibración).
   Pulsa **Export Project** para generar el `.apk`.
4. Otra opción: activa la *depuración USB* en el teléfono y usa el botón de Android
   (arriba a la derecha) para instalarla directo.

## Pendiente / siguiente fase

- Medir en sitio las distancias y posiciones reales: están estimadas a partir del mapa
  oficial y se cambian en `campus.gd`.
- Agregar los demás edificios (C, D, K, M…) y zonas seguras (Cancha de fútbol, Parqueo N).
- Ubicación real del usuario (por ejemplo, un código QR en cada pasillo).

## Ubicación por GPS (nuevo)
- En el celular, la app te ubica sola con el GPS (permiso de ubicación). Lee el GPS desde GDScript con `JavaClassWrapper` + `AndroidRuntime` (Godot 4.7), sin plugins.
- `scripts/geo.gd` convierte latitud/longitud a metros del mapa. `scripts/gps.gd` lee el GPS.
- Si estás dentro de A, B o C, la app pregunta **en qué planta estás** (el GPS no distingue pisos). Tu posición se "pega" a la arista más cercana del grafo en ese piso y desde ahí corre Dijkstra.
- Navegación real: la ruta avanza contigo; si te sales más de ~14 m durante 4 s, recalcula. En las escaleras se toca **"Ya estoy en planta X"** (o se detecta cuando te alejas de la escalera siguiendo la ruta).
- **Calibrar una vez en el campus**: chip de GPS (arriba) → "Calibrar GPS en el campus" → párate en un punto conocido, tócalo en el mapa, camina a otro punto a más de 40 m y tócalo. Los valores quedan copiados para pegarlos en `geo.gd` (LAT0, LON0, giro, escala).
- En PC no hay GPS: se marca la ubicación tocando el mapa (sirve para presentar).
- La cafetería (edificio K) ya es un destino.

## Versión en Python
`python/rutasseguras.py`: la misma estructura de clase (Vertex: city, neig; Graph: vertexs, insertVertex, link, printMatrix) con los mismos lugares y distancias que la app. Ejecutar: `python rutasseguras.py`.

## Requisitos
Godot **4.7** (Compatibility). Pruebas: `tests/auditoria.tscn` (grafo y rutas), `tests/gps.tscn` (simula caminar con GPS).
