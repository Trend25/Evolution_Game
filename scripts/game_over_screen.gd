extends CanvasLayer
class_name GameOverScreen
## GameOverScreen — UC-04: Oyun Bitti ekranı. GameManager.game_over_ready
## sinyalini dinleyip final skor/XP'yi gösterir; "Tekrar Oyna" butonu yeni
## bir tur başlatır. Mimari belgenin Bölüm 5 sahne hiyerarşisinde ayrı bir
## node olarak listelenmemiştir, ancak UC-04 Adım 2'nin gerektirdiği "Oyun
## Bitti ekranı" için gereklidir.

@onready var score_label: Label = $Panel/VBoxContainer/ScoreLabel
@onready var xp_label: Label = $Panel/VBoxContainer/XPLabel
@onready var retry_button: Button = $Panel/VBoxContainer/RetryButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Oyun duraklatılsa (UC-04) bile ekran/buton çalışsın
	visible = false
	GameManager.game_over_ready.connect(_on_game_over_ready)
	retry_button.pressed.connect(_on_retry_pressed)

## UC-04 Adım 2: Final skor/XP istatistiklerini gösterip ekranı açar.
func _on_game_over_ready(final_stats: Dictionary) -> void:
	score_label.text = "Skor: %d" % int(final_stats.get("score", 0))
	xp_label.text = "Kazanılan XP: %d" % int(final_stats.get("xp", 0))
	visible = true

## "Tekrar Oyna" butonuna basınca ekranı kapatır ve GameManager üzerinden yeni turu başlatır.
func _on_retry_pressed() -> void:
	visible = false
	GameManager.reset_run()
