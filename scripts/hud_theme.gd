class_name HUDTheme
## HUDTheme — style: apply polished HUD and run summary. TEK, merkezi görsel
## stil kaynağı: renkler, fontlar, panel StyleBoxFlat üretimi, sayı biçimlendirme.
## Hiçbir HUD/Game Over/toast script'i kendi başına renk/font sabiti taşımaz,
## hepsi buradan okur — panel görünümü tek bir yerden değiştirilebilsin diye.
## Oynanış/organizma/skor/XP/can mantığına dokunmaz, yalnızca görsel stil sağlar.
##
## FONT NOTU (kullanıcı onayı ile): İstenen Manrope/Space Grotesk dosyalarına bu
## ortamdan (bulut kapsayıcısı + kullanıcının Mac'i) ağ erişimi mümkün olmadı
## (raw.githubusercontent.com, fonts.google.com, npm, PyPI, Ubuntu arşivleri —
## hepsi organizasyon ağ politikasınca 403 ile engellendi, bkz. final rapor).
## Kullanıcı onayıyla, bu ortamda zaten yerel ve OFL lisanslı olarak bulunan
## GERÇEK Google Fonts ailesi kullanıldı:
##   - Genel UI/etiket metni            -> Instrument Sans (Regular, 400)
##   - SCORE / RUN XP / büyük sonuç sayıları -> Bricolage Grotesque (Regular, 400)
## Her iki fontun da yalnızca Regular (400) statik dosyası yerel pakette mevcuttu
## (Medium/500 dosyası yok) — kullanıcının izin verdiği 400/500 aralığında
## kaldığından 400 kullanıldı. assets/fonts/ altına ilgili OFL.txt lisans
## dosyalarıyla birlikte eklendi.

const FONT_UI: FontFile = preload("res://assets/fonts/InstrumentSans-Regular.ttf")
const FONT_NUMBER: FontFile = preload("res://assets/fonts/BricolageGrotesque-Regular.ttf")

# -- Renkler (kullanıcı talebindeki hex/opacity referanslarının birebir karşılığı,
# 8-haneli #RRGGBBAA hex ile -- Godot Color(String) bunu doğrudan ayrıştırır) --
const HUD_SURFACE: Color = Color("#0B3441E0")    # #0B3441 @88%
const NEXT_SURFACE: Color = Color("#09303DF0")   # #09303D @94%
const HUD_BORDER: Color = Color("#E0FAFA38")     # #E0FAFA @22%
const NEXT_BORDER: Color = Color("#74DDCB7A")    # #74DDCB @48%
const TEXT_PRIMARY: Color = Color("#F5FBFA")
const TEXT_SECONDARY: Color = Color("#A8CFD2")
const LIFE_COLOR: Color = Color("#FF6D71")
const MINT_ACCENT: Color = Color("#74DDCB")
const GOLD_ACCENT: Color = Color("#F1C875")
const XP_TRACK: Color = Color("#031C24A6")       # #031C24 @65%

const BUTTON_TEXT_DARK: Color = Color("#09303D")  # "Play again" butonu koyu metin (kullanıcı talebi)

const PANEL_CORNER_RADIUS: int = 31
const PANEL_BORDER_WIDTH: int = 2
const PANEL_SHADOW_SIZE: int = 6
const PANEL_SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.22)

## Ana HUD panelleri (Lives/Level/XP paneli ve Score paneli) için ortak yüzey.
static func make_hud_panel_stylebox() -> StyleBoxFlat:
	return _make_panel(HUD_SURFACE, HUD_BORDER)

## NEXT paneli için, diğerlerinden biraz daha belirgin vurgu sınırlı yüzey.
static func make_next_panel_stylebox() -> StyleBoxFlat:
	return _make_panel(NEXT_SURFACE, NEXT_BORDER)

static func _make_panel(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(PANEL_BORDER_WIDTH)
	sb.set_corner_radius_all(PANEL_CORNER_RADIUS)
	sb.shadow_color = PANEL_SHADOW_COLOR
	sb.shadow_size = PANEL_SHADOW_SIZE
	sb.anti_aliasing = true
	return sb

## XP bar track/fill -- kenarlıksız, hafif yuvarlatılmış (kullanıcı talebi: "Border kullanma").
static func make_xp_track_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = XP_TRACK
	sb.set_corner_radius_all(5)
	sb.anti_aliasing = true
	return sb

static func make_xp_fill_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = MINT_ACCENT
	sb.set_corner_radius_all(5)
	sb.anti_aliasing = true
	return sb

## Seviye atlama capsule'ü -- koyu teal yüzey + ince muted-gold sınır (kullanıcı talebi).
static func make_toast_capsule_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = NEXT_SURFACE
	sb.border_color = Color(GOLD_ACCENT.r, GOLD_ACCENT.g, GOLD_ACCENT.b, 0.55)
	sb.set_border_width_all(1.5)
	sb.set_corner_radius_all(18)
	sb.anti_aliasing = true
	return sb

## Run summary (Game Over) paneli -- HUD yüzeyiyle aynı aile, biraz daha opak.
static func make_summary_panel_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(HUD_SURFACE.r, HUD_SURFACE.g, HUD_SURFACE.b, 0.97)
	sb.border_color = HUD_BORDER
	sb.set_border_width_all(PANEL_BORDER_WIDTH)
	sb.set_corner_radius_all(PANEL_CORNER_RADIUS)
	sb.shadow_color = PANEL_SHADOW_COLOR
	sb.shadow_size = 10
	sb.anti_aliasing = true
	return sb

## "Play again" butonu -- mint yüzey, koyu metin (kullanıcı talebi).
static func make_button_stylebox(pressed: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = MINT_ACCENT.darkened(0.12) if pressed else MINT_ACCENT
	sb.set_corner_radius_all(20)
	sb.anti_aliasing = true
	return sb

## Harf aralıklı ("letter-spaced") küçük başlıklar için (SCORE/NEXT/EVOLUTION RUN vb.)
## -- FontVariation ile aynı temel fontun glyph aralığı artırılır, yeni bir font
## dosyası eklenmez.
static func make_spaced_variation(base: FontFile, spacing_px: int) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = base
	variation.set_spacing(TextServer.SPACING_GLYPH, spacing_px)
	return variation

## Bir Label'a merkezi font/boyut/renk uygular -- tek merkezden, kod tekrarını önler.
static func style_label(label: Label, font: Font, size: int, color: Color) -> void:
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)

## Binlik ayraçlı (İngilizce, virgül) tam sayı biçimlendirme -- Godot'ta hazır bir
## grup ayraçlı %d biçimlendirici olmadığından elle yazıldı. Skor/XP HESAPLAMASINA
## dokunmaz, yalnızca GÖSTERİM biçimidir.
static func format_thousands(n: int) -> String:
	var negative: bool = n < 0
	var digits: String = str(abs(n))
	var grouped: String = ""
	var count: int = 0
	for i in range(digits.length() - 1, -1, -1):
		grouped = digits[i] + grouped
		count += 1
		if count % 3 == 0 and i != 0:
			grouped = "," + grouped
	return ("-" + grouped) if negative else grouped
