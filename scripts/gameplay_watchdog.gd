extends Node
## GameplayWatchdog -- fix: recover stalled gameplay loop (Bölüm A). Autoload.
## (Projenin diğer autoload'ları -- GameManager/GameFlow/AudioManager/
## OrganismTypes -- gibi kasıtlı olarak class_name TANIMLAMAZ; tekil erişim
## her zaman autoload singleton adı (GameplayWatchdog) üzerinden yapılır.)
##
## Kullanıcı isteği: oyunun kendi çalışma durumunu KENDİSİ izlemesi ("oyun
## kendi çalışma durumunu izlemiyor"). Bu script, Spawner/Organism/GameManager
## sinyallerini dinleyerek basit, gözlemlenebilir bir "üretim döngüsü" durumu
## (LoopState) çıkarsar VE her CHECK_INTERVAL_SECONDS'ta (0.5s) bir, yalnızca
## PLAYING sırasında, dar kapsamlı DEĞİŞMEZLER (invariant) kontrol eder:
##
##   1) Üretim durdu mu? (Spawner'ın bekleyen "sıradaki canlı"sı
##      STALL_PRODUCTION_SECONDS (1.5s) boyunca geçersiz/yok mu?)
##      -> spawner.force_recover_pending_organism() ile YENİDEN üretilir.
##   2) Aktif bir canlı fanus sınırlarının dışına (ekran dışına)
##      STUCK_ORGANISM_SECONDS (2.5s) boyunca kesintisiz taştı mı?
##      -> fanus içine GERİ konumlandırılır (silinmez/çoğaltılmaz).
##      Oyuncu bekleyen canlıyı SÜRÜKLERKEN bu tarama TAMAMEN atlanır.
##   3) Can bitti ama oyun hâlâ PLAYING/duraklamamış görünüyor mu?
##      -> GameManager.force_game_over_if_stuck() ile oyun sonu akışı
##      YENİDEN tetiklenir (normal akışta bu zaten senkron olur, bu SADECE
##      bir yedek/ikinci güvenlik ağıdır).
##
## KESİN KURALLAR (kullanıcı isteği): hiçbir kurtarma skor/XP EKLEMEZ/
## DÜŞÜRMEZ, canlı ÇOĞALTMAZ, can DÜŞÜRMEZ. Her kurtarma nedeni print() ile
## loglanır VE _recovery_log dizisinde (QA/rapor için) tutulur. Kontroller
## sabit aralıklı (0.5s) ve DURUMSUZ yeniden denenir -- hiçbir yerde
## rekürsif/kendi kendini tetikleyen bir döngü YOKTUR, bu yüzden sonsuz
## döngüye girme riski yapısal olarak yoktur.
##
## Skor/XP/collision/merge/spawn/bonus EKONOMİSİNE dokunmaz -- yalnızca
## GÖZLEMLER ve, ancak bir ihlal tespit edildiğinde, dar kapsamlı bir onarım
## uygular.

enum LoopState { IDLE, SPAWNING, PLAYER_CONTROL, FALLING, RESOLVING }

const CHECK_INTERVAL_SECONDS: float = 0.5
const STALL_PRODUCTION_SECONDS: float = 1.5
const STUCK_ORGANISM_SECONDS: float = 2.5

# Fanus/ekran sınırları (Main.tscn: WallLeft x=10 WallRight x=710, genişlik
# 20 -- iç yüzler x=20/x=700; Floor y=1270, GameOverZone y=200'ün ÇOK
# üzerinde bir tampon). Bu sınırların BELİRGİN şekilde dışına taşan bir
# canlı "ekran dışına düşmüş/takılmış" sayılır.
const STAGE_LEFT_X: float = -60.0
const STAGE_RIGHT_X: float = 780.0
const STAGE_TOP_Y: float = -300.0
const STAGE_BOTTOM_Y: float = 1500.0

var current_state: int = LoopState.IDLE

var _check_accum: float = 0.0
var _spawner: Node = null
var _no_pending_elapsed: float = 0.0
var _stuck_elapsed: Dictionary = {}   # instance_id(int) -> float saniye (ekran dışında kesintisiz gecen sure)
var _is_dragging: bool = false
var _recovery_log: Array = []          # QA/rapor için son kurtarmalar (Dictionary listesi)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE  # Pause/menu sırasında (get_tree().paused) denetim de doğal olarak durur
	call_deferred("_connect_spawner")
	GameManager.organism_merged.connect(_on_organism_merged)
	GameManager.run_reset.connect(_on_run_reset)
	GameManager.game_over_ready.connect(_on_game_over_ready)

