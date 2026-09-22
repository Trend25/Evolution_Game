extends CanvasLayer
class_name HowToPlayPanel
## HowToPlayPanel -- feat: add start pause and how-to-play flow. Tek, kısa
## yardım paneli; GameFlow.State.HOW_TO_PLAY iken görünür. Adımlar GERÇEK
## oynanış mekaniğine dayanır (bkz. spawner.gd'nin gerçek sürükle/bırak
## girdisi: _unhandled_input -> _set_dragging/_handle_drag, ve
## game_manager.gd/organism.gd'nin merge + bonus + split-fish mantığı) --
## hayali kontrol ANLATILMAZ. Kapanınca GameFlow açıldığı ekrana (Start ya
## da Pause) döner; burası bunu bilmez, yalnızca GameFlow.close_how_to_play()
## çağırır -- arka planda oyunu asla yeniden başlatmaz.

@onready var _title_label: Label = $Panel/TitleLabel
@onready var _steps_label: Label = $Panel/StepsLabel
@onready var _close_button: Button = $Panel/CloseButton

const STEPS_TEXT: String = "1. Drag anywhere to aim, release to drop the creature.\n2. Merge two matching creatures to evolve them into the next stage.\n3. Combine both halves of a split fish to complete it.\n4. Keep the tank clear: don't let creatures pile up past the top."

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Start/Pause'dan açıldığında dünya duraklı olsa da çalışsın
	visible = false
	_apply_style()
	_close_button.pressed.connect(_on_close_pressed)
	GameFlow.state_changed.connect(_on_state_changed)

func _on_state_changed(new_state: int) -> void:
	visible = new_state == GameFlow.State.HOW_TO_PLAY

func _on_close_pressed() -> void:
	GameFlow.close_how_to_play()

func _apply_style() -> void:
	$Panel.add_theme_stylebox_override("panel", HUDTheme.make_summary_panel_stylebox())
	HUDTheme.style_label(_title_label, HUDTheme.make_spaced_variation(HUDTheme.FONT_UI, 3), 20, HUDTheme.MINT_ACCENT)
	_title_label.text = "HOW TO PLAY"
	HUDTheme.style_label(_steps_label, HUDTheme.FONT_UI, 16, HUDTheme.TEXT_PRIMARY)
	_steps_label.text = STEPS_TEXT

	_close_button.text = "CLOSE"
	_close_button.add_theme_stylebox_override("normal", HUDTheme.make_button_stylebox(false))
	_close_button.add_theme_stylebox_override("hover", HUDTheme.make_button_stylebox(false))
	_close_button.add_theme_stylebox_override("pressed", HUDTheme.make_button_stylebox(true))
	_close_button.add_theme_stylebox_override("focus", HUDTheme.make_button_stylebox(false))
	_close_button.add_theme_color_override("font_color", HUDTheme.BUTTON_TEXT_DARK)
	_close_button.add_theme_color_override("font_hover_color", HUDTheme.BUTTON_TEXT_DARK)
	_close_button.add_theme_color_override("font_pressed_color", HUDTheme.BUTTON_TEXT_DARK)
	_close_button.add_theme_font_override("font", HUDTheme.FONT_UI)
	_close_button.add_theme_font_size_override("font_size", 18)
