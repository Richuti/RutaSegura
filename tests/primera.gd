# Capturas de la navegación en primera persona.
extends Node

func _ready() -> void:
	var main = load("res://main.tscn").instantiate()
	add_child(main)
	var a := Array(OS.get_cmdline_user_args())
	# Por defecto: sin capturas, desde B2, 4 fotos cada 1.5 s
	while a.size() < 4:
		a.append(["", "B2 - Pasillo Central", "4", "1.5"][a.size()])
	await get_tree().create_timer(0.3).timeout
	main.cerrar_bienvenida()
	main.seleccionar_origen(a[1])
	main.emergencia()
	main.alternar_vista()
	for k in int(a[2]):
		await get_tree().create_timer(float(a[3])).timeout
		if a[0] != "" and DisplayServer.get_name() != "headless":
			get_viewport().get_texture().get_image().save_png("%s_%d.png" % [a[0], k])
		print("FOTO %d: %s | %s | %s" % [k, main.banner_dist.text, main.banner_instr.text, main.banner_hacia.text])
	get_tree().quit()
