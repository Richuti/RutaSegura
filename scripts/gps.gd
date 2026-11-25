# ==========================================================
#  RutasSeguras - GPS del teléfono (Android)
#  Usa el LocationManager de Android directamente desde GDScript
#  (JavaClassWrapper + AndroidRuntime, Godot 4.7), sin plugins.
#  - Pide el permiso de ubicación.
#  - Activa el GPS y la red (la red ayuda dentro de los edificios).
#  - Cada medio segundo lee la última posición y emite "posicion".
#  En PC no hay GPS: la ubicación se marca tocando el mapa.
# ==========================================================
class_name Gps
extends Node

signal posicion(lat: float, lon: float, precision: float)
signal estado_cambio(estado: String)

const PERMISO := "android.permission.ACCESS_FINE_LOCATION"
const PROVEEDORES := ["gps", "network"]
const VIEJA_SEG := 25.0   # una lectura más vieja que esto no sirve

# "sin_gps" | "sin_permiso" | "apagado" | "buscando" | "ok"
var estado := "sin_gps"
var lat := 0.0
var lon := 0.0
var precision := 999.0
var negado := false       # el usuario negó el permiso (hay que ir a los ajustes)

var _rt = null            # AndroidRuntime
var _lm = null            # android.location.LocationManager
var _reloj = null         # android.os.SystemClock
var _looper = null
var _registrados := {}
var _escucha = null       # LocationListener (proxy)
var _receptor: _Receptor
var _ultima_ns := 0
var _t := 0.0
var _simulado := false


# Implementa android.location.LocationListener. No toca la escena:
# Android lo llama desde otro hilo; las lecturas se hacen en _process.
class _Receptor:
	extends Object
	func onLocationChanged(_location) -> void:
		pass
	func onStatusChanged(_provider, _status, _extras) -> void:
		pass
	func onProviderEnabled(_provider) -> void:
		pass
	func onProviderDisabled(_provider) -> void:
		pass
	func onFlushComplete(_request_code) -> void:
		pass


func _ready() -> void:
	if OS.get_name() != "Android":
		return
	_rt = Engine.get_singleton("AndroidRuntime")
	if _rt == null:
		return
	get_tree().on_request_permissions_result.connect(_al_permiso)
	if PERMISO in OS.get_granted_permissions():
		_iniciar()
	else:
		_poner_estado("sin_permiso")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and estado == "sin_permiso" and PERMISO in OS.get_granted_permissions():
		negado = false
		_iniciar()


func _exit_tree() -> void:
	if _lm != null and _escucha != null:
		_lm.removeUpdates(_escucha)
	if _receptor:
		_receptor.free()
		_receptor = null


func pedir_permiso() -> void:
	if _rt != null:
		if PERMISO in OS.get_granted_permissions():
			_iniciar()
		elif negado:
			# Tras negarlo, Android puede no volver a mostrar el diálogo
			abrir_ajustes()
		else:
			# Android 12+ requiere pedir ubicación aproximada y precisa juntas.
			OS.request_permissions()


# Abre la pantalla de ajustes de esta app (Permisos > Ubicación).
# Al volver a la app, _notification detecta el permiso y arranca el GPS.
func abrir_ajustes() -> void:
	if _rt == null:
		return
	var actividad = _rt.getActivity()
	var intent_cls = JavaClassWrapper.wrap("android.content.Intent")
	var uri := "package:%s#Intent;action=android.settings.APPLICATION_DETAILS_SETTINGS;launchFlags=0x10000000;end" % actividad.getPackageName()
	var intent = intent_cls.parseUri(uri, 0)
	if JavaClassWrapper.get_exception() != null or intent == null:
		push_warning("No se pudo crear el intent de ajustes")
		return
	actividad.startActivity(intent)
	if JavaClassWrapper.get_exception() != null:
		push_warning("No se pudieron abrir los ajustes de la app")


func es_automatico() -> bool:
	return OS.get_name() == "Android" or _simulado


func _al_permiso(permiso: String, concedido: bool) -> void:
	if permiso == PERMISO:
		if concedido:
			negado = false
			_iniciar()
		else:
			negado = true
			_poner_estado("sin_permiso")
			estado_cambio.emit(estado)   # para que la interfaz ofrezca abrir los ajustes


func _iniciar() -> void:
	if _lm != null:
		return
	_lm = _rt.getActivity().getSystemService("location")
	_reloj = JavaClassWrapper.wrap("android.os.SystemClock")
	_looper = JavaClassWrapper.wrap("android.os.Looper").getMainLooper()
	if _lm == null or _looper == null:
		_lm = null
		_poner_estado("sin_gps")
		return
	_receptor = _Receptor.new()
	_escucha = JavaClassWrapper.create_proxy(_receptor, PackedStringArray(["android.location.LocationListener"]))
	_poner_estado("buscando" if _escucha != null else "sin_gps")


func _process(delta: float) -> void:
	if _escucha == null or _simulado:
		return
	_t += delta
	if _t < 0.5:
		return
	_t = 0.0
	var activos: Array[String] = []
	for p in PROVEEDORES:
		if _lm.isProviderEnabled(p):
			activos.append(p)
			if not _registrados.has(p):
				_lm.requestLocationUpdates(p, 1000, 0.0, _escucha, _looper)
				if JavaClassWrapper.get_exception() == null:
					_registrados[p] = true
	if activos.is_empty():
		_poner_estado("apagado")
		return
	# La lectura más reciente (y, si son casi igual de nuevas, la más precisa)
	var mejor = null
	var mejor_ns := 0
	var ahora: int = _reloj.elapsedRealtimeNanos()
	for p in activos:
		var loc = _lm.getLastKnownLocation(p)
		if JavaClassWrapper.get_exception() != null or loc == null or not loc.hasAccuracy():
			continue
		var ns: int = loc.getElapsedRealtimeNanos()
		if (ahora - ns) / 1e9 > VIEJA_SEG:
			continue
		if mejor == null or ns > mejor_ns + 3000000000 or (absi(ns - mejor_ns) <= 3000000000 and loc.getAccuracy() < mejor.getAccuracy()):
			mejor = loc
			mejor_ns = ns
	if mejor == null:
		_poner_estado("buscando")
		return
	if mejor_ns == _ultima_ns and estado == "ok":
		return
	_ultima_ns = mejor_ns
	lat = mejor.getLatitude()
	lon = mejor.getLongitude()
	precision = mejor.getAccuracy()
	_poner_estado("ok")
	posicion.emit(lat, lon, precision)


# Para pruebas y demostraciones en PC: una lectura "falsa" de GPS
func simular(la: float, lo: float, prec: float = 5.0) -> void:
	_simulado = true
	lat = la
	lon = lo
	precision = prec
	_poner_estado("ok")
	posicion.emit(lat, lon, precision)


func _poner_estado(e: String) -> void:
	if e != estado:
		estado = e
		estado_cambio.emit(e)
