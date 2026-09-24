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

# feat: improve mobile scale and scoring feedback (Bölüm C) -- kullanıcı
# isteği: "tek tek +1 skorlaması yerine merkezi bir skor tablosu: düşürme
# +5". Bu, merge ekonomisinden (OrganismTypes.STAGES[].score_value)
# TAMAMEN ayrı, sabit bir ödüldür -- her BAŞARILI bırakma (Spawner) anında
# verilir, kombo/bonus çarpanı UYGULANMAZ.
const DROP_SCORE_VALUE: int = 5

# feat: improve mobile scale and scoring feedback (Bölüm C) -- kullanıcı
# isteği: "1.5 saniye içinde art arda gerçekleşen mergeler için gerçek
# x2/x3/x4 kombo çarpanları uygula". Bu, chain_toast.gd'nin ÖNCEKİ salt-
# KOZMETİK 2.25s zincir sayacının YERİNİ ALAN, GERÇEK skoru etkileyen tek
# yetkili (authoritative) kombo sistemidir -- chain_toast artık kendi
# sayacını tutmuyor, bu sistemin ürettiği combo_count'u organism_merged
# sinyalinden okuyup SADECE gösteriyor (bkz. chain_toast.gd).
const COMBO_WINDOW_SECONDS: float = 1.5
# combo_count'a göre çarpan: 1. merge x1 (çarpan yok), 2. merge x2, 3. merge
# x3, 4. ve sonrası x4'te SABİTLENİR (kullanıcı isteği: "x2/x3/x4").
const COMBO_MULTIPLIERS: Array[float] = [1.0, 2.0, 3.0, 4.0]

signal score_changed(new_score: int)
signal xp_changed(new_xp: int)
# feat: add merge burst and floating score feedback -- imza genisletildi:
# is_bonus/awarded_score/score_awarded eklendi ki TEK bir sinyal hem burst
# (HER basarili merge), hem floating score (YALNIZCA skor verilen merge),
# hem chain sayaci icin yeterli veriyi tasisin. Onceden bu sinyali dinleyen
# YOKTU (grep ile dogrulandi, docstring zaten "Tween/ses/parcacik
# tetikleyicisi icin" diyordu) -- imza genisletmek mevcut hicbir davranisi
# BOZMAZ. Skor EKONOMISINE (nasil hesaplandigi) dokunmaz, sadece ZATEN
# hesaplanmis degerleri disari tasir.
# feat: improve mobile scale and scoring feedback (Bölüm C) -- imza TEKRAR
# genişletildi: combo_count eklendi (1 = kombo yok, 2+ = gerçek zincir).
# ÖNEMLİ (gerçek GL çalışma zamanında doğrulandı, bkz. final rapor QA
# notları): Godot sinyal->Callable bağlantılarında eksik parametreli
# dinleyiciler fazladan argümanı SESSİZCE YOK SAYMAZ -- "Method expected N
# argument(s), but called with M" ile SERT bir çalışma zamanı HATASI verir.
# Bu yüzden sinyali dinleyen HER script (audio_manager.gd, chain_toast.gd,
# merge_feedback_manager.gd, gameplay_watchdog.gd) varsayılan değerli
# (=0/=1) bir 6. parametre eklenerek GÜNCELLENDİ -- aksi halde her gerçek
# merge'de bir script hatası/çökme olurdu.
signal organism_merged(position: Vector2, merged_stage_id: int, is_bonus: bool, awarded_score: int, score_awarded: bool, combo_count: int)  # UI/UX rolü: Tween/ses/parçacık tetikleyicisi için
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

# feat: improve mobile scale and scoring feedback (Bölüm C) -- 1.5s'lik
# kombo penceresinin GERÇEK ZAMANLI (menü Pause'u hariç tutan) takibi.
# chain_toast.gd'nin daha önce kanıtlanmış aynı deseni (_effective_now_ms /
# _paused_accum_ms) burada, artık YETKİLİ (skoru gerçekten etkileyen)
# tarafta tekrarlanıyor.
var _combo_count: int = 0
var _last_combo_merge_ticks_ms: int = -1
var _paused_accum_ms: int = 0
var _pause_started_ms: int = -1

func _ready() -> void:
	game_over.connect(_on_game_over)
	_run_start_xp = xp  # oyun açılışında xp=0
	# feat: improve mobile scale and scoring feedback (Bölüm C) -- GameFlow'un
	# menü amaçlı (Start/Pause) duraklatmaları sırasında geçen süreyi kombo
	# penceresi hesabından düşmek için (chain_toast.gd'deki AYNI desen).
	GameFlow.pause_state_changed.connect(_on_pause_state_changed)

func _on_pause_state_changed(is_paused: bool) -> void:
	if is_paused:
		_pause_started_ms = Time.get_ticks_msec()
	elif _pause_started_ms >= 0:
		_paused_accum_ms += Time.get_ticks_msec() - _pause_started_ms
		_pause_started_ms = -1

func _effective_now_ms() -> int:
	return Time.get_ticks_msec() - _paused_accum_ms

