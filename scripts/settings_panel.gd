extends CanvasLayer
class_name SettingsPanel
## SettingsPanel -- feat: add sound haptics and persistent settings. Start ve
## Pause akışından açılabilen küçük bir ayar paneli: SOUND ON/OFF, HAPTICS
## ON/OFF, BACK. GameFlow.State.SETTINGS iken görünür; kapanınca açıldığı
## ekrana (Start ya da Pause) döner -- HowToPlayPanel'in kapanış deseniyle
## BİREBİR aynı (bkz. game_flow.gd open_settings/close_settings). Oyun
## mantığına DOKUNMAZ -- yalnızca AudioManager.sound_enabled/haptics_enabled
## bayraklarını okur/değiştirir. Mevcut HUD panel ölçülerine dokunmaz.

@onready var _title_label: Label = $Panel/TitleLabel
@onready var _sound_caption: Label = $Panel/SoundCaption
@onready var _sound_button: Button = $Panel/SoundButton
@onready var _haptics_caption: Label = $Panel/HapticsCaption
@onready var _haptics_button: Button = $Panel/HapticsButton
@onready var _back_button: Button = $Panel/BackButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Start/Pause'dan açıldığında dünya duraklı olsa da çalışsın
	visible = false
	_apply_style()
	_sound_button.pressed.connect(_on_sound_pressed)
	_haptics_button.pressed.connect(_on_haptics_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	GameFlow.state_changed.connect(_on_state_changed)

func _on_state_changed(new_state: int) -> void:
	visible = new_state == GameFlow.State.SETTINGS
	if visible:
		_refresh_labels()

func _refresh_labels() -> void:
	_sound_button.text = "ON" if AudioManager.sound_enabled else "OFF"
	_haptics_button.text = "ON" if AudioManager.haptics_enabled else "OFF"

func _on_sound_pressed() -> void:
	AudioManager.set_sound_enabled(not AudioManager.sound_enabled)
	AudioManager.play_ui_tick()
	_refresh_labels()

func _on_haptics_pressed() -> void:
	AudioManager.set_haptics_enabled(not AudioManager.haptics_enabled)
	AudioManager.play_ui_tick()
	_refresh_labels()

func _on_back_pressed() -> void:
	AudioManager.play_ui_tick()
	GameFlow.close_settings()

func _apply_style() -> void:
	$Panel.add_theme_stylebox_override("panel", HUDTheme.make_summary_panel_stylebox())
	HUDTheme.style_label(_title_label, HUDTheme.make_spaced_variation(HUDTheme.FONT_UI, 3), 20, HUDTheme.MINT_ACCENT)
	_title_label.text = "SETTINGS"
	HUDTheme.style_label(_sound_caption, HUDTheme.FONT_UI, 16, HUDTheme.TEXT_PRIMARY)
	_sound_caption.text = "SOUND"
	HUDTheme.style_label(_haptics_caption, HUDTheme.FONT_UI, 16, HUDTheme.TEXT_PRIMARY)
	_haptics_caption.text = "HAPTICS"
	_style_button(_sound_button)
	_style_button(_haptics_button)
	_style_button(_back_button)
	_back_button.text = "BACK"

func _style_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", HUDTheme.make_button_stylebox(false))
	button.add_theme_stylebox_override("hover", HUDTheme.make_button_stylebox(false))
	button.add_theme_stylebox_override("pressed", HUDTheme.make_button_stylebox(true))
	button.add_theme_stylebox_override("focus", HUDTheme.make_button_stylebox(false))
	button.add_theme_color_override("font_color", HUDTheme.BUTTON_TEXT_DARK)
	button.add_theme_color_override("font_hover_color", HUDTheme.BUTTON_TEXT_DARK)
	button.add_theme_color_override("font_pressed_color", HUDTheme.BUTTON_TEXT_DARK)
	button.add_theme_font_override("font", HUDTheme.FONT_UI)
	button.add_theme_font_size_override("font_size", 18)
