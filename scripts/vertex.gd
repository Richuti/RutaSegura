# ==========================================================
#  RutasSeguras - Vertex (igual que en clase)
#  Un vértice = un punto del campus
# ==========================================================
class_name Vertex
extends RefCounted

var city: String          # nombre del punto
var segura: bool          # true = zona de seguridad
var pos: Vector3          # posición en el mundo 3D (metros)
var neig: Array = []      # lista de [Vertex, peso]


func _init(_city: String, _segura: bool = false, _pos: Vector3 = Vector3.ZERO) -> void:
	city = _city
	segura = _segura
	pos = _pos
