extends Node2D
class_name XPBar
## XPBar — UC-05 / mimari Bölüm 5: Meta seviye ilerleme çubuğu. style: apply
## polished HUD and run summary -- düz mavi dikdörtgen yerine StyleBoxFlat
## tabanlı, kenarlıksız, hafif yuvarlatılmış koyu track + mint dolum
## (kullanıcı talebi: ~10px yükseklik, border yok). Genişlik SABİT değil --
## HUDRoot, safe-area'ya göre Sol Panel daralır/genişlerse set_bar_width() ile
## günceller (bkz. hud_root.gd _apply_safe_area). Oynanış mantığına dokunmaz;
## sadece GameManager'ın xp/level/LEVEL_XP_BASE verisini okuyup çizer.

const BAR_HEIGHT: float = 10.0  # kullanıcı talebi: ~10px
const DEFAULT_BAR_WIDTH: float = 134.0

var _bar_width: float = DEFAULT_BAR_WIDTH
var _track: Panel
var _fill: Panel

func _ready() -> void:
	_track = _make_bar_panel(HUDTheme.make_xp_track_stylebox())
	add_child(_track)

	_fill = _make_bar_panel(HUDTheme.make_xp_fill_stylebox())
	add_child(_fill)

	GameManager.xp_changed.connect(_on_xp_or_level_changed)
	GameManager.level_changed.connect(_on_xp_or_level_changed)
	_update_bar()

func _make_bar_panel(style: StyleBoxFlat) -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2.ZERO
	panel.size = Vector2(_bar_width, BAR_HEIGHT)
	return panel

## HUDRoot tarafından, safe-area'ya göre Sol Panel daralırsa/genişlerse
## çağrılır. Oynanış/XP hesaplamasına dokunmaz, yalnızca çubuğun ÇİZİM
## genişliğini günceller.
func set_bar_width(new_width: float) -> void:
	_bar_width = max(40.0, new_width)
	if _track:
		_track.size.x = _bar_width
	_update_bar()

func _on_xp_or_level_changed(_value: int) -> void:
	_update_bar()

## UC-05 Adım 2: Mevcut seviye aralığındaki XP ilerlemesini (0..1) hesaplayıp çubuğu doldurur.
func _update_bar() -> void:
	if _fill == null:
		return
	var previous_threshold: int = (GameManager.level - 1) * GameManager.LEVEL_XP_BASE
	var next_threshold: int = GameManager.level * GameManager.LEVEL_XP_BASE
	var range_size: int = next_threshold - previous_threshold
	var progress: float = 0.0
	if range_size > 0:
		progress = clamp(float(GameManager.xp - previous_threshold) / float(range_size), 0.0, 1.0)
	_fill.size.x = _bar_width * progress
