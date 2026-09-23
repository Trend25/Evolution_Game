extends CanvasLayer
class_name PauseScreen
## PauseScreen -- feat: add start pause and how-to-play flow. GameFlow.
## State.PAUSED iken görünür. RESUME/HOW TO PLAY/RESTART RUN düğmeleri
## yalnızca GameFlow'un (resume/open_how_to_play) veya onun üzerinden
## GameManager'ın (restart_run -> reset_run(), Game Over "Play again" ile
## BİREBİR AYNI fonksiyon) hazır güvenli fonksiyonlarını çağırır -- skor/XP/
## reset mantığı KOPYALANMAZ. NEXT/Score/Lives panellerinin ölçülerine
## dokunmaz (ayrı bir CanvasLayer, HUD'un ÜSTÜNDE, layer=41).

@onready var _title_label: Label = $Panel/TitleLabel
@onready var _resume_button: Button = $Panel/ResumeButton
@onready var _how_to_play_button: Button = $Panel/HowToPlayButton
@onready var _restart_button: Button = $Panel/RestartButton
@onready var _settings_button: Button = $Panel/SettingsButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # get_tree().paused = true iken de düğmeler çalışsın
	visible = false
	_apply_style()
	_resume_button.pressed.connect(_on_resume_pressed)
	_how_to_play_button.pressed.connect(_on_how_to_play_pressed)
	_how_to_play_button.pressed.connect(AudioManager.play_ui_tick)  # feat: add sound haptics -- genel navigasyon tıkı (Resume/Restart Run'ın kendi özel sesleri var, burada TEKRAR eklenmez)
	_restart_button.pressed.connect(_on_restart_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_settings_button.pressed.connect(AudioManager.play_ui_tick)
	GameFlow.state_changed.connect(_on_state_changed)

func _on_state_changed(new_state: int) -> void:
	visible = new_state == GameFlow.State.PAUSED

func _on_resume_pressed() -> void:
	GameFlow.resume()

func _on_how_to_play_pressed() -> void:
	GameFlow.open_how_to_play()

func _on_restart_pressed() -> void:
	GameFlow.restart_run()

func _on_settings_pressed() -> void:
	GameFlow.open_settings()

func _apply_style() -> void:
	$Panel.add_theme_stylebox_override("panel", HUDTheme.make_summary_panel_stylebox())
	HUDTheme.style_label(_title_label, HUDTheme.make_spaced_variation(HUDTheme.FONT_UI, 3), 22, HUDTheme.TEXT_PRIMARY)
	_title_label.text = "PAUSED"
	_style_button(_resume_button, "RESUME")
	_style_button(_how_to_play_button, "HOW TO PLAY")
	_style_button(_restart_button, "RESTART RUN")
	_style_button(_settings_button, "SETTINGS")

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
