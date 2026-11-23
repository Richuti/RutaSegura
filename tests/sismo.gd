# Prueba del modo sismo: parser del feed USGS, simulacro y evacuación automática.
extends Node

func _foto(n: String) -> void:
	get_viewport().get_texture().get_image().save_png(n)

func _ready() -> void:
	var main = load("res://main.tscn").instantiate()
	add_child(main)
	var a := OS.get_cmdline_user_args()
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
		{"id": "x4", "properties": {"mag": 5.0, "place": "viejo", "time": ahora - 3600000}, "geometry": {"coordinates": [-86.28, 12.02, 10]}}]}
	main.alerta._http.set_meta("solo_marcar", false)
	main.alerta._al_responder(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(feed).to_utf8_buffer())
	print("PARSER: alertas=%d (esperado 1) -> %s" % [recibidos.size(), recibidos])
	print("HAVERSINE Managua-Masaya: %.1f km" % AlertaSismo.distancia_km(12.11, -86.27, 11.97, -86.09))
	await get_tree().create_timer(1.0).timeout
	_foto(a[0] + "_1_alerta.png")

	# 2) Con ubicación: al terminar la cuenta arranca la evacuación sola
	main.salir_sismo()
	main.seleccionar_origen("B2 - Pasillo Central")
	main.alerta.simular()
	await get_tree().create_timer(16.5).timeout
	print("AUTO-EVACUACIÓN con ubicación: ", not main.nav.is_empty() and main.nav.emergencia)
	await get_tree().create_timer(1.5).timeout
	_foto(a[0] + "_2_evacuando.png")

	# 3) Sin ubicación: pide ubicarte y arranca al tocar el mapa
	main.terminar()
	main.origen = ""
	main.alerta.simular()
	main.salir_sismo()
	print("ESPERA UBICACIÓN: ", main.evacuar_al_ubicar)
	main.seleccionar_origen("A - Pasillo Central")
	await get_tree().process_frame
	await get_tree().process_frame
	print("AUTO-EVACUACIÓN al ubicar: ", not main.nav.is_empty() and main.nav.emergencia)
	get_tree().quit()
