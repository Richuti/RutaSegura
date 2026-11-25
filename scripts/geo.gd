# ==========================================================
#  RutasSeguras - Georreferencia
#  Convierte GPS (latitud, longitud) <-> mapa del campus (metros).
#  El mapa de la app copia el cartel oficial de Rutas de Evacuación,
#  que tiene el ESTE arriba: x = sur, z = oeste (A queda al este y
#  B y C se extienden hacia el oeste). Por eso el giro base es -90°.
#  El origen sale de los contornos de OpenStreetMap (A, B y C miden
#  unos 88 x 31 m, igual que en campus.gd). Se afinan en el campus con "Calibrar GPS":
#  te paras en dos lugares conocidos y la app calcula el giro,
#  la escala y el desplazamiento del mapa.
# ==========================================================
class_name Geo
extends RefCounted

const LAT0 := 12.1085553    # GPS del punto (0, 0) del mapa: esquina NE del Edificio A
const LON0 := -86.2565728
const GIRO_BASE := -PI / 2.0  # el "arriba" del mapa es el este
const VERSION_CALIBRACION := 2   # sube si cambian LAT0/LON0/GIRO_BASE (invalida calibraciones viejas)
const M_POR_GRADO_LAT := 110574.0
const CENTRO := Vector2(10, 55)      # centro del campus en el mapa
const RADIO_CAMPUS := 260.0          # más lejos que esto = "fuera de la UAM"

static var giro := GIRO_BASE         # radianes: giro del mapa respecto al norte
static var escala := 1.0
static var desplaz := Vector2.ZERO   # (este, norte) en metros
static var calibrado := false


static func _m_por_grado_lon() -> float:
	return 111320.0 * cos(deg_to_rad(LAT0))


# GPS -> (este, norte) en metros respecto a LAT0 / LON0
static func _enu(lat: float, lon: float) -> Vector2:
	return Vector2((lon - LON0) * _m_por_grado_lon(), (lat - LAT0) * M_POR_GRADO_LAT)


# GPS -> mapa (x, z)
static func a_local(lat: float, lon: float) -> Vector2:
	var p := ((_enu(lat, lon) - desplaz) / escala).rotated(-giro)
	return Vector2(p.x, -p.y)


# Mapa (x, z) -> GPS (lat, lon)
static func a_gps(x: float, z: float) -> Vector2:
	var en := Vector2(x, -z).rotated(giro) * escala + desplaz
	return Vector2(LAT0 + en.y / M_POR_GRADO_LAT, LON0 + en.x / _m_por_grado_lon())


static func en_campus(local: Vector2) -> bool:
	return local.distance_to(CENTRO) <= RADIO_CAMPUS


# Calibración con un punto: solo corrige el desplazamiento
static func calibrar_1(local: Vector2, gps: Vector2) -> void:
	desplaz = _enu(gps.x, gps.y) - Vector2(local.x, -local.y).rotated(giro) * escala
	calibrado = true


# Calibración con dos puntos: corrige giro, escala y desplazamiento.
# Devuelve "" si salió bien o el motivo si no.
static func calibrar_2(l1: Vector2, g1: Vector2, l2: Vector2, g2: Vector2) -> String:
	var u1 := Vector2(l1.x, -l1.y)
	var u2 := Vector2(l2.x, -l2.y)
	var w1 := _enu(g1.x, g1.y)
	var w2 := _enu(g2.x, g2.y)
	var du := u2 - u1
	var dw := w2 - w1
	if du.length() < 40.0:
		return "Los dos puntos están muy cerca en el mapa: elige uno a más de 40 m."
	var s := dw.length() / du.length()
	if s < 0.6 or s > 1.6:
		return "El GPS no coincide con el mapa (señal débil). Repite afuera, con cielo abierto."
	giro = dw.angle() - du.angle()
	escala = s
	desplaz = w1 - u1.rotated(giro) * escala
	calibrado = true
	return ""


static func cargar(cfg: ConfigFile) -> void:
	if cfg.get_value("gps", "version", 1) != VERSION_CALIBRACION:
		reiniciar()   # calibración hecha con el mapa viejo: ya no sirve
		return
	giro = cfg.get_value("gps", "giro", GIRO_BASE)
	escala = cfg.get_value("gps", "escala", 1.0)
	desplaz = cfg.get_value("gps", "desplaz", Vector2.ZERO)
	calibrado = cfg.get_value("gps", "calibrado", false)


static func guardar(cfg: ConfigFile) -> void:
	cfg.set_value("gps", "version", VERSION_CALIBRACION)
	cfg.set_value("gps", "giro", giro)
	cfg.set_value("gps", "escala", escala)
	cfg.set_value("gps", "desplaz", desplaz)
	cfg.set_value("gps", "calibrado", calibrado)


static func reiniciar() -> void:
	giro = GIRO_BASE
	escala = 1.0
	desplaz = Vector2.ZERO
	calibrado = false


# Texto para copiar los valores al código (y que toda la app quede calibrada)
static func texto() -> String:
	var o := a_gps(0, 0)
	return "LAT0 := %.7f  LON0 := %.7f  giro = %.2f°  escala = %.3f" % [o.x, o.y, rad_to_deg(giro), escala]
