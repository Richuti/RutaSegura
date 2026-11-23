# Escribe el grafo de la app en sintaxis Python (para rutasseguras.py)
extends SceneTree
func _init():
	var m := Campus.crear_campus()
	var out := PackedStringArray()
	out.append("lugares = [")
	for v in m.vertexs:
		if not v.segura:
			out.append('    "%s",' % v.city)
	out.append("]")
	out.append("zonas_seguras = [")
	for v in m.vertexs:
		if v.segura:
			out.append('    "%s",' % v.city)
	out.append("]")
	out.append("pasillos = [")
	var vistos := {}
	for v in m.vertexs:
		for par in v.neig:
			var k := Graph.clave(v.city, par[0].city)
			if vistos.has(k):
				continue
			vistos[k] = true
			out.append('    ("%s", "%s", %d),' % [v.city, par[0].city, int(par[1])])
	out.append("]")
	var f := FileAccess.open("res://tests/_datos_python.txt", FileAccess.WRITE)
	f.store_string("\n".join(out))
	f.close()
	quit()
