# ==========================================================
#  RutasSeguras - Mundo 3D del campus
#  Edificios, zonas seguras, ruta animada, tu ubicación y cámara.
# ==========================================================
class_name Escena3D
extends Node3D

signal toque(pos: Vector3)   # el usuario tocó el mapa (sin arrastrar)

const PARED := Color("#F4F1EA")
const ZOCALO := Color("#D9D3C7")
const CORNISA := Color("#E6E0D4")
const TECHO := Color("#5EAE9C")
const VIDRIO := Color("#2F4E66")
const SUELO := Color("#E9ECE6")
const GRAMA := Color("#D3E5C6")
const ACERA := Color("#FBFAF6")
const ASFALTO := Color("#C6CBCE")
const CTX_PARED := Color("#EEECE7")
const CTX_TECHO := Color("#CBD5D1")

var mapa: Graph
var sobre_ui: Callable = func(_p): return false

# Cámara (valores actuales y objetivo, para movimientos suaves)
var pivot: Node3D
var camara: Camera3D
var yaw := deg_to_rad(-32.0)
var pitch := deg_to_rad(50.0)
var distancia := 240.0
var foco := Vector3(-12, 0, 57)
var yaw_obj := yaw
var pitch_obj := pitch
var dist_obj := distancia
var foco_obj := foco
var en_escalera := false
var primera_persona := false
var yaw_escalera := 0.0
const VISTA_FOCO := Vector3(-12, 0, 57)

# Ruta
var ruta_nodo: Node3D
var ruta_pts: Array[Vector3] = []
var ruta_largo := 0.0
var mats_ruta: Array[ShaderMaterial] = []
var _shader_ruta: Shader
var _shader_ruta_3d: Shader

# Usuario
var usuario: Node3D
var halo: MeshInstance3D

# Zonas y bloqueos
var anillos := {}            # Vertex -> MeshInstance3D
var zona_destino: Vertex = null
var bloqueo_nodo: Node3D
var tiempo := 0.0

# Gestos
var toques := {}
var toque_ini := {}
var arrastro := false
var pinch_ini := 0.0
var dist_ini := 0.0

var _mats := {}
var edificios: Array = []   # edificios navegables (para la vista interior)


func construir(_mapa: Graph) -> void:
	mapa = _mapa
	_entorno()
	_suelo()
	_vias_y_parqueos()
	_pasillos()
	for e in Campus.EDIFICIOS:
		_edificio(e[3], e[4], e[5], e[6], e[7], e[8], PARED, TECHO, VIDRIO, true)
		_insignia(e[1], e[2], e[0], Vector3((e[3] + e[5]) / 2.0, e[7] + 14.0, (e[4] + e[6]) / 2.0), true)
	_pasarela()
	for c in Campus.CONTEXTO:
		_edificio(c[1], c[2], c[3], c[4], c[5], c[6], CTX_PARED, CTX_TECHO, Color("#9AABB5"), false)
		var nombre_c: String = c[7] if c.size() > 7 else ""
		_insignia(c[0], Color("#C9822B") if nombre_c != "" else Color("#9AA7AD"), nombre_c, Vector3((c[1] + c[3]) / 2.0, c[5] + 8.0, (c[2] + c[4]) / 2.0), false)
	for p in Campus.PUERTAS:
		_puerta(p[0], p[1])
	_puente()
	_zonas()
	_arboles()
	_camara()
	ruta_nodo = Node3D.new()
	add_child(ruta_nodo)
	bloqueo_nodo = Node3D.new()
	add_child(bloqueo_nodo)
	_usuario()


# ==========================================================
#  API usada por la interfaz
# ==========================================================
func vista_general() -> void:
	foco_obj = VISTA_FOCO
	dist_obj = 240.0
	pitch_obj = deg_to_rad(50.0)
	yaw_obj = deg_to_rad(-32.0)


func enfocar(pos: Vector3) -> void:
	foco_obj = pos
	dist_obj = 120.0
	pitch_obj = deg_to_rad(52.0)


func encuadrar(camino: Array) -> void:
	var a := AABB(camino[0].pos, Vector3.ZERO)
	for v in camino:
		a = a.expand(v.pos)
	foco_obj = a.get_center() + Vector3(0, 0, 6)
	dist_obj = clampf(a.size.length() * 1.9 + 40.0, 80.0, 200.0)
	pitch_obj = deg_to_rad(52.0)


func seguir(pos: Vector3, dir: Vector3, cerca: bool = false) -> void:
	var plano := Vector3(dir.x, 0, dir.z)
	if plano.length() < 0.01:
		plano = Vector3(0, 0, 1)
	var fp := primera_persona and not cerca
	usuario.visible = not fp
	camara.near = 0.05 if fp else 0.5
	camara.fov = 72.0 if fp else 42.0
	if fp:
		# Cámara a la altura de los ojos, mirando hacia donde caminas
		foco_obj = pos + Vector3(0, _piso(pos + Vector3(0, 0.3, 0)) + 1.6, 0)
		yaw_obj = atan2(-plano.x, -plano.z)
		pitch_obj = deg_to_rad(4.0 - clampf(dir.normalized().y, -0.6, 0.6) * 30.0)
		dist_obj = 0.25
		halo.visible = false
		return
	foco_obj = pos + plano.normalized() * (0.0 if cerca else 6.0)
	# En la escalera la cámara NO gira con cada tramo (marearía): mantiene el
	# ángulo con el que llegaste y mira casi desde arriba.
	if cerca:
		if not en_escalera:
			yaw_escalera = yaw_obj
		yaw_obj = yaw_escalera
	else:
		yaw_obj = atan2(-plano.x, -plano.z)
	en_escalera = cerca
	# En la escalera la cámara se acerca y mira más desde arriba
	# En la escalera: vista casi cenital para ver los tramos sin que los muros tapen
	pitch_obj = deg_to_rad(76.0 if cerca else 36.0)
	dist_obj = 36.0 if cerca else 52.0
	halo.visible = not cerca


# Vista interior: los edificios indicados se "cortan" a la altura de la
# planta baja (sin techo) para ver aulas, pasillos y tu ubicación adentro.
const ALTURA_CORTE := 2.9

# cortes: {índice de edificio: planta a mostrar (1 = planta baja)}
func cortar_edificios(cortes: Dictionary) -> void:
	for i in edificios.size():
		var e: Dictionary = edificios[i]
		var planta: int = cortes.get(i, 0)
		if planta == e.cortado:
			continue
		e.cortado = planta
		var abierto := planta > 0
		e.superior.visible = not abierto
		for k in e.por_planta.size():
			e.por_planta[k].visible = not abierto or k < planta


func edificio_en(p: Vector3) -> int:
	for i in edificios.size():
		if edificios[i].rect.grow(0.3).has_point(Vector2(p.x, p.z)):
			return i
	return -1


func etiquetas(visibles: bool) -> void:
	for n in get_tree().get_nodes_in_group("etiquetas"):
		n.visible = visibles


func set_primera_persona(activa: bool) -> void:
	primera_persona = activa
	camara.near = 0.05 if activa else 0.5
	camara.fov = 72.0 if activa else 42.0
	usuario.visible = usuario.visible and not activa


func zoom(factor: float) -> void:
	dist_obj = clampf(dist_obj * factor, 30.0, 280.0)


func poner_usuario(pos: Vector3, dir: Vector3 = Vector3(0, 0, 1), visible_: bool = true) -> void:
	usuario.visible = visible_ and not (primera_persona and not en_escalera)
	usuario.position = pos
	if dir.length() > 0.01:
		usuario.rotation.y = atan2(-dir.x, -dir.z)


