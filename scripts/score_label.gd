extends Label
## ScoreLabel — UI_Canvas: GameManager.score_changed sinyalini dinleyip
## güncel skoru gösterir. Oynanış mantığına dokunmaz, sadece görselleştirir.

func _ready() -> void:
	text = "Skor: %d" % GameManager.score
	GameManager.score_changed.connect(_on_score_changed)

## Skor değiştiğinde etiket metnini günceller.
func _on_score_changed(new_score: int) -> void:
	text = "Skor: %d" % new_score
