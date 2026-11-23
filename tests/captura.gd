# Prueba automática: recorre las pantallas y guarda capturas.
# Uso: godot --path . res://tests/captura.tscn -- prefijo origen destino [clave_bloqueo_durante_nav]
extends Node

func _foto(nombre: String) -> void:
	get_viewport().get_texture().get_image().save_png(nombre)

func _ready() -> void:
	var main = load("res://main.tscn").instantiate()
	add_child(main)
	var a := OS.get_cmdline_user_args()
	await get_tree().create_timer(0.3).timeout
	main.mostrar_bienvenida()
	await get_tree().create_timer(1.0).timeout
	_foto(a[0] + "_0_bienvenida.png")
	main.cerrar_bienvenida()
	await get_tree().create_timer(0.8).timeout
	_foto(a[0] + "_1a_sin_ubicacion.png")
	main.seleccionar_origen(a[1])
	await get_tree().create_timer(1.0).timeout
	_foto(a[0] + "_1b_inicio.png")
	main.ver_ruta(a[2])
	await get_tree().create_timer(2.0).timeout
	_foto(a[0] + "_2_vista_previa.png")
	main.terminar()
	main.emergencia()
	for k in 6:
		await get_tree().create_timer(1.6).timeout
		_foto(a[0] + "_3_nav_%d.png" % k)
		print("BANNER %d: %s | %s | %s | luego: %s" % [k, main.banner_dist.text, main.banner_instr.text, main.banner_hacia.text, main.luego_txt.text])
	if a.size() > 3:
		main.bloquear(a[3])
		await get_tree().create_timer(1.2).timeout
		_foto(a[0] + "_3b_recalculo.png")
	await get_tree().create_timer(26.0).timeout
	_foto(a[0] + "_4_llegada.png")
	get_tree().quit()
