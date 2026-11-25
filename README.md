# RutasSeguras — App Android (Godot 4.7)

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
  campus.gd          Datos: edificios A, B, C (y vecinos K, E, F, G, M, H, J, D, N), aulas, puntos por planta,
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
| Plantas | Cada planta de B y C tiene sus vértices (B2 - Pasillo Central, C3 - Extremo Oeste…) |
| Escaleras | Cada cambio de planta = tramo + descanso + tramo (aristas inclinadas, peso ×1.5). En la app se agrupan en una sola instrucción: "Baja las escaleras hasta la planta baja" |
| Puente B-C | Vértice en planta 2 entre B2 y C2, con su escalera al Patio B-C |
| Regla de evacuación (grafo **dirigido**) | En una evacuación se prohíben las aristas *afuera → adentro* (no vuelves a entrar a un edificio) y *edificio X → edificio Y* (no cruzas a otro edificio). Las de *adentro → afuera* sí se permiten. Dijkstra recibe esta regla como parámetro |
| Pasillo bloqueado | Dijkstra ignora esa arista y recalcula |
| Indicaciones Waze | En cada vértice de la ruta se compara la arista que llega con la que sale (ángulo y lado) para decir "gira a la izquierda/derecha" o "sigue recto" |

`printMatrix()` imprime la matriz de adyacencia en la consola de Godot al abrir la app.

## Zonas seguras (del cartel oficial)

| Zona | Dónde | Camino |
|---|---|---|
| Plaza Central Rubén Darío | Entre K, B y E | Salidas norte de A y B, y la cafetería |
| Punto de Reunión Oeste | Entre F, G y M | Paso entre G y M, desde la salida oeste de B y el sendero B-C |
| Cancha de Fútbol | Al oeste del campus | Sigue desde el paso G-M |
| Zona Segura Parqueo N | Entre N y el edificio Copérnico | Calle frente a A, esquina de J y calle este de N |

Los edificios vecinos (K, E, F, G, M, H, J, D y N) salen de OpenStreetMap y del cartel; ninguna ruta los atraviesa.

## Pantallas

0. **Bienvenida** en dos pasos con ilustración del campus y un ejemplo de selección de piso.
   En Android ofrece activar la ubicación precisa o abrir el mapa y habilitarla después desde el indicador de GPS.
1. **Inicio**: mapa 3D, tarjeta de ubicación y destino, reporte de pasillo bloqueado,
   tarjetas de **zonas seguras cercanas** (ordenadas con Dijkstra) y botón **EMERGENCIA**.
   En Android el GPS fija tu ubicación. Toca una zona segura para ver la ruta. En PC
   puedes indicar el origen en el mapa para probar la navegación.
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
  Si hay un sismo de magnitud ≥ 4 a 150 km o menos de la UAM en los últimos 30 minutos, se abre sola
  (el USGS puede tardar 10-20 min en publicar sismos fuera de EE. UU.):
  "ALERTA DE SISMO · Agáchate, cúbrete, sujétate". Tras 15 s (o al tocar "Ya paró") te guía
  automáticamente a la zona segura más cercana. En Android usa el GPS (en emergencia acepta hasta ±40 m)
  y, si en 10 s no logra ubicarte, te pide tocar en el mapa dónde estás.
- Botón **Simulacro** para practicar y para la demostración.
- Las alertas tempranas de Google (Android Earthquake Alerts) son del sistema operativo y no tienen API
  para apps: deben dejarse activadas en el teléfono; esta app las complementa guiándote a la salida.

## Pruebas automáticas

Todas de una vez (PowerShell): `.	ests\probar_todo.ps1 -Godot "C:
uta\Godot_v4.7.2-stable_win64_console.exe"`.
Corre la auditoría, la prueba de GPS y la de sismo sin ventana y sale con código 1 si alguna falla.
Las de capturas (`captura`, `primera`, `rapida`) funcionan sin argumentos; con un prefijo guardan imágenes.

## Auditoría automática

`godot --headless --path . res://tests/auditoria.tscn` revisa: aristas en ambos sentidos, grafo conectado,
ninguna arista atraviesa paredes (solo por puertas), aulas ni edificios vecinos, evacuación completa desde
cada punto, recálculo con pasillo bloqueado a mitad de camino, todas las rutas entre puntos y calidad de
las indicaciones, que ninguna evacuación vuelva a entrar a un edificio ni cruce a otro, y que la ruta dibujada (con sus curvas) solo cruce muros por el hueco de una puerta.
Resultado actual: **0 errores** (36 evacuaciones, 36 recálculos, 1260 rutas, 0 curvas que crucen paredes).
Tarda unos 5 minutos.

## Voz (como Waze)

