extends Sprite2D
class_name BackgroundFill
## BackgroundFill -- feat: mobile edge-to-edge layout fix (Bölüm E).
## window/stretch/aspect artık "expand" (bkz. project.godot) -- yani
## mantıksal viewport boyutu artık SABİT tasarım boyutu (720x1280) DEĞİL,
## pencere en-boy oranına göre bir eksende BÜYÜYEBİLİYOR (gerçek Godot
## 4.7.2 kaynağı -- scene/main/window.cpp _update_viewport_size() --
## incelenerek doğrulandı: büyüyen eksende ekstra alan her zaman SAĞ/ALT'ta
## belirir, origin sol-üstte SABİT kalır; bkz. final rapor).
##
## Bu script, BackgroundImage'ın (720x1280 tasarım dokusu) her zaman açığa
## çıkan TÜM alanı kenarlıksız kaplaması için scale'ini DİNAMİK günceller --
## yalnızca ARKA PLAN GÖRSELİ. Fanusun GERÇEK oynanabilir sınırları
## (duvarlar/taban) AYRI ve kontrollü bir şekilde environment_bounds.gd
## tarafından genişletilir -- ikisi birbirinden bağımsız, "fiziksel/oyun
## alanını kontrolsüzce germe" riski YOKTUR (kullanıcı isteği).

const DESIGN_SIZE: Vector2 = Vector2(720.0, 1280.0)

func _ready() -> void:
	centered = true
	_update_fill()
	get_tree().root.size_changed.connect(_update_fill)

func _update_fill() -> void:
	var logical_size: Vector2 = get_viewport().get_visible_rect().size
	if logical_size.x <= 0.0 or logical_size.y <= 0.0:
		return
	# Yalnızca BÜYÜT -- tasarım boyutunun altına asla küçültme (expand modu
	# zaten bunu garanti eder, ama defansif bir alt sınır).
	var target: Vector2 = Vector2(max(DESIGN_SIZE.x, logical_size.x), max(DESIGN_SIZE.y, logical_size.y))
	scale = Vector2(target.x / DESIGN_SIZE.x, target.y / DESIGN_SIZE.y)
	position = target / 2.0  # origin sol-üstte sabit kalacak şekilde ortalama (0,0)-(target.x,target.y) dikdörtgeninin merkezi
