extends Node
## GameManager — Autoload. Oyun genelinde skor/XP durumunu tutar.
## UC-02 Adım 3: Her merge işleminde skor ve kalıcı profil XP'si burada güncellenir.
## (Meta seviye eşiği ve seviye atlama mantığı UC-05 kapsamındadır, bu görevde ele alınmadı.)

signal score_changed(new_score: int)
signal xp_changed(new_xp: int)
signal organism_merged(position: Vector2, merged_stage_id: int)  # UI/UX rolü: Tween/ses/parçacık tetikleyicisi için

var score: int = 0
var xp: int = 0

## UC-02 Adım 3: Merge sonucu kazanılan skor ve XP'yi ekler, ilgili sinyalleri yayınlar.
func add_merge_reward(stage_id: int, merge_position: Vector2) -> void:
	var stage: Dictionary = OrganismTypes.get_stage(stage_id)
	if stage.is_empty():
		return
	score += int(stage.get("score_value", 0))
	xp += int(stage.get("xp_value", 0))
	score_changed.emit(score)
	xp_changed.emit(xp)
	organism_merged.emit(merge_position, stage_id)

## Skor ve XP'yi sıfırlar (yeni oyun turu başlangıcı için).
func reset_run() -> void:
	score = 0
	xp = 0
	score_changed.emit(score)
	xp_changed.emit(xp)
