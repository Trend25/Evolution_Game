extends Button
class_name PauseButton
## PauseButton -- feat: add start pause and how-to-play flow. Oynanış
## sırasında erişilebilir, küçük ve sade duraklat düğmesi. NEXT/Score/Lives
## panellerinin ölçülerine HİÇ DOKUNMAZ -- HUD panel satırının TAMAMEN
## DIŞINDA, ekranın sağ ALT köşesinde, kendi başına bir kontrol (Main.tscn:
## UI_Canvas altında, HUDRoot/panellerin KARDEŞİ, onlardan bağımsız). HUD
## katmanında (CanvasLayer=10) olduğundan tank dolsa bile dünya-uzayı
## organizmalarının HER ZAMAN üstünde kalır.
##
## Yalnızca GameFlow.State.PLAYING iken görünür -- "Game Over sırasında
## Pause açılamıyor" kuralı BÖYLECE doğal olarak sağlanır: Game Over
## durumunda bu düğme zaten gizli ve tıklanamaz.

const LOGICAL_WIDTH: float = 720.0   # Main.tscn/hud_root.gd'nin ZATEN varsaydığı sabit mantıksal genişlik
const BUTTON_SIZE: float = 44.0      # min. dokunma hedefi
const EDGE_MARGIN: float = 16.0

func _ready() -> void:
	text = "II"
	custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_style()
	_position_button()
	get_tree().root.size_changed.connect(_position_button)  # gameplay/core-loop-v4 V02 düzeltmesi (bkz. aşağı) -- diğer HUD parçalarıyla AYNI desen
	pressed.connect(_on_pressed)
	GameFlow.state_changed.connect(_on_state_changed)
	visible = GameFlow.current_state == GameFlow.State.PLAYING

func _on_state_changed(new_state: int) -> void:
	visible = new_state == GameFlow.State.PLAYING

func _on_pressed() -> void:
	GameFlow.open_pause()

## Sağ ALT köşe -- SafeArea kenar payının hemen içinde. HUD üst panel
## satırından (LeftPanel/NextPanel/ScorePanel) TAMAMEN AYRI bir bölgede
## olduğundan onların konum/boyutuna asla dokunmaz.
##
## DÜZELTME (2026-09-24, V02 vertical slice -- kullanıcı: "Pause düğmesini
## HUD düzenine geri bağla"): KÖK NEDEN -- dikey konum SABİT KODLANMIŞ bir
## LOGICAL_HEIGHT=1280 sabitine göre hesaplanıyordu; 720x1650 hedef
## çözünürlükte (bkz. MAX_PLAY_HEIGHT notu, graybox_config.gd) bu, düğmeyi
## gerçek ekran altından ~370px YUKARIDA, boş alanın ortasında "asılı" bırakıyordu.
## Artık background_fill.gd/environment_bounds.gd ile AYNI desenle gerçek
## viewport yüksekliği ÇALIŞMA ZAMANINDA okunur ve resize'da yeniden hesaplanır.
func _position_button() -> void:
	var margins: Dictionary = SafeArea.get_margins()
	var right: float = max(float(margins.get("right", 16.0)), 12.0)
	var bottom: float = float(margins.get("bottom", 0.0))
	var logical_size: Vector2 = get_viewport().get_visible_rect().size
	var logical_height: float = max(1280.0, logical_size.y)  # tasarım yüksekliğinin altına asla küçülme
	position = Vector2(
		LOGICAL_WIDTH - right - EDGE_MARGIN - BUTTON_SIZE,
		logical_height - bottom - EDGE_MARGIN - BUTTON_SIZE,
	)

func _apply_style() -> void:
	add_theme_stylebox_override("normal", HUDTheme.make_button_stylebox(false))
	add_theme_stylebox_override("hover", HUDTheme.make_button_stylebox(false))
	add_theme_stylebox_override("pressed", HUDTheme.make_button_stylebox(true))
	add_theme_stylebox_override("focus", HUDTheme.make_button_stylebox(false))
	add_theme_color_override("font_color", HUDTheme.BUTTON_TEXT_DARK)
	add_theme_color_override("font_hover_color", HUDTheme.BUTTON_TEXT_DARK)
	add_theme_color_override("font_pressed_color", HUDTheme.BUTTON_TEXT_DARK)
	add_theme_font_override("font", HUDTheme.FONT_UI)
	add_theme_font_size_override("font_size", 16)
