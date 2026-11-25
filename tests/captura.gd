# Prueba automática: recorre las pantallas y guarda capturas.
# Uso: godot --path . res://tests/captura.tscn -- prefijo origen destino [clave_bloqueo_durante_nav]
extends Node

var pre := ""

# Sin prefijo (o en modo headless) no se guardan capturas
func _foto(nombre: String) -> void:
	if pre != "" and DisplayServer.get_name() != "headless":
		get_viewport().get_texture().get_image().save_png(pre + nombre)

func _ready() -> void:
	var main = load("res://main.tscn").instantiate()
	add_child(main)
	var a := Array(OS.get_cmdline_user_args())
	# Valores por defecto: prefijo vacío (sin capturas), origen y destino de ejemplo
	while a.size() < 3:
		a.append(["", "B2 - Pasillo Central", "Cafetería"][a.size()])
	pre = a[0]
	await get_tree().create_timer(0.3).timeout
	main.mostrar_bienvenida()
	await get_tree().create_timer(1.0).timeout
	_foto("_0_bienvenida.png")
	# Muestra la explicación del permiso de Android en la captura de escritorio.
	main.bienvenida.usa_gps = true
	main.bienvenida.falta_permiso = true
	main.bienvenida._principal.pressed.emit()
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":   # sin ventana nunca se dibuja
		await RenderingServer.frame_post_draw
	_foto("_0b_ubicacion_y_piso.png")
	main.cerrar_bienvenida()
	await get_tree().create_timer(0.8).timeout
	_foto("_1a_sin_ubicacion.png")
	main.seleccionar_origen(a[1])
	await get_tree().create_timer(1.0).timeout
	_foto("_1b_inicio.png")
	main.ver_ruta(a[2])
	await get_tree().create_timer(2.0).timeout
	_foto("_2_vista_previa.png")
	main.terminar()
	main.emergencia()
	for k in 6:
		await get_tree().create_timer(1.6).timeout
		_foto("_3_nav_%d.png" % k)
		print("BANNER %d: %s | %s | %s | luego: %s" % [k, main.banner_dist.text, main.banner_instr.text, main.banner_hacia.text, main.luego_txt.text])
	if a.size() > 3:
		main.bloquear(a[3])
		await get_tree().create_timer(1.2).timeout
		_foto("_3b_recalculo.png")
	await get_tree().create_timer(26.0).timeout
	_foto("_4_llegada.png")
	get_tree().quit()
