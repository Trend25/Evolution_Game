extends CanvasLayer
class_name LevelUpToast
## LevelUpToast — UC-05 Adım 3: "Seviye Atladın!" bildirimi. Mimari belgenin
## Bölüm 5 sahne hiyerarşisinde ayrı bir node olarak listelenmemiştir (orada
## sadece UC-06 için AchievementToast var), ancak UC-05 Adım 3'ün metni
## ("ekranda 'Seviye Atladın!' bildirimi gösterilir") bunu gerektiriyor.
## GameManager.level_up sinyalini dinleyip Tween ile fade in/bekleme/fade out
## animasyonu oynatır. Oynanış mantığına dokunmaz.

const FADE_SECONDS: float = 0.4      # Fade in/out süresi
const DISPLAY_SECONDS: float = 1.6   # Tam görünür kalma süresi

@onready var label: Label = $Label

func _ready() -> void:
	label.modulate.a = 0.0
	GameManager.level_up.connect(_on_level_up)

## UC-05 Adım 3: Yeni seviyeyi gösterip fade in → bekleme → fade out oynatır.
func _on_level_up(new_level: int, _unlocked_reward_id: String) -> void:
	label.text = "Seviye Atladın! Seviye %d" % new_level
	var tween: Tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, FADE_SECONDS)
	tween.tween_interval(DISPLAY_SECONDS)
	tween.tween_property(label, "modulate:a", 0.0, FADE_SECONDS)
