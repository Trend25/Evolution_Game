extends Node2D
class_name EnvironmentBounds
## EnvironmentBounds -- feat: mobile edge-to-edge layout fix (Bölüm E).
## window/stretch/aspect="expand" (bkz. background_fill.gd üzerindeki notlar)
## mantıksal viewport'u dikeyde büyütebildiğinden, fanusun sol/sağ duvarları
## ve tabanı bu YENİ, gerçekten oynanabilir alanın alt sınırına KONTROLLÜ
## olarak genişletilir/yeniden konumlandırılır -- kullanıcının açık uyarısı
## ("fiziksel/oyun alanını kontrolsüzce germe") burada gözetildi:
##
##   - Yalnızca duvar/taban GEOMETRİSİ (StaticBody2D konumu + CollisionShape2D
##     boyutu) güncellenir; organizma boyutu/ölçeği/fizik sabitleri
##     (yerçekimi, merge mesafesi, sprite boyutu) HİÇ DEĞİŞMEZ.
##   - Hesap yalnızca gerçek bir boyut DEĞİŞİMİNDE (size_changed) BİR KEZ
##     yeniden yapılır -- her karede değil, sürekli bir "gerilme" YOKTUR.
##   - Spawner'ın bırakma noktası (y=100) ve GameOverZone'un tehlike çizgisi
##     (y=200) SABİT KALIR -- kullanıcı yalnızca "taban ve duvarların"
##     genişletilmesini istedi, oynanışın üst kısmına dokunulmadı.
##   - Yatay eksen (sol/sağ duvar X konumu, Spawner'ın left/right_bound_x'i)
##     KASITLI OLARAK değiştirilmedi: "expand" modu bu projede yalnızca
##     DİKEY eksende büyür (kullanıcının bildirdiği sorun da "üstte/altta
##     siyah kenarlık" -- dikey). Olası gelecekte çok geniş/kare bir cihazda
##     yatay büyüme de gerekirse bu AYRI, kendi kararını gerektiren bir
##     kapsam genişletmesi olur (final raporda not edildi).

const DESIGN_HEIGHT: float = 1280.0
const FLOOR_THICKNESS: float = 20.0

@onready var _wall_left: StaticBody2D = $WallLeft
@onready var _wall_left_shape: CollisionShape2D = $WallLeft/CollisionShape2D
@onready var _wall_right: StaticBody2D = $WallRight
@onready var _wall_right_shape: CollisionShape2D = $WallRight/CollisionShape2D
@onready var _floor: StaticBody2D = $Floor
@onready var _floor_shape: CollisionShape2D = $Floor/CollisionShape2D

func _ready() -> void:
	_update_bounds()
	get_tree().root.size_changed.connect(_update_bounds)

func _update_bounds() -> void:
	var logical_size: Vector2 = get_viewport().get_visible_rect().size
	if logical_size.y <= 0.0:
		return
	var height: float = max(DESIGN_HEIGHT, logical_size.y)  # yalnızca BÜYÜT, tasarım yüksekliğinin altına asla küçültme

	_wall_left.position.y = height / 2.0
	(_wall_left_shape.shape as RectangleShape2D).size.y = height

	_wall_right.position.y = height / 2.0
	(_wall_right_shape.shape as RectangleShape2D).size.y = height

	_floor.position.y = height - FLOOR_THICKNESS / 2.0  # taban her zaman YENİ alt kenara tam bitişik
