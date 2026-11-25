# Prueba del modo sismo: parser del feed USGS, simulacro y evacuación automática.
# Uso: godot --path . res://tests/sismo.tscn [-- prefijo_capturas]
# Sale con código 1 si alguna comprobación falla.
extends Node

var pre := ""
var fallos := 0

func _foto(n: String) -> void:
	if pre != "" and DisplayServer.get_name() != "headless":
		get_viewport().get_texture().get_image().save_png(pre + n)

func _comprobar(condicion: bool, mensaje: String) -> void:
	if not condicion:
		fallos += 1
		push_error(mensaje)

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if not a.is_empty():
		pre = a[0]
	var main = load("res://main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	main.cerrar_bienvenida()

	# 1) Parser del feed con datos de ejemplo (formato real del USGS)
	var recibidos := []
	main.alerta.sismo.connect(func(m, l, d): recibidos.append([m, l, d]))
	var ahora := int(Time.get_unix_time_from_system() * 1000)
	var feed := {"features": [
		{"id": "x1", "properties": {"mag": 5.2, "place": "10 km S of Managua, Nicaragua", "time": ahora - 60000}, "geometry": {"coordinates": [-86.28, 12.02, 10]}},
		{"id": "x2", "properties": {"mag": 6.1, "place": "Japón", "time": ahora}, "geometry": {"coordinates": [140.0, 36.0, 10]}},
		{"id": "x3", "properties": {"mag": 3.1, "place": "Masaya", "time": ahora}, "geometry": {"coordinates": [-86.1, 11.97, 10]}},
		{"id": "x4", "properties": {"mag": 5.0, "place": "viejo", "time": ahora - 3600000}, "geometry": {"coordinates": [-86.28, 12.02, 10]}},
		# Publicado con 20 min de retraso (habitual fuera de EE. UU.): debe alertar
		{"id": "x5", "properties": {"mag": 4.8, "place": "Tardío", "time": ahora - 20 * 60000}, "geometry": {"coordinates": [-86.3, 12.1, 10]}}]}
	main.alerta._http.set_meta("solo_marcar", false)
	main.alerta._al_responder(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(feed).to_utf8_buffer())
	print("PARSER: alertas=%d (esperado 2) -> %s" % [recibidos.size(), recibidos])
	_comprobar(recibidos.size() == 2, "El parser debe alertar solo por los 2 sismos cercanos y recientes")
	var d := AlertaSismo.distancia_km(12.11, -86.27, 11.97, -86.09)
	print("HAVERSINE Managua-Masaya: %.1f km" % d)
	_comprobar(absf(d - 25.0) < 1.0, "Haversine Managua-Masaya debe dar unos 25 km")
	await get_tree().create_timer(1.0).timeout
	_foto("_1_alerta.png")

	# 2) Con ubicación: al terminar la cuenta arranca la evacuación sola
	main.salir_sismo()
	main.terminar()
	main.seleccionar_origen("B2 - Pasillo Central")
	main.alerta.simular()
	await get_tree().create_timer(main.ESPERA_SISMO + 1.5).timeout
	var auto1: bool = not main.nav.is_empty() and main.nav.emergencia
	print("AUTO-EVACUACIÓN con ubicación: ", auto1)
	_comprobar(auto1, "Tras la cuenta regresiva debe empezar la evacuación")
	await get_tree().create_timer(1.5).timeout
	_foto("_2_evacuando.png")

	# 3) Sin ubicación: pide ubicarte y arranca al marcarla
	main.terminar()
	main.origen = ""
	main.alerta.simular()
	main.salir_sismo()
	print("ESPERA UBICACIÓN: ", main.evacuar_al_ubicar)
	_comprobar(main.evacuar_al_ubicar, "Sin ubicación, debe esperar a que la marques")
	main.seleccionar_origen("A - Pasillo Central")
	await get_tree().process_frame
	await get_tree().process_frame
	var auto2: bool = not main.nav.is_empty() and main.nav.emergencia
	print("AUTO-EVACUACIÓN al ubicar: ", auto2)
	_comprobar(auto2, "Al marcar la ubicación debe arrancar la evacuación")
	print("SISMO: ", fallos, " fallos")
	get_tree().quit(mini(fallos, 1))