func mostrar_ruta(camino: Array, color: Color) -> void:
	limpiar_ruta()
	# 1) Polilínea con esquinas redondeadas (menos en las escaleras)
	var res := _suavizar(camino)
	ruta_pts = res[0]
	var esc: Array = res[1]
	ruta_largo = 0.0
	var acum: Array[float] = [0.0]
	for i in ruta_pts.size() - 1:
		ruta_largo += ruta_pts[i].distance_to(ruta_pts[i + 1])
		acum.append(ruta_largo)

	# 2) Se parte en piezas: calle/pasillo (encima de todo) y escalera (apoyada en los escalones)
	mats_ruta.clear()
	var ini := 0
	for i in range(1, ruta_pts.size()):
		var fin_pieza: bool = i == ruta_pts.size() - 1 or (esc[i] or esc[i + 1]) != (esc[ini] or esc[ini + 1])
		if fin_pieza:
			var trozo: Array[Vector3] = []
			for k in range(ini, i + 1):
				trozo.append(ruta_pts[k])
			var es_esc: bool = esc[ini] or esc[ini + 1]
			if es_esc:
				var cinta := MeshInstance3D.new()
				cinta.mesh = _cinta(trozo, 1.5, 0.55, acum[ini])
				var m := _mat_ruta(color, color.darkened(0.32), 13, false, true)
				cinta.material_override = m
				mats_ruta.append(m)
				ruta_nodo.add_child(cinta)
			else:
				var sombra := MeshInstance3D.new()
				sombra.mesh = _cinta(trozo, 2.2 if primera_persona else 4.2, 0.03, acum[ini], true)
				sombra.material_override = _mat_ruta(Color(0.05, 0.1, 0.15, 0.16), Color(0.05, 0.1, 0.15, 0.0), 11, false, true)
				ruta_nodo.add_child(sombra)
				var cinta := MeshInstance3D.new()
				cinta.mesh = _cinta(trozo, 1.5 if primera_persona else 2.7, 0.07, acum[ini], true)
				var m := _mat_ruta(color, color.darkened(0.32), 12, true, true)
				cinta.material_override = m
				mats_ruta.append(m)
				ruta_nodo.add_child(cinta)
			ini = i

	# 3) Destino: pin si no es zona segura
	var fin: Vertex = camino[-1]
	if not fin.segura:
		_marcador(fin.pos, "pin", color, 160)
	zona_destino = fin if fin.segura else null
	progreso_ruta(0.0)


func limpiar_ruta() -> void:
	for c in ruta_nodo.get_children():
		c.queue_free()
	ruta_pts.clear()
	marcadores.clear()
	mats_ruta.clear()
	zona_destino = null


# Avance (0..1): la parte recorrida se pinta gris, como en Waze
func progreso_ruta(f: float) -> void:
	for m in mats_ruta:
		m.set_shader_parameter("progreso", f * ruta_largo)
	_ocultar_pasados(f)


# Posición y dirección sobre la ruta suavizada en la fracción f (0..1)
func posicion_en(f: float) -> Array:
	var info := _punto_en(clampf(f, 0.0, 1.0) * ruta_largo)
	return [info[0] - Vector3(0, 0.3, 0), info[1]]


func _suavizar(camino: Array) -> Array:
	var y := Vector3(0, 0.3, 0)
	var r_max := 3.0
	var out: Array[Vector3] = [camino[0].pos + y]
	var flags: Array = [Campus.es_escalera(camino[0])]
	for i in range(1, camino.size() - 1):
		var a: Vector3 = camino[i - 1].pos
		var p: Vector3 = camino[i].pos
		var b: Vector3 = camino[i + 1].pos
		var cerca_esc: bool = Campus.es_escalera(camino[i - 1]) or Campus.es_escalera(camino[i]) or Campus.es_escalera(camino[i + 1])
		var f: bool = Campus.es_escalera(camino[i])
		if cerca_esc:
			out.append(p + y)
			flags.append(f)
			continue
		var r := minf(r_max, minf(p.distance_to(a), p.distance_to(b)) * 0.45)
		var p1 := p + (a - p).normalized() * r
		var p2 := p + (b - p).normalized() * r
		for k in 11:
			var t := k / 10.0
			out.append(p1.lerp(p, t).lerp(p.lerp(p2, t), t) + y)   # Bézier cuadrática
			flags.append(f)
	out.append(camino[-1].pos + y)
	flags.append(Campus.es_escalera(camino[-1]))
	# quitar puntos repetidos
	var limpio: Array[Vector3] = [out[0]]
	var fl: Array = [flags[0]]
	for i in out.size():
		if out[i].distance_to(limpio[-1]) > 0.05:
			limpio.append(out[i])
			fl.append(flags[i])
	fl.append(fl[-1])
	return [limpio, fl]


# Cinta plana sobre el suelo. UV.x = metros recorridos, UV.y = 0..1 de lado a lado
# Altura del piso bajo un punto de la ruta (adentro el piso está más alto que afuera)
func _piso(p: Vector3) -> float:
	var y := p.y - 0.3
	if y > 0.3:
		return 0.2            # losas de plantas altas / puente
	for e in Campus.EDIFICIOS:
		if Rect2(e[3], e[4], e[5] - e[3], e[6] - e[4]).has_point(Vector2(p.x, p.z)):
			return 0.56
	if Rect2(3.0, 26.0, 6.0, 4.0).has_point(Vector2(p.x, p.z)):
		return 0.56           # pasarela A-B
	return 0.2


