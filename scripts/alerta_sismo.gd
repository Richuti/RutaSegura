# ==========================================================
#  RutasSeguras - Alerta de sismos
#  Consulta cada minuto el feed público de sismos del USGS
#  (sin clave). Si hay un sismo cercano a la UAM, emite la señal
#  "sismo" y la app entra sola en modo emergencia.
#
#  Nota: las alertas tempranas de Google (Android Earthquake
#  Alerts) son un servicio del sistema operativo y no tienen API
#  para apps; deben dejarse activadas en el teléfono. Este módulo
#  las complementa: reacciona al sismo confirmado y te guía.
# ==========================================================
class_name AlertaSismo
extends Node

signal sismo(magnitud: float, lugar: String, distancia_km: float)

const FEED := "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/2.5_hour.geojson"
const UAM_LAT := 12.10849   # UAM, Managua (Plus Code 764M4P5V+96W)
const UAM_LON := -86.25692
const RADIO_KM := 150.0     # sismos a esta distancia o menos
const MAG_MIN := 4.0        # magnitud mínima para alertar
# Solo sismos de los últimos 30 minutos. El USGS puede tardar 10-20 min en
# publicar sismos fuera de EE. UU.; con menos margen la alerta se perdería.
const VIGENCIA_S := 30 * 60
const INTERVALO_S := 60.0

var activo := true
var vistos := {}
var _http: HTTPRequest
var _timer: Timer


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 20
	add_child(_http)
	_http.request_completed.connect(_al_responder)
	_timer = Timer.new()
	_timer.wait_time = INTERVALO_S
	_timer.autostart = true
	_timer.timeout.connect(consultar)
	add_child(_timer)
	# Primera consulta: solo marca como "vistos" los sismos ya existentes,
	# para no alertar por algo que pasó antes de abrir la app.
	consultar(true)


func consultar(solo_marcar: bool = false) -> void:
	if not activo or _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	_http.set_meta("solo_marcar", solo_marcar)
	_http.request(FEED)


func _al_responder(resultado: int, codigo: int, _h: PackedStringArray, cuerpo: PackedByteArray) -> void:
	if resultado != HTTPRequest.RESULT_SUCCESS or codigo != 200:
		return
	var datos = JSON.parse_string(cuerpo.get_string_from_utf8())
	if typeof(datos) != TYPE_DICTIONARY or not datos.has("features"):
		return
	var solo_marcar: bool = _http.get_meta("solo_marcar", false)
	var ahora := Time.get_unix_time_from_system()
	for f in datos.features:
		var id: String = str(f.get("id", ""))
		if id == "" or vistos.has(id):
			continue
		vistos[id] = true
		if solo_marcar:
			continue
		var p: Dictionary = f.get("properties", {})
		var c: Array = f.get("geometry", {}).get("coordinates", [])
		if c.size() < 2 or p.get("mag") == null:
			continue
		var mag := float(p.mag)
		var edad := ahora - float(p.get("time", 0)) / 1000.0
		var dist := distancia_km(UAM_LAT, UAM_LON, float(c[1]), float(c[0]))
		if mag >= MAG_MIN and dist <= RADIO_KM and edad <= VIGENCIA_S:
			sismo.emit(mag, str(p.get("place", "")), dist)


# Para la demostración: simula un sismo cercano
func simular() -> void:
	sismo.emit(5.6, "12 km al SO de Managua (simulacro)", 12.0)


# Distancia sobre la Tierra (fórmula de haversine)
static func distancia_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
	var r := 6371.0
	var dlat := deg_to_rad(lat2 - lat1)
	var dlon := deg_to_rad(lon2 - lon1)
	var a := sin(dlat / 2) ** 2 + cos(deg_to_rad(lat1)) * cos(deg_to_rad(lat2)) * sin(dlon / 2) ** 2
	return r * 2.0 * atan2(sqrt(a), sqrt(1.0 - a))
