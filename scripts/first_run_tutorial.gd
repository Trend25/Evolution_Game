extends CanvasLayer
class_name FirstRunTutorial
## FirstRunTutorial -- feat: add first-run gameplay guidance (Bölüm D). Kısa,
## atlanabilir bir ilk-çalıştırma ipucu katmanı (kullanıcı isteği): oyuncu
## GERÇEKTEN ilk kez PLAYING durumuna geçtiğinde (run_reset'in İLK çağrısı)
## otomatik gösterilir. Üç kısa satır gösterir (kullanıcının verdiği METİN
## BİREBİR): "Canlıyı sürükle ve bırak", "Aynı canlıları birleştir",
## "Birleştirerek evrimleştir!". Bırakma çizgisini ve bırakılabilir alanı
## GÖRSEL olarak işaretler (bkz. drop_zone_marker.gd). İlk BAŞARILI (skor
## veren) merge'de OTOMATİK kapanır; ATLA düğmesiyle de elle kapatılabilir.
##
## Kalıcılık: user://tutorial.cfg (audio_manager.gd'nin settings.cfg
## dosyasından KASITLI OLARAK AYRI bir dosya -- ayrıntı için bkz. final
## rapor: audio_manager._save_settings() dosyayı ÖNCE load ETMEDEN yeniden
## yazıyor, aynı dosyaya ikinci bir bölüm eklersek diğer script'in bir
## SONRAKİ kaydı bu bölümü SESSİZCE SİLERDİ -- bu riskten TAMAMEN kaçınmak
## için ayrı dosya kullanıldı, audio_manager.gd'ye HİÇ dokunulmadı).
##
## SettingsPanel'deki "TUTORIAL'I TEKRAR GÖSTER" düğmesi request_replay()'i
## çağırır -- bu, kalıcı "görüldü" bayrağına DOKUNMADAN overlay'i hemen
## tekrar gösterir (manuel tekrar oynatma, otomatik ilk-çalıştırma
## davranışını YENİDEN silahlandırmaz).
##
## Oynanışı kısıtlamaz: panel/skip düğmesi DIŞINDAKİ hiçbir alan
## mouse_filter=IGNORE'dur (HUDRoot ile AYNI kural, bkz. hud_root.gd) --
## Spawner'ın sürükle/bırak girdisi HER ZAMAN çalışmaya devam eder, aksi
## halde oyuncu ilk merge'i hiç yapamaz ve tutorial asla kapanmazdı.
## Tutorial açıkken oyunun "kontrolsüzce arka planda" ilerlememesi için
## (kullanıcı isteği) Spawner'ın Bonus Sistemi zamanlayıcısı geçici olarak
## DURDURULUR (bkz. spawner.gd set_tutorial_active) -- drop/cooldown/
## collision/merge mantığının KENDİSİNE dokunulmaz, oyuncu normal şekilde
## oynayabilir.

const SAVE_PATH: String = "user://tutorial.cfg"
const STEPS: Array[String] = [
	"Canlıyı sürükle ve bırak",
	"Aynı canlıları birleştir",
	"Birleştirerek evrimleştir!",
]

@onready var _panel: Panel = $Panel
@onready var _steps_label: Label = $Panel/StepsLabel
@onready var _skip_button: Button = $Panel/SkipButton
@onready var _drop_zone_marker: DropZoneMarker = $DropZoneMarker

var _seen: bool = false
var _spawner: Node = null

func _ready() -> void:
	add_to_group("first_run_tutorial")  # feat: add first-run gameplay guidance -- SettingsPanel'in sahne yoluna bağımlı olmadan bulması için
	process_mode = Node.PROCESS_MODE_ALWAYS  # Pause/menu geçişlerinde de düzgün davranabilsin
	# NOT: layer değeri Main.tscn'deki sahne instance'ında ayarlanır (diğer
	# tüm overlay'lerle -- ChainToast/LevelUpToast/GameOverScreen -- AYNI
	# kural, bkz. Main.tscn).
	visible = false
	_apply_style()
	_skip_button.pressed.connect(_on_skip_pressed)
	_skip_button.pressed.connect(AudioManager.play_ui_tick)
	GameManager.run_reset.connect(_on_run_reset)
	GameManager.organism_merged.connect(_on_organism_merged)
	_load_seen()
	call_deferred("_connect_spawner")