func _cinta(pts: Array[Vector3], ancho: float, alto: float, inicio: float = 0.0, sobre_piso: bool = false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var acum := inicio
	var izq: Array[Vector3] = []
	var der: Array[Vector3] = []
	var us: Array[float] = []
	for i in pts.size():
		var t: Vector3
		if i == 0:
			t = pts[1] - pts[0]
		elif i == pts.size() - 1:
			t = pts[i] - pts[i - 1]
		else:
			t = pts[i + 1] - pts[i - 1]
			acum += pts[i].distance_to(pts[i - 1])
		if i == pts.size() - 1:
			acum += pts[i].distance_to(pts[i - 1])
		t.y = 0
		t = t.normalized()
		var n := Vector3(-t.z, 0, t.x) * ancho / 2.0
		var y_base: float = pts[i].y - 0.3 + alto + (_piso(pts[i]) if sobre_piso else 0.0)
		var base := Vector3(pts[i].x, y_base, pts[i].z)
		izq.append(base + n)
		der.append(base - n)
		us.append(acum)
	for i in pts.size() - 1:
		var v := [[izq[i], Vector2(us[i], 0)], [der[i], Vector2(us[i], 1)], [izq[i + 1], Vector2(us[i + 1], 0)],
			[der[i], Vector2(us[i], 1)], [der[i + 1], Vector2(us[i + 1], 1)], [izq[i + 1], Vector2(us[i + 1], 0)]]
		for q in v:
			st.set_uv(q[1])
			st.add_vertex(q[0])
	return st.commit()


func _mat_ruta(color: Color, borde: Color, prioridad: int, flechas: bool, con_profundidad: bool = false) -> ShaderMaterial:
	if _shader_ruta == null:
		_shader_ruta = Shader.new()
		_shader_ruta.code = CODIGO_RUTA
		_shader_ruta_3d = Shader.new()
		_shader_ruta_3d.code = CODIGO_RUTA.replace("depth_test_disabled, ", "")
	var m := ShaderMaterial.new()
	m.shader = _shader_ruta_3d if con_profundidad else _shader_ruta
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("borde", borde)
	m.set_shader_parameter("flechas", 1.0 if flechas else 0.0)
	m.render_priority = prioridad
	return m


const CODIGO_RUTA := """
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, blend_mix;
uniform vec4 color : source_color;
uniform vec4 borde : source_color;
uniform vec4 gris : source_color = vec4(0.66, 0.70, 0.73, 1.0);
uniform float progreso = 0.0;
uniform float flechas = 1.0;
uniform float espacio = 4.5;
uniform float velocidad = 3.0;
void fragment() {
	float e = abs(UV.y - 0.5) * 2.0;            // 0 centro, 1 orilla
	bool hecho = UV.x < progreso;
	vec4 c = hecho ? gris : color;
	vec4 b = hecho ? vec4(gris.rgb * 0.82, gris.a) : borde;
	vec4 col = e > 0.76 ? b : c;
	if (flechas > 0.5 && !hecho) {
		float d = fract((UV.x - TIME * velocidad) / espacio);
		float s = d + e * 0.2;
		float a = smoothstep(0.47, 0.49, s) * (1.0 - smoothstep(0.60, 0.62, s)) * (1.0 - smoothstep(0.58, 0.64, e));
		col.rgb = mix(col.rgb, vec3(1.0), a * 0.95);
	}
	// suavizado de la orilla exterior
	col.a *= 1.0 - smoothstep(0.93, 1.0, e);
	ALBEDO = col.rgb;
	ALPHA = col.a;
}
"""


func marcar_bloqueo(a: Vertex, b: Vertex) -> void:
	for c in bloqueo_nodo.get_children():
		c.queue_free()
	if a == null:
		return
	# Cinta a rayas rojas y blancas (cinta de "prohibido el paso")
	var cinta := MeshInstance3D.new()
	var pts: Array[Vector3] = [a.pos + Vector3(0, 0.3, 0), b.pos + Vector3(0, 0.3, 0)]
	cinta.mesh = _cinta(pts, 2.6, 0.09, 0.0, true)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 rojo : source_color;
void fragment() {
	float raya = step(0.5, fract((UV.x + UV.y * 2.6) / 1.6));
	float e = abs(UV.y - 0.5) * 2.0;
	vec3 c = mix(vec3(1.0), rojo.rgb, raya);
	ALBEDO = e > 0.8 ? rojo.rgb * 0.8 : c;
	ALPHA = 0.95 * (1.0 - smoothstep(0.93, 1.0, e));
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	sm.set_shader_parameter("rojo", Estilo.ROJO)
	sm.render_priority = 11
	cinta.material_override = sm
	bloqueo_nodo.add_child(cinta)
	var medio := (a.pos + b.pos) / 2.0
	var dir := (b.pos - a.pos).normalized()
	var lado := Vector3(-dir.z, 0, dir.x)
	# Barrera de obra
	var m_rojo := _mat(Estilo.ROJO, 0.6)
	var m_blanco := _mat(Color.WHITE, 0.6)
	for s in [-1.0, 1.0]:
		bloqueo_nodo.add_child(_caja(Vector3(0.3, 1.6, 0.3), medio + lado * 2.2 * s + Vector3(0, 0.8, 0), m_blanco))
	var barra := _caja(Vector3(5.0, 0.55, 0.25), medio + Vector3(0, 1.35, 0), m_rojo)
	barra.rotation.y = atan2(lado.x, lado.z) + PI / 2.0
	bloqueo_nodo.add_child(barra)
	var cartel := _cartel("CERRADO", Estilo.ROJO, Color.WHITE, 30, Estilo.F_EXTRA, medio + Vector3(0, 6, 0), 3.4)
	bloqueo_nodo.add_child(cartel)


# ==========================================================
#  Animación por cuadro
# ==========================================================
func _process(delta: float) -> void:
	tiempo += delta
	var s := 1.0 - exp(-delta * 4.5)
	yaw = lerp_angle(yaw, yaw_obj, s)
	pitch = lerpf(pitch, pitch_obj, s)
	distancia = lerpf(distancia, dist_obj, s)
	foco = foco.lerp(foco_obj, s)
	pivot.position = foco
	pivot.rotation = Vector3(-pitch, yaw, 0)
	camara.position = Vector3(0, 0, distancia)

	var pulso := 0.5 + 0.5 * sin(tiempo * 3.0)
	halo.scale = Vector3.ONE * (1.0 + pulso * 0.6)
	halo.transparency = 0.35 + pulso * 0.5
	# Los marcadores de giro se desvanecen cuando estás encima (no tapan tu ubicación)
	for m in marcadores:
		if is_instance_valid(m[0]) and m[0].visible:
			var d := Vector2(usuario.position.x - m[2].x, usuario.position.z - m[2].z).length()
			var alfa := 1.0 if not usuario.visible else clampf((d - 3.0) / 6.0, 0.12, 1.0)
			for h in m[0].get_children():
				if h is Sprite3D:
					h.modulate.a = alfa
	for v in anillos:
		var fuerte: bool = v == zona_destino
		var k := 1.0 + (0.12 if fuerte else 0.04) * sin(tiempo * (5.0 if fuerte else 2.0))
		anillos[v].scale = Vector3(k, 1, k)


func _punto_en(d: float) -> Array:
	for i in ruta_pts.size() - 1:
		var l := ruta_pts[i].distance_to(ruta_pts[i + 1])
		if d <= l:
			return [ruta_pts[i].lerp(ruta_pts[i + 1], d / l), ruta_pts[i + 1] - ruta_pts[i]]
		d -= l
	return [ruta_pts[-1], ruta_pts[-1] - ruta_pts[-2]]


# ==========================================================
#  Gestos: un dedo gira, dos dedos hacen zoom
# ==========================================================
func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed:
			if sobre_ui.call(ev.position):
				return
			toques[ev.index] = ev.position
			toque_ini[ev.index] = ev.position
			if toques.size() == 1:
				arrastro = false
		else:
			if toques.has(ev.index) and toques.size() == 1 and not arrastro:
				_emitir_toque(ev.position)
			toques.erase(ev.index)
			toque_ini.erase(ev.index)
		if toques.size() == 2:
			var p: Array = toques.values()
			pinch_ini = p[0].distance_to(p[1])
			dist_ini = dist_obj
	elif ev is InputEventScreenDrag:
		if not toques.has(ev.index):
			return
		toques[ev.index] = ev.position
		if toques.size() > 1 or ev.position.distance_to(toque_ini.get(ev.index, ev.position)) > 14.0:
			arrastro = true
		if not arrastro:
			return
		if toques.size() == 1:
			yaw_obj -= ev.relative.x * 0.006
			pitch_obj = clampf(pitch_obj + ev.relative.y * 0.004, deg_to_rad(18), deg_to_rad(86))
			yaw = yaw_obj
			pitch = pitch_obj
		elif toques.size() == 2 and pinch_ini > 0:
			var p: Array = toques.values()
			dist_obj = clampf(dist_ini * pinch_ini / maxf(p[0].distance_to(p[1]), 1.0), 30.0, 280.0)
	elif ev is InputEventMagnifyGesture:
		zoom(1.0 / ev.factor)
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(0.9)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(1.1)


func _emitir_toque(pos_pantalla: Vector2) -> void:
	var o := camara.project_ray_origin(pos_pantalla)
	var d := camara.project_ray_normal(pos_pantalla)
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(o, d)
	if hit != null:
		toque.emit(hit)


# Marcadores 3D en cada vértice donde hay que girar (como Waze)
var marcadores: Array = []   # [Sprite3D, Node3D palo, fracción de la ruta]


func marcar_maniobras(items: Array) -> void:
	if primera_persona:
		return   # en primera persona las indicaciones van en el banner
	for it in items:
		var m := _marcador(it[0], it[1], it[2])
		marcadores.append([m, it[3] if it.size() > 3 else 0.0, it[0]])


func _ocultar_pasados(f: float) -> void:
	for m in marcadores:
		if is_instance_valid(m[0]):
			m[0].visible = f < m[1] - 0.01


func _marcador(pos: Vector3, tipo: String, color: Color, tam: int = 160) -> Node3D:
	var grupo := Node3D.new()
	ruta_nodo.add_child(grupo)
	var sv := SubViewport.new()
	sv.size = Vector2i(tam, tam)
	sv.transparent_bg = true
	sv.disable_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(tam / 2)
	sb.corner_detail = 20
	sb.anti_aliasing = true
	sb.border_color = Color.WHITE
	sb.set_border_width_all(int(tam * 0.065))
	panel.add_theme_stylebox_override("panel", sb)
	panel.size = Vector2(tam, tam)
	sv.add_child(panel)
	var ic := Icono.new(tipo, Color.WHITE, tam)
	ic.size = Vector2(tam, tam)
	ic.escala = 0.6
	sv.add_child(ic)
	grupo.add_child(sv)
	var sp := Sprite3D.new()
	sp.texture = sv.get_texture()
	sp.pixel_size = 3.6 / tam
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sp.shaded = false
	sp.no_depth_test = true
	sp.render_priority = 25
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sp.position = pos + Vector3(0, 6.0, 0)
	grupo.add_child(sp)
	grupo.add_child(_caja(Vector3(0.16, 4.0, 0.16), pos + Vector3(0, 2.2, 0), _mat_encima(Color(1, 1, 1, 0.9), 24)))
	grupo.add_child(_disco(pos + Vector3(0, 0.45, 0), 0.55, 0.05, _mat_encima(color, 24)))
	var tw := sp.create_tween().set_loops()
	tw.tween_property(sp, "position:y", pos.y + 6.7, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sp, "position:y", pos.y + 6.0, 0.7).set_trans(Tween.TRANS_SINE)
	return grupo


# ==========================================================
#  Construcción del mundo
# ==========================================================
func _entorno() -> void:
	var cielo := ProceduralSkyMaterial.new()
	cielo.sky_top_color = Color("#6FAEE0")
	cielo.sky_horizon_color = Color("#E3EDF2")
	cielo.ground_horizon_color = Color("#E3EDF2")
	cielo.ground_bottom_color = Color("#D7DEDB")
	cielo.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = cielo

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#DCE6EC")
	env.ambient_light_energy = 0.8
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-48, -38, 0)
	sol.light_color = Color("#FFF2DE")
	sol.light_energy = 1.6
	sol.shadow_enabled = false   # sombras "pintadas": más bonitas y baratas en el celular
	add_child(sol)

	var relleno := DirectionalLight3D.new()
	relleno.rotation_degrees = Vector3(-30, 140, 0)
	relleno.light_color = Color("#CFE2FF")
	relleno.light_energy = 0.35
	add_child(relleno)


func _suelo() -> void:
	add_child(_plano(Vector2(700, 700), Vector3(-10, 0, 55), SUELO))
	# Áreas verdes
	add_child(_plano(Vector2(40, 112), Vector3(-27, 0.01, 46), GRAMA))
	add_child(_plano(Vector2(6.5, 60), Vector3(15.5, 0.01, 60), GRAMA))
	add_child(_plano(Vector2(60, 22), Vector3(-10, 0.01, 112), GRAMA))
	# Plaza Central (piso de adoquín con anillo decorativo)
	var plaza := Vector3(-35, 0, 45)
	add_child(_disco(plaza + Vector3(0, 0.02, 0), 17.0, 0.04, _mat(Color("#F3EFE6"))))
	add_child(_disco(plaza + Vector3(0, 0.03, 0), 13.5, 0.04, _mat(Color("#E4DCCB"))))
	add_child(_disco(plaza + Vector3(0, 0.04, 0), 12.8, 0.04, _mat(Color("#F3EFE6"))))


func _vias_y_parqueos() -> void:
	var asfalto := _mat(ASFALTO, 0.95)
	var linea := _mat(Color("#FFFFFF"), 0.8)
	# Calles norte y sur
	add_child(_caja(Vector3(190, 0.06, 9), Vector3(-15, 0.03, -16), asfalto))
	add_child(_caja(Vector3(190, 0.06, 9), Vector3(-15, 0.03, 131), asfalto))
	for x in range(-105, 80, 8):
		add_child(_caja(Vector3(3.5, 0.07, 0.25), Vector3(x, 0.04, -16), linea))
		add_child(_caja(Vector3(3.5, 0.07, 0.25), Vector3(x, 0.04, 131), linea))
	# Parqueo oeste con líneas y carros
	add_child(_caja(Vector3(26, 0.06, 126), Vector3(-66, 0.03, 57), asfalto))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var colores := [Color("#E9ECEE"), Color("#3C4A57"), Color("#C2423A"), Color("#2D6CB5"), Color("#F5F5F2"), Color("#8E989E"), Color("#1F2A33")]
	for fila in [-73.0, -59.0]:
		for z in range(0, 116, 3):
			add_child(_caja(Vector3(5.2, 0.07, 0.14), Vector3(fila, 0.04, z), linea))
			if rng.randf() < 0.42 and z < 113:
				_carro(Vector3(fila, 0, z + 1.5), colores[rng.randi() % colores.size()], rng)


func _carro(pos: Vector3, color: Color, rng: RandomNumberGenerator) -> void:
	var m := _mat(color, 0.35, 0.2)
	var vidrio := _mat(Color("#25333D"), 0.2, 0.4)
	var giro := rng.randf_range(-0.06, 0.06)
	var cuerpo := _caja(Vector3(4.2, 0.8, 1.85), pos + Vector3(0, 0.55, 0), m)
	cuerpo.rotation.y = giro
	add_child(cuerpo)
	var cabina := _caja(Vector3(2.3, 0.6, 1.6), pos + Vector3(-0.2, 1.2, 0), vidrio)
	cabina.rotation.y = giro
	add_child(cabina)


func _pasillos() -> void:
	var m := _mat(ACERA, 0.9)
	for e in mapa.aristas():
		if e[0].pos.y < 0.5 and e[1].pos.y < 0.5:
			add_child(_segmento(e[0].pos, e[1].pos, 3.4, m, 0.05))
	for v in mapa.vertexs:
		if v.pos.y < 0.5:
			add_child(_disco(v.pos + Vector3(0, 0.05, 0), 1.7, 0.1, m))


func _edificio(x1: float, z1: float, x2: float, z2: float, h: float, plantas: int,
		pared: Color, techo: Color, vidrio: Color, detallado: bool) -> void:
	var w := x2 - x1
	var d := z2 - z1
	var c := Vector3((x1 + x2) / 2.0, 0, (z1 + z2) / 2.0)
	var hp := h / plantas
	# base: siempre visible | muros: se "cortan" | superior: se oculta en vista interior
	var base := Node3D.new()
	var muros := Node3D.new()
	var superior := Node3D.new()
	add_child(base)
	add_child(muros)
	add_child(superior)

	_sombra(Rect2(x1, z1, w, d), h)
	base.add_child(_caja(Vector3(w + 0.9, 0.5, d + 0.9), c + Vector3(0, 0.25, 0), _mat(ZOCALO)))
	if detallado:
		base.add_child(_caja(Vector3(w, 0.06, d), c + Vector3(0, 0.53, 0), _mat(Color("#FBF8F2"))))
	else:
		muros.add_child(_caja(Vector3(w, h, d), c + Vector3(0, h / 2.0, 0), _mat(pared)))
	# Cada planta es una "rebanada" (muros con puertas, aulas, ventanas, losa).
	# La vista interior solo oculta las plantas de arriba: nada se deforma.
	var por_planta: Array[Node3D] = []
	for k in plantas:
		var nodo := Node3D.new()
		base.add_child(nodo)
		por_planta.append(nodo)
		if detallado:
			_muros_planta(nodo, Rect2(x1, z1, w, d), k, hp, _mat(pared))
		if k > 0:
			_anillo(nodo, c, w + 0.35, d + 0.35, hp * k, 0.28, 0.9, _mat(CORNISA))
			if detallado:
				# Losa del piso, con hueco donde están las escaleras
				var za := z1 + 0.5
				var zb := z2 - 0.5
				for esc in Campus.ESCALERAS:
					if esc[1] > x1 and esc[1] < x2:
						if esc[3] < esc[2]:
							za = maxf(za, esc[2])
						else:
							zb = minf(zb, esc[2])
				nodo.add_child(_caja(Vector3(w - 1.0, 0.3, zb - za), Vector3(c.x, hp * k + 0.05, (za + zb) / 2.0), _mat(Color("#FBF8F2"))))
	superior.add_child(_caja(Vector3(w + 0.5, 0.45, d + 0.5), c + Vector3(0, h, 0), _mat(CORNISA)))

	# Ventanas por planta (MultiMesh: muchas ventanas, una sola llamada de dibujo)
	var paso := 3.2
	var ventana := BoxMesh.new()
	ventana.size = Vector3(1.8, hp * 0.48, 0.14)
	var alfeizar := BoxMesh.new()
	alfeizar.size = Vector3(2.1, 0.14, 0.3)
	for k in plantas:
		var trans: Array[Transform3D] = []
		var y := hp * k + hp * 0.56
		var nx := int((w - 2.0) / paso)
		for i in nx:
			var x := x1 + (w - (nx - 1) * paso) / 2.0 + i * paso
			if not _hay_puerta(Vector3(x, k * hp, z1), Vector3(0, 0, -1), hp):
				trans.append(Transform3D(Basis(), Vector3(x, y, z1 - 0.04)))
			if not _hay_puerta(Vector3(x, k * hp, z2), Vector3(0, 0, 1), hp):
				trans.append(Transform3D(Basis(), Vector3(x, y, z2 + 0.04)))
		var nz := int((d - 2.0) / paso)
		for i in nz:
			var z := z1 + (d - (nz - 1) * paso) / 2.0 + i * paso
			if not _hay_puerta(Vector3(x1, k * hp, z), Vector3(-1, 0, 0), hp):
				trans.append(Transform3D(Basis().rotated(Vector3.UP, PI / 2.0), Vector3(x1 - 0.04, y, z)))
			if not _hay_puerta(Vector3(x2, k * hp, z), Vector3(1, 0, 0), hp):
				trans.append(Transform3D(Basis().rotated(Vector3.UP, PI / 2.0), Vector3(x2 + 0.04, y, z)))
		var destino: Node3D = por_planta[k]
		destino.add_child(_multimalla(ventana, _mat(vidrio, 0.12, 0.35 if detallado else 0.0), trans))
		if detallado:
			var t2: Array[Transform3D] = []
			for t in trans:
				t2.append(Transform3D(t.basis, t.origin - Vector3(0, hp * 0.26, 0)))
			destino.add_child(_multimalla(alfeizar, _mat(Color.WHITE, 0.7), t2))

	superior.add_child(_techo(x1, z1, x2, z2, h + 0.22, minf(w, d) * 0.26, techo))
	if detallado:
		_aulas(Rect2(x1, z1, w, d), hp, por_planta)
		for esc in Campus.ESCALERAS:
			if esc[1] > x1 and esc[1] < x2:
				_escalera(esc, plantas, hp, por_planta)
		edificios.append({"rect": Rect2(x1, z1, w, d), "muros": muros, "superior": superior, "h": h, "hp": hp,
			"por_planta": por_planta, "cortado": 0})


# Puente techado entre B y C (planta 2) con escalera que baja al patio
func _puente() -> void:
	var y := Campus.PUENTE_Y
	var z := Campus.PUENTE_Z
	var x1 := Campus.PUENTE_X1
	var x2 := Campus.PUENTE_X2
	var cx := (x1 + x2) / 2.0
	var ancho := 3.2
	var m_losa := _mat(Color("#E6E0D4"))
	var m_vidrio := _mat(Color("#A9CFE0"), 0.2, 0.2)
	var m_col := _mat(Color("#D9D3C7"))
	add_child(_caja(Vector3(x2 - x1, 0.4, ancho), Vector3(cx, y - 0.2, z), m_losa))
	# columnas a los lados del paso de planta baja
	for xc in [x1 + 1.2, x2 - 1.2]:
		for zc in [z - ancho / 2 + 0.25, z + ancho / 2 - 0.25]:
			add_child(_caja(Vector3(0.35, y - 0.4, 0.35), Vector3(xc, (y - 0.4) / 2.0, zc), m_col))
	# barandas (con hueco donde baja la escalera)
	var esc_a: Vector3 = Campus.PUENTE_ESCALERA[0]
	var esc_b: Vector3 = Campus.PUENTE_ESCALERA[1]
	add_child(_caja(Vector3(x2 - x1, 1.0, 0.08), Vector3(cx, y + 0.5, z - ancho / 2 + 0.04), m_vidrio))
	var hueco := 1.1
	add_child(_caja(Vector3(esc_a.x - hueco - x1, 1.0, 0.08), Vector3((x1 + esc_a.x - hueco) / 2.0, y + 0.5, z + ancho / 2 - 0.04), m_vidrio))
	add_child(_caja(Vector3(x2 - esc_a.x - hueco, 1.0, 0.08), Vector3((x2 + esc_a.x + hueco) / 2.0, y + 0.5, z + ancho / 2 - 0.04), m_vidrio))
	# escalera recta del puente al patio
	var nodo := Node3D.new()
	add_child(nodo)
	var escalones: Array[Transform3D] = []
	var tonos: Array[Color] = []
	_tramo(Vector3(esc_a.x, y, z + ancho / 2), Vector3(esc_b.x, 0.0, esc_b.z), nodo, escalones, tonos, 1.8)
	var cubo := BoxMesh.new()
	cubo.size = Vector3.ONE
	var m := _mat(Color.WHITE, 0.8)
	m.vertex_color_use_as_albedo = true
	nodo.add_child(_multimalla(cubo, m, escalones, tonos))


# Un tramo de escalera recto de a hasta b (escalones, viga y barandas)
func _tramo(a: Vector3, b: Vector3, nodo: Node3D, escalones: Array[Transform3D], tonos: Array[Color], ancho: float = 1.9) -> void:
	var n := maxi(8, roundi(absf(b.y - a.y) / 0.17))
	var paso := (b - a) / n
	var sube := paso.y > 0
	for k in n:
		var alto := absf(paso.y) + 0.16
		var top := (a.y + paso.y * (k + 1)) if sube else (a.y + paso.y * k)
		var centro := Vector3(a.x + paso.x * (k + 0.5), top - alto / 2.0, a.z + paso.z * (k + 0.5))
		escalones.append(Transform3D(Basis().scaled(Vector3(ancho, alto, absf(paso.z) + 0.03)), centro))
		tonos.append(Color("#D8CCB6") if k % 2 == 0 else Color("#B7A88F"))
	nodo.add_child(_viga(a - Vector3(0, 0.25, 0), b - Vector3(0, 0.25, 0), Vector3(ancho, 0.22, 0), _mat(Color("#C7BFB0"), 0.8)))
	for lado in [-1.0, 1.0]:
		var o := Vector3(lado * (ancho / 2.0 + 0.03), 0.55, 0)
		nodo.add_child(_viga(a + o, b + o, Vector3(0.06, 1.0, 0), _mat(Color("#A9CFE0"), 0.2, 0.2)))


# Caja de escaleras: por cada cambio de planta, tramo + descanso + tramo
# (mismas posiciones que los vértices de escalera del grafo)
func _escalera(esc: Array, plantas: int, hp: float, por_planta: Array[Node3D]) -> void:
	var x: float = esc[1]
	var z_piso: float = esc[2]
	var z_desc: float = esc[3]
	var dx := Campus.SEPARACION_TRAMOS
	var m_escalon := _mat(Color.WHITE, 0.8)
	m_escalon.vertex_color_use_as_albedo = true
	var m_descanso := _mat(Color("#C9BCA6"), 0.8)
	var m_viga := _mat(Color("#C7BFB0"), 0.8)
	var m_vidrio := _mat(Color("#A9CFE0"), 0.2, 0.2)
	var hacia := signf(z_desc - z_piso)
	for f in range(1, plantas):
		var nodo: Node3D = por_planta[f]
		var y0 := (f - 1) * hp
		var y1 := f * hp
		var ym := (y0 + y1) / 2.0
		var escalones: Array[Transform3D] = []
		var tonos: Array[Color] = []
		_tramo(Vector3(x + dx, y0, z_piso), Vector3(x + dx, ym, z_desc), nodo, escalones, tonos, dx * 1.5)
		_tramo(Vector3(x - dx, ym, z_desc), Vector3(x - dx, y1, z_piso), nodo, escalones, tonos, dx * 1.5)
		var cubo := BoxMesh.new()
		cubo.size = Vector3.ONE
		nodo.add_child(_multimalla(cubo, m_escalon, escalones, tonos))
		# descanso a media altura
		nodo.add_child(_caja(Vector3(dx * 4, 0.25, 1.8), Vector3(x, ym - 0.125, z_desc + hacia * 0.9), m_descanso))
		# muro central entre los dos tramos
		nodo.add_child(_caja(Vector3(0.2, hp, absf(z_desc - z_piso)), Vector3(x, y0 + hp / 2.0, (z_desc + z_piso) / 2.0), _mat(Color("#E4DDD0"))))


# Borde perimetral (cornisa) sin tapar el interior
func _anillo(padre: Node3D, c: Vector3, w: float, d: float, y: float, alto: float, grosor: float, m: Material) -> void:
	padre.add_child(_caja(Vector3(w, alto, grosor), Vector3(c.x, y, c.z - d / 2 + grosor / 2), m))
	padre.add_child(_caja(Vector3(w, alto, grosor), Vector3(c.x, y, c.z + d / 2 - grosor / 2), m))
	padre.add_child(_caja(Vector3(grosor, alto, d), Vector3(c.x - w / 2 + grosor / 2, y, c.z), m))
	padre.add_child(_caja(Vector3(grosor, alto, d), Vector3(c.x + w / 2 - grosor / 2, y, c.z), m))


func _viga(a: Vector3, b: Vector3, seccion: Vector3, m: Material) -> MeshInstance3D:
	var dir := b - a
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(seccion.x, seccion.y, dir.length())
	mi.mesh = bm
	mi.material_override = m
	mi.transform = Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), (a + b) / 2.0)
	return mi


