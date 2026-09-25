extends CanvasLayer
class_name NewLifeToast
## NewLifeToast -- gameplay/core-loop-v4 "Evrim Laboratuvarı" V02 vertical
## slice (madde 5/8 -- kullanıcı: "kısa bir 'Yeni Yaşam: Bakteri' bildirimi").
## LevelUpToast/ChainToast ile AYNI kapsül/tween deseni (bu projede zaten
## çalışır durumda kanıtlanmış) -- GameManager.new_life_discovered sinyalini
## dinler, SADECE GÖRSEL/bildirim: skor/XP/collection/evrim mantığına
## KATILMAZ, GameManager ZATEN hesaplamış olan (stage_id, stage_name,
## is_first_ever) verisini GÖSTERİR. Konum HUDRoot.compute_panel_layout() ile
## AYNI merkezi hesaptan gelir (ayrı/çatallanmış sabit koordinat YOK) --
## LevelUpToast'ın TAM ALTINA, üst üste binmesin diye ayrı bir satıra
## konumlanır.

const FADE_SECONDS: float = 0.35
const DISPLAY_SECONDS: float = 1.5
const SLIDE_DISTANCE: float = 8.0
# DÜZELTME (V02 İKİNCİ düzeltme turu -- kullanıcı madde 5: "'Yeni Yaşam'
# bildiriminin kontrastını artır"): eski MINT_ACCENT (#74DDCB) metin, koyu
# teal panel (NEXT_SURFACE) üzerinde -- artan sahne yoğunluğuyla (bioreactor_
# ambience.gd'nin güçlendirilmiş atmosferi, DNA-sarmalı/ışık-patlaması burst'ü
# vb.) arka planın kendisi de artık daha "canlı/parlak" -- eski kontrast
# yetersiz kalıyordu. Metin artık TEXT_PRIMARY'ye (neredeyse beyaz --
# GOLD_ACCENT sınırdan/MINT_ACCENT'ten çok daha yüksek kontrast) çekildi VE
# floating_score_text.gd'deki AYNI koyu-dış-hat tekniği eklendi (kalın metin
# hissi + her arka plan tonunda net kenar). Kapsül biraz genişletildi (220->236)
# ki büyütülen font (17->19) hiçbir stage adında kırpılmasın.
const CAPSULE_WIDTH: float = 236.0
const CAPSULE_HEIGHT: float = 40.0
const CAPSULE_GAP_BELOW_HUD: float = 12.0
const ROW_GAP: float = 8.0  # LevelUpToast'un (AYNI yükseklikte, AYNI y'de) kapsülünün hemen altına iner
const TEXT_OUTLINE_COLOR: Color = Color(0.02, 0.05, 0.05, 0.9)
const TEXT_OUTLINE_SIZE: int = 5

@onready var _capsule: Panel = $Capsule
@onready var _label: Label = $Capsule/Label

var _active_tween: Tween = null
var _rest_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	_capsule.add_theme_stylebox_override("panel", HUDTheme.make_toast_capsule_stylebox())
	HUDTheme.style_label(_label, HUDTheme.FONT_UI, 19, HUDTheme.TEXT_PRIMARY)
	_label.add_theme_color_override("font_outline_color", TEXT_OUTLINE_COLOR)
	_label.add_theme_constant_override("outline_size", TEXT_OUTLINE_SIZE)
	_capsule.modulate.a = 0.0
	_position_capsule()
	get_tree().root.size_changed.connect(_position_capsule)
	GameManager.new_life_discovered.connect(_on_new_life_discovered)
	GameManager.game_over_ready.connect(_on_reset_state)
	GameManager.run_reset.connect(_on_reset_state)

func _position_capsule() -> void:
	var layout: Dictionary = HUDRoot.compute_panel_layout(SafeArea.get_margins())
	var hud_bottom: float = float(layout.get("top", 20.0)) + float(layout.get("height", 124.0))
	var levelup_bottom: float = hud_bottom + CAPSULE_GAP_BELOW_HUD + 40.0  # LevelUpToast CAPSULE_HEIGHT ile aynı sabit
	_rest_position = Vector2(360.0 - CAPSULE_WIDTH / 2.0, levelup_bottom + ROW_GAP)
	_capsule.position = _rest_position
	_capsule.size = Vector2(CAPSULE_WIDTH, CAPSULE_HEIGHT)

## GameManager.new_life_discovered(stage_id, stage_name, is_first_ever).
## Yalnızca is_first_ever=true olduğunda gösterilir -- kullanıcı isteği "yeni
## yaşam" tanımıyla eşleşen tek an budur (aynı aşamanın SONRAKİ merge'lerinde
## tekrar tekrar "Yeni Yaşam" göstermek anlamsız/gürültülü olurdu).
func _on_new_life_discovered(_stage_id: int, stage_name: String, is_first_ever: bool) -> void:
	if not is_first_ever:
		return
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_label.text = "Yeni Yaşam: %s" % stage_name
	_capsule.modulate.a = 0.0
	_capsule.position = _rest_position + Vector2(0.0, SLIDE_DISTANCE)
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.tween_property(_capsule, "modulate:a", 1.0, FADE_SECONDS)
	_active_tween.tween_property(_capsule, "position", _rest_position, FADE_SECONDS)
	_active_tween.chain().tween_interval(DISPLAY_SECONDS)
	_active_tween.chain().tween_property(_capsule, "modulate:a", 0.0, FADE_SECONDS)

## NOT: hem game_over_ready(final_stats: Dictionary) hem de run_reset()
## (parametresiz) sinyaline BAĞLI -- bkz. chain_toast.gd/level_up_toast.gd
## AYNI notu (gerçek GL çalışma zamanında bulunan sınıf hatasından kaçınmak
## için varsayılan değerli opsiyonel parametre kullanılır).
func _on_reset_state(_final_stats: Dictionary = {}) -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_capsule.modulate.a = 0.0
