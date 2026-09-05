extends Node2D
class_name LivesUI
## LivesUI — UC-03: 3 can (kalp) göstergesi. GameManager.lives_changed
## sinyalini dinleyip kalp ikonlarının dolu/boş durumunu günceller.
## Oynanış mantığına dokunmaz, sadece GameManager'ın can verisini görselleştirir.

const HEART_SPACING: float = 36.0                            # Kalp ikonları arası yatay boşluk
const HEART_RADIUS: float = 14.0                              # Yer tutucu kalp ikonu yarıçapı
const HEART_FULL_COLOR: Color = Color(0.86, 0.15, 0.25, 1.0)  # Dolu kalp rengi (kırmızı)
const HEART_EMPTY_COLOR: Color = Color(0.35, 0.35, 0.35, 0.5) # Boş kalp rengi (soluk gri)

var _hearts: Array[Polygon2D] = []

func _ready() -> void:
	_build_hearts(GameManager.MAX_LIVES)
	_update_hearts(GameManager.lives)
	GameManager.lives_changed.connect(_update_hearts)

## GameManager.MAX_LIVES kadar yer tutucu kalp ikonu oluşturur; gerçek kalp
## sprite'ı hazır olduğunda bu Polygon2D'ler bir Sprite2D ile değiştirilebilir.
func _build_hearts(max_lives: int) -> void:
	for i in range(max_lives):
		var heart := Polygon2D.new()
		heart.polygon = _circle_points(HEART_RADIUS)
		heart.position = Vector2(i * HEART_SPACING, 0)
		add_child(heart)
		_hearts.append(heart)

## Kalan can sayısına göre kalplerin dolu/boş rengini günceller (UC-03 Adım 2 görselleştirmesi).
func _update_hearts(remaining_lives: int) -> void:
	for i in range(_hearts.size()):
		_hearts[i].color = HEART_FULL_COLOR if i < remaining_lives else HEART_EMPTY_COLOR

## Basit bir dairenin köşe noktalarını üretir (yer tutucu kalp görseli).
func _circle_points(radius: float, segments: int = 16) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle: float = TAU * i / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