# Aulas dentro del edificio: piso de color y muros delgados (un MultiMesh)
func _aulas(huella: Rect2, hp: float, por_planta: Array[Node3D]) -> void:
	var cubo := BoxMesh.new()
	cubo.size = Vector3.ONE
	var plano := PlaneMesh.new()
	plano.size = Vector2(1, 1)
	var g := 0.2
	for k in por_planta.size():
		var y0 := k * hp
		var piso := 0.565 if k == 0 else y0 + 0.21
		var pisos: Array[Transform3D] = []
		var paredes: Array[Transform3D] = []
		for a in Campus.AULAS:
			var r := Rect2(a[0], a[1], a[2] - a[0], a[3] - a[1])
			if not huella.grow(0.1).encloses(r):
				continue
			var cx := r.get_center().x
			var cz := r.get_center().y
			var yc := y0 + hp / 2.0
			pisos.append(Transform3D(Basis().scaled(Vector3(r.size.x - 0.6, 1, r.size.y - 0.6)), Vector3(cx, piso, cz)))
			paredes.append(Transform3D(Basis().scaled(Vector3(r.size.x, hp, g)), Vector3(cx, yc, r.position.y + g / 2)))
			paredes.append(Transform3D(Basis().scaled(Vector3(r.size.x, hp, g)), Vector3(cx, yc, r.end.y - g / 2)))
			paredes.append(Transform3D(Basis().scaled(Vector3(g, hp, r.size.y)), Vector3(r.position.x + g / 2, yc, cz)))
			paredes.append(Transform3D(Basis().scaled(Vector3(g, hp, r.size.y)), Vector3(r.end.x - g / 2, yc, cz)))
		por_planta[k].add_child(_multimalla(plano, _mat(Color("#EDE5D6")), pisos))
		por_planta[k].add_child(_multimalla(cubo, _mat(Color("#E4DDD0")), paredes))


