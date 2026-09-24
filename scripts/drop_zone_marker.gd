extends Node2D
class_name DropZoneMarker
## DropZoneMarker -- feat: add first-run gameplay guidance (Bölüm D). SADECE
## GÖRSEL: Spawner'ın gerçek bırakma çizgisini (Spawner'ın y konumu) ve
## oyuncunun canlıyı yatayda hareket ettirebileceği GERÇEK sürüklenebilir
## aralığı (Spawner.left_bound_x/right_bound_x + HORIZONTAL_MARGIN) FanusZone
## sınırlarına göre işaretler. Collision/fizik/spawn/merge mantığına
## KATILMAZ -- yalnızca _draw() ile çizer. FirstRunTutorial tarafından
## bekleyen canlının GERÇEK stage_id'sinden BAĞIMSIZ, sabit koordinatlarla
## kurulur (Spawner ile aynı Main.tscn sabitlerini kullanır).

const DROP_LINE_Y: float = 100.0        # Spawner'ın Main.tscn'deki position.y'si ile AYNI
const DRAG_LEFT_X: float = 30.0 + 65.0  # Spawner.left_bound_x + HORIZONTAL_MARGIN (spawner.gd)
const DRAG_RIGHT_X: float = 690.0 - 65.0 # Spawner.right_bound_x - HORIZONTAL_MARGIN (spawner.gd)
const LINE_MARGIN_X: float = 20.0       # Fanus iç duvar yüzleri (WallLeft/WallRight)
const LINE_WIDTH: float = 3.0
const DASH_LENGTH: float = 14.0
const DASH_GAP: float = 8.0
const BAND_HEIGHT: float = 64.0

var _line_color: Color = Color("#74DDCB")   # HUDTheme.MINT_ACCENT (yeni bağımlılık eklememek için sabit değer kopyalandı)
var _band_color: Color = Color(0.455, 0.867, 0.796, 0.14)

func _ready() -> void:
	z_index = 8  # MergeBurst(5)/FloatingScoreText(6)'nın üstünde, ama HUD CanvasLayer'ının (ayrı katman) HER ZAMAN altında

func _draw() -> void:
	# Bırakılabilir alan: yarı saydam dikey bant (oyuncunun canlıyı
	# sürükleyebileceği GERÇEK aralık).
	draw_rect(Rect2(Vector2(DRAG_LEFT_X, DROP_LINE_Y - BAND_HEIGHT / 2.0), Vector2(DRAG_RIGHT_X - DRAG_LEFT_X, BAND_HEIGHT)), _band_color, true)
	# Bırakma çizgisi: kesikli yatay çizgi, fanus genişliği boyunca.
	var x: float = LINE_MARGIN_X
	while x < 720.0 - LINE_MARGIN_X:
		var seg_end: float = min(x + DASH_LENGTH, 720.0 - LINE_MARGIN_X)
		draw_line(Vector2(x, DROP_LINE_Y), Vector2(seg_end, DROP_LINE_Y), _line_color, LINE_WIDTH, true)
		x = seg_end + DASH_GAP
