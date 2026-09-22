extends Node
## GameManager — Autoload. Oyun genelinde skor/XP/can/seviye durumunu tutar.
## UC-02 Adım 3: Her merge işleminde skor ve kalıcı profil XP'si burada güncellenir.
## UC-03: Can (kalp) sistemini yönetir.
## UC-05: Meta seviye (XP eşiği) ve seviye atlama mantığını yönetir.

const MAX_LIVES: int = 3        # 3.1 Can Sistemi: Oyuncu her turda 3 can ile başlar
const LEVEL_XP_BASE: int = 100  # UC-05 / 3.2: Seviye n → n+1 eşiği ≈ n × LEVEL_XP_BASE

# Bonus Sistemi (kullanıcı isteği): Spawner'ın zaman zaman ürettiği özel
# "bonus" canlı ile birleşince skor bu kat artar (bkz. organism.gd is_bonus,
# spawner.gd bonus zamanlayıcısı). XP'ye dokunmaz, sadece skora uygulanır.
const BONUS_ORGANISM_SCORE_MULTIPLIER: float = 4.0

signal score_changed(new_score: int)
signal xp_changed(new_xp: int)
signal organism_merged(position: Vector2, merged_stage_id: int)  # UI/UX rolü: Tween/ses/parçacık tetikleyicisi için
signal lives_changed(new_lives: int)          # UI/UX rolü: LivesUI (3 kalp göstergesi) için
signal life_lost(lives_remaining: int)        # UI/UX rolü: "Can Kaybı" uyarı animasyonu/sesi için
signal game_over                              # UC-03 Adım 3: can bitince yayınlanır
signal game_over_ready(final_stats: Dictionary)  # UI/UX rolü: "Oyun Bitti" ekranı için
signal run_reset                              # Main.gd: yeni tur başında fanusun temizlenmesi için
signal level_changed(new_level: int)          # UI/UX rolü: XPBar için
signal level_up(new_level: int, unlocked_reward_id: String)  # UI/UX rolü: "Seviye Atladın!" bildirimi için

var score: int = 0
var xp: int = 0
var lives: int = MAX_LIVES
var level: int = 1
var unlocked_rewards: Array[String] = []  # UC-05 Adım 3: açılan kozmetik ödül id'leri (kalıcı profil verisi)

# style: apply polished HUD and run summary -- Run Summary ekranındaki "RUN XP"
# alanı için, SADECE bu turda kazanılan XP'yi izleyen ek bir bookkeeping
# değişkeni. XP EKONOMİSİNE (nasıl kazanılır, seviye eşikleri, kalıcılık —
# xp hâlâ reset_run()'da SIFIRLANMAZ) dokunmaz; yalnızca xp'nin turun
# BAŞINDAKİ değerini saklar ki final_stats bir fark hesaplayabilsin.
var _run_start_xp: int = 0

func _ready() -> void:
	game_over.connect(_on_game_over)
	_run_start_xp = xp  # oyun açılışında xp=0

## UC-02 Adım 3: Merge sonucu kazanılan skor ve XP'yi ekler, ilgili sinyalleri
## yayınlar. Bonus Sistemi: is_bonus true ise (Spawner'ın ürettiği özel canlı
## birleşmenin bir tarafıysa) skor BONUS_ORGANISM_SCORE_MULTIPLIER ile çarpılır.
## Geriye uyumluluk: is_bonus parametresi varsayılan false — eski çağrı yeri
## (varsa) davranışı değişmeden çalışır.
func add_merge_reward(stage_id: int, merge_position: Vector2, is_bonus: bool = false) -> void:
	var stage: Dictionary = OrganismTypes.get_stage(stage_id)
	if stage.is_empty():
		return
	var bonus_multiplier: float = BONUS_ORGANISM_SCORE_MULTIPLIER if is_bonus else 1.0
	var awarded_score: int = int(round(int(stage.get("score_value", 0)) * bonus_multiplier))
	score += awarded_score
	xp += int(stage.get("xp_value", 0))
	score_changed.emit(score)
	xp_changed.emit(xp)
	organism_merged.emit(merge_position, stage_id)
	_check_level_up()

## UC-05 Adım 2-3: XP eşiği aşıldıkça seviyeyi artırır (tek merge'te birden
## fazla eşik aşılabileceğinden while ile), her seviyede bir kozmetik ödül
## açar ve level_up sinyalini yayınlar.
func _check_level_up() -> void:
	while xp >= level * LEVEL_XP_BASE:
		level += 1
		var reward_id: String = "reward_level_%d" % level
		unlocked_rewards.append(reward_id)
		level_changed.emit(level)
		level_up.emit(level, reward_id)

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
		"xp_gained": xp - _run_start_xp,  # style: apply polished HUD and run summary -- Run Summary "RUN XP" alanı için
		"level": level,
		"achievements": [],  # UC-06 henüz kodlanmadı; şimdilik boş liste
	}
	LeaderboardService.submit_score(score)  # UC-04 Adım 3 / UC-07
	game_over_ready.emit(final_stats)

## Skor ve canları başlangıç değerlerine sıfırlar, oyunu duraklatmadan çıkarır
## ve run_reset sinyaliyle fanusun temizlenmesini tetikler (Tester bulgusu:
## "Tekrar Oyna" önceden fanustaki eski canlıları temizlemiyordu).
## NOT: XP ve seviye SIFIRLANMAZ — 3.2'ye göre XP "kalıcı oyuncu profili"
## verisidir, sadece skor "anlık oyun turu" verisidir. Önceki sürümde xp de
## sıfırlanıyordu; bu, UC-05'in "kalıcı" XP gereksinimiyle çelişiyordu.
func reset_run() -> void:
	score = 0
	lives = MAX_LIVES
	get_tree().paused = false
	score_changed.emit(score)
	lives_changed.emit(lives)
	_run_start_xp = xp  # style: apply polished HUD and run summary -- yeni turun XP başlangıcı; kalıcı xp'ye DOKUNMAZ
	run_reset.emit()
