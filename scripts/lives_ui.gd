extends Node2D
class_name LivesUI
## LivesUI — UC-03: 3 can (kalp) göstergesi. style: apply polished HUD and run
## summary -- düz kırmızı dairelerin yerine minimal, VEKTÖREL (prosedürel
## Polygon2D, PNG değil) kalp ikonları. GameManager.lives_changed sinyalini
## dinleyip dolu/boş durumunu günceller. Oynanış mantığına dokunmaz, sadece
## GameManager'ın can verisini görselleştirir. Renkler HUDTheme'den (tek
## merkezi stil kaynağı) okunur.

const HEART_SIZE: float = 28.0                  # kullanıcı talebi: ~28x28 px
const HEART_SPACING: float = HEART_SIZE + 14.0  # kullanıcı talebi: kalpler arası ~14px boşluk
const HEART_SEGMENTS: int = 28
const EMPTY_FILL: Color = Color("#0B3441A6")    # eksik can: koyu/pasif dolgu
const EMPTY_OUTLINE: Color = Color("#A8CFD266") # eksik can: soluk outline (kullanıcı talebi: "yalnızca outline veya koyu pasif görünüm")
const OUTLINE_WIDTH: float = 1.4

var _hearts: Array[Polygon2D] = []
var _outlines: Array[Line2D] = []

func _ready() -> void:
	_build_hearts(GameManager.MAX_LIVES)
	_update_hearts(GameManager.lives)
	GameManager.lives_changed.connect(_update_hearts)

## GameManager.MAX_LIVES kadar kalp ikonu oluşturur (dolgu Polygon2D + soluk outline Line2D).
func _build_hearts(max_lives: int) -> void:
	var shape: PackedVector2Array = _heart_points(HEART_SIZE)
	for i in range(max_lives):
		var heart := Polygon2D.new()
		heart.polygon = shape
		heart.position = Vector2(i * HEART_SPACING, 0)
		add_child(heart)
		_hearts.append(heart)

		var outline := Line2D.new()
		outline.points = shape
		outline.closed = true
		outline.width = OUTLINE_WIDTH
		outline.position = heart.position
		outline.default_color = EMPTY_OUTLINE
		outline.antialiased = true
		add_child(outline)
		_outlines.append(outline)

## Kalan can sayısına göre kalplerin dolu (coral dolgu, outline gizli) / boş
## (pasif dolgu + soluk outline) görünümünü günceller (UC-03 Adım 2).
func _update_hearts(remaining_lives: int) -> void:
	for i in range(_hearts.size()):
		var is_active: bool = i < remaining_lives
		_hearts[i].color = HUDTheme.LIFE_COLOR if is_active else EMPTY_FILL
		_outlines[i].width = 0.0 if is_active else OUTLINE_WIDTH

## Minimal, tanınabilir bir kalp siluetinin köşe noktalarını üretir --
## klasik parametrik kalp eğrisi (16 sin^3 t tabanlı), verilen kutu boyutuna
## ölçeklenip Godot'un y-aşağı eksenine göre çevrilir (sivri uç altta kalsın).
static func _heart_points(size: float) -> PackedVector2Array:
	var raw: Array = []
	for i in range(HEART_SEGMENTS):
		var t: float = TAU * float(i) / float(HEART_SEGMENTS)
		var x: float = 16.0 * pow(sin(t), 3.0)
		var y: float = 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		raw.append(Vector2(x, -y))

	var min_v: Vector2 = raw[0]
	var max_v: Vector2 = raw[0]
	for p in raw:
		min_v.x = min(min_v.x, p.x)
		min_v.y = min(min_v.y, p.y)
		max_v.x = max(max_v.x, p.x)
		max_v.y = max(max_v.y, p.y)
	var span: Vector2 = max_v - min_v
	var center_raw: Vector2 = (min_v + max_v) / 2.0
	var scale: float = size / max(span.x, span.y)

	var points := PackedVector2Array()
	for p in raw:
		points.append((p - center_raw) * scale)
	return points
