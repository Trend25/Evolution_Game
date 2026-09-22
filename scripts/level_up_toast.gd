extends CanvasLayer
class_name LevelUpToast
## LevelUpToast — UC-05 Adım 3: Seviye atlama bildirimi. style: apply polished
## HUD and run summary -- "Seviye Atladın! Seviye N" yerine kısa "LEVEL N"
## capsule: küçük yatay kapsül, koyu teal yüzey + ince muted-gold sınır, kısa
## fade+slide (bounce/konfeti YOK). fix: stabilize HUD layout and layer
## ordering commit'inden gelen "Game Over açıkken toast görünmesin/tween
## güvenle durdurulsun" davranışı KORUNUYOR. Konum, HUDRoot ile AYNI merkezi
## compute_panel_layout() fonksiyonunu kullanır -- ayrı/çatallanmış sabit
## koordinat YOK.

const FADE_SECONDS: float = 0.4
const DISPLAY_SECONDS: float = 1.6
const SLIDE_DISTANCE: float = 8.0
const CAPSULE_WIDTH: float = 168.0
const CAPSULE_HEIGHT: float = 40.0
const CAPSULE_GAP_BELOW_HUD: float = 12.0  # kullanıcı talebi: "Ana HUD'un hemen altında"

@onready var _capsule: Panel = $Capsule
@onready var _label: Label = $Capsule/Label

var _active_tween: Tween = null
var _rest_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	_capsule.add_theme_stylebox_override("panel", HUDTheme.make_toast_capsule_stylebox())
	HUDTheme.style_label(_label, HUDTheme.FONT_UI, 18, HUDTheme.GOLD_ACCENT)
	_capsule.modulate.a = 0.0
	_position_capsule()
	get_tree().root.size_changed.connect(_position_capsule)
	GameManager.level_up.connect(_on_level_up)
	GameManager.game_over_ready.connect(_on_game_over_ready)

## Kapsülü, HUDRoot ile AYNI merkezi düzen fonksiyonunu (HUDRoot.compute_panel_layout,
## static) kullanarak HUD panellerinin hemen altına, yatayda ekran merkezine
## (x=360) hizalı konumlandırır.
func _position_capsule() -> void:
	var layout: Dictionary = HUDRoot.compute_panel_layout(SafeArea.get_margins())
	var hud_bottom: float = float(layout.get("top", 20.0)) + float(layout.get("height", 124.0))
	_rest_position = Vector2(360.0 - CAPSULE_WIDTH / 2.0, hud_bottom + CAPSULE_GAP_BELOW_HUD)
	_capsule.position = _rest_position
	_capsule.size = Vector2(CAPSULE_WIDTH, CAPSULE_HEIGHT)

## UC-05 Adım 3: Yeni seviyeyi gösterip kısa fade+slide oynatır.
func _on_level_up(new_level: int, _unlocked_reward_id: String) -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_label.text = "LEVEL %d" % new_level
	_capsule.modulate.a = 0.0
	_capsule.position = _rest_position + Vector2(0.0, SLIDE_DISTANCE)
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.tween_property(_capsule, "modulate:a", 1.0, FADE_SECONDS)
	_active_tween.tween_property(_capsule, "position", _rest_position, FADE_SECONDS)
	_active_tween.chain().tween_interval(DISPLAY_SECONDS)
	_active_tween.chain().tween_property(_capsule, "modulate:a", 0.0, FADE_SECONDS)

## fix: stabilize HUD layout and layer ordering'den korunan davranış: Oyun
## Bitti açıldığında aktif bir bildirim (varsa çalışan tween'i dahil) görünür
## kalmasın diye anında gizlenir. GameManager skor/XP/seviye mantığına dokunmaz.
func _on_game_over_ready(_final_stats: Dictionary) -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_capsule.modulate.a = 0.0
