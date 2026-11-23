# ==========================================================
#  RutasSeguras - Sistema visual (colores, fuentes, estilos)
# ==========================================================
class_name Estilo
extends RefCounted

const TEAL := Color("#13A38B")
const TEAL_CLARO := Color("#E3F5F1")
const TINTA := Color("#17232B")
const TENUE := Color("#6E7F88")
const LINEA := Color("#E6EBED")
const GRIS_BOTON := Color("#EEF2F3")
const ROJO := Color("#E5383B")
const AZUL := Color("#2F6BFF")
const VERDE := Color("#1E9E5A")
const AMBAR := Color("#F2A900")
const NOCHE := Color("#16212B")

const F_MEDIA = preload("res://fonts/Inter-Medium.woff2")
const F_NEGRITA = preload("res://fonts/Inter-Bold.woff2")
const F_EXTRA = preload("res://fonts/Inter-ExtraBold.woff2")


static func caja(color: Color, radio: int = 28, sombra: bool = true, margen: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radio)
	sb.corner_detail = 12
	sb.anti_aliasing = true
	if sombra:
		sb.shadow_color = Color(0.04, 0.09, 0.12, 0.18)
		sb.shadow_size = 24
		sb.shadow_offset = Vector2(0, 8)
	sb.set_content_margin_all(margen)
	return sb


static func texto(t: String, tam: int, fuente: Font = null, color: Color = TINTA) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", fuente if fuente else F_MEDIA)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	return l


static func boton(t: String, fondo: Color, color_txt: Color, tam: int, radio: int = 24) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_override("font", F_NEGRITA)
	b.add_theme_font_size_override("font_size", tam)
	for s in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(s, color_txt)
	b.add_theme_stylebox_override("normal", caja(fondo, radio, false))
	b.add_theme_stylebox_override("hover", caja(fondo.lightened(0.06), radio, false))
	b.add_theme_stylebox_override("pressed", caja(fondo.darkened(0.12), radio, false))
	b.add_theme_stylebox_override("hover_pressed", caja(fondo.darkened(0.12), radio, false))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


# Botón redondo con un ícono dibujado
static func boton_icono(tipo: String, fondo: Color, color_icono: Color, tam: int, sombra: bool = true) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(tam, tam)
	var r := int(tam / 2.0)
	b.add_theme_stylebox_override("normal", caja(fondo, r, sombra))
	b.add_theme_stylebox_override("hover", caja(fondo.darkened(0.03), r, sombra))
	b.add_theme_stylebox_override("pressed", caja(fondo.darkened(0.1), r, sombra))
	b.add_theme_stylebox_override("hover_pressed", caja(fondo.darkened(0.1), r, sombra))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ic := Icono.new(tipo, color_icono, tam)
	ic.escala = 0.5
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(ic)
	return b


static func separador() -> Control:
	var c := ColorRect.new()
	c.color = LINEA
	c.custom_minimum_size = Vector2(0, 2)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func chip(t: String, fondo: Color, color_txt: Color, tam: int = 17) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := caja(fondo, 10, false)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(texto(t, tam, F_EXTRA, color_txt))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


# Tema global: fuente Inter, menús desplegables limpios.
static func tema() -> Theme:
	var t := Theme.new()
	t.default_font = F_MEDIA
	t.default_font_size = 24

	var menu := caja(Color.WHITE, 22, true, 12)
	t.set_stylebox("panel", "PopupMenu", menu)
	var hover := caja(TEAL_CLARO, 12, false)
	t.set_stylebox("hover", "PopupMenu", hover)
	t.set_color("font_color", "PopupMenu", TINTA)
	t.set_color("font_hover_color", "PopupMenu", TINTA)
	t.set_color("font_disabled_color", "PopupMenu", TENUE)
	t.set_font("font", "PopupMenu", F_MEDIA)
	t.set_font_size("font_size", "PopupMenu", 26)
	t.set_constant("v_separation", "PopupMenu", 26)
	t.set_constant("item_start_padding", "PopupMenu", 18)
	t.set_constant("item_end_padding", "PopupMenu", 18)

	var vacio := StyleBoxEmpty.new()
	vacio.content_margin_left = 6
	vacio.content_margin_right = 6
	for s in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		t.set_stylebox(s, "OptionButton", vacio)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "OptionButton", TINTA)
	t.set_icon("arrow", "OptionButton", textura_lineas(34,
		[[Vector2(0.28, 0.4), Vector2(0.5, 0.62)], [Vector2(0.5, 0.62), Vector2(0.72, 0.4)]], 3.6, TENUE))
	t.set_constant("arrow_margin", "OptionButton", 6)
	return t


# ---------- Texturas dibujadas por código (sin imágenes externas) ----------
static func textura_lineas(tam: int, trazos: Array, grosor: float, color: Color,
		circulo: Color = Color(0, 0, 0, 0), borde: Color = Color(0, 0, 0, 0)) -> ImageTexture:
	var img := Image.create(tam, tam, false, Image.FORMAT_RGBA8)
	var c := Vector2(tam, tam) / 2.0
	var r := tam / 2.0 - 1.0
	for y in tam:
		for x in tam:
			var p := Vector2(x + 0.5, y + 0.5)
			var col := Color(0, 0, 0, 0)
			var d := p.distance_to(c)
			if borde.a > 0:
				col = _sobre(col, borde, clampf(r - d, 0.0, 1.0))
				col = _sobre(col, circulo, clampf(r * 0.84 - d, 0.0, 1.0))
			elif circulo.a > 0:
				col = _sobre(col, circulo, clampf(r - d, 0.0, 1.0))
			var dmin := INF
			for tr in trazos:
				var q := Geometry2D.get_closest_point_to_segment(p, tr[0] * tam, tr[1] * tam)
				dmin = minf(dmin, p.distance_to(q))
			if dmin < INF:
				col = _sobre(col, color, clampf(grosor / 2.0 - dmin + 0.5, 0.0, 1.0))
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func _sobre(base: Color, top: Color, a: float) -> Color:
	var aa := top.a * a
	var out_a := aa + base.a * (1.0 - aa)
	if out_a <= 0.0:
		return Color(0, 0, 0, 0)
	var r := (top.r * aa + base.r * base.a * (1.0 - aa)) / out_a
	var g := (top.g * aa + base.g * base.a * (1.0 - aa)) / out_a
	var b := (top.b * aa + base.b * base.a * (1.0 - aa)) / out_a
	return Color(r, g, b, out_a)
