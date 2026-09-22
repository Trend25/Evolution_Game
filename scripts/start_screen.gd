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

@onready var _title_label: Label = $Panel/TitleLabel
@onready var _play_button: Button = $Panel/PlayButton
@onready var _how_to_play_button: Button = $Panel/HowToPlayButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Dünya duraklıyken de bu ekranın düğmeleri çalışsın
	_title_label.text = String(ProjectSettings.get_setting("application/config/name", "Evrim"))
	_apply_style()
	_play_button.pressed.connect(_on_play_pressed)
	_how_to_play_button.pressed.connect(_on_how_to_play_pressed)
	GameFlow.state_changed.connect(_on_state_changed)
	visible = GameFlow.current_state == GameFlow.State.START

func _on_state_changed(new_state: int) -> void:
	visible = new_state == GameFlow.State.START

func _on_play_pressed() -> void:
	GameFlow.start_run()

func _on_how_to_play_pressed() -> void:
	GameFlow.open_how_to_play()

## Görsel stil -- GameOverScreen._apply_style() ile AYNI merkezi HUDTheme
## kaynağından, aynı desenle (soft indie / cozy oddball, büyük çocuk oyunu
## butonları veya parlak renkler yok, maskot yok).
func _apply_style() -> void:
	$Panel.add_theme_stylebox_override("panel", HUDTheme.make_summary_panel_stylebox())
	HUDTheme.style_label(_title_label, HUDTheme.make_spaced_variation(HUDTheme.FONT_NUMBER, 1), 36, HUDTheme.TEXT_PRIMARY)
	_style_button(_play_button, "PLAY")
	_style_button(_how_to_play_button, "HOW TO PLAY")

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
