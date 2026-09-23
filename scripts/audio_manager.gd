extends Node
## AudioManager -- feat: add sound haptics and persistent settings. Autoload.
## Oyuna sakin, tatmin edici ses/titreşim geri bildirimi ekleyen TEK merkezi
## kaynak. %60 Soft Indie + %30 Cozy Oddball + %10 Graphic Arcade -- çocuksu,
## aşırı parlak, casino benzeri veya rahatsız edici ses YOK. Skor/XP
## ekonomisi, merge sonucu, chain süresi, spawn/cooldown/bonus ihtimali,
## collision/physics, organism görselleri, HUD/NEXT ölçüleri, background
## HİÇBİR şekilde değiştirilmez -- bu script yalnızca ZATEN var olan
## sinyalleri DİNLER, kendi ekonomi/zamanlama kararı ASLA vermez.
##
## Ses kaynağı: tüm WAV dosyaları (assets/audio/) bu ortamda Python'un
## standart `wave` modülüyle yerel olarak, matematiksel sentezle (sinüs
## dalgaları + üstel zarf) üretildi -- HARİCİ/TELİFLİ hiçbir asset
## kullanılmadı. Üretim betiği ve lisans/kaynak durumu final raporda
## açıkça belirtilir.
##
## Havuz mimarisi: AYRI bir AudioStreamPlayer havuzu (round-robin) kullanılır
## ki hızlı art arda merge'lerde sesler birbirini KESMESİN (her çalma yeni/
## boş bir player'a gider, önceki hâlâ çalıyor olsa bile kesilmez). Runtime'da
## AĞIR ses üretimi YAPILMAZ -- tüm WAV'lar önceden, offline üretildi ve
## yalnızca AudioStreamWAV olarak yüklenip oynatılır.

const SETTINGS_PATH: String = "user://settings.cfg"
const SFX_POOL_SIZE: int = 8

const MERGE_PITCH_BASE: float = 1.0
const MERGE_PITCH_PER_STAGE: float = 0.025
const MERGE_PITCH_MAX: float = 1.25
const CHAIN_PITCH_BASE: float = 1.0
const CHAIN_PITCH_PER_STEP: float = 0.06
const CHAIN_PITCH_MAX: float = 1.3

const HAPTIC_DROP_MS: int = 11
const HAPTIC_MERGE_MS: int = 20
const HAPTIC_BONUS_MS: int = 30
const HAPTIC_LEVEL_UP_MS: int = 32
const HAPTIC_GAME_OVER_MS: int = 45

## QA amaçlı sayaç/signal -- SADECE test/doğrulama için. Hiçbir üretim
## davranışını (hangi sesin çalacağını, ne zaman çalacağını) ETKİLEMEZ;
## yalnızca zaten gerçekleşen play/haptic çağrılarını DIŞARI bildirir.
## sound_enabled=false iken _play() erken çıktığından bu sinyal hiç
## yayınlanmaz -- "Sound OFF sonrası hiçbir ses yok" QA kontrolü bunu
## doğrudan bu sinyalin hiç tetiklenmediğini gözlemleyerek yapabilir.
signal qa_sound_played(event_name: String)
signal qa_haptic_triggered(event_name: String, duration_ms: int)

var sound_enabled: bool = true
var haptics_enabled: bool = true

var _sfx_pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0
var _streams: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Pause ekranındaki UI sesleri de çalışabilsin
	_load_streams()
	_build_pool()
	_load_settings()
	GameManager.organism_merged.connect(_on_organism_merged)
	GameManager.level_up.connect(_on_level_up)
	GameManager.game_over_ready.connect(_on_game_over_ready)
	GameManager.run_reset.connect(_on_run_reset)
	GameFlow.pause_state_changed.connect(_on_pause_state_changed)