func _connect_spawner() -> void:
	_spawner = get_tree().get_first_node_in_group("spawner")

func _apply_style() -> void:
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", HUDTheme.make_summary_panel_stylebox())
	HUDTheme.style_label(_steps_label, HUDTheme.FONT_UI, 17, HUDTheme.TEXT_PRIMARY)
	_steps_label.text = "  •  ".join(STEPS)
	_skip_button.text = "ATLA"
	_skip_button.mouse_filter = Control.MOUSE_FILTER_STOP  # TEK interaktif kontrol -- HUDRoot deseniyle aynı (bkz. hud_root.gd)
	_skip_button.add_theme_stylebox_override("normal", HUDTheme.make_button_stylebox(false))
	_skip_button.add_theme_stylebox_override("hover", HUDTheme.make_button_stylebox(false))
	_skip_button.add_theme_stylebox_override("pressed", HUDTheme.make_button_stylebox(true))
	_skip_button.add_theme_stylebox_override("focus", HUDTheme.make_button_stylebox(false))
	_skip_button.add_theme_color_override("font_color", HUDTheme.BUTTON_TEXT_DARK)
	_skip_button.add_theme_color_override("font_hover_color", HUDTheme.BUTTON_TEXT_DARK)
	_skip_button.add_theme_color_override("font_pressed_color", HUDTheme.BUTTON_TEXT_DARK)
	_skip_button.add_theme_font_override("font", HUDTheme.FONT_UI)
	_skip_button.add_theme_font_size_override("font_size", 16)

func _load_seen() -> void:
	var cfg := ConfigFile.new()
	var err: int = cfg.load(SAVE_PATH)
	_seen = bool(cfg.get_value("tutorial", "seen", false)) if err == OK else false

func _save_seen() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("tutorial", "seen", _seen)
	cfg.save(SAVE_PATH)

## run_reset HER "Play"/"Play again"/"Restart Run"da tetiklenir -- yalnızca
## HİÇ görülmemişse (_seen==false) otomatik gösterilir, sonraki turlarda
## sessizce hiçbir şey yapmaz.
func _on_run_reset() -> void:
	if _seen:
		return
	_show()

## Yalnızca SKOR ÖDÜLÜ VEREN (score_awarded=true) gerçek bir merge, ilk
## başarılı birleşme sayılır -- Balık parça tamamlanması (score_awarded=
## false) tutorial'ı KAPATMAZ, kullanıcı isteğinin "aynı canlıları
## birleştir / birleştirerek evrimleştir" adımlarıyla eşleşmez.
func _on_organism_merged(_position: Vector2, _stage_id: int, _is_bonus: bool, _awarded_score: int, score_awarded: bool, _combo_count: int = 0) -> void:
	if not visible or not score_awarded:
		return
	_dismiss(true)

func _on_skip_pressed() -> void:
	_dismiss(true)

## SettingsPanel'den çağrılır -- kalıcı "görüldü" bayrağına DOKUNMADAN
## overlay'i hemen yeniden gösterir (bkz. yukarı sınıf notu).
func request_replay() -> void:
	_show()

func _show() -> void:
	visible = true
	_drop_zone_marker.queue_redraw()
	if _spawner != null and _spawner.has_method("set_tutorial_active"):
		_spawner.set_tutorial_active(true)

## mark_seen: true ise kalıcı "görüldü" bayrağı diske yazılır (otomatik ilk
## gösterim BİR DAHA tetiklenmez). SettingsPanel'den manuel tekrar
## oynatmada da mark_seen=true geçilir -- zaten görülmüş bir tutorial'ı
## tekrar izlemek, "görülmedi" durumuna GERİ DÖNDÜRMEMELİDİR.
func _dismiss(mark_seen: bool) -> void:
	visible = false
	if mark_seen and not _seen:
		_seen = true
		_save_seen()
	if _spawner != null and _spawner.has_method("set_tutorial_active"):
		_spawner.set_tutorial_active(false)
