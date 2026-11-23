extends Node
func _ready() -> void:
	var main = load("res://main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var mapa: Graph = main.mapa
	for v in mapa.vertexs:
		if v.segura or Campus.es_escalera(v):
			continue
		var r := mapa.evacuar(v.city, [], Campus.permitido_evacuar)
		var nombres := []
		for w in r.camino:
			if not Campus.es_escalera(w):
				nombres.append(w.city)
			elif nombres.is_empty() or nombres[-1] != "[esc]":
				nombres.append("[esc]")
		var real := 0.0
		for i in r.camino.size() - 1:
			real += r.camino[i].pos.distance_to(r.camino[i + 1].pos)
		print("EVAC %-22s peso=%3d real=%3d  %s" % [v.city, r.distancia, roundi(real), " > ".join(nombres)])
		# alternativas por cada zona segura
		var d := mapa.dijkstra(v.city, [], Campus.permitido_evacuar)
		var alt := []
		for z in mapa.vertexs:
			if z.segura:
				alt.append("%s=%d" % [z.city.left(12), d.dist[z]])
		print("     zonas: ", ", ".join(alt))
	get_tree().quit()
