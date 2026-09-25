extends Node2D
class_name Spawner
## Spawner — UC-01: Canlı Bırakma. Oyuncunun parmağını/imlecini yatay eksende
## takip eder, bıraktığında canlıyı serbest bırakır ve ardından bekleme
## süresi (cooldown) uygular.

const DROP_COOLDOWN_SECONDS: float = 1.0    # UC-01 Adım 3: Spam koruması
# DÜZELTME (V02 İKİNCİ düzeltme turu -- madde 5): ilk merge'in "neden
# birleşti" ipucu artık merge anının KENDİSİNDE değil, ödül görselleri
# (evolution_burst.gd TOTAL_DURATION=0.72s + merge_burst.gd DURATION=0.58s)
# oturduktan SONRA belirir -- bkz. _on_intro_organism_merged.
const INTRO_HINT_MERGE_DELAY: float = 0.9
# feat: improve mobile scale and scoring feedback (Bölüm B) -- en büyük
# üretilebilir aşama (MAX_SPAWNABLE_STAGE_ID=4, Kurbağa) yeni boyut
# tablosunda radius=60.0'a çıktığından, pay da bu yarıçapı (+ küçük bir
# tampon) karşılayacak şekilde büyütüldü; aksi halde en büyük üretilebilir
# canlı sürüklemenin uç noktalarında fanus duvarına gömülürdü.
# DÜZELTME (kullanıcı: "görsel-collision uyumu" -- kenar sınırı hesaplaması da
# TEK merkezi effective_radius kaynağından beslensin): eskiden sabit bir
# sayıydı (65.0 = 60+5 tampon, elle hesaplanmıştı). Artık _ready()'de
# GrayboxConfig.effective_radius() ÜZERİNDEN, üretilebilir aşamaların GERÇEK
# (graybox'ta büyütülmüş) yarıçaplarından türetilir -- bkz. _compute_horizontal_margin.
# ENABLED=false iken sonuç SAYISAL OLARAK BİREBİR AYNI (65.0) kalır (üretim
# davranışı değişmez); ENABLED iken VISUAL_SCALE_BY_STAGE değerleri ileride
# değişse bile pay otomatik doğru kalır.
const HORIZONTAL_MARGIN_BUFFER: float = 5.0  # eski sabit 65.0 = stage4(60px) + bu tampon
var _horizontal_margin: float = 65.0        # _ready()'de gerçek değerle üzerine yazılır (varsayılan: mevcut üretim değeriyle aynı)
const ORGANISM_SCENE: PackedScene = preload("res://scenes/Organism.tscn")

# Bonus Sistemi (kullanıcı isteği): belirli aralıklarla bir sonraki bırakılacak
# canlı "bonus" olarak işaretlenir (bkz. Organism.is_bonus / GameManager
# BONUS_ORGANISM_SCORE_MULTIPLIER). Sık gelmesi istendiği için aralık kısa tutuldu.
const BONUS_INTERVAL_MIN_SECONDS: float = 9.0
const BONUS_INTERVAL_MAX_SECONDS: float = 15.0

# Balık 2-parça mekaniği (kullanıcı isteği — "balık 2 parçadan oluşur, her
# parça ayrı ayrı gelir, fanusta birleştirilir"): Spawner Balık aşamasını
# üretmek istediğinde tek bir tam Balık yerine arka arkaya İKİ "Balık
# Parçası" düşürür (bkz. organism.gd is_fish_part/fish_part_index).
const FISH_STAGE_ID: int = 3  # OrganismTypes.STAGES[3] = Balık

