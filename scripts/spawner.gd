extends Node2D
class_name Spawner
## Spawner — UC-01: Canlı Bırakma. Oyuncunun parmağını/imlecini yatay eksende
## takip eder, bıraktığında canlıyı serbest bırakır ve ardından bekleme
## süresi (cooldown) uygular.

const DROP_COOLDOWN_SECONDS: float = 1.0    # UC-01 Adım 3: Spam koruması
const HORIZONTAL_MARGIN: float = 40.0       # Canlının fanus duvarlarına gömülmesini engelleyen kenar payı
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
signal organism_dropped(position: Vector2, is_bonus: bool)  # UI/UX rolü: presentation-only giriş efekti için

@export var left_bound_x: float = 0.0
@export var right_bound_x: float = 720.0

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

func _ready() -> void:
	add_to_group("spawner")  # fix: recover stalled gameplay loop -- GameplayWatchdog'un Spawner'ı sahne yoluna bağımlı olmadan bulması için
	_prepare_next_organism()

## Cooldown süresini her karede azaltır; Bonus Sistemi zamanlayıcısını ilerletir.
func _process(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining = max(0.0, _cooldown_remaining - delta)
	_advance_bonus_timer(delta)

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
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_set_dragging(event.pressed, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_set_dragging(event.pressed, event.position)
	elif event is InputEventScreenDrag:
		_handle_drag(event.position)
	elif event is InputEventMouseMotion and _is_dragging:
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
	global_position.x = clamp(screen_position.x, left_bound_x + HORIZONTAL_MARGIN, right_bound_x - HORIZONTAL_MARGIN)

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
	organism_dropped.emit(dropped.global_position, dropped.is_bonus)
	AudioManager.play_drop()  # feat: add sound haptics -- SADECE ses/haptic; drop/cooldown/spawn/bonus mantığına dokunmaz
	_cooldown_remaining = DROP_COOLDOWN_SECONDS
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
