extends CanvasLayer
class_name GameOverScreen
## GameOverScreen — UC-04: Oyun Bitti / Run Summary ekranı. style: apply
## polished HUD and run summary -- "Oyun Bitti" yerine "Run complete" run
## summary paneli: EVOLUTION RUN kicker, SCORE / RUN XP iki sonuç sütunu,
## "Play again" butonu. RUN XP yalnızca BU TURDA kazanılan (GameManager'ın
## final_stats["xp_gained"] alanından okunan, salt EKLENMİŞ bir bookkeeping
## alanı) XP'yi gösterir -- GameManager'ın XP EKONOMİSİ (nasıl kazanılır,
## seviye eşikleri, kalıcılık) DEĞİŞMEDİ (bkz. game_manager.gd yorumu, final
## rapor "gameplay mantığı değişmedi" bölümü). Mimari belgenin Bölüm 5 sahne
## hiyerarşisinde ayrı bir node olarak listelenmemiştir, ancak UC-04 Adım 2'nin
## gerektirdiği "Oyun Bitti ekranı" için gereklidir.

@onready var _panel: Panel = $Panel
@onready var _kicker: Label = $Panel/Kicker
@onready var _title: Label = $Panel/Title
@onready var _score_caption: Label = $Panel/ResultsRow/ScoreResult/ScoreCaption
@onready var _score_value: Label = $Panel/ResultsRow/ScoreResult/ScoreValue
@onready var _xp_caption: Label = $Panel/ResultsRow/XPResult/XPCaption
@onready var _xp_value: Label = $Panel/ResultsRow/XPResult/XPValue
@onready var _retry_button: Button = $Panel/RetryButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Oyun duraklatılsa (UC-04) bile ekran/buton çalışsın
	visible = false
	_apply_style()
	GameManager.game_over_ready.connect(_on_game_over_ready)
	_retry_button.pressed.connect(_on_retry_pressed)

## Panel/metin/buton görsel stilini HUDTheme'den (tek merkezi kaynak) uygular.
func _apply_style() -> void:
	_panel.add_theme_stylebox_override("panel", HUDTheme.make_summary_panel_stylebox())
	HUDTheme.style_label(_kicker, HUDTheme.make_spaced_variation(HUDTheme.FONT_UI, 3), 14, HUDTheme.MINT_ACCENT)
	HUDTheme.style_label(_title, HUDTheme.FONT_UI, 28, HUDTheme.TEXT_PRIMARY)
	HUDTheme.style_label(_score_caption, HUDTheme.FONT_UI, 15, HUDTheme.TEXT_SECONDARY)
	HUDTheme.style_label(_xp_caption, HUDTheme.FONT_UI, 15, HUDTheme.TEXT_SECONDARY)
	HUDTheme.style_label(_score_value, HUDTheme.FONT_NUMBER, 34, HUDTheme.TEXT_PRIMARY)
	HUDTheme.style_label(_xp_value, HUDTheme.FONT_NUMBER, 34, HUDTheme.MINT_ACCENT)

	_retry_button.add_theme_stylebox_override("normal", HUDTheme.make_button_stylebox(false))
	_retry_button.add_theme_stylebox_override("hover", HUDTheme.make_button_stylebox(false))
	_retry_button.add_theme_stylebox_override("pressed", HUDTheme.make_button_stylebox(true))
	_retry_button.add_theme_stylebox_override("focus", HUDTheme.make_button_stylebox(false))
	_retry_button.add_theme_color_override("font_color", HUDTheme.BUTTON_TEXT_DARK)
	_retry_button.add_theme_color_override("font_hover_color", HUDTheme.BUTTON_TEXT_DARK)
	_retry_button.add_theme_color_override("font_pressed_color", HUDTheme.BUTTON_TEXT_DARK)
	_retry_button.add_theme_font_override("font", HUDTheme.FONT_UI)
	_retry_button.add_theme_font_size_override("font_size", 18)

	_kicker.text = "EVOLUTION RUN"
	_title.text = "Run complete"
	_score_caption.text = "SCORE"
	_xp_caption.text = "RUN XP"
	_retry_button.text = "Play again"

## UC-04 Adım 2: Final skoru ve BU TURDA kazanılan XP'yi gösterip ekranı açar.
func _on_game_over_ready(final_stats: Dictionary) -> void:
	var score: int = int(final_stats.get("score", 0))
	var xp_gained: int = int(final_stats.get("xp_gained", 0))
	_score_value.text = HUDTheme.format_thousands(score)
	_xp_value.text = "+%s" % HUDTheme.format_thousands(xp_gained)
	visible = true

## "Play again" butonuna basınca ekranı kapatır ve GameManager üzerinden yeni turu başlatır.
func _on_retry_pressed() -> void:
	visible = false
	GameManager.reset_run()
