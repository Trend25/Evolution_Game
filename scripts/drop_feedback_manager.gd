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
const LightTransferBeamScript: GDScript = preload("res://scripts/light_transfer_beam.gd")

@onready var _spawner: Spawner = get_node("../Spawner")

func _ready() -> void:
	_spawner.organism_dropped.connect(_on_organism_dropped)
	GameManager.game_over_ready.connect(_clear_active_effects)
	GameManager.run_reset.connect(_clear_active_effects)

func _on_organism_dropped(world_position: Vector2, is_bonus: bool, organism: Node = null) -> void:
	var visible_position: Vector2 = Vector2(world_position.x, _visible_min_y(world_position.y))
	var pop: Node2D = DropEntryPopScene.instantiate()
	add_child(pop)
	pop.global_position = visible_position
	pop.play(is_bonus)
	_maybe_spawn_light_transfer_beam(visible_position, organism, is_bonus)

## gameplay/core-loop-v4 "Evrim Laboratuvarı" (madde 3 -- "ışık transferi"):
## SADECE bu dilimin kapsadığı aşamalarda (Virüs/Bakteri/Tek Hücreli) ve
## LAB_VISUALS_ENABLED iken -- diğer durumlarda (üretim, ya da bu dilimde
## erişilemeyen aşamalar/balık parçaları) eski davranış (yalnızca
## DropEntryPop) DEĞİŞMEDEN kalır. `organism` geçersizse (teorik olarak
## imkansız -- Spawner sinyali her zaman geçerli bir referansla yayınlar, ama
## savunmacı) sessizce atlanır.
func _maybe_spawn_light_transfer_beam(visible_position: Vector2, organism: Node, is_bonus: bool) -> void:
	if not is_instance_valid(organism):
		return
	var stage_id: int = int(organism.get("stage_id"))
	var is_fish_part: bool = bool(organism.get("is_fish_part"))
	if not (GrayboxConfig.ENABLED and GrayboxConfig.LAB_VISUALS_ENABLED and stage_id <= OrganismTypes.VERTICAL_SLICE_FINAL_STAGE_ID and not is_fish_part):
		return
	var radius: float = GrayboxConfig.effective_radius(stage_id, int(organism.get("tier")))
	var beam := Node2D.new()
	beam.set_script(LightTransferBeamScript)
	add_child(beam)
	# Portalın GÖRSEL konumuyla (dna_portal.gd) AYNI kaynak/sabit -- huzme
	# kuyruğu gerçekten portaldan çıkıyormuş gibi görünsün diye (kullanıcı:
	# "portal ile düşen canlı arasında ... ışık kuyruğu"). Spawner drop
	# anında x ekseninde bu konumdaydı; sabit yakalanır ki oyuncu hemen
	# ardından yeniden aim etmeye başlarsa (Spawner x'i değişir) bu ÖNCEKİ
	# huzme yanlış konuma "atlamaz".
	var portal_anchor: Vector2 = Vector2(visible_position.x, _spawner.global_position.y + GrayboxConfig.PORTAL_ANCHOR_Y_OFFSET)
	beam.start(visible_position, organism, radius, is_bonus, portal_anchor)

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
