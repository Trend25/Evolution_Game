class_name SafeArea
## SafeArea — fix: stabilize HUD layout and layer ordering. Android çentik/
## durum çubuğu ve farklı ekran oranları için TEK, merkezi güvenli-alan
## (safe-area) kenar payı hesaplayıcısı. Durumsuz statik yardımcı sınıf;
## otoload DEĞİL, sahneye hiç eklenmez. Yalnızca HUDRoot (`hud_root.gd`)
## çağırır — LivesUI/XPBar/ScoreLabel bundan habersiz, kendi başlarına
## sihirli sayı taşımaz. Oynanış/organizma/skor/XP/can mantığına dokunmaz.
##
## Godot 4.7'nin DisplayServer.get_display_safe_area() API'si anlamlı bir
## "çentik/kamera kesintisi" dikdörtgenini yalnızca Android'de döner; masaüstü
## ve headless (xvfb) ortamlarda ya tam ekranla birebir aynı dikdörtgeni ya da
## geçersiz/sıfır bir değer döner. Bu durumlarda FALLBACK_* sabitleri
## kullanılır — gerçek Android'de çentik olmasa bile bu minimum pay makul bir
## güvenlik boşluğu sağlar (task 6: "güvenli bir minimum fallback margin").

const FALLBACK_TOP: float = 24.0   # Durum çubuğu/çentik verisi yoksa uygulanan üst pay
const FALLBACK_SIDE: float = 16.0  # Yuvarlak köşe/kamera kesintisi için yatay pay

## QA/test amaçlı override — boş olmadığı sürece gerçek DisplayServer
## sorgusunun YERİNE doğrudan bu değer döner (bkz. "safe-area simülasyonu"
## test senaryosu). Üretim/varsayılan davranışta boş kalır, hiçbir etkisi
## olmaz; yalnızca geçici test script'lerinden set edilmesi amaçlanır.
static var debug_override_margins: Dictionary = {}

## Mevcut pencere/ekran için, PROJE VIEWPORT'U (720x1280 mantıksal) piksel
## uzayında {left, top, right, bottom} güvenli-alan kenar paylarını döndürür.
## Oyun dünyasının (organizmalar, duvarlar, taban) koordinatlarını HİÇ
## etkilemez — yalnızca HUDRoot'un kendi iç yerleşimi için kullanılır.
static func get_margins() -> Dictionary:
	if not debug_override_margins.is_empty():
		return debug_override_margins

	var margins: Dictionary = {"left": FALLBACK_SIDE, "top": FALLBACK_TOP, "right": FALLBACK_SIDE, "bottom": 0.0}

	var screen_full: Vector2i = DisplayServer.screen_get_size()
	var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
	var window_px: Vector2i = DisplayServer.window_get_size()
	if screen_full.x <= 0 or screen_full.y <= 0 or safe_rect.size.x <= 0 or safe_rect.size.y <= 0 or window_px.x <= 0 or window_px.y <= 0:
		return margins  # Masaüstü/headless genelde buraya düşer -- fallback yeterli
	if safe_rect.position == Vector2i.ZERO and safe_rect.size == screen_full:
		return margins  # Çentik yok / API bu platformda anlamlı değil -- yine minimum fallback uygulanır

	var logical_size := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 720)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 1280)),
	)
	# canvas_items + aspect=keep: içerik, pencereye SIĞDIRILARAK (letterbox ile)
	# tek bir oranla büyütülür -- bu yüzden iki eksenin KÜÇÜK olanı gerçek ölçek.
	var scale: float = min(float(window_px.x) / logical_size.x, float(window_px.y) / logical_size.y)
	if scale <= 0.0:
		return margins

	var native_left: float = float(safe_rect.position.x)
	var native_top: float = float(safe_rect.position.y)
	var native_right: float = float(screen_full.x - (safe_rect.position.x + safe_rect.size.x))
	var native_bottom: float = float(screen_full.y - (safe_rect.position.y + safe_rect.size.y))

	margins["left"] = max(FALLBACK_SIDE, native_left / scale)
	margins["top"] = max(FALLBACK_TOP, native_top / scale)
	margins["right"] = max(FALLBACK_SIDE, native_right / scale)
	margins["bottom"] = max(0.0, native_bottom / scale)
	return margins
