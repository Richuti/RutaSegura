# ==========================================================
#  Íconos vectoriales dibujados en código (flechas tipo Waze,
#  escudo, pin, etc.). No dependen de emojis ni imágenes.
# ==========================================================
class_name Icono
extends Control

var tipo := "recto"
var color := Color.WHITE
var escala := 1.0


func _init(_tipo: String = "recto", _color: Color = Color.WHITE, tam: int = 48) -> void:
	tipo = _tipo
	color = _color
	custom_minimum_size = Vector2(tam, tam)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func poner(_tipo: String, _color: Color = color) -> void:
	tipo = _tipo
	color = _color
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y) * escala
	var o := size / 2.0
	var k := s / 100.0          # coordenadas de diseño: -50..50
	var w := s * 0.13
	match tipo:
		"recto":
			_flecha([Vector2(0, 42), Vector2(0, -40)], k, o, w)
		"abajo":
			_flecha([Vector2(0, -42), Vector2(0, 40)], k, o, w)
		"izquierda":
			_flecha([Vector2(16, 44), Vector2(16, 0), Vector2(-40, 0)], k, o, w)
		"derecha":
			_flecha([Vector2(-16, 44), Vector2(-16, 0), Vector2(40, 0)], k, o, w)
		"leve_izquierda":
			_flecha([Vector2(12, 44), Vector2(12, 10), Vector2(-30, -32)], k, o, w)
		"leve_derecha":
			_flecha([Vector2(-12, 44), Vector2(-12, 10), Vector2(30, -32)], k, o, w)
		"vuelta":
			var pts := [Vector2(18, 44), Vector2(18, -6)]
			for i in range(1, 12):
				var t := PI * i / 11.0
				pts.append(Vector2(18 * cos(t), -6 - 18 * sin(t)))
			pts.append(Vector2(-18, 30))
			_flecha(pts, k, o, w)
		"llegada":
			_linea([Vector2(-30, 2), Vector2(-9, 24), Vector2(32, -22)], k, o, w * 1.1)
		"punto":
			draw_circle(o, s * 0.36, color, true, -1.0, true)
			draw_circle(o, s * 0.25, Color.WHITE, true, -1.0, true)
			draw_circle(o, s * 0.15, color, true, -1.0, true)
		"pin":
			var c := o + Vector2(0, -12) * k
			draw_colored_polygon(PackedVector2Array([o + Vector2(-22, 0) * k, o + Vector2(22, 0) * k, o + Vector2(0, 42) * k]), color)
			draw_circle(c, 28 * k, color, true, -1.0, true)
			draw_circle(c, 11 * k, Color.WHITE, true, -1.0, true)
		"escudo":
			var p := PackedVector2Array()
			for q in [Vector2(0, -44), Vector2(36, -30), Vector2(33, 6), Vector2(20, 28), Vector2(0, 44), Vector2(-20, 28), Vector2(-33, 6), Vector2(-36, -30)]:
				p.append(o + q * k)
			draw_colored_polygon(p, color)
			_linea([Vector2(-15, 0), Vector2(-4, 12), Vector2(17, -12)], k, o, w * 0.9, Color.WHITE if color != Color.WHITE else Estilo.TEAL)
		"alerta":
			var tri := PackedVector2Array([o + Vector2(0, -40) * k, o + Vector2(44, 36) * k, o + Vector2(-44, 36) * k])
			draw_colored_polygon(tri, color)
			_linea([Vector2(0, -14), Vector2(0, 10)], k, o, w * 0.8, Color.WHITE)
			draw_circle(o + Vector2(0, 23) * k, w * 0.5, Color.WHITE, true, -1.0, true)
		"mas":
			_linea([Vector2(-30, 0), Vector2(30, 0)], k, o, w)
			_linea([Vector2(0, -30), Vector2(0, 30)], k, o, w)
		"menos":
			_linea([Vector2(-30, 0), Vector2(30, 0)], k, o, w)
		"cerrar":
			_linea([Vector2(-26, -26), Vector2(26, 26)], k, o, w)
			_linea([Vector2(26, -26), Vector2(-26, 26)], k, o, w)
		"centrar":
			draw_arc(o, 26 * k, 0, TAU, 40, color, w * 0.75, true)
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				_linea([d * 30, d * 46], k, o, w * 0.75)
			draw_circle(o, 10 * k, color, true, -1.0, true)
		"escaleras":
			_linea([Vector2(-38, 36), Vector2(-38, 18), Vector2(-14, 18), Vector2(-14, -2), Vector2(10, -2),
				Vector2(10, -22), Vector2(34, -22), Vector2(34, -40)], k, o, w * 0.85)
		"persona":
			draw_circle(o + Vector2(0, -22) * k, 14 * k, color, true, -1.0, true)
			var cuerpo := PackedVector2Array()
			for i in 13:
				var t := PI + PI * i / 12.0
				cuerpo.append(o + (Vector2(0, 34) + Vector2(cos(t) * 30, sin(t) * 30)) * k)
			draw_colored_polygon(cuerpo, color)
		"mapa":
			var p := [Vector2(-40, -28), Vector2(-13, -38), Vector2(13, -28), Vector2(40, -38),
				Vector2(40, 28), Vector2(13, 38), Vector2(-13, 28), Vector2(-40, 38), Vector2(-40, -28)]
			_linea(p, k, o, w * 0.7)
			_linea([Vector2(-13, -38), Vector2(-13, 28)], k, o, w * 0.6)
			_linea([Vector2(13, -28), Vector2(13, 38)], k, o, w * 0.6)
		"voz", "voz_off":
			var bocina := PackedVector2Array()
			for q in [Vector2(-40, -13), Vector2(-20, -13), Vector2(4, -34), Vector2(4, 34), Vector2(-20, 13), Vector2(-40, 13)]:
				bocina.append(o + q * k)
			draw_colored_polygon(bocina, color)
			if tipo == "voz":
				draw_arc(o + Vector2(6, 0) * k, 16 * k, -PI / 4, PI / 4, 12, color, w * 0.7, true)
				draw_arc(o + Vector2(6, 0) * k, 31 * k, -PI / 4, PI / 4, 16, color, w * 0.7, true)
			else:
				_linea([Vector2(18, -14), Vector2(42, 14)], k, o, w * 0.75)
				_linea([Vector2(42, -14), Vector2(18, 14)], k, o, w * 0.75)
		"ir":
			var nav := PackedVector2Array([o + Vector2(0, -42) * k, o + Vector2(32, 38) * k, o + Vector2(0, 20) * k, o + Vector2(-32, 38) * k])
			draw_colored_polygon(nav, color)


func _linea(pts: Array, k: float, o: Vector2, w: float, col: Color = color) -> void:
	var p := PackedVector2Array()
	for q in pts:
		p.append(o + q * k)
	draw_polyline(p, col, w, true)
	for q in p:
		draw_circle(q, w / 2.0, col, true, -1.0, true)


func _flecha(pts: Array, k: float, o: Vector2, w: float) -> void:
	var p := PackedVector2Array()
	for q in pts:
		p.append(o + q * k)
	var fin := p[p.size() - 1]
	var dir := (fin - p[p.size() - 2]).normalized()
	var cabeza := w * 2.3
	var base := fin - dir * cabeza
	var tallo := p.duplicate()
	tallo[tallo.size() - 1] = base + dir * w * 0.3
	draw_polyline(tallo, color, w, true)
	for i in tallo.size() - 1:
		draw_circle(tallo[i], w / 2.0, color, true, -1.0, true)
	var n := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([fin + dir * w * 0.2, base + n * cabeza * 0.9, base - n * cabeza * 0.9]), color)