func _load_streams() -> void:
	var names: Array[String] = [
		"ui_tick", "drop", "merge", "bonus_shimmer", "fish_complete",
		"chain", "level_up", "game_over", "start_retry", "pause", "resume",
	]
	for n in names:
		var path: String = "res://assets/audio/%s.wav" % n
		if ResourceLoader.exists(path):
			_streams[n] = load(path)

func _build_pool() -> void:
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.bus = "Master"
		add_child(player)
		_sfx_pool.append(player)

# -----------------------------------------------------------------------
# Ayarlar kalıcılığı (user://settings.cfg) -- Varsayılan: Sound ON, Haptics ON
# -----------------------------------------------------------------------

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var err: int = cfg.load(SETTINGS_PATH)
	if err == OK:
		sound_enabled = bool(cfg.get_value("audio", "sound_enabled", true))
		haptics_enabled = bool(cfg.get_value("audio", "haptics_enabled", true))
	else:
		sound_enabled = true
		haptics_enabled = true

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sound_enabled", sound_enabled)
	cfg.set_value("audio", "haptics_enabled", haptics_enabled)
	cfg.save(SETTINGS_PATH)

## Settings panelinden çağrılır -- Sound OFF TÜM oyun/UI seslerini susturur.
func set_sound_enabled(value: bool) -> void:
	sound_enabled = value
	_save_settings()

## Settings panelinden çağrılır -- Haptics OFF TÜM titreşimleri durdurur.
func set_haptics_enabled(value: bool) -> void:
	haptics_enabled = value
	_save_settings()

# -----------------------------------------------------------------------
# Merkezi çalma yardımcıları
# -----------------------------------------------------------------------

## Havuzdaki bir sonraki (round-robin) player'ı kullanır -- hızlı art arda
## çağrılarda önceki ses ASLA kesilmez, her çağrı kendi player'ında çalar.
func _play(event_name: String, pitch: float = 1.0) -> void:
	if not sound_enabled:
		return
	var stream: AudioStream = _streams.get(event_name)
	if stream == null:
		return
	var player: AudioStreamPlayer = _sfx_pool[_pool_index]
	_pool_index = (_pool_index + 1) % _sfx_pool.size()
	player.stream = stream
	player.pitch_scale = pitch
	player.play()
	qa_sound_played.emit(event_name)

## Game Over / Retry sırasında aktif kalmış olabilecek herhangi bir SFX'i
## durdurur -- tüm seslerimiz zaten kısa tek-atımlık (one-shot) olduğundan
## normalde gereksizdir, ama bu iki geçiş noktasında ek güvence olarak eklendi.
func _stop_all_players() -> void:
	for p in _sfx_pool:
		if p.playing:
			p.stop()

func _haptic(event_name: String, duration_ms: int) -> void:
	if not haptics_enabled:
		return
	Input.vibrate_handheld(duration_ms)  # Godot: desteklenmeyen platformlarda (desktop/web) güvenli no-op
	qa_haptic_triggered.emit(event_name, duration_ms)

# -----------------------------------------------------------------------
# Genel navigasyon sesi -- yalnızca "özel" bir sesi olmayan düğmelerde
# kullanılır (How to Play aç/kapat, Settings aç/kapat, Sound/Haptics toggle).
# Play/Retry/Resume/Pause/RestartRun gibi düğmeler KENDİ özel seslerini zaten
# aşağıdaki sinyal bağlantıları üzerinden alır -- "aynı olay için ses
# yalnızca bir kez çalmalı" kuralı gereği bunlara AYRICA tick eklenmez.
# -----------------------------------------------------------------------
func play_ui_tick() -> void:
	_play("ui_tick")

# -----------------------------------------------------------------------
# Oyun içi (gameplay) tetikleyiciler -- yalnızca GameFlow.State.PLAYING
# sırasında çalar: Pause/Start/HowToPlay/Settings/GameOver ekranları
# açıkken (get_tree().paused=true olduğu durumlarda) fizik zaten
# ilerlemediğinden bu sinyaller doğal olarak ateşlenmez, ama bu ek kontrol
# "gameplay sesleri pause sırasında ilerlemez" garantisini açıkça sağlar.
# -----------------------------------------------------------------------