signal next_organism_ready(preview_data: Dictionary)  # feat: add dedicated next organism preview -- NEXT UI güncellemesi için
# feat: add drop aiming and landing feedback -- iki minimal, salt-bilgilendirici
# sinyal: biri (drag_state_changed) DropAimGuide'ın ne zaman görünür/gizli
# olacağını, diğeri (organism_dropped) DropFeedbackManager'ın giriş efektini
# NEREDE ve NORMAL/BONUS mı oynatacağını bildirir. İkisi de sadece Spawner'ın
# ZATEN yaptığı işin (sürükleme durumu, drop konumu/is_bonus) dışa aktarımıdır --
# cooldown/bonus/spawn/collision mantığının HİÇBİR parçasını değiştirmez.
signal drag_state_changed(is_dragging: bool)      # UI/UX rolü: presentation-only aim guide için
# gameplay/core-loop-v4 "Evrim Laboratuvarı" (madde 3 -- "ışık transferi"):
# 3. parametre (dropped organism referansı) EKLENDİ ki DropFeedbackManager
# ışık huzmesini düşen GERÇEK fizik nesnesinin her karede GÜNCEL konumunu
# TAKİP ederek çizebilsin (bkz. light_transfer_beam.gd) -- yalnızca OKUR,
# hiçbir şekilde organizmanın transform/velocity/collision'ına yazmaz. Godot
# sinyal->Callable bağlantıları eksik parametreli dinleyicileri KABUL
# ETMEDİĞİNDEN (bkz. audio_manager.gd _on_organism_merged notu) bu sinyale
# önceden bağlı TÜM dinleyicilerin (drop_feedback_manager.gd,
# gameplay_watchdog.gd) imzaları da aynı anda güncellendi.
signal organism_dropped(position: Vector2, is_bonus: bool, organism: Node)  # UI/UX rolü: presentation-only giriş efekti için

@export var left_bound_x: float = 0.0
@export var right_bound_x: float = 720.0

# V4 core-loop/graybox -- tek-parmak kilidi (single-pointer lockout): aim
# sırasında hangi dokunma/fare "sahibinin" sürüklemeyi kontrol ettiğini
# izler. -1 = aktif aim yok. Dokunma olaylarında event.index (>=0), fare
# olaylarında sabit MOUSE_POINTER_ID kullanılır. Bu SADECE hangi girdi
# kaynağının aime devam edebileceğini belirler -- mevcut yatay-eksen aim/
# cooldown/drop mantığının KENDİSİNE dokunmaz.
const MOUSE_POINTER_ID: int = -2
var _active_pointer_id: int = -1

var _is_dragging: bool = false
var _cooldown_remaining: float = 0.0
var _pending_organism: Organism = null
var _bonus_elapsed_seconds: float = 0.0
var _next_bonus_threshold_seconds: float = randf_range(BONUS_INTERVAL_MIN_SECONDS, BONUS_INTERVAL_MAX_SECONDS)
var _bonus_flag_ready: bool = false
var _force_next_fish_part_index: int = -1  # -1 = bekleyen zorunlu eşleşme yok

# fix: recover stalled gameplay loop -- KÖK NEDEN düzeltmesi. Bekleyen
# ("next") canlı Organism.tscn'de contact_monitor=true ile TAM fiziksel
# olarak çarpışma-aktif instantiate edilir ve organism.gd'deki merge-arm
# zamanlayıcısı (MERGE_ARM_DELAY) bırakılma durumuna bakmaksızın KOŞULSUZ
# işler. Bekleyen canlı Spawner'ın çocuğu olarak SABİT spawn noktasında
# durduğundan, düşmekte olan/yeni yerleşmiş aynı-aşama bir canlı ona geri
# değip erken bir merge tetikleyebilir (~%20 ihtimal, OrganismTypes'ın
# 5 üretilebilir aşama üzerinde tekdüze rastgele seçimiyle) -- bu da
# organism.gd._perform_merge()'in HEM kendisini HEM de bekleyen canlıyı
# queue_free() etmesine yol açar. spawner.gd bu referansı hiçbir zaman
# is_instance_valid() ile doğrulamadığından, bir sonraki bırakma denemesi
# artık silinmiş nesneye erişip çöker ve _pending_organism sonsuza dek
# null/üretimsiz kalırdı (üretim SESSİZCE durur, oyun donmuş görünür).
#
# Bu iki alan, bekleyen canlının GERÇEK collision_layer/collision_mask
# değerlerini (Organism.tscn'in kendi varsayılanları) SAKLAR ki
# _prepare_next_organism() bunları geçici olarak sıfırlayabilsin (bkz.
# aşağı) ve _drop_current_organism() gerçek bırakma anında GERİ yükleyebilsin.
var _pending_collision_layer: int = 1
var _pending_collision_mask: int = 1