## feat: improve mobile scale and scoring feedback (Bölüm C) -- düşürme
## ödülü: merge ekonomisinden bağımsız, sabit DROP_SCORE_VALUE puanı ekler.
## XP'ye, kombo sayacına ve bonus çarpanına DOKUNMAZ -- yalnızca skor.
func add_drop_reward() -> void:
	score += DROP_SCORE_VALUE
	score_changed.emit(score)

## feat: improve mobile scale and scoring feedback (Bölüm C) -- bir merge
## GERÇEKLEŞTİĞİNDE (skor verilsin ya da vermesin çağrılabilir, ama kombo
## SADECE gerçek skor veren merge'lerde ilerler -- bkz. add_merge_reward)
## kombo penceresini ilerletir/sıfırlar ve GÜNCEL combo_count'u döndürür.
func _advance_combo() -> int:
	var now_ms: int = _effective_now_ms()
	if _last_combo_merge_ticks_ms >= 0 and float(now_ms - _last_combo_merge_ticks_ms) / 1000.0 <= COMBO_WINDOW_SECONDS:
		_combo_count += 1
	else:
		_combo_count = 1
	_last_combo_merge_ticks_ms = now_ms
	return _combo_count

func _combo_multiplier(combo_count: int) -> float:
	var index: int = clamp(combo_count, 1, COMBO_MULTIPLIERS.size()) - 1
	return COMBO_MULTIPLIERS[index]

## UC-02 Adım 3: Merge sonucu kazanılan skor ve XP'yi ekler, ilgili sinyalleri
## yayınlar. Bonus Sistemi: is_bonus true ise (Spawner'ın ürettiği özel canlı
## birleşmenin bir tarafıysa) skor BONUS_ORGANISM_SCORE_MULTIPLIER ile çarpılır.
## feat: improve mobile scale and scoring feedback (Bölüm C) -- AYRICA 1.5
## saniye içinde art arda gelen mergeler için gerçek x2/x3/x4 kombo çarpanı
## uygulanır (bkz. _advance_combo/_combo_multiplier). Bonus ve kombo
## çarpanları ÇARPIMSAL olarak birlikte uygulanır (ikisi de aynı anda
## gerçekleşebilir -- örn. bonus bir canlıyla 3. art arda merge).
## Geriye uyumluluk: is_bonus parametresi varsayılan false — eski çağrı yeri
## (varsa) davranışı değişmeden çalışır.
##
## fix: correct merge score-table mapping (kullanıcı geri bildirimi) -- stage_id
## hâlâ ÖN-birleşme aşamasıdır (çağrı imzası/çağrı yeri DEĞİŞMEDİ, bkz.
## organism.gd _perform_merge), ama SKOR artık o birleşmenin ÜRETTİĞİ SONUÇ
## aşamasının (stage_id+1, son aşamada 9'da sabitlenir) score_value'sundan
## okunuyor -- OrganismTypes.STAGES'teki geniş yorum bunu tam olarak açıklıyor.
## XP'ye DOKUNMAZ: xp_value hâlâ ÖN-birleşme stage_id'sinden doğrudan okunur.
func add_merge_reward(stage_id: int, merge_position: Vector2, is_bonus: bool = false) -> void:
	var stage: Dictionary = OrganismTypes.get_stage(stage_id)
	if stage.is_empty():
		return
	var reward_stage_id: int = min(stage_id + 1, OrganismTypes.STAGES.size() - 1)
	var reward_stage: Dictionary = OrganismTypes.get_stage(reward_stage_id)
	var combo_count: int = _advance_combo()
	var combo_multiplier: float = _combo_multiplier(combo_count)
	var bonus_multiplier: float = BONUS_ORGANISM_SCORE_MULTIPLIER if is_bonus else 1.0
	var awarded_score: int = int(round(int(reward_stage.get("score_value", 0)) * bonus_multiplier * combo_multiplier))
	score += awarded_score
	xp += int(stage.get("xp_value", 0))
	score_changed.emit(score)
	xp_changed.emit(xp)
	organism_merged.emit(merge_position, stage_id, is_bonus, awarded_score, true, combo_count)  # score_awarded=true -- bu fonksiyon zaten yalnizca gercek bir odul verildiginde calisir
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
	# feat: improve mobile scale and scoring feedback (Bölüm C) -- yeni turun
	# eski turdan sızmış bir kombo zinciriyle BAŞLAMAMASI için sıfırlanır.
	_combo_count = 0
	_last_combo_merge_ticks_ms = -1
	_paused_accum_ms = 0
	_pause_started_ms = -1
	run_reset.emit()

## fix: recover stalled gameplay loop (Bölüm A) -- GameplayWatchdog'un
## "kayıp çizgisi aşıldı ama oyun hâlâ PLAYING görünüyor" yedek denetimi
## (normal akışta lose_life() zaten lives==0 anında game_over'ı SENKRON
## yayınlar, bkz. yukarısı -- bu fonksiyon yalnızca beklenmedik bir
## senkronizasyon kaybına karşı ikinci bir güvenlik ağıdır). Can/skor/
## canlılara DOKUNMAZ -- yalnızca zaten sıfırlanmış canlar için oyun sonu
## akışını YENİDEN tetikler; oyun zaten bitmişse (get_tree().paused=true
## veya lives>0) hiçbir şey yapmaz.
func force_game_over_if_stuck() -> void:
	if lives > 0 or get_tree().paused:
		return
	game_over.emit()