func play_drop() -> void:
	if GameFlow.current_state != GameFlow.State.PLAYING:
		return
	_play("drop")
	_haptic("drop", HAPTIC_DROP_MS)

## GameManager.organism_merged(position, merged_stage_id, is_bonus, awarded_score, score_awarded)
## score_awarded=true  -> gerçek evrim/tier-büyüme merge'i (normal veya bonus)
## score_awarded=false -> YALNIZCA Balık parça tamamlanması (bkz. organism.gd
##                         _perform_fish_part_merge) -- merge sesi DEĞİL, ayrı
##                         bir "fish complete" sesi çalar.
func _on_organism_merged(_position: Vector2, merged_stage_id: int, is_bonus: bool, _awarded_score: int, score_awarded: bool) -> void:
	if GameFlow.current_state != GameFlow.State.PLAYING:
		return
	if not score_awarded:
		_play("fish_complete")
		_haptic("fish_complete", HAPTIC_MERGE_MS)
		return
	var pitch: float = clamp(MERGE_PITCH_BASE + float(merged_stage_id) * MERGE_PITCH_PER_STAGE, MERGE_PITCH_BASE, MERGE_PITCH_MAX)
	_play("merge", pitch)
	if is_bonus:
		_play("bonus_shimmer")
	_haptic("merge", HAPTIC_BONUS_MS if is_bonus else HAPTIC_MERGE_MS)

## chain_toast.gd, kendi zaten hesapladığı chain sayacı count>=2 olup toast'ı
## gösterdiği ANDA bunu çağırır (bkz. o dosyadaki _show_chain). Chain
## sayısının/zamanlama penceresinin hesaplanmasına bu fonksiyon HİÇ karışmaz,
## yalnızca zaten alınmış kararı sese çevirir.
func play_chain(count: int) -> void:
	if GameFlow.current_state != GameFlow.State.PLAYING:
		return
	var pitch: float = clamp(CHAIN_PITCH_BASE + float(count - 2) * CHAIN_PITCH_PER_STEP, CHAIN_PITCH_BASE, CHAIN_PITCH_MAX)
	_play("chain", pitch)

func _on_level_up(_new_level: int, _unlocked_reward_id: String) -> void:
	_play("level_up")
	_haptic("level_up", HAPTIC_LEVEL_UP_MS)

## GameManager.game_over_ready(final_stats) -- run_reset ile AYNI anda asla
## tetiklenmez (bkz. game_manager.gd), bu yüzden burada da stop_all sonrası
## tek bir çağrı yeterlidir.
func _on_game_over_ready(_final_stats: Dictionary) -> void:
	_stop_all_players()
	_play("game_over")
	_haptic("game_over", HAPTIC_GAME_OVER_MS)

## GameManager.run_reset -- hem Start ekranının PLAY'i hem Pause'un
## RESTART RUN'ı hem Game Over'ın "Play again"i BURAYA, TEK bir merkezi
## reset_run() çağrısı üzerinden ulaşır (bkz. game_flow.gd yorumu) --
## "Play/Retry" için ayrı ayrı üç kopya tetikleyici EKLENMEDİ.
func _on_run_reset() -> void:
	_stop_all_players()
	_play("start_retry")

## Yalnızca GameFlow'un MENÜ amaçlı (Start/Pause) duraklatmasında yayınlanır
## -- Game Over'ın kendi duraklatması bunu tetiklemez (zaten kendi
## game_over/game_over_ready sesine sahip). Bu, "Pause/Resume: çok hafif
## geri bildirim" maddesinin TEK ve doğru tetikleme noktasıdır.
func _on_pause_state_changed(is_paused: bool) -> void:
	if is_paused:
		_play("pause")
	else:
		_play("resume")
