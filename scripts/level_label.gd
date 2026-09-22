extends Label
class_name LevelLabelUI
## LevelLabelUI — style: apply polished HUD and run summary. UI_Canvas/HUDRoot/
## LeftPanel altındaki "LVL 3" benzeri seviye etiketi. GameManager.level_changed
## sinyalini dinleyip metni günceller. Oynanış/XP/seviye mantığına dokunmaz,
## sadece GameManager.level'ı okuyup gösterir.

func _ready() -> void:
	HUDTheme.style_label(self, HUDTheme.FONT_UI, 15, HUDTheme.TEXT_PRIMARY)
	text = "LVL %d" % GameManager.level
	GameManager.level_changed.connect(_on_level_changed)

func _on_level_changed(new_level: int) -> void:
	text = "LVL %d" % new_level