# Muros exteriores de una planta, con aberturas reales donde hay puertas
func _muros_planta(nodo: Node3D, r: Rect2, k: int, hp: float, m: Material) -> void:
	var g := 0.5
	var y0 := k * hp
	var lados := [
		["x", r.position.y + g / 2, r.position.x, r.end.x, Vector3(0, 0, -1)],
		["x", r.end.y - g / 2, r.position.x, r.end.x, Vector3(0, 0, 1)],
		["z", r.position.x + g / 2, r.position.y, r.end.y, Vector3(-1, 0, 0)],
		["z", r.end.x - g / 2, r.position.y, r.end.y, Vector3(1, 0, 0)],
	]
	for lado in lados:
		var huecos := []
		for ab in Campus.aberturas():
			var p: Vector3 = ab[0]
			var n: Vector3 = ab[1]
			if n.distance_to(lado[4]) > 0.1 or roundi(p.y / hp) != k:
				continue
			var fijo: float = p.z if lado[0] == "x" else p.x
			var a_lo_largo: float = p.x if lado[0] == "x" else p.z
			var borde: float = lado[1] + g / 2.0 * (n.x + n.z)
			if absf(fijo - borde) < 0.8 and a_lo_largo > lado[2] and a_lo_largo < lado[3]:
				huecos.append(a_lo_largo)
		huecos.sort()
		var cursor: float = lado[2]
		var mitad := Campus.ANCHO_PUERTA / 2.0
		for hc in huecos:
			_pieza_muro(nodo, lado, cursor, hc - mitad, y0, hp, g, m)
			_pieza_muro(nodo, lado, hc - mitad, hc + mitad, y0 + Campus.ALTO_PUERTA + (0.56 if k == 0 else 0.2), hp - Campus.ALTO_PUERTA - (0.56 if k == 0 else 0.2), g, m)
			cursor = hc + mitad
		_pieza_muro(nodo, lado, cursor, lado[3], y0, hp, g, m)


