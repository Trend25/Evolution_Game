extends Node2D
class_name XPBar
## XPBar — UC-05 / mimari Bölüm 5: Meta seviye ilerleme çubuğu.
## GameManager.xp_changed ve level_changed sinyallerini dinleyip mevcut
## seviye aralığındaki XP ilerlemesini görselleştirir. Oynanış mantığına
## dokunmaz; sadece GameManager'ın xp/level/LEVEL_XP_BASE verisini okuyup çizer.

const BAR_WIDTH: float = 200.0
const BAR_HEIGHT: float = 16.0
const BACKGROUND_COLOR: Color = Color(0.2, 0.2, 0.2, 0.6)  # Kontrast için koyu, yarı saydam zemin
const FILL_COLOR: Color = Color(0.25, 0.65, 0.95, 1.0)     # Dolum rengi

var _background: ColorRect
var _fill: ColorRect

func _ready() -> void:
	_background = ColorRect.new()
	_background.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_background.color = BACKGROUND_COLOR
	add_child(_background)

	_fill = ColorRect.new()
	_fill.size = Vector2(0.0, BAR_HEIGHT)
	_fill.color = FILL_COLOR
	add_child(_fill)

	GameManager.xp_changed.connect(_on_xp_or_level_changed)
	GameManager.level_changed.connect(_on_xp_or_level_changed)
	_update_bar()

## XP veya seviye değiştiğinde çubuğu yeniden çizer (imza uyumu için parametre alır, kullanılmaz).
func _on_xp_or_level_changed(_value: int) -> void:
	_update_bar()

## UC-05 Adım 2: Mevcut seviye aralığındaki XP ilerlemesini (0..1) hesaplayıp çubuğu doldurur.
func _update_bar() -> void:
	var previous_threshold: int = (GameManager.level - 1) * GameManager.LEVEL_XP_BASE
	var next_threshold: int = GameManager.level * GameManager.LEVEL_XP_BASE
	var range_size: int = next_threshold - previous_threshold
	var progress: float = 0.0
	if range_size > 0:
		progress = clamp(float(GameManager.xp - previous_threshold) / float(range_size), 0.0, 1.0)
	_fill.size.x = BAR_WIDTH * progress