## Main.tscn her zaman ilk kare hazır olmadan Spawner'ı garanti etmediğinden
## (autoload _ready() sahne ağacından ÖNCE çalışabilir), bağlantı bir kare
## ertelenir. Spawner kendi _ready()'sinde "spawner" grubuna eklenir (bkz.
## spawner.gd) -- bu sayede sahne yoluna (get_node) hiç BAĞIMLI olunmaz.
func _connect_spawner() -> void:
	_spawner = get_tree().get_first_node_in_group("spawner")
	if _spawner == null:
		# Sahne henüz tam kurulmadıysa bir kare daha bekle (QA/otomasyon
		# senaryolarında sahne geç kurulabilir) -- sonsuz yeniden deneme
		# DEĞİL, tek seferlik bir ek deneme.
		await get_tree().process_frame
		_spawner = get_tree().get_first_node_in_group("spawner")
	if _spawner == null:
		return
	_spawner.next_organism_ready.connect(_on_next_organism_ready)
	_spawner.organism_dropped.connect(_on_organism_dropped)
	_spawner.drag_state_changed.connect(_on_drag_state_changed)

func _on_next_organism_ready(_preview_data: Dictionary) -> void:
	current_state = LoopState.PLAYER_CONTROL
	_no_pending_elapsed = 0.0

func _on_organism_dropped(_position: Vector2, _is_bonus: bool) -> void:
	current_state = LoopState.FALLING

func _on_drag_state_changed(is_dragging: bool) -> void:
	_is_dragging = is_dragging

func _on_organism_merged(_position: Vector2, _stage_id: int, _is_bonus: bool, _awarded_score: int, _score_awarded: bool, _combo_count: int = 0) -> void:
	current_state = LoopState.RESOLVING
	# Bir sonraki _process karesinde durum PLAYER_CONTROL/SPAWNING'e doğal
	# olarak geri döner (bkz. _process) -- burada zorla ayarlamak GEREKMEZ,
	# yalnızca RESOLVING'in en azından bir kare GÖZLEMLENEBİLİR olmasını sağlar.

func _on_run_reset() -> void:
	current_state = LoopState.SPAWNING
	_no_pending_elapsed = 0.0
	_stuck_elapsed.clear()

func _on_game_over_ready(_final_stats: Dictionary = {}) -> void:
	current_state = LoopState.IDLE
	_no_pending_elapsed = 0.0
	_stuck_elapsed.clear()

func _process(delta: float) -> void:
	if GameFlow.current_state != GameFlow.State.PLAYING:
		return
	# RESOLVING kısa ömürlü bir gözlem durumudur -- bir sonraki karede,
	# bekleyen canlı hâlâ geçerliyse PLAYER_CONTROL'e, değilse SPAWNING'e
	# (üretim kontrolünün doğal olarak devraldığı duruma) geri döner.
	if current_state == LoopState.RESOLVING:
		current_state = LoopState.PLAYER_CONTROL if (_spawner != null and _spawner.has_valid_pending_organism()) else LoopState.SPAWNING
	_check_accum += delta
	if _check_accum < CHECK_INTERVAL_SECONDS:
		return
	var elapsed: float = _check_accum
	_check_accum = 0.0
	_check_stalled_production(elapsed)
	_check_stuck_organisms(elapsed)
	_check_game_over_backstop()

## Değişmez #1: bekleyen ("sıradaki") canlı STALL_PRODUCTION_SECONDS boyunca
## kesintisiz geçersiz/yok kaldıysa üretim ZORLA yeniden başlatılır. Normal
## akışta bu asla tetiklenmez (spawner.gd artık is_instance_valid() ile
## korunuyor, bkz. fix: recover stalled gameplay loop kök neden düzeltmesi)
## -- bu YALNIZCA beklenmedik/gelecekteki bir regresyona karşı bir güvenlik
## ağıdır.
func _check_stalled_production(elapsed: float) -> void:
	if _spawner == null:
		return
	if _spawner.has_valid_pending_organism():
		_no_pending_elapsed = 0.0
		if current_state == LoopState.SPAWNING:
			current_state = LoopState.PLAYER_CONTROL
		return
	current_state = LoopState.SPAWNING
	_no_pending_elapsed += elapsed
	if _no_pending_elapsed >= STALL_PRODUCTION_SECONDS:
		_no_pending_elapsed = 0.0
		_spawner.force_recover_pending_organism()
		_log_recovery("stalled_production", "Üretim >=%.1fs boyunca durdu -- bekleyen canlı zorla yeniden üretildi." % STALL_PRODUCTION_SECONDS)