func _hay_puerta(p: Vector3, normal: Vector3, hp: float) -> bool:
	for ab in Campus.aberturas():
		var q: Vector3 = ab[0]
		if (ab[1] as Vector3).distance_to(normal) < 0.1 and roundi(q.y / hp) == roundi(p.y / hp) \
				and Vector2(q.x, q.z).distance_to(Vector2(p.x, p.z)) < Campus.ANCHO_PUERTA / 2.0 + 1.0:
			return true
	return false


func _pieza_muro(nodo: Node3D, lado: Array, desde: float, hasta: float, y0: float, alto: float, g: float, m: Material) -> void:
	if hasta - desde < 0.05 or alto < 0.05:
		return
	var largo := hasta - desde
	var medio := (desde + hasta) / 2.0
	if lado[0] == "x":
		nodo.add_child(_caja(Vector3(largo, alto, g), Vector3(medio, y0 + alto / 2.0, lado[1]), m))
	else:
		nodo.add_child(_caja(Vector3(g, alto, largo), Vector3(lado[1], y0 + alto / 2.0, medio), m))


# Sombra suave proyectada (hacia el sureste, como el sol de la escena)
func _sombra(r: Rect2, h: float) -> void:
	var desp := Vector3(0.55, 0, 0.45) * h
	for i in 3:
		var crece := 1.0 + i * 1.2
		var p := _plano(Vector2(r.size.x + crece * 2, r.size.y + crece * 2),
			Vector3(r.get_center().x, 0.025 + i * 0.004, r.get_center().y) + desp * (0.6 + i * 0.25), Color.BLACK)
		p.material_override = _mat_sombra(0.09)
		add_child(p)


