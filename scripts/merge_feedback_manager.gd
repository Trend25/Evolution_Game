extends Node2D
class_name MergeFeedbackManager
## MergeFeedbackManager -- feat: add merge burst and floating score feedback.
## Main.tscn'de "EffectsLayer" olarak, OrganismContainer'in KARDESI (world-
## space, ayni CanvasLayer=0) olarak durur. GameManager.organism_merged
## sinyalini dinleyen KUCUK bir orkestrator: HER basarili merge'de bir
## MergeBurst, YALNIZCA skor odulu veren merge'lerde EK olarak bir
## FloatingScoreText instantiate eder. Kendisi hicbir collision/fizik/skor/
## XP/bonus/spawn mantigina KATILMAZ -- yalnizca GameManager/organism.gd
## tarafindan ZATEN hesaplanmis degerleri (position, stage_id, is_bonus,
## awarded_score, score_awarded) GORSELLESTIRIR.
##
## Aynı merge icin cift efekt riski yoktur: organism_merged sinyali
## organism.gd/game_manager.gd tarafindan her gercek merge'de TAM OLARAK
## bir kez yayinlanir (bkz. _is_merging/instance-id koruma, final rapor) --
## bu manager de o TEK sinyale tam olarak bir burst + (varsa) bir floating
## score ile karsilik verir.
##
## Game Over/Retry'da hala oynayan (tween'i bitmemis) efektler HEMEN
## temizlenir ki ekranda eski bir burst/floating-score asili kalmasin.

const MergeBurstScene: PackedScene = preload("res://scenes/MergeBurst.tscn")
const FloatingScoreTextScene: PackedScene = preload("res://scenes/FloatingScoreText.tscn")

func _ready() -> void:
	GameManager.organism_merged.connect(_on_organism_merged)
	GameManager.game_over_ready.connect(_clear_active_effects)
	GameManager.run_reset.connect(_clear_active_effects)

func _on_organism_merged(merge_position: Vector2, stage_id: int, is_bonus: bool, awarded_score: int, score_awarded: bool, combo_count: int = 1) -> void:
	_spawn_burst(merge_position, stage_id, is_bonus)
	if score_awarded:
		_spawn_floating_score(merge_position, awarded_score, is_bonus, combo_count)

## Burst boyutu, o aşamanın GERCEK collision radius'undan (OrganismTypes)
## turetilir -- sabit/kopyalanmis bir boyut tablosu YOKTUR.
func _spawn_burst(world_position: Vector2, stage_id: int, is_bonus: bool) -> void:
	var stage: Dictionary = OrganismTypes.get_stage(stage_id)
	var stage_radius: float = float(stage.get("radius", 24.0))
	var burst: Node2D = MergeBurstScene.instantiate()
	add_child(burst)
	burst.global_position = world_position
	burst.play(is_bonus, stage_radius)

func _spawn_floating_score(world_position: Vector2, awarded_score: int, is_bonus: bool, combo_count: int = 1) -> void:
	var text: Node2D = FloatingScoreTextScene.instantiate()
	add_child(text)
	text.global_position = world_position
	text.play(awarded_score, is_bonus, combo_count)

## Game Over veya Retry ("Play again") tetiklendiginde hala sahnede olan
## (animasyonu bitmemis) tum burst/floating-score instance'larini aninda
## kaldirir. Chain sayacinin kendi sifirlanmasi ayri (chain_toast.gd) --
## bu fonksiyon yalnizca bu manager'in KENDI cocuklarindan sorumludur.
## NOT: bu fonksiyon hem game_over_ready(final_stats: Dictionary) hem de
## run_reset() (parametresiz) sinyaline BAGLI -- Godot'ta bagli callable'in
## parametre sayisi sinyalin gonderdigi arguman sayisiyla TAM eslesmezse
## "Method expected 0 argument(s), but called with 1" hatasiyla cagri hic
## YAPILMAZ (bulundu: game_over_ready tetiklendiginde bu fonksiyon hicbir
## zaman calismiyordu, bu yuzden Game Over sonrasi aktif efektler ekranda
## kaliyordu). Varsayilan degerli opsiyonel parametre iki sinyal imzasiyla
## da uyumlu olur.
func _clear_active_effects(_final_stats: Dictionary = {}) -> void:
	for child in get_children():
		child.queue_free()