# feat: add first-run gameplay guidance (Bölüm D) -- ilk-çalıştırma
# tutorial'ı açıkken Bonus Sistemi zamanlayıcısının "kontrolsüzce arka
# planda" ilerlememesi için (kullanıcı isteği). Drop/cooldown/collision/
# merge mantığının KENDİSİNE dokunmaz -- oyuncu tutorial açıkken de normal
# şekilde sürükleyip bırakabilir, yalnızca görünmez bonus zamanlayıcısı
# duraklar.
var _tutorial_active: bool = false

# V4 core-loop/graybox (madde 9 -- ilk 30 saniye akışı): bu turda şu ana
# kadar BAŞARIYLA yapılmış bırakma (drop) sayısı -- yalnızca GrayboxConfig.
# ENABLED iken kullanılır, üretim davranışını ETKİLEMEZ. run_reset'te 0'a
# döner; ilk INTRO_FORCED_STAGE0_COUNT bırakma _prepare_next_organism()
# tarafından zorla Stage 0 yapılır, sonrasında normal rastgele seçime döner.
var _moves_since_reset: int = 0
var _first_merge_hint_shown: bool = false
var _run_token: int = 0  # DÜZELTME (V02 İKİNCİ düzeltme turu): _on_intro_organism_merged'in gecikmeli await'i, arada hızlı bir "Tekrar Oyna" olursa ESKİ turun ipucunu YENİ turda göstermesin diye
var _intro_hint_layer: CanvasLayer = null
var _intro_hint_panel: Panel = null
var _intro_hint_label: Label = null
var _intro_hint_tween: Tween = null

func _ready() -> void:
	add_to_group("spawner")  # fix: recover stalled gameplay loop -- GameplayWatchdog'un Spawner'ı sahne yoluna bağımlı olmadan bulması için
	_horizontal_margin = _compute_horizontal_margin()
	_prepare_next_organism()
	# V4 core-loop/graybox -- pause-sırasında-asılı-kalan aim düzeltmesi:
	# GameFlow.open_pause() (ör. Android Back tuşuyla) parmak HÂLÂ basılıyken
	# tetiklenirse get_tree().paused=true olur ve Spawner (PROCESS_MODE_INHERIT)
	# artık _unhandled_input ALMAZ -- bırakma (release) olayı hiç gelmez,
	# _is_dragging sonsuza dek true'da asılı kalır (aim guide görünür kalır,
	# GameplayWatchdog'un stuck-tarama atlaması da yanlışlıkla sürer gider).
	# Bu yüzden pause anında aim GÜVENLE İPTAL edilir (DROP YAPILMADAN --
	# parmağın hâlâ ekranda olup olmadığı bilinmiyor); resume'de oyuncu
	# normal şekilde yeniden aim başlatabilir.
	GameFlow.pause_state_changed.connect(_on_pause_state_changed)
	# V4 core-loop/graybox (madde 9): deterministik/tekrarlanabilir ilk-30-
	# saniye akışı SADECE ENABLED iken kurulur -- üretimde (ENABLED=false)
	# hiçbir yeni sinyal bağlanmaz/node eklenmez.
	if GrayboxConfig.ENABLED:
		_build_intro_hint_ui()
		GameManager.run_reset.connect(_on_intro_run_reset)
		GameManager.organism_merged.connect(_on_intro_organism_merged)
		_on_intro_run_reset()  # oyun ilk açıldığında da (run_reset beklemeden) deterministik akış geçerli olsun

## V4 core-loop/graybox -- bkz. yukarı _ready() notu. Sadece pause AÇILDIĞINDA
## ve aktif bir aim varsa çalışır; drop/cooldown/spawn/bonus mantığına dokunmaz.
func _on_pause_state_changed(is_paused: bool) -> void:
	if not is_paused or not _is_dragging:
		return
	_is_dragging = false
	_active_pointer_id = -1
	drag_state_changed.emit(false)

