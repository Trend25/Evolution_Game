extends Node2D
class_name DropFeedbackManager
## DropFeedbackManager -- feat: add drop aiming and landing feedback.
## Main.tscn'de "DropFeedbackManager" olarak, EffectsLayer'ın KARDEŞİ
## (world-space, aynı CanvasLayer=0) olarak durur. Spawner.organism_dropped
## sinyalini dinleyen KÜÇÜK bir orkestrator: HER drop'ta tam olarak bir
## DropEntryPop instantiate eder. Kendisi hiçbir collision/fizik/skor/XP/
## bonus/spawn/cooldown mantığına KATILMAZ -- yalnızca Spawner tarafından
## ZATEN hesaplanmış değerleri (position, is_bonus) GÖRSELLEŞTİRİR.
##
## Aynı drop için çift efekt riski yoktur: organism_dropped sinyali
## Spawner._drop_current_organism() içinde her gerçek drop'ta TAM OLARAK
## bir kez yayınlanır.
##
## Game Over/Retry'da hâlâ oynayan (tween'i bitmemiş) efektler HEMEN
## temizlenir ki ekranda eski bir giriş halkası asılı kalmasın.

const DropEntryPopScene: PackedScene = preload("res://scenes/DropEntryPop.tscn")

@onready var _spawner: Spawner = get_node("../Spawner")

func _ready() -> void:
	_spawner.organism_dropped.connect(_on_organism_dropped)
	GameManager.game_over_ready.connect(_clear_active_effects)
	GameManager.run_reset.connect(_clear_active_effects)

func _on_organism_dropped(world_position: Vector2, is_bonus: bool) -> void:
	var pop: Node2D = DropEntryPopScene.instantiate()
	add_child(pop)
	pop.global_position = Vector2(world_position.x, _visible_min_y(world_position.y))
	pop.play(is_bonus)

## Spawner'ın y konumu (Main.tscn: 100) HUD panellerinin (üstteki üç kutu)
## dikey aralığı İÇİNDEDİR -- bu yüzden efekt tam drop konumunda oynatılırsa
## HUD'un (CanvasLayer=10, her zaman üstte) ARKASINDA tamamen görünmez kalır
## (organizmanın KENDİSİ de aynı nedenle panelin altına düşene kadar
## görünmez zaten -- bkz. spawner.gd _prepare_next_organism). Efekt bu yüzden
## panellerin GERÇEK alt kenarının (HUDRoot ile AYNI merkezi hesap, chain_
## toast.gd/level_up_toast.gd'nin de kullandığı) hemen altına klemplenir.
## SADECE efektin GÖRSEL konumunu ayarlar -- dropped.global_position'ın
## GameManager/organism.gd tarafından hesaplanan GERÇEK değeri, sinyalde
## ZATEN olduğu gibi taşınmaya devam eder; collision/fizik konumuna dokunmaz.
func _visible_min_y(drop_y: float) -> float:
	var layout: Dictionary = HUDRoot.compute_panel_layout(SafeArea.get_margins())
	var hud_bottom: float = float(layout.get("top", 20.0)) + float(layout.get("height", 124.0))
	return max(drop_y, hud_bottom + 6.0)

## NOT: bu fonksiyon hem game_over_ready(final_stats: Dictionary) hem de
## run_reset() (parametresiz) sinyaline BAĞLI -- aynı imza-uyumsuzluğu
## sınıfından kaçınmak için (bkz. merge_feedback_manager.gd'de bulunan ve
## düzeltilen hata) varsayılan değerli opsiyonel parametre kullanılır.
func _clear_active_effects(_final_stats: Dictionary = {}) -> void:
	for child in get_children():
		child.queue_free()