func _mat_sombra(alfa: float) -> StandardMaterial3D:
	var clave := "sombra%s" % alfa
	if _mats.has(clave):
		return _mats[clave]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.16, 0.18, alfa)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[clave] = m
	return m


func _techo(x1: float, z1: float, x2: float, z2: float, y: float, sube: float, color: Color) -> MeshInstance3D:
	var o := 1.0
	x1 -= o; z1 -= o; x2 += o; z2 += o
	var cx := (x1 + x2) / 2.0
	var cz := (z1 + z2) / 2.0
	var p1 := Vector3(x1, y, z1)
	var p2 := Vector3(x2, y, z1)
	var p3 := Vector3(x2, y, z2)
	var p4 := Vector3(x1, y, z2)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	if (z2 - z1) >= (x2 - x1):
		var m := (x2 - x1) / 2.0
		var r1 := Vector3(cx, y + sube, z1 + m)
		var r2 := Vector3(cx, y + sube, z2 - m)
		_tri(st, p1, p2, r1); _tri(st, p3, p4, r2)
		_tri(st, p2, p3, r2); _tri(st, p2, r2, r1)
		_tri(st, p4, p1, r1); _tri(st, p4, r1, r2)
	else:
		var m := (z2 - z1) / 2.0
		var r1 := Vector3(x1 + m, y + sube, cz)
		var r2 := Vector3(x2 - m, y + sube, cz)
		_tri(st, p4, p1, r1); _tri(st, p2, p3, r2)
		_tri(st, p1, p2, r2); _tri(st, p1, r2, r1)
		_tri(st, p3, p4, r1); _tri(st, p3, r1, r2)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mt := _mat(color, 0.75)
	mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mt
	return mi


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


func _pasarela() -> void:
	# Pasillo techado y hueco que une A con B (se puede caminar por dentro)
	add_child(_caja(Vector3(5.4, 0.56, 4.2), Vector3(6, 0.28, 28), _mat(Color("#FBF8F2"))))
	add_child(_caja(Vector3(6.4, 0.3, 4.6), Vector3(6, 3.6, 28), _mat(CORNISA)))
	for xs in [3.15, 8.85]:
		add_child(_caja(Vector3(0.3, 3.1, 4.0), Vector3(xs, 2.05, 28), _mat(PARED)))


func _puerta(pos: Vector3, normal: Vector3) -> void:
	var rot := atan2(normal.x, normal.z)
	# Marco de la puerta (la abertura es real: el muro tiene el hueco)
	var marco := Node3D.new()
	marco.position = pos + Vector3(0, 0.56 if pos.y < 0.5 else 0.2, 0)
	marco.rotation.y = rot
	add_child(marco)
	var mm := _mat(Color("#3B4A55"), 0.4, 0.2)
	var mitad := Campus.ANCHO_PUERTA / 2.0
	for sx in [-1.0, 1.0]:
		marco.add_child(_caja(Vector3(0.14, Campus.ALTO_PUERTA, 0.62), Vector3(sx * (mitad + 0.07), Campus.ALTO_PUERTA / 2.0, 0), mm))
	marco.add_child(_caja(Vector3(Campus.ANCHO_PUERTA + 0.28, 0.14, 0.62), Vector3(0, Campus.ALTO_PUERTA + 0.07, 0), mm))
	if pos.y > 0.5:
		return   # puertas al puente: sin alero (taparía el puente)
	var alero := _caja(Vector3(4.2, 0.25, 2.2), pos + normal * 1.0 + Vector3(0, 3.1, 0), _mat(Color.WHITE, 0.6))
	alero.rotation.y = rot
	add_child(alero)


func _insignia(letra: String, color: Color, nombre: String, pos: Vector3, principal: bool) -> void:
	add_child(_cartel(letra, color, Color.WHITE, 60, Estilo.F_EXTRA, pos, 8.5 if principal else 5.4, true))
	if nombre != "":
		add_child(_cartel(nombre, Color.WHITE, Estilo.TINTA, 30, Estilo.F_NEGRITA, pos - Vector3(0, 6.4, 0), 4.2))


func _zonas() -> void:
	var tex := Estilo.textura_lineas(160, [[Vector2(0.3, 0.52), Vector2(0.44, 0.66)], [Vector2(0.44, 0.66), Vector2(0.71, 0.37)]],
		15.0, Color.WHITE, Estilo.VERDE, Color.WHITE)
	for v in mapa.vertexs:
		if not v.segura:
			continue
		add_child(_disco(v.pos + Vector3(0, 0.06, 0), 10.5, 0.06, _mat(Color("#E4F4E8"))))
		var anillo := MeshInstance3D.new()
		var toro := TorusMesh.new()
		toro.inner_radius = 8.4
		toro.outer_radius = 9.6
		toro.rings = 48
		anillo.mesh = toro
		var m := _mat(Estilo.VERDE, 0.5)
		m.emission_enabled = true
		m.emission = Estilo.VERDE
		m.emission_energy_multiplier = 0.4
		anillo.material_override = m
		anillo.position = v.pos + Vector3(0, 0.1, 0)
		anillo.scale = Vector3(1, 0.25, 1)
		add_child(anillo)
		anillos[v] = anillo

		add_child(_caja(Vector3(0.28, 7.5, 0.28), v.pos + Vector3(0, 3.75, 0), _mat(Color("#F5F7F8"), 0.4, 0.3)))
		var senal := Sprite3D.new()
		senal.texture = tex
		senal.pixel_size = 0.036
		senal.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		senal.shaded = false
		senal.position = v.pos + Vector3(0, 9.6, 0)
		add_child(senal)
		add_child(_cartel("ZONA SEGURA", Estilo.VERDE, Color.WHITE, 30, Estilo.F_EXTRA, v.pos + Vector3(0, 18.0, 0), 4.6))
		add_child(_cartel(v.city, Color.WHITE, Estilo.TINTA, 28, Estilo.F_NEGRITA, v.pos + Vector3(0, 13.4, 0), 3.9))