## Cooldown süresini her karede azaltır; Bonus Sistemi zamanlayıcısını ilerletir.
func _process(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining = max(0.0, _cooldown_remaining - delta)
	if not _tutorial_active:
		_advance_bonus_timer(delta)

## feat: add first-run gameplay guidance (Bölüm D) -- FirstRunTutorial
## tarafından çağrılır (bkz. yukarı sınıf-seviyesi not).
func set_tutorial_active(active: bool) -> void:
	_tutorial_active = active

## Bonus Sistemi: Eşik süresi dolduğunda, halen bekleyen canlı varsa onu bonus
## olarak işaretler; yoksa bir sonraki hazırlanan canlıya uygulanmak üzere
## bayrağı kaldırır (bkz. _prepare_next_organism).
func _advance_bonus_timer(delta: float) -> void:
	_bonus_elapsed_seconds += delta
	if _bonus_elapsed_seconds < _next_bonus_threshold_seconds:
		return
	_bonus_elapsed_seconds = 0.0
	_next_bonus_threshold_seconds = randf_range(BONUS_INTERVAL_MIN_SECONDS, BONUS_INTERVAL_MAX_SECONDS)
	# fix: recover stalled gameplay loop -- is_instance_valid() ile: ham obje
	# referansı freed bir node'da ASLA otomatik null olmaz (== null her zaman
	# false döner), bu yüzden düz "!= null" kontrolü freed bir referansa
	# yazmayı denerdi ve script hatasıyla çökerdi.
	if is_instance_valid(_pending_organism):
		_pending_organism.is_bonus = true
	else:
		_bonus_flag_ready = true

## UC-01: Dokunma/tıklama ve sürükleme girdilerini yakalar (mobil dokunma + editör test için fare).
## V4 core-loop/graybox -- tek-parmak kilidi: zaten bir aim aktifken gelen
## İKİNCİ bir press (farklı dokunma index'i veya fare) TAMAMEN YOK SAYILIR;
## sadece aime BAŞLATAN kaynağın drag/release olayları işlenir. Bu, "no
## double-spawn" gereksinimini de doğal olarak sağlar -- ikinci parmak asla
## yeni bir aim/drop tetikleyemez.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _active_pointer_id != -1:
				return  # başka bir parmak zaten aim ediyor -- yok say
			_active_pointer_id = event.index
			_set_dragging(true, event.position)
		else:
			if event.index != _active_pointer_id:
				return  # aim'i başlatmayan bir parmağın release'i -- yok say
			_active_pointer_id = -1
			_set_dragging(false, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _active_pointer_id != -1:
				return
			_active_pointer_id = MOUSE_POINTER_ID
			_set_dragging(true, event.position)
		else:
			if _active_pointer_id != MOUSE_POINTER_ID:
				return
			_active_pointer_id = -1
			_set_dragging(false, event.position)
	elif event is InputEventScreenDrag:
		if event.index == _active_pointer_id:
			_handle_drag(event.position)
	elif event is InputEventMouseMotion and _is_dragging and _active_pointer_id == MOUSE_POINTER_ID:
		_handle_drag(event.position)

## UC-01 Adım 1/2: Basılı tutma sürüklemeyi başlatır; parmağı/imleci çekme canlıyı düşürür.
func _set_dragging(pressed: bool, event_position: Vector2) -> void:
	_is_dragging = pressed
	drag_state_changed.emit(_is_dragging)  # feat: add drop aiming and landing feedback
	if pressed:
		_handle_drag(event_position)
	else:
		_drop_current_organism()

## UC-01 Adım 1: Spawner'ı yatay eksende, fanus sınırları içinde parmağa/imlece göre konumlandırır.
## Bekleyen canlı Spawner'ın çocuğu olduğundan otomatik olarak onunla birlikte hareket eder.
func _handle_drag(screen_position: Vector2) -> void:
	global_position.x = clamp(screen_position.x, left_bound_x + _horizontal_margin, right_bound_x - _horizontal_margin)

## DÜZELTME (kullanıcı: "görsel-collision uyumu" -- kenar sınırı hesaplaması):
## üretilebilir aşamaların (0..MAX_SPAWNABLE_STAGE_ID) GERÇEK collision
## yarıçapını (GrayboxConfig.effective_radius -- ENABLED iken büyütülmüş)
## TEK merkezi kaynaktan okuyup en büyüğüne küçük bir tampon ekler. ENABLED=
## false iken bu, eski elle-hesaplanmış sabitle (65.0) SAYISAL OLARAK BİREBİR
## aynı sonucu üretir (stage4/Kurbağa=60px + 5px tampon) -- üretim davranışı
## değişmez.
func _compute_horizontal_margin() -> float:
	var max_radius: float = 0.0
	for sid in range(OrganismTypes.MAX_SPAWNABLE_STAGE_ID + 1):
		max_radius = max(max_radius, GrayboxConfig.effective_radius(sid))
	return max_radius + HORIZONTAL_MARGIN_BUFFER

## UC-01 Adım 2-3: Gösterilen canlıyı serbest bırakır (yerçekimine bırakır), fanusun
## OrganismContainer'ına taşır ve 1 saniyelik bırakma cooldown'ını başlatır.
func _drop_current_organism() -> void:
	# fix: recover stalled gameplay loop -- is_instance_valid() KULLANILIR
	# (bkz. yukarı not): freed bir _pending_organism artık burada sessizce
	# yok sayılır, bir sonraki geçerli üretime kadar bırakma denemesi
	# çökmeden erken çıkar.
	if _cooldown_remaining > 0.0 or not is_instance_valid(_pending_organism):
		return
	var organism_container: Node = get_tree().get_first_node_in_group("organism_container")
	if organism_container == null:
		return
	var dropped: Organism = _pending_organism
	_pending_organism = null
	dropped.freeze = false
	# fix: recover stalled gameplay loop -- KÖK NEDEN düzeltmesinin diğer
	# yarısı: bekleyen canlının GERÇEK collision_layer/collision_mask
	# değerleri tam bırakma anında geri yüklenir (bkz. _prepare_next_organism
	# içindeki sıfırlama notu).
	# fix: recover stalled gameplay loop -- set_deferred() KULLANILIR: gercek
	# GL calisma zamaninda dogrulandi (bkz. final rapor QA notlari), bir
	# RigidBody2D'nin collision_layer/mask'ini fizik sorgu-flush penceresi
	# sirasinda SENKRON degistirmek Godot'un kendi motor uyarisini
	# tetikliyordu ("Can't change this state while flushing queries. Use
	# call_deferred() or set_deferred()..."). Fonksiyonel davranisi BOZMAZ --
	# yalnizca degisikligi mevcut karenin sonuna erteleyerek motorun kendi
	# ONERDIGI güvenli yolu kullanir.
	dropped.set_deferred("collision_layer", _pending_collision_layer)
	dropped.set_deferred("collision_mask", _pending_collision_mask)
	dropped.visible = true  # feat: add dedicated next organism preview -- dunya-uzayinda gorunur olma ani TAM burasi
	dropped.reparent(organism_container)
	# feat: add drop aiming and landing feedback -- SADECE GÖRSEL giriş efekti
	# için; collision/spawn/cooldown/bonus mantığına dokunmaz, zaten hesaplanmış
	# is_bonus'u dışarı taşır.
	organism_dropped.emit(dropped.global_position, dropped.is_bonus, dropped)
	AudioManager.play_drop()  # feat: add sound haptics -- SADECE ses/haptic; drop/cooldown/spawn/bonus mantığına dokunmaz
	# feat: improve mobile scale and scoring feedback (Bölüm C) -- yeni
	# merkezi ekonomi: her BAŞARILI bırakma sabit +5 puan verir (mevcut
	# "tek tek yavaş +1" hissini gidermek için, kullanıcı isteği). Bu
	# skor merge ekonomisinden TAMAMEN ayrıdır -- GameManager.add_merge_reward
	# ÇAĞRILMAZ, kombo/bonus çarpanı UYGULANMAZ.
	GameManager.add_drop_reward()
	_cooldown_remaining = DROP_COOLDOWN_SECONDS
	# V4 core-loop/graybox (madde 9) -- SADECE ENABLED iken sayaç ilerler ve
	# ilk bırakmadan sonra "dokun/sürükle/bırak" ipucu kapatılır. Üretimde
	# hiçbir etkisi yoktur.
	if GrayboxConfig.ENABLED:
		_moves_since_reset += 1
		if _moves_since_reset == 1:
			_hide_intro_hint_now()
	_prepare_next_organism()

## UC-01: Bir sonraki bırakılacak canlıyı rastgele seçer ve Spawner'ın altında
## dondurulmuş (freeze) halde, ekranda "sıradaki canlı" olarak bekletir.
## Balık 2-parça mekaniği: eğer az önce Balık'ın 1. parçasını hazırladıysak
## (bkz. _force_next_fish_part_index), bu çağrı ZORUNLU olarak 2. parçayı
## üretir (rastgele seçime bırakılmaz) — böylece iki parça her zaman art
## arda gelir. Aksi halde normal rastgele aşama seçilir; seçilen aşama Balık
## ise bu spawn 1. parça olur ve bir sonraki çağrı için 2. parça zorlanır.
func _prepare_next_organism() -> void:
	var stage_id: int
	var is_fish_part: bool = false
	var fish_part_index: int = 0

	if _force_next_fish_part_index >= 0:
		stage_id = FISH_STAGE_ID
		is_fish_part = true
		fish_part_index = _force_next_fish_part_index
		_force_next_fish_part_index = -1
	elif GrayboxConfig.ENABLED and _moves_since_reset < GrayboxConfig.INTRO_FORCED_STAGE0_COUNT:
		# V4 core-loop/graybox (madde 9): ilk INTRO_FORCED_STAGE0_COUNT bırakma
		# DETERMİNİSTİK olarak Stage 0 (Tek Hücreli) -- ilk merge'in erken ve
		# GARANTİ gerçekleşmesi için (hedef: ≤10s). Balık ayrışması (FISH_
		# STAGE_ID) bu dalda hiç devreye girmez çünkü stage_id sabit 0.
		stage_id = 0
	else:
		stage_id = OrganismTypes.get_random_spawnable_stage_id()
		if stage_id == FISH_STAGE_ID:
			is_fish_part = true
			fish_part_index = 0
			_force_next_fish_part_index = 1

	_pending_organism = ORGANISM_SCENE.instantiate()
	_pending_organism.stage_id = stage_id
	_pending_organism.is_fish_part = is_fish_part
	_pending_organism.fish_part_index = fish_part_index
	_pending_organism.freeze = true
	_pending_organism.is_bonus = _bonus_flag_ready  # Bonus Sistemi: bekleyen bayrak varsa yeni canlıya uygula
	_bonus_flag_ready = false
	# feat: add dedicated next organism preview -- gercek fizik objesi drop
	# edilene kadar dunya-uzayinda GORUNMEZ (NEXT panelinin kendi ayri
	# TextureRect onizlemesi gorunur olani ustlenir, bkz. next_preview.gd).
	_pending_organism.visible = false
	# fix: recover stalled gameplay loop -- KÖK NEDEN düzeltmesi: canlı henüz
	# bırakılmadığı sürece GERÇEK collision_layer/collision_mask'ı saklayıp
	# sıfıra çekilir, böylece hiçbir fiziksel gövdeyle (dolayısıyla hiçbir
	# merge'le) TEMAS EDEMEZ -- 0.15s'lik merge-arm süresinin bırakılma
	# durumundan bağımsız işlemesinin yarattığı açığı KÖKTEN kapatır (bkz.
	# yukarı sınıf-seviyesi not). Bırakıldığı an _drop_current_organism()
	# bu gerçek değerleri geri yükler.
	_pending_collision_layer = _pending_organism.collision_layer
	_pending_collision_mask = _pending_organism.collision_mask
	# fix: recover stalled gameplay loop -- set_deferred() (bkz. aşağı drop
	# tarafındaki AYNI not) -- freeze=true zaten bu karede kinematik hale
	# getirdiğinden, sıfırlamanın kare sonuna ertelenmesi güvenlidir.
	_pending_organism.set_deferred("collision_layer", 0)
	_pending_organism.set_deferred("collision_mask", 0)
	add_child(_pending_organism)
	_pending_organism.position = Vector2.ZERO
	next_organism_ready.emit(get_pending_preview_data())

## fix: recover stalled gameplay loop (Bölüm A) -- GameplayWatchdog için
## salt-okunur durum sorgusu: bekleyen canlı referansı hâlâ geçerli mi?
func has_valid_pending_organism() -> bool:
	return is_instance_valid(_pending_organism)

## fix: recover stalled gameplay loop (Bölüm A) -- GameplayWatchdog, üretim
## 1.5s boyunca durduğunu (bkz. has_valid_pending_organism()==false) tespit
## ederse bu fonksiyonu çağırır. Geçersiz/dangling referansı temizler ve
## üretimi YENİDEN başlatır -- skor/can/mevcut canlılara HİÇBİR şekilde
## dokunmaz, yalnızca bekleyen "sıradaki canlı" üretim zincirini onarır.
## Zaten geçerli bir bekleyen canlı varsa (yanlış alarm) hiçbir şey yapmaz.
func force_recover_pending_organism() -> void:
	if is_instance_valid(_pending_organism):
		return
	_pending_organism = null  # dangling referansı temizle (queue_free sonrası == null olmaz, bkz. yukarı not)
	_prepare_next_organism()

## V4 core-loop/graybox (madde 9) -- run_reset'te (hem "Play again" hem
## GameManager._on_game_over sonrası olası yeniden başlatma) deterministik
## akışı yeniden kurar: seed sabitlenir, sayaç sıfırlanır, olası bekleyen
## canlı (önceki turdan kalma stage_id ile) atılıp DETERMİNİSTİK biçimde
## yeniden hazırlanır, "dokun/sürükle/bırak" ipucu tekrar gösterilir. SADECE
## ENABLED iken çalışır -- üretimde bu fonksiyon hiçbir şey yapmaz.
func _on_intro_run_reset() -> void:
	if not GrayboxConfig.ENABLED:
		return
	seed(GrayboxConfig.INTRO_SEED)
	_moves_since_reset = 0
	_first_merge_hint_shown = false
	_run_token += 1
	_force_next_fish_part_index = -1
	if is_instance_valid(_pending_organism):
		_pending_organism.queue_free()
	_pending_organism = null
	_prepare_next_organism()
	_show_intro_drag_hint()

## V4 core-loop/graybox (madde 9) -- SADECE turun İLK skorlu (score_awarded)
## merge'inde tetiklenir: kısa bir "neden birleşti" ipucu gösterir, sonra
## otomatik kapanır. Balık parça tamamlanması (score_awarded=false) bunu
## TETİKLEMEZ -- kullanıcının "aynı canlıları birleştir" adımıyla eşleşmez.
## DÜZELTME (V02 İKİNCİ düzeltme turu -- kullanıcı madde 5: "Alt öğretici
## mesaj birleşme sırasında gizlenmeli"): KÖK NEDEN -- bu ipucu eskiden
## organism_merged sinyaliyle AYNI karede, yani TAM merge anında (merge
## burst + evolution burst + DNA-sarmalı/ışık-patlaması + floating skor
## metninin hepsinin aynı anda oynadığı an) beliriyordu -- tam da kullanıcının
## "birbirinin üzerine binmemeli" dediği kalabalık anın ortasına yeni bir
## metin daha ekliyordu. Artık merge anının KENDİSİNDE (INTRO_HINT_MERGE_
## DELAY boyunca) alt ipucu GİZLİ kalır -- yalnızca ödül görselleri
## (evolution_burst.gd TOTAL_DURATION=0.72s) tamamen oturduktan SONRA belirir.
func _on_intro_organism_merged(_position: Vector2, _stage_id: int, _is_bonus: bool, _awarded_score: int, score_awarded: bool, _combo_count: int = 0) -> void:
	if not GrayboxConfig.ENABLED or _first_merge_hint_shown or not score_awarded:
		return
	_first_merge_hint_shown = true
	var token_at_merge: int = _run_token
	await get_tree().create_timer(INTRO_HINT_MERGE_DELAY).timeout
	if token_at_merge != _run_token:
		return  # bekleme sırasında yeni bir tur başladı (run_reset) -- eski turun ipucu YENİ turda gösterilmez
	_set_intro_hint_text("Aynı canlılar birleşince evrimleşir!")
	_show_intro_hint(1.8)

## V4 core-loop/graybox (madde 9) -- ipucu kapsülünü (Spawner'ın kendi
## CanvasLayer'ı altında, ekranın alt kenarına yakın) OLUŞTURUR. HUDRoot/
## ChainToast/LevelUpToast/FirstRunTutorial ile AYNI stil kaynağını
## (HUDTheme) kullanır ama KENDİ ayrı, bağımsız bir node'dur -- mevcut HUD
## katmanlarına/yerleşimine dokunmaz. mouse_filter=IGNORE: Spawner'ın
## sürükle/bırak girdisini asla yutmaz.
func _build_intro_hint_ui() -> void:
	_intro_hint_layer = CanvasLayer.new()
	_intro_hint_layer.layer = 21  # ChainToast/LevelUpToast(20) üstünde, FirstRunTutorial(25) altında
	add_child(_intro_hint_layer)

	_intro_hint_panel = Panel.new()
	_intro_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_hint_panel.add_theme_stylebox_override("panel", HUDTheme.make_toast_capsule_stylebox())
	_intro_hint_panel.anchor_left = 0.5
	_intro_hint_panel.anchor_right = 0.5
	_intro_hint_panel.anchor_top = 1.0
	_intro_hint_panel.anchor_bottom = 1.0
	_intro_hint_panel.offset_left = -160.0
	_intro_hint_panel.offset_right = 160.0
	_intro_hint_panel.offset_top = -160.0
	_intro_hint_panel.offset_bottom = -114.0
	_intro_hint_panel.modulate.a = 0.0
	_intro_hint_panel.visible = false
	_intro_hint_layer.add_child(_intro_hint_panel)

	_intro_hint_label = Label.new()
	_intro_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_intro_hint_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	HUDTheme.style_label(_intro_hint_label, HUDTheme.FONT_UI, 15, HUDTheme.TEXT_PRIMARY)
	_intro_hint_panel.add_child(_intro_hint_label)

func _set_intro_hint_text(text: String) -> void:
	if _intro_hint_label != null:
		_intro_hint_label.text = text

## auto_hide_after<=0 ise ipucu ELLE kapatılana kadar (bkz. _hide_intro_hint_now)
## açık kalır -- ilk iki bırakma boyunca "dokun/sürükle/bırak" ipucu için.
## auto_hide_after>0 ise o kadar saniye gösterilip kendiliğinden solarak kapanır.
func _show_intro_hint(auto_hide_after: float) -> void:
	if _intro_hint_panel == null:
		return
	if _intro_hint_tween != null and _intro_hint_tween.is_valid():
		_intro_hint_tween.kill()
	_intro_hint_panel.visible = true
	_intro_hint_panel.modulate.a = 0.0
	_intro_hint_tween = create_tween()
	_intro_hint_tween.tween_property(_intro_hint_panel, "modulate:a", 1.0, 0.2)
	if auto_hide_after > 0.0:
		_intro_hint_tween.tween_interval(auto_hide_after)
		_intro_hint_tween.tween_property(_intro_hint_panel, "modulate:a", 0.0, 0.3)
		_intro_hint_tween.tween_callback(_hide_intro_hint_now)

func _show_intro_drag_hint() -> void:
	_set_intro_hint_text("Dokunun, sürükleyin, bırakın")
	_show_intro_hint(-1.0)

func _hide_intro_hint_now() -> void:
	if _intro_hint_panel == null:
		return
	if _intro_hint_tween != null and _intro_hint_tween.is_valid():
		_intro_hint_tween.kill()
	_intro_hint_panel.visible = false
	_intro_hint_panel.modulate.a = 0.0

## feat: add dedicated next organism preview -- NEXT paneli icin, bekleyen
## canlinin gorsel kimligini (stage_id/is_bonus/is_fish_part/fish_part_index)
## salt-okunur bir Dictionary olarak disa verir. Fizik/collision/merge/spawn
## mantigina dokunmaz.
func get_pending_preview_data() -> Dictionary:
	if not is_instance_valid(_pending_organism):
		return {}
	return {
		"stage_id": _pending_organism.stage_id,
		"is_bonus": _pending_organism.is_bonus,
		"is_fish_part": _pending_organism.is_fish_part,
		"fish_part_index": _pending_organism.fish_part_index,
	}
