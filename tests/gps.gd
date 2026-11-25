# Prueba del GPS: simula lecturas GPS caminando por el campus.
# Uso: godot --path . res://tests/gps.tscn -- prefijo
extends Node

var main
var pre := ""
var fallos := 0

func _foto(n: String) -> void:
	if pre != "" and DisplayServer.get_name() != "headless":
		get_viewport().get_texture().get_image().save_png(pre + n)

func _comprobar(condicion: bool, mensaje: String) -> void:
	if not condicion:
		fallos += 1
		push_error(mensaje)

func _fix(x: float, z: float) -> void:
	var g := Geo.a_gps(x, z)
	main.gps.simular(g.x, g.y, 6.0)
	await get_tree().create_timer(0.25).timeout

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		pre = args[0]
	main = load("res://main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	main.mostrar_bienvenida()
	var intro: Control = main.bienvenida
	_comprobar(intro._paso == 0 and intro._foto.texture != null, "La bienvenida debe abrir con la ilustración del campus")
	intro.usa_gps = true
	intro.falta_permiso = true
	intro._principal.pressed.emit()
	_comprobar(intro._paso == 1 and intro._principal.text == "Activar ubicación" and intro._omitir.visible,
		"La bienvenida debe explicar la ubicación antes de pedir el permiso")
	intro._volver.pressed.emit()
	_comprobar(intro._paso == 0, "Se debe poder volver al primer paso")
	intro._principal.pressed.emit()
	intro._omitir.pressed.emit()
	_comprobar(main.bienvenida == null, "Se debe poder abrir el mapa sin otorgar el permiso")
	# 1) Afuera, junto a la puerta norte del B
	await _fix(-6, 51.5)
	await get_tree().create_timer(1.0).timeout
	print("CHIP afuera: ", main.chip_gps.text, " | origen: ", main.origen)
	_comprobar(main._usar_gps() and main.op_origen.disabled, "El GPS debe fijar el origen sin selección manual")
	var origen_gps: String = main.origen
	main.seleccionar_origen("A - Entrada Este")
	_comprobar(main.origen == origen_gps, "La selección manual no debe reemplazar el GPS")
	var g := Geo.a_gps(-6, 51.5)
	main.gps.simular(g.x, g.y, 60.0)
	_comprobar(not main._usar_gps() and main.origen == "", "Una lectura imprecisa debe invalidar el origen")
	await _fix(-6, 51.5)
	_foto("_1_afuera.png")
	# 2) Entras al B: pregunta la planta
	for k in 4:
		await _fix(6, 58)
	await get_tree().create_timer(0.8).timeout
	print("HOJA PLANTA visible: ", main.hoja_planta.visible, " | ", main.planta_titulo.text)
	_comprobar(main.hoja_planta.visible and not main._usar_gps(), "La app debe esperar el piso antes de calcular")
	_foto("_2_planta.png")
	main.emergencia()
	_comprobar(main.nav.is_empty(), "La emergencia debe esperar la confirmación del piso")
	main._elegir_planta(2)
	await get_tree().create_timer(1.0).timeout
	print("CHIP: ", main.chip_gps.text, " | origen: ", main.origen)
	_foto("_3_ubicado.png")
	# 3) Emergencia desde tu ubicación real
	await get_tree().create_timer(1.5).timeout
	if main.nav.is_empty():
		push_error("La emergencia debe continuar después de elegir el piso")
		get_tree().quit(1)
		return
	var cam: Array = main.nav.camino
	_comprobar(Campus.planta_de(cam[0]) == 2, "La ruta debe iniciar en el piso elegido")
	print("RUTA: ", " -> ".join(cam.map(func(v): return v.city)))
	_foto("_4_emergencia.png")
	# 4) Caminas siguiendo la ruta (2 m por lectura)
	var esperas := 0
	var paso := 0
	for k in cam.size() - 1:
		var a: Vector3 = cam[k].pos
		var b: Vector3 = cam[k + 1].pos
		var n := maxi(1, ceili(Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) / 2.0))
		for s in n:
			var p := a.lerp(b, float(s + 1) / n)
			await _fix(p.x, p.z)
			paso += 1
			if main.btn_escalera.visible and esperas == 0:
				esperas += 1
				print("ESCALERA: ", main.btn_escalera.text, " | ", main.banner_instr.text)
				await get_tree().create_timer(1.0).timeout
				_foto("_5_escalera.png")
			if paso == 6:
				_foto("_5a_caminando.png")
				print("BANNER: ", main.banner_dist.text, " | ", main.banner_instr.text)
		if main.btn_escalera.visible and not main.nav.fin:
			var tramo: Dictionary = main.nav.tramos[main._tramo_de(main.nav.i)]
			if tramo.escalera and tramo.hasta == k:
				_comprobar(main.planta_actual > Campus.planta_de(cam[k + 1]), "El GPS no debe cambiar el piso por sí solo en la escalera")
				main._confirmar_escalera()
	await get_tree().create_timer(1.5).timeout
	print("FIN modo: ", main.modo, " | planta: ", main.planta_actual)
	_comprobar(main.modo == "llegada", "La ruta GPS debe llegar a la zona segura")
	_foto("_6_llegada.png")
	# 5) Desvío: te sales de la ruta -> recalcula
	main.terminar()
	await _fix(15, 5)   # dentro de A
	await _fix(15, 5)
	await _fix(15, 5)
	_comprobar(main.hoja_planta.visible, "El edificio A también debe solicitar el piso")
	main._elegir_planta(2)
	_comprobar(main._usar_gps() and main.bajar_desde == 2 and Campus.planta_de(main.ubic.a) == 1,
		"A2 (sin mapear) debe partir de la planta baja y pedir bajar")
	main._elegir_planta(1)
	_comprobar(main.bajar_desde == 0, "En A planta baja no se pide bajar")
	main.op_destino.selected = 0
	for i in main.op_destino.item_count:
		if main.op_destino.get_item_text(i) == "Cafetería":
			main.op_destino.selected = i
	main.ver_ruta()
	main.vamos()
	await get_tree().create_timer(0.5).timeout
	print("RUTA CAFE: ", " -> ".join(main.nav.camino.map(func(v): return v.city)))
	for k in 34:
		await _fix(15, 5 - k * 1.5)   # sales por el este, lejos de la ruta
	await get_tree().create_timer(0.5).timeout
	print("RECALCULADA: ", " -> ".join(main.nav.camino.map(func(v): return v.city)))

	# 6) Plan B: GPS débil (±30 m). Fuera de emergencia no se usa la lectura,
	#    pero se puede marcar la ubicación a mano y evacuar desde ahí.
	main.terminar()
	var g2 := Geo.a_gps(-6, 51.5)
	main.gps.simular(g2.x, g2.y, 30.0)
	_comprobar(not main._usar_gps() and main._puede_marcar_a_mano() and not main.op_origen.disabled,
		"Con GPS débil se debe poder marcar el origen a mano")
	main.seleccionar_origen("B2 - Pasillo Central")
	_comprobar(main.origen == "B2 - Pasillo Central" and main.origen_manual, "El origen manual debe aceptarse")
	main.gps.simular(g2.x, g2.y, 30.0)
	_comprobar(main.origen == "B2 - Pasillo Central", "Una lectura débil no debe borrar el origen manual")
	main.emergencia()
	_comprobar(not main.nav.is_empty() and main.nav.emergencia and main.nav.camino[0].city == "B2 - Pasillo Central",
		"La emergencia debe arrancar desde el origen manual")

	# 7) En emergencia se aceptan lecturas de hasta 40 m
	main.terminar()
	main.origen_manual = false
	main.origen = ""
	main.gps.simular(g2.x, g2.y, 60.0)
	main.emergencia()
	_comprobar(main.nav.is_empty() and main.evacuar_al_ubicar, "Sin ubicación, la emergencia debe esperar")
	for k in 4:
		main.gps.simular(g2.x, g2.y, 35.0)
		await get_tree().create_timer(0.1).timeout
	await get_tree().process_frame
	_comprobar(not main.nav.is_empty() and main.nav.emergencia, "En emergencia una lectura de ±35 m debe bastar")

	# 8) Toque a mano dentro de un edificio de varios pisos: pregunta el piso
	main.terminar()
	main.origen_manual = false
	main.origen = ""
	main.gps.simular(g2.x, g2.y, 60.0)
	main._al_tocar_mapa(Vector3(6, 0, 60))
	_comprobar(main.hoja_planta.visible, "Tocar el edificio B debe preguntar el piso")
	main._elegir_planta(3)
	_comprobar(main.origen.begins_with("B3"), "Debe ubicarte en la planta 3 de B (origen: %s)" % main.origen)
	print("GPS: ", fallos, " fallos")
	get_tree().quit(mini(fallos, 1))
