extends CanvasLayer
class_name StartScreen
## StartScreen -- feat: add start pause and how-to-play flow. Açılış ekranı:
## GameFlow.State.START iken görünür. PLAY, GameFlow.start_run() üzerinden
## (yani GameManager.reset_run() üzerinden) temiz bir run başlatır. HOW TO
## PLAY, tek panelli yardım ekranını açar. Oyun mantığına DOKUNMAZ -- yalnızca
## GameFlow'un halihazırda güvenli, mevcut fonksiyonlarını çağırır.
##
## Oyun adı SABİT KODLANMAZ: project.godot'taki application/config/name
## (kullanıcı talebi -- "mevcut oyun adını kontrol et ve başlıkta onu kullan")
## çalışma zamanında okunur.

const LabPreviewHostScript: GDScript = preload("res://scripts/lab_preview_host.gd")
const OrganismVisualScript: GDScript = preload("res://scripts/organism_visual.gd")
const HERO_VIRUS_TARGET_DIAMETER: float = 92.0
const HERO_VIRUS_POSITION: Vector2 = Vector2(240.0, 136.0)  # Panel yerel uzayı (480 genişlik/2, TitleLabel(92) ile PlayButton(180) arası boşluğun ortası)

@onready var _title_label: Label = $Panel/TitleLabel
@onready var _play_button: Button = $Panel/PlayButton
@onready var _how_to_play_button: Button = $Panel/HowToPlayButton
@onready var _settings_button: Button = $Panel/SettingsButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Dünya duraklıyken de bu ekranın düğmeleri çalışsın
	_title_label.text = String(ProjectSettings.get_setting("application/config/name", "Evrim"))
	_apply_style()
	_maybe_build_hero_visual()
	_play_button.pressed.connect(_on_play_pressed)
	_how_to_play_button.pressed.connect(_on_how_to_play_pressed)
	_how_to_play_button.pressed.connect(AudioManager.play_ui_tick)  # feat: add sound haptics -- genel navigasyon tıkı (PLAY'in kendi start_retry sesi var, burada TEKRAR eklenmez)
	_settings_button.pressed.connect(_on_settings_pressed)
	_settings_button.pressed.connect(AudioManager.play_ui_tick)
	GameFlow.state_changed.connect(_on_state_changed)
	visible = GameFlow.current_state == GameFlow.State.START

func _on_state_changed(new_state: int) -> void:
	visible = new_state == GameFlow.State.START

func _on_play_pressed() -> void:
	GameFlow.start_run()

func _on_how_to_play_pressed() -> void:
	GameFlow.open_how_to_play()

func _on_settings_pressed() -> void:
	GameFlow.open_settings()

## Görsel stil -- GameOverScreen._apply_style() ile AYNI merkezi HUDTheme
## kaynağından, aynı desenle (soft indie / cozy oddball, büyük çocuk oyunu
## butonları veya parlak renkler yok, maskot yok).
func _apply_style() -> void:
	$Panel.add_theme_stylebox_override("panel", HUDTheme.make_summary_panel_stylebox())
	HUDTheme.style_label(_title_label, HUDTheme.make_spaced_variation(HUDTheme.FONT_NUMBER, 1), 36, HUDTheme.TEXT_PRIMARY)
	# gameplay/core-loop-v4 "Evrim Laboratuvarı" V02 (madde 1 -- kullanıcı:
	# "'Oyuna Başla' ve 'Nasıl Oynanır' çalışmalı") -- metin DEĞİŞİKLİĞİ,
	# GameFlow.start_run()/open_how_to_play() ÇAĞRILARI zaten değişmeden
	# çalışıyor, yalnızca görünen etiket Türkçeleştirildi.
	_style_button(_play_button, "Oyuna Başla")
	_style_button(_how_to_play_button, "Nasıl Oynanır")
	_style_button(_settings_button, "SETTINGS")

## gameplay/core-loop-v4 "Evrim Laboratuvarı" V02 (madde 1 -- kullanıcı: "V02
## Başlangıç Ekranı (Virüs-merkezli) uygulansın; farenin/eski aşama
## görselinin YERİNDE olmasın"). Bu ekranda zaten hiçbir fare/eski-aşama
## görseli YOKTU (yalnızca V02 mockup'ında -- StartScreen.dc.html -- vardı,
## GERÇEK oyun kodunda hiç referans edilmemişti); bu fonksiyon SADECE V02'nin
## Virüs-merkezli hero görselini EKLER. NEXT önizlemesi/DropAimGuide hayaleti
## ile AYNI LabPreviewHost + organism_visual.gd deseni kullanılır -- yeni bir
## çizim yolu İCAT EDİLMEZ. SADECE lab modunda (ENABLED and LAB_VISUALS_
## ENABLED) eklenir; üretimde bu ekran DEĞİŞMEDEN kalır.
func _maybe_build_hero_visual() -> void:
	if not (GrayboxConfig.ENABLED and GrayboxConfig.LAB_VISUALS_ENABLED):
		return
	var hero := Node2D.new()
	hero.set_script(LabPreviewHostScript)
	hero.name = "VirusHero"
	hero.stage_id = 0
	$Panel.add_child(hero)
	var visual := Polygon2D.new()
	visual.name = "Visual"
	visual.set_script(OrganismVisualScript)
	hero.add_child(visual)
	var radius: float = GrayboxConfig.effective_radius(0)
	hero.scale = Vector2.ONE * (HERO_VIRUS_TARGET_DIAMETER / (radius * 2.0))
	hero.position = HERO_VIRUS_POSITION

func _style_button(button: Button, label_text: String) -> void:
	button.text = label_text
	button.add_theme_stylebox_override("normal", HUDTheme.make_button_stylebox(false))
	button.add_theme_stylebox_override("hover", HUDTheme.make_button_stylebox(false))
	button.add_theme_stylebox_override("pressed", HUDTheme.make_button_stylebox(true))
	button.add_theme_stylebox_override("focus", HUDTheme.make_button_stylebox(false))
	button.add_theme_color_override("font_color", HUDTheme.BUTTON_TEXT_DARK)
	button.add_theme_color_override("font_hover_color", HUDTheme.BUTTON_TEXT_DARK)
	button.add_theme_color_override("font_pressed_color", HUDTheme.BUTTON_TEXT_DARK)
	button.add_theme_font_override("font", HUDTheme.FONT_UI)
	button.add_theme_font_size_override("font_size", 18)
