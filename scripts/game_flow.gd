extends Node
## GameFlow -- feat: add start pause and how-to-play flow. Autoload. Oyunun
## GENEL AKIŞ durumunu (Start / Playing / Paused / How to Play / Game Over)
## TEK bir merkezden yönetir. Skor/XP/collision/fizik/merge/spawn/bonus
## EKONOMİSİNE HİÇBİR ŞEKİLDE dokunmaz -- yalnızca get_tree().paused
## bayrağını ve hangi akış ekranının (Start/Pause/How to Play) görünür
## olduğunu belirler.
##
## Var olan Game Over duraklatma mekanizması (GameManager._on_game_over()'ın
## DOĞRUDAN get_tree().paused = true yapması, reset_run()'ın false yapması)
## KORUNUR ve HİÇ DEĞİŞTİRİLMEZ -- GameFlow yalnızca GameManager.
## game_over_ready / run_reset sinyallerini DİNLEYEREK kendi akış durumunu
## senkronize eder. Böylece Task A/B'de test edilmiş Game Over/Retry akışı
## bozulmadan kalır.
##
## "Restart Run" (Pause ekranı) ile "Play again" (Game Over ekranı) AYNI
## GameManager.reset_run() fonksiyonunu çağırır -- reset/skor/XP mantığı
## KOPYALANMAZ, ikisi de run_reset sinyaliyle buraya PLAYING durumuna geçer.

enum State { START, PLAYING, PAUSED, HOW_TO_PLAY, GAME_OVER, SETTINGS }

signal state_changed(new_state: int)
## Yalnızca BU script'in menü amaçlı (Start/Pause) duraklatma geçişlerinde
## yayınlanır -- Game Over'ın kendi duraklatması bunu TETİKLEMEZ (bkz. yukarı
## not, Game Over zaten kendi başına chain/effects state'ini sıfırlıyor).
## chain_toast.gd bunu, duraklama sırasında geçen GERÇEK ZAMANLI süreyi
## zincir penceresi hesabından düşmek için dinler (bkz. o dosyadaki yorum).
signal pause_state_changed(is_paused: bool)

var current_state: int = State.START
var _how_to_play_return_state: int = State.START
var _settings_return_state: int = State.START  # feat: add sound haptics and persistent settings -- How to Play'deki _how_to_play_return_state ile AYNI desen

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Pause/Start sırasında da Android Back/Escape işlensin
	get_tree().paused = true  # Açılışta dünya tamamen dursun: PLAY'e kadar fizik/spawn/drop beklesin
	GameManager.game_over_ready.connect(_on_game_over_ready)
	GameManager.run_reset.connect(_on_run_reset)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_handle_back()
		get_viewport().set_input_as_handled()

## Android'in donanım Geri düğmesi masaüstündeki Escape'ten (ui_cancel) FARKLI
## bir yoldan gelir -- Godot bunu ui_cancel'a eşlemez, bu bildirimi yayınlar.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back()

## Android Back / masaüstü Escape -- öncelik sırası kullanıcı talebiyle
## BİREBİR: 1) How to Play açıksa kapat (geldiği ekrana dön) 2) Pause
## açıksa devam et (Resume) 3) Oyun aktifse Pause aç 4) Start ekranındaysa
## (veya Game Over'da) hiçbir şey yapma -- uygulamayı KAPATMA, mevcut ekran kalsın.
func _handle_back() -> void:
	match current_state:
		State.HOW_TO_PLAY:
			close_how_to_play()
		State.SETTINGS:
			close_settings()  # feat: add sound haptics and persistent settings -- How to Play ile AYNI öncelik katmanı: açık panel varsa önce o kapanır
		State.PAUSED:
			resume()
		State.PLAYING:
			open_pause()
		_:
			pass  # Start / Game Over: mevcut ekran kalır, otomatik kapatma yok

func _set_state(new_state: int) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	state_changed.emit(current_state)

## PLAY -- Start ekranından çağrılır. Mevcut güvenli reset_run() akışını
## kullanır (skor/can zaten varsayılan değerinde olsa da çağrı idempotent ve
## güvenlidir) -- PLAYING durumuna geçiş run_reset sinyaliyle _on_run_reset()
## içinde, TEK bir yerden olur.
func start_run() -> void:
	if current_state != State.START:
		return
	GameManager.reset_run()

## Küçük Pause düğmesi -- yalnızca PLAYING sırasında çağrılabilir. "Game Over
## sırasında Pause açılamıyor" kuralı burada DOĞAL olarak sağlanır: Game Over
## durumunda current_state PLAYING olmadığından bu fonksiyon hiçbir şey yapmaz.
func open_pause() -> void:
	if current_state != State.PLAYING:
		return
	_set_state(State.PAUSED)
	get_tree().paused = true
	pause_state_changed.emit(true)

func resume() -> void:
	if current_state != State.PAUSED:
		return
	_set_state(State.PLAYING)
	get_tree().paused = false
	pause_state_changed.emit(false)

## RESTART RUN (Pause ekranı) -- Game Over ekranının "Play again" düğmesiyle
## BİREBİR AYNI reset_run() çağrısı; skor/XP/reset mantığı KOPYALANMAZ.
func restart_run() -> void:
	GameManager.reset_run()

## How to Play -- yalnızca Start veya Pause'dan açılabilir; kapanınca
## geldiği ekrana (Start ya da Pause) döner. Arka planda oyunu YENİDEN
## BAŞLATMAZ (reset_run() burada ASLA çağrılmaz).
func open_how_to_play() -> void:
	if current_state != State.START and current_state != State.PAUSED:
		return
	_how_to_play_return_state = current_state
	_set_state(State.HOW_TO_PLAY)

func close_how_to_play() -> void:
	if current_state != State.HOW_TO_PLAY:
		return
	_set_state(_how_to_play_return_state)

## Settings -- yalnızca Start veya Pause'dan açılabilir; kapanınca geldiği
## ekrana (Start ya da Pause) döner. open_how_to_play()/close_how_to_play()
## ile BİREBİR AYNI desen -- arka planda oyunu YENİDEN BAŞLATMAZ (reset_run()
## burada da ASLA çağrılmaz). Oynanış/skor/XP/spawn/bonus/collision/physics
## EKONOMİSİNE dokunmaz, yalnızca akış durumunu değiştirir.
func open_settings() -> void:
	if current_state != State.START and current_state != State.PAUSED:
		return
	_settings_return_state = current_state
	_set_state(State.SETTINGS)

func close_settings() -> void:
	if current_state != State.SETTINGS:
		return
	_set_state(_settings_return_state)

## GameManager.run_reset (0 argümanlı) -- hem Pause'un "Restart Run" hem de
## Game Over'ın "Play again" düğmesi buraya reset_run() üzerinden ulaşır.
## reset_run() get_tree().paused'ı ZATEN false yapar; burada yalnızca akış
## durumunu senkronize ederiz.
func _on_run_reset() -> void:
	_set_state(State.PLAYING)

## GameManager.game_over_ready(final_stats: Dictionary) -- varsayılan değerli
## opsiyonel parametre, bu projede zaten kanıtlanmış imza-uyumsuzluğu
## kaçınma deseniyle tutarlı (bkz. merge_feedback_manager.gd/chain_toast.gd).
func _on_game_over_ready(_final_stats: Dictionary = {}) -> void:
	_set_state(State.GAME_OVER)
