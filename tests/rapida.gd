extends Node
func _ready() -> void:
	var main = load("res://main.tscn").instantiate()
	add_child(main)
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		main.seleccionar_origen(a[1])
	await get_tree().create_timer(1.2).timeout
	if not a.is_empty() and DisplayServer.get_name() != "headless":
		get_viewport().get_texture().get_image().save_png(a[0])
	get_tree().quit()