Usa la voz del sistema (Text-to-Speech) en español:
- Al iniciar: "Emergencia. Te llevo a la zona segura más cercana: Plaza Central Rubén Darío. Son 63 metros."
- Al empezar cada tramo: "Camina 17 metros hacia Salida Norte del edificio A. Luego, gira levemente a la izquierda."
- Al llegar al giro: "Gira a la derecha ahora."
- Si se bloquea un pasillo: "Pasillo cerrado. Recalculando ruta."
- Al llegar: "Llegaste a Plaza Central Rubén Darío. Estás en una zona segura…"

Funciona en Android, iOS, Windows y macOS. El botón del altavoz la silencia.
En Android, si no habla: Ajustes → Accesibilidad → Salida de texto a voz → instala/elige español.

## Probar

1. Instala **Godot 4.7** y abre `project.godot`.
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

- Medir en sitio las distancias reales: A (~11 m de fondo) y B y C (~73 m) salen de OpenStreetMap;
  se ajustan en `campus.gd`.
- Mapear por dentro los edificios vecinos (hoy son solo contexto visual) y confirmar en sitio los caminos
  exteriores nuevos: el paso entre G y M y la calle frente a A hacia el parqueo de N.

## Ubicación por GPS
- En Android, concede **ubicación precisa** mientras usas la app. La app lee las coordenadas del teléfono con `LocationManager` desde GDScript, mediante `JavaClassWrapper` y `AndroidRuntime`.
- `scripts/geo.gd` convierte latitud/longitud a metros del mapa. `scripts/gps.gd` lee el GPS.
- **Orientación**: el cartel oficial (y el mapa de la app) tiene el **este arriba**: x = sur, z = oeste. `geo.gd` aplica ese giro de -90° y su origen sale de OpenStreetMap, donde A, B y C miden 88 × 31 m (en la app, 90 × 30 m). Las calibraciones guardadas con la versión anterior se descartan.
- La app deduce el edificio y pide **en qué piso estás**. Afuera calcula el origen automáticamente. Dijkstra parte de la arista más cercana en el piso correspondiente. El edificio A solo tiene planta baja mapeada, así que la app informa si eliges su segundo piso.
- Si falta señal, la lectura tiene un margen de error superior a 20 m (40 m en una emergencia) o estás fuera del campus, la app espera otra ubicación. Durante la navegación, el GPS hace avanzar la ruta y permite recalcular si te desvías. Al cambiar de piso, toca **"Ya estoy en planta X"**; como respaldo, si pasó el tiempo de bajar esos pisos y el GPS te ve siguiendo la ruta lejos de la escalera, avanza solo.
- **Plan B sin GPS**: mientras el GPS no da una ubicación útil, puedes tocar el mapa o elegir tu lugar en la lista (en B y C te pregunta el piso). Una lectura mala no borra esa ubicación; en cuanto el GPS da una buena, vuelve a mandar. En una emergencia sin ubicación, a los 10 s la app te pide marcarla a mano.
- **Pisos sin mapear** (por ahora, la planta 2 de A): la ruta parte de la planta baja y la app dice "Baja por la escalera más cercana a la planta baja".
- **Permiso negado**: si negaste la ubicación, el botón abre los ajustes de la app (Android ya no vuelve a mostrar el diálogo).
- Las coordenadas base del mapa son aproximadas. Para ajustar el mapa en el campus, abre el chip de GPS → "Calibrar GPS en el campus". Párate en un punto conocido y tócalo en el mapa. Repite en otro punto a más de 40 m. La app guarda el ajuste en el dispositivo.
- En PC no hay GPS: se marca la ubicación tocando el mapa (sirve para presentar).
- La cafetería (edificio K) ya es un destino.

## Versión en Python
`python/rutasseguras.py`: la misma estructura de clase (Vertex: city, neig; Graph: vertexs, insertVertex, link, printMatrix) con los mismos lugares y distancias que la app. Ejecutar: `python rutasseguras.py`.

La ruta más corta se busca **probando caminos** (`explorar`): desde cada lugar se prueba ir a cada vecino sin repetir lugares; al llegar a la meta se guarda el camino si es el más corto hasta ahora, y un camino que ya es más largo que el mejor se deja de probar. En una evacuación la meta es cualquier zona segura y se respetan las reglas (no volver a entrar, no cruzar a otro edificio). Da las mismas distancias que la app.

Si cambias `campus.gd`, regenera las listas con `godot --headless --path . -s res://tests/exportar_python.gd` (crea `tests/_datos_python.txt` para copiarlas).

## Requisitos
Godot **4.7** (Compatibility). Pruebas: `tests/auditoria.tscn` (grafo y rutas), `tests/gps.tscn` (simula caminar con GPS).