## Değişmez #2: OrganismContainer'daki her canlı için fanus sınırlarının
## dışında kesintisiz geçirdiği süreyi izler; eşiği aşan bir canlı fanus
## içine GERİ konumlandırılır (queue_free/duplicate YOK -- yalnızca
## teleport + sıfır hız, mevcut nesne/skor/can durumuna dokunulmaz).
## Oyuncu bekleyen canlıyı sürüklerken (drag_state_changed) TÜM tarama
## atlanır -- kullanıcı isteği "oyuncu aktif sürüklerken asla".
func _check_stuck_organisms(elapsed: float) -> void:
	if _is_dragging:
		return
	var container: Node = get_tree().get_first_node_in_group("organism_container")
	if container == null:
		return
	var live_ids: Dictionary = {}
	for child in container.get_children():
		if not is_instance_valid(child) or not (child is Organism):
			continue
		var organism: Organism = child
		var id: int = organism.get_instance_id()
		live_ids[id] = true
		var pos: Vector2 = organism.global_position
		var off_screen: bool = pos.x < STAGE_LEFT_X or pos.x > STAGE_RIGHT_X or pos.y < STAGE_TOP_Y or pos.y > STAGE_BOTTOM_Y
		if not off_screen:
			_stuck_elapsed.erase(id)
			continue
		_stuck_elapsed[id] = float(_stuck_elapsed.get(id, 0.0)) + elapsed
		if _stuck_elapsed[id] >= STUCK_ORGANISM_SECONDS:
			_stuck_elapsed.erase(id)
			var recovered_pos: Vector2 = Vector2(
				clamp(pos.x, STAGE_LEFT_X + 100.0, STAGE_RIGHT_X - 100.0),
				clamp(pos.y, STAGE_TOP_Y + 100.0, STAGE_BOTTOM_Y - 200.0)
			)
			organism.global_position = recovered_pos
			organism.linear_velocity = Vector2.ZERO
			organism.angular_velocity = 0.0
			if organism.sleeping:
				organism.sleeping = false  # UYUYAN/hareketsiz kalmış gövdeyi de uyandır ki fizik yeniden işlesin
			_log_recovery("stuck_organism", "Canlı (id=%d) >=%.1fs ekran dışında takılı kaldı -- fanus içine geri konumlandırıldı, konum=%s." % [id, STUCK_ORGANISM_SECONDS, recovered_pos])
	# fix: recover stalled gameplay loop -- artık sahnede olmayan (queue_free
	# edilmiş/merge olmuş) canlıların takip kayıtlarını temizle (geçersiz/
	# silinmiş referans temizliği).
	for tracked_id in _stuck_elapsed.keys():
		if not live_ids.has(tracked_id):
			_stuck_elapsed.erase(tracked_id)

## Değişmez #3: can bitti ama oyun akışı hâlâ PLAYING görünüyorsa (beklenmedik
## bir senkronizasyon kaybı) oyun sonu akışını yeniden tetikler. Normal
## akışta lose_life() zaten senkron game_over yayınladığından bu dal pratikte
## hiç çalışmaz -- yalnızca ikinci bir güvenlik ağıdır.
func _check_game_over_backstop() -> void:
	if GameManager.lives <= 0:
		GameManager.force_game_over_if_stuck()
		_log_recovery("game_over_backstop", "Can<=0 iken oyun hâlâ PLAYING görünüyordu -- oyun sonu akışı yeniden tetiklendi.")

func _log_recovery(reason: String, detail: String) -> void:
	var entry: Dictionary = {"reason": reason, "detail": detail, "ticks_ms": Time.get_ticks_msec()}
	_recovery_log.append(entry)
	print("GAMEPLAY_WATCHDOG_RECOVERY reason=", reason, " detail=", detail)

## QA/test sürücüleri için salt-okunur erişim (bkz. mandatory test suite).
func get_recovery_log() -> Array:
	return _recovery_log.duplicate()
