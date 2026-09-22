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

var _active_tween: Tween = null  # fix: stabilize HUD layout and layer ordering -- Game Over anında güvenle durdurulabilsin diye saklanır

func _ready() -> void:
	label.modulate.a = 0.0
	GameManager.level_up.connect(_on_level_up)
	GameManager.game_over_ready.connect(_on_game_over_ready)

## UC-05 Adım 3: Yeni seviyeyi gösterip fade in → bekleme → fade out oynatır.
func _on_level_up(new_level: int, _unlocked_reward_id: String) -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	label.text = "Seviye Atladın! Seviye %d" % new_level
	label.modulate.a = 0.0
	_active_tween = create_tween()
	_active_tween.tween_property(label, "modulate:a", 1.0, FADE_SECONDS)
	_active_tween.tween_interval(DISPLAY_SECONDS)
	_active_tween.tween_property(label, "modulate:a", 0.0, FADE_SECONDS)

## fix: stabilize HUD layout and layer ordering -- Oyun Bitti ekranı açıldığında
## aktif bir seviye bildirimi (varsa çalışan tween'i dahil) görünür kalmasın
## diye anında gizlenir. Yalnızca bu toast'ın kendi görünürlüğünü etkiler;
## GameManager skor/XP/seviye mantığına dokunmaz.
func _on_game_over_ready(_final_stats: Dictionary) -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	label.modulate.a = 0.0
