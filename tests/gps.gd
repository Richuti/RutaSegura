# Prueba del GPS: simula lecturas GPS caminando por el campus.
# Uso: godot --path . res://tests/gps.tscn -- prefijo
extends Node

var main
var pre := ""

func _foto(n: String) -> void:
	get_viewport().get_texture().get_image().save_png(pre + n)

func _fix(x: float, z: float) -> void:
	var g := Geo.a_gps(x, z)
	main.gps.simular(g.x, g.y, 6.0)
	await get_tree().create_timer(0.25).timeout

func _ready() -> void:
	pre = OS.get_cmdline_user_args()[0]
	main = load("res://main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	main.cerrar_bienvenida()
	# 1) Afuera, junto a la puerta oeste del B
	await _fix(-6, 60)
	await get_tree().create_timer(1.0).timeout
	print("CHIP afuera: ", main.chip_gps.text, " | origen: ", main.origen)
	_foto("_1_afuera.png")
	# 2) Entras al B: pregunta la planta
	for k in 4:
		await _fix(6, 58)
	await get_tree().create_timer(0.8).timeout
	print("HOJA PLANTA visible: ", main.hoja_planta.visible, " | ", main.planta_titulo.text)
	_foto("_2_planta.png")
	main._elegir_planta(2)
	await get_tree().create_timer(1.0).timeout
	print("CHIP: ", main.chip_gps.text, " | origen: ", main.origen)
	_foto("_3_ubicado.png")
	# 3) Emergencia desde tu ubicación real
	main.emergencia()
	await get_tree().create_timer(1.5).timeout
	var cam: Array = main.nav.camino
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
	await get_tree().create_timer(1.5).timeout
	print("FIN modo: ", main.modo, " | planta: ", main.planta_actual)
	_foto("_6_llegada.png")
	# 5) Desvío: te sales de la ruta -> recalcula
	main.terminar()
	await _fix(15, 13)   # dentro de A
	await _fix(15, 13)
	await _fix(15, 13)
	main.op_destino.selected = 0
	for i in main.op_destino.item_count:
		if main.op_destino.get_item_text(i) == "Cafetería":
			main.op_destino.selected = i
	main.ver_ruta()
	main.vamos()
	await get_tree().create_timer(0.5).timeout
	print("RUTA CAFE: ", " -> ".join(main.nav.camino.map(func(v): return v.city)))
	for k in 34:
		await _fix(15, 13 - k * 1.5)   # sales por el norte, lejos de la ruta
	await get_tree().create_timer(0.5).timeout
	print("RECALCULADA: ", " -> ".join(main.nav.camino.map(func(v): return v.city)))
	get_tree().quit()
