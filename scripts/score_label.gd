extends Label
## ScoreLabel — UI_Canvas/HUDRoot/ScorePanel/ScoreValue: GameManager.score_changed
## sinyalini dinleyip güncel skoru gösterir. style: apply polished HUD and run
## summary -- Bricolage Grotesque font + binlik ayraçlı (İngilizce virgül)
## gösterim biçimi (bkz. HUDTheme.format_thousands). Skor HESAPLAMASINA
## dokunmaz, YALNIZCA gösterim biçimini değiştirir.

const VALUE_FONT_SIZE: int = 39  # kullanıcı talebi: ~38-40px

func _ready() -> void:
	HUDTheme.style_label(self, HUDTheme.FONT_NUMBER, VALUE_FONT_SIZE, HUDTheme.TEXT_PRIMARY)
	text = HUDTheme.format_thousands(GameManager.score)
	GameManager.score_changed.connect(_on_score_changed)

## Skor değiştiğinde etiket metnini günceller.
func _on_score_changed(new_score: int) -> void:
	text = HUDTheme.format_thousands(new_score)
