extends Polygon2D
## BackgroundVisual — UI/UX: Onbirinci geri bildirim ("background yeşil
## yerine evrime uygun olsun ve can yandığında yeni oyun başlattığında
## değişsin"). Main.tscn'deki "Background" Polygon2D önceden sabit koyu
## yeşildi (Color(0.055, 0.11, 0.098, 1)). Artık iki katmanlı davranışı var:
##  1) Her yeni tur başında (GameManager.run_reset — "Tekrar Oyna") THEMES
##     içinden rastgele bir "evrim temalı" palet seçilir (ilkel okyanus,
##     mağara, gece ormanı, volkanik çamur, yıldızlararası); art arda aynı
##     temanın gelmemesi için basit bir tekrar kontrolü var.
##  2) Seçilen temanın İÇİNDE, GameManager.level yükseldikçe renk kademeli
##     olarak (Tween ile, asla sıçramadan) "start" tonundan "evolved" (daha
##     asil/gelişmiş) tonuna kayar — LEVEL_SHIFT_CAP seviyesinde tam evolved
##     tona ulaşılır. Sadece görseldir; oynanış mantığına dokunmaz, sadece
##     GameManager'ın zaten var olan sinyallerini (level_changed, run_reset)
##     dinler.

const THEMES: Array[Dictionary] = [
	{"name": "İlkel Okyanus", "start": Color(0.04, 0.10, 0.13, 1), "evolved": Color(0.05, 0.22, 0.28, 1)},
	{"name": "Derin Mağara", "start": Color(0.07, 0.07, 0.10, 1), "evolved": Color(0.16, 0.14, 0.22, 1)},
	{"name": "Gece Ormanı", "start": Color(0.04, 0.09, 0.06, 1), "evolved": Color(0.08, 0.20, 0.13, 1)},
	{"name": "Volkanik Çamur", "start": Color(0.10, 0.05, 0.04, 1), "evolved": Color(0.24, 0.09, 0.06, 1)},
	{"name": "Yıldızlararası", "start": Color(0.05, 0.04, 0.11, 1), "evolved": Color(0.14, 0.08, 0.24, 1)},
]
const LEVEL_SHIFT_CAP: int = 25          # Bu seviyede "evolved" tona tam ulaşılmış olur
const COLOR_TWEEN_DURATION: float = 1.2  # Seviye atlayınca yeni tona kayış süresi

var _current_theme: Dictionary = {}

func _ready() -> void:
	GameManager.level_changed.connect(_on_level_changed)
	GameManager.run_reset.connect(_on_run_reset)
	_pick_random_theme()
	_apply_color_for_level(GameManager.level, false)

## GameManager.run_reset ("Tekrar Oyna"): yeni bir tema zarlanır ve mevcut
## seviyeye göre (level SIFIRLANMAZ — bkz. game_manager.gd reset_run notu)
## anında (sıçramadan, Tween olmadan) uygulanır.
func _on_run_reset() -> void:
	_pick_random_theme()
	_apply_color_for_level(GameManager.level, false)

func _on_level_changed(new_level: int) -> void:
	_apply_color_for_level(new_level, true)

## Mevcut temadan FARKLI rastgele bir tane seçer (art arda aynı tema
## gelmesin diye) — tek tema tanımlıysa olduğu gibi kalır.
func _pick_random_theme() -> void:
	if THEMES.size() <= 1:
		_current_theme = THEMES[0]
		return
	var candidate: Dictionary = THEMES[randi() % THEMES.size()]
	while candidate.get("name") == _current_theme.get("name"):
		candidate = THEMES[randi() % THEMES.size()]
	_current_theme = candidate

## Verilen seviyeye göre start→evolved arası oranı hesaplayıp uygular.
## animate=true ise (level_changed'te) Tween ile yumuşak geçiş yapar;
## false ise (ilk açılış/yeni tur) anında uygular.
func _apply_color_for_level(for_level: int, animate: bool) -> void:
	var t: float = clamp(float(for_level - 1) / float(LEVEL_SHIFT_CAP), 0.0, 1.0)
	var start_color: Color = _current_theme.get("start", Color.BLACK)
	var evolved_color: Color = _current_theme.get("evolved", Color.BLACK)
	var target: Color = start_color.lerp(evolved_color, t)
	if animate:
		var tween: Tween = create_tween()
		tween.tween_property(self, "color", target, COLOR_TWEEN_DURATION)
	else:
		color = target
