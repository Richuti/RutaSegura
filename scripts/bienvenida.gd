extends Control

signal terminar(activar_ubicacion: bool)

const FONDO := Color("#0A2A2C")
const MENTA := Color("#79E4BA")
const PAPEL := Color("#F7F9F3")
const TEXTO := Color("#183332")
const SECUNDARIO := Color("#48615D")
const IMAGEN := "res://arte/bienvenida-campus.png"

var usa_gps := false
var falta_permiso := false

var _paso := 0
var _marco: MarginContainer
var _portada: PanelContainer
var _foto: TextureRect
var _ejemplo: VBoxContainer
var _progreso: Array[ColorRect] = []
var _volver: Button
var _titulo: Label
var _detalle: Label
var _principal: Button
var _omitir: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fondo := ColorRect.new()
	fondo.color = FONDO
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	# Si el texto ocupa más espacio en una pantalla baja, todo el contenido
	# sigue accesible y el botón de continuar puede desplazarse a la vista.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.follow_focus = true
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	_marco = MarginContainer.new()
	_marco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_marco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_marco.add_theme_constant_override("margin_top", 36)
	_marco.add_theme_constant_override("margin_bottom", 26)
	scroll.add_child(_marco)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 20)
	_marco.add_child(columna)

	var cabecera := HBoxContainer.new()
	cabecera.add_theme_constant_override("separation", 12)
	columna.add_child(cabecera)
	var escudo := Icono.new("escudo", MENTA, 40)
	escudo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cabecera.add_child(escudo)
	var marca := Estilo.texto("RutasSeguras", 27, Estilo.F_EXTRA, PAPEL)
	marca.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	marca.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cabecera.add_child(marca)
	_volver = _boton("Saltar", FONDO, PAPEL, 23)
	_volver.pressed.connect(func():
		if _paso == 0:
			terminar.emit(false)
		else:
			_mostrar_paso(0))
	cabecera.add_child(_volver)

	_portada = PanelContainer.new()
	_portada.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_portada.custom_minimum_size.y = 270
	_portada.clip_contents = true
	columna.add_child(_portada)
	_foto = TextureRect.new()
	_foto.texture = load(IMAGEN) as Texture2D
	_foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portada.add_child(_foto)
	_crear_ejemplo()

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Estilo.caja(PAPEL, 34, false, 34))
	columna.add_child(panel)
	var contenido := VBoxContainer.new()
	contenido.add_theme_constant_override("separation", 14)
	panel.add_child(contenido)

	var progreso := HBoxContainer.new()
	progreso.add_theme_constant_override("separation", 8)
	contenido.add_child(progreso)
	for i in 2:
		var tramo := ColorRect.new()
		tramo.custom_minimum_size = Vector2(36, 5)
		tramo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		progreso.add_child(tramo)
		_progreso.append(tramo)
	_titulo = _texto("", 54, Estilo.F_EXTRA, TEXTO)
	_titulo.add_theme_constant_override("line_spacing", -5)
	contenido.add_child(_titulo)
	_detalle = _texto("", 27, Estilo.F_MEDIA, SECUNDARIO)
	contenido.add_child(_detalle)
	var espacio := Control.new()
	espacio.custom_minimum_size.y = 12
	contenido.add_child(espacio)
	_principal = _boton("Continuar  →", TEXTO, PAPEL, 28)
	_principal.custom_minimum_size.y = 80
	_principal.pressed.connect(func():
		if _paso == 0:
			_mostrar_paso(1)
		else:
			terminar.emit(usa_gps and falta_permiso))
	contenido.add_child(_principal)
	_omitir = _boton("Ahora no", PAPEL, TEXTO, 23)
	_omitir.pressed.connect(func(): terminar.emit(false))
	contenido.add_child(_omitir)

	resized.connect(_ajustar_tamano)
	_ajustar_tamano()
	_mostrar_paso(0)


func _crear_ejemplo() -> void:
	_ejemplo = VBoxContainer.new()
	_ejemplo.alignment = BoxContainer.ALIGNMENT_CENTER
	_ejemplo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_ejemplo.add_theme_constant_override("separation", 10)
	_portada.add_child(_ejemplo)
	var etiqueta := Estilo.texto("Ejemplo · Edificio B", 23, Estilo.F_NEGRITA, MENTA)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ejemplo.add_child(etiqueta)
	for piso in [3, 2, 1]:
		var elegido: bool = piso == 2
		var fila := PanelContainer.new()
		fila.custom_minimum_size = Vector2(350, 70)
		fila.add_theme_stylebox_override("panel", Estilo.caja(MENTA if elegido else Color("#214849"), 14, false))
		_ejemplo.add_child(fila)
		var nombre := Estilo.texto("✓  Piso 2" if elegido else ("Piso 3" if piso == 3 else "Planta baja"),
			23, Estilo.F_NEGRITA, FONDO if elegido else PAPEL)
		nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nombre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fila.add_child(nombre)


func _mostrar_paso(paso: int) -> void:
	_paso = paso
	var primero := paso == 0
	_foto.visible = primero
	_ejemplo.visible = not primero
	_portada.add_theme_stylebox_override("panel", Estilo.caja(FONDO if primero else Color("#123536"), 30, false))
	_volver.text = "Saltar" if primero else "Volver"
	_titulo.text = "Encuentra tu ruta en la UAM" if primero else ("Confirma tu piso" if usa_gps else "Marca tu punto de partida")
	if primero:
		_detalle.text = "Elige un destino o toca Emergencia para ver la ruta a la zona segura más cercana."
	elif usa_gps:
		var ubicacion := "Activa la ubicación precisa para encontrar tu punto de partida." if falta_permiso else "El GPS encuentra tu punto de partida."
		_detalle.text = ubicacion + " Dentro de un edificio, solo eliges el piso."
	else:
		_detalle.text = "En este equipo, toca un punto del mapa para ubicarte. En Android, el GPS encuentra el edificio y tú eliges el piso."
	_principal.text = "Continuar  →" if primero else ("Activar ubicación" if falta_permiso else "Abrir mapa")
	_omitir.visible = not primero and falta_permiso
	for i in _progreso.size():
		_progreso[i].color = Color("#0F7768") if i == paso else Color("#CAD9D1")


func _ajustar_tamano() -> void:
	var margen := maxi(30, roundi((size.x - 650.0) / 2.0))
	_marco.add_theme_constant_override("margin_left", margen)
	_marco.add_theme_constant_override("margin_right", margen)
	_titulo.add_theme_font_size_override("font_size", 46 if size.x < 620.0 else 54)


func _boton(texto: String, fondo: Color, color: Color, tamano: int) -> Button:
	var boton := Estilo.boton(texto, fondo, color, tamano, 18)
	boton.custom_minimum_size = Vector2(120, 62)
	var foco := Estilo.caja(Color.TRANSPARENT, 18, false)
	foco.border_color = Color("#218B77") if fondo == PAPEL else MENTA
	foco.set_border_width_all(3)
	boton.add_theme_stylebox_override("focus", foco)
	return boton


func _texto(texto: String, tamano: int, fuente: Font, color: Color) -> Label:
	var etiqueta := Estilo.texto(texto, tamano, fuente, color)
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return etiqueta
