extends Control
class_name HUDRoot
## HUDRoot — fix: stabilize HUD layout and layer ordering. UI_Canvas altındaki
## tüm normal HUD elemanlarının (LivesUI, XPBar, ScoreLabel) TEK, merkezi
## yerleşim köküdür. Safe-area kenar paylarını SafeArea'dan okuyup
## TopLeftAnchor ve ScoreLabel'e uygular — üç bileşende ayrı ayrı sihirli
## sayı YOK, hepsi burada. Oynanış/organizma/skor/XP/can mantığına dokunmaz,
## yalnızca konumlandırır.
##
## Tam ekranı kaplayan bir Control olduğu için mouse_filter=IGNORE (hem
## kendisinde hem çocuklarında, bkz. Main.tscn'deki node override'ları)
## ZORUNLU: aksi halde Spawner'ın _unhandled_input ile dinlediği
## sürükle-bırak dokunma/fare girdisini sessizce yutar ve oynanışı kırar.

const SCORE_LABEL_WIDTH: float = 220.0    # Orijinal genişlik (480-700 @720px) -- görsel olarak değişmedi
const SCORE_LABEL_HEIGHT: float = 40.0    # Orijinal yükseklik (20-60) -- görsel olarak değişmedi
const SCORE_BASE_TOP: float = 20.0        # Orijinal üst boşluk -- safe-area payı yalnızca bunu AŞARSA etkili olur
const SCORE_BASE_RIGHT_GAP: float = 20.0  # Orijinal sağ kenar boşluğu -- safe-area payı yalnızca bunu AŞARSA etkili olur

@onready var _top_left_anchor: Control = $TopLeftAnchor
@onready var _score_label: Label = $ScoreLabel

func _ready() -> void:
	_apply_safe_area()
	get_tree().root.size_changed.connect(_apply_safe_area)

## Safe-area kenar paylarını okuyup HUD köşelerine uygular. Yalnızca bu
## fonksiyon SafeArea'yı çağırır -- diğer HUD script'leri (lives_ui.gd,
## xp_bar.gd, score_label.gd) bundan tamamen habersizdir ve değiştirilmedi.
func _apply_safe_area() -> void:
	var m: Dictionary = SafeArea.get_margins()
	_top_left_anchor.position = Vector2(m.get("left", 0.0), m.get("top", 0.0))

	var right_margin: float = m.get("right", 0.0)
	var top_margin: float = m.get("top", 0.0)
	var extra_right: float = max(0.0, right_margin - SafeArea.FALLBACK_SIDE)
	_score_label.offset_right = -(SCORE_BASE_RIGHT_GAP + extra_right)
	_score_label.offset_left = _score_label.offset_right - SCORE_LABEL_WIDTH
	_score_label.offset_top = max(SCORE_BASE_TOP, top_margin)
	_score_label.offset_bottom = _score_label.offset_top + SCORE_LABEL_HEIGHT
