extends Node
## GameManager — Autoload. Oyun genelinde skor/XP/can durumunu tutar.
## UC-02 Adım 3: Her merge işleminde skor ve kalıcı profil XP'si burada güncellenir.
## UC-03: Can (kalp) sistemini yönetir.
## (Meta seviye eşiği ve seviye atlama mantığı UC-05 kapsamındadır, bu görevde ele alınmadı.)

const MAX_LIVES: int = 3  # 3.1 Can Sistemi: Oyuncu her turda 3 can ile başlar

signal score_changed(new_score: int)
signal xp_changed(new_xp: int)
signal organism_merged(position: Vector2, merged_stage_id: int)  # UI/UX rolü: Tween/ses/parçacık tetikleyicisi için
signal lives_changed(new_lives: int)          # UI/UX rolü: LivesUI (3 kalp göstergesi) için
signal life_lost(lives_remaining: int)        # UI/UX rolü: "Can Kaybı" uyarı animasyonu/sesi için
signal game_over                              # UC-03 Adım 3: can bitince yayınlanır
signal game_over_ready(final_stats: Dictionary)  # UI/UX rolü: "Oyun Bitti" ekranı için

var score: int = 0
var xp: int = 0
var lives: int = MAX_LIVES

func _ready() -> void:
	game_over.connect(_on_game_over)

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

## UC-03 Adım 2-3: Bir can azaltır ve ilgili sinyalleri yayınlar; can bitince
## (Kalan can = 0) UC-04'ü tetikleyecek game_over sinyalini yayınlar.
func lose_life() -> void:
	if lives <= 0:
		return
	lives -= 1
	lives_changed.emit(lives)
	life_lost.emit(lives)
	if lives <= 0:
		game_over.emit()  # UC-04: Oyun Sonu — _on_game_over() işler; "Oyun Bitti" ekranı UI/UX rolünün kapsamında

## UC-04 Adım 2-3: Can bittiğinde oyunu duraklatır, final istatistiklerini
## hazırlar (skor/XP/başarımlar) ve skoru liderlik tablosu servisine gönderir.
func _on_game_over() -> void:
	get_tree().paused = true
	var final_stats: Dictionary = {
		"score": score,
		"xp": xp,
		"achievements": [],  # UC-06 henüz kodlanmadı; şimdilik boş liste
	}
	LeaderboardService.submit_score(score)  # UC-04 Adım 3 / UC-07
	game_over_ready.emit(final_stats)

## Skor, XP ve canları başlangıç değerlerine sıfırlar; oyunu duraklatmadan
## çıkarır (yeni oyun turu başlangıcı için).
func reset_run() -> void:
	score = 0
	xp = 0
	lives = MAX_LIVES
	get_tree().paused = false
	score_changed.emit(score)
	xp_changed.emit(xp)
	lives_changed.emit(lives)