func _arboles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var lugares: Array[Vector3] = []
	for z in range(-6, 100, 7):
		lugares.append(Vector3(-9, 0, z))
		lugares.append(Vector3(-49, 0, z + 3))
	for z in range(33, 90, 6):
		lugares.append(Vector3(15.5, 0, z))
	for x in range(-48, 36, 7):
		lugares.append(Vector3(x, 0, -9))
		lugares.append(Vector3(x + 3, 0, 124))
	for i in 12:
		var a := TAU * i / 12.0
		lugares.append(Vector3(-35, 0, 45) + Vector3(cos(a), 0, sin(a)) * 20.0)
	for i in 9:
		var a := TAU * i / 9.0 + 0.3
		lugares.append(Vector3(-15, 0, 116) + Vector3(cos(a), 0, sin(a)) * 14.0)

	var troncos: Array[Transform3D] = []
	var copas: Array[Transform3D] = []
	var colores: Array[Color] = []
	var verdes := [Color("#6FA85E"), Color("#5C9A52"), Color("#82B56A"), Color("#4F8C4A")]
	for p in lugares:
		if _ocupado(p):
			continue
		var s := rng.randf_range(0.85, 1.3)
		troncos.append(Transform3D(Basis().scaled(Vector3(1, s, 1)), p + Vector3(0, 1.1 * s, 0)))
		var b := Basis().rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s))
		copas.append(Transform3D(b, p + Vector3(0, 3.6 * s, 0)))
		colores.append(verdes[rng.randi() % verdes.size()])

	var sombras: Array[Transform3D] = []
	for t in copas:
		sombras.append(Transform3D(Basis().scaled(Vector3(t.basis.get_scale().x, 1, t.basis.get_scale().x)), Vector3(t.origin.x + 1.6, 0.03, t.origin.z + 1.3)))
	var disco := CylinderMesh.new()
	disco.top_radius = 2.3
	disco.bottom_radius = 2.3
	disco.height = 0.01
	disco.radial_segments = 20
	add_child(_multimalla(disco, _mat_sombra(0.16), sombras))

	var tronco := CylinderMesh.new()
	tronco.top_radius = 0.22
	tronco.bottom_radius = 0.32
	tronco.height = 2.2
	tronco.radial_segments = 6
	add_child(_multimalla(tronco, _mat(Color("#7A5A44")), troncos))
	var copa := SphereMesh.new()
	copa.radius = 2.4
	copa.height = 4.2
	copa.radial_segments = 7
	copa.rings = 4
	var mc := _mat(Color.WHITE, 0.9)
	mc.vertex_color_use_as_albedo = true
	add_child(_multimalla(copa, mc, copas, colores))


func _ocupado(p: Vector3) -> bool:
	for e in mapa.aristas():
		var q := Geometry3D.get_closest_point_to_segment(p, e[0].pos, e[1].pos)
		if p.distance_to(q) < 4.0:
			return true
	for v in mapa.vertexs:
		if v.segura and p.distance_to(v.pos) < 11.5:
			return true
	for e in Campus.EDIFICIOS:
		if Rect2(e[3] - 2.5, e[4] - 2.5, e[5] - e[3] + 5, e[6] - e[4] + 5).has_point(Vector2(p.x, p.z)):
			return true
	for c in Campus.CONTEXTO:
		if Rect2(c[1] - 2.5, c[2] - 2.5, c[3] - c[1] + 5, c[4] - c[2] + 5).has_point(Vector2(p.x, p.z)):
			return true
	return false


func _usuario() -> void:
	usuario = Node3D.new()
	usuario.visible = false
	add_child(usuario)
	halo = _disco(Vector3(0, 0.5, 0), 3.6, 0.05, _mat_encima(Color(Estilo.AZUL, 0.3), 10))
	usuario.add_child(halo)
	usuario.add_child(_disco(Vector3(0, 0.6, 0), 2.0, 0.3, _mat_encima(Color.WHITE, 31)))
	usuario.add_child(_disco(Vector3(0, 0.65, 0), 1.45, 0.32, _mat_encima(Estilo.AZUL, 32)))
	var flecha := MeshInstance3D.new()
	flecha.mesh = _malla_flecha(1.5)
	flecha.material_override = _mat_encima(Color.WHITE, 33)
	flecha.position = Vector3(0, 0.9, 0)
	usuario.add_child(flecha)


func _camara() -> void:
	pivot = Node3D.new()
	add_child(pivot)
	camara = Camera3D.new()
	camara.fov = 42
	camara.near = 0.5
	camara.far = 2000
	pivot.add_child(camara)
	pivot.position = foco
	pivot.rotation = Vector3(-pitch, yaw, 0)
	camara.position = Vector3(0, 0, distancia)


# ==========================================================
#  Utilidades
# ==========================================================
func _mat(color: Color, rugosidad: float = 0.85, metal: float = 0.0) -> StandardMaterial3D:
	var clave := "%s|%s|%s" % [color.to_html(), rugosidad, metal]
	if _mats.has(clave):
		return _mats[clave]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rugosidad
	m.metallic = metal
	_mats[clave] = m
	return m


# Material que se dibuja por encima de todo (ruta, tu ubicación)
func _mat_encima(color: Color, prioridad: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.render_priority = prioridad
	return m


func _caja(tam: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	return mi


func _plano(tam: Vector2, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = tam
	mi.mesh = pm
	mi.material_override = _mat(color, 1.0)
	mi.position = pos
	return mi


func _disco(pos: Vector3, radio: float, alto: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radio
	cm.bottom_radius = radio
	cm.height = alto
	cm.radial_segments = 40
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	return mi


func _segmento(a: Vector3, b: Vector3, ancho: float, m: Material, y: float = 0.0) -> MeshInstance3D:
	var dir := b - a
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(ancho, 0.3, dir.length())
	mi.mesh = bm
	mi.material_override = m
	mi.transform = Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), (a + b) / 2.0 + Vector3(0, y, 0))
	return mi


func _multimalla(malla: Mesh, m: Material, trans: Array[Transform3D], colores: Array[Color] = []) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colores.is_empty()
	mm.mesh = malla
	mm.instance_count = trans.size()
	for i in trans.size():
		mm.set_instance_transform(i, trans[i])
		if mm.use_colors:
			mm.set_instance_color(i, colores[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	return mmi


func _malla_flecha(tam: float = 1.0) -> ArrayMesh:
	# Punta de flecha (chevron) plana, apunta hacia -Z
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(0, 0, -0.75) * tam
	var b := Vector3(0.65, 0, 0.45) * tam
	var c := Vector3(0, 0, 0.1) * tam
	var d := Vector3(-0.65, 0, 0.45) * tam
	_tri(st, a, b, c)
	_tri(st, a, c, d)
	return st.commit()


# Cartel tipo "píldora" (texto renderizado una vez en un SubViewport)
func _cartel(texto: String, fondo: Color, color_txt: Color, tam: int, fuente: Font, pos: Vector3,
		alto_mundo: float, cuadrado: bool = false) -> Sprite3D:
	var t := tam * 2
	var ancho := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, t).x
	var alto := fuente.get_height(t)
	var sz := Vector2i(int(ancho) + t, int(alto) + int(t * 0.55))
	if cuadrado:
		var lado := maxi(sz.x, sz.y)
		sz = Vector2i(lado, lado)
	var sv := SubViewport.new()
	sv.size = sz
	sv.transparent_bg = true
	sv.disable_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.set_corner_radius_all(int(sz.y * (0.26 if cuadrado else 0.5)))
	sb.corner_detail = 16
	sb.anti_aliasing = true
	if fondo == Color.WHITE:
		sb.border_color = Color("#DCE3E6")
		sb.set_border_width_all(3)
	panel.add_theme_stylebox_override("panel", sb)
	panel.size = sz
	sv.add_child(panel)
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", fuente)
	l.add_theme_font_size_override("font_size", t)
	l.add_theme_color_override("font_color", color_txt)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = sz
	sv.add_child(l)
	add_child(sv)

	var sp := Sprite3D.new()
	sp.texture = sv.get_texture()
	sp.pixel_size = alto_mundo / sz.y
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sp.shaded = false
	sp.no_depth_test = true
	sp.render_priority = 20
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sp.position = pos
	sp.add_to_group("etiquetas")
	return sp


func _etiqueta(texto: String, tam: int, color: Color, borde: Color, pos: Vector3, grosor: int,
		fuente: Font = null) -> Label3D:
	var l := Label3D.new()
	l.text = texto
	l.font = fuente if fuente else Estilo.F_NEGRITA
	l.font_size = tam
	l.pixel_size = 0.04
	l.modulate = color
	l.outline_size = grosor
	l.outline_modulate = borde
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 20
	l.outline_render_priority = 19
	l.position = pos
	l.add_to_group("etiquetas")
	return l
