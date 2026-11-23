# Capturas de la navegación en primera persona.
extends Node

func _ready() -> void:
	var main = load("res://main.tscn").instantiate()
	add_child(main)
	var a := OS.get_cmdline_user_args()
	await get_tree().create_timer(0.3).timeout
	main.cerrar_bienvenida()
	main.seleccionar_origen(a[1])
	main.emergencia()
	main.alternar_vista()
	for k in int(a[2]):
		await get_tree().create_timer(float(a[3])).timeout
		get_viewport().get_texture().get_image().save_png("%s_%d.png" % [a[0], k])
		print("FOTO %d: %s | %s | %s" % [k, main.banner_dist.text, main.banner_instr.text, main.banner_hacia.text])
	get_tree().quit()
