extends Node2D
class_name DropAimGuide
## DropAimGuide -- feat: add drop aiming and landing feedback. Oyuncu
## bırakma konumunu SEÇERKEN (Spawner sürüklenirken) fanusun tabanına kadar
## uzanan ince, yarı şeffaf bir dikey rehber çizgi gösterir. SADECE GÖRSEL:
## collision/fizik/spawn/cooldown/bonus mantığına HİÇBİR şekilde katılmaz.
##
## Spawner'ın KENDİ çocuğu olarak durur (Main.tscn) -- bu yüzden x konumunu
## AYRICA takip etmeye gerek yoktur: Spawner zaten yatay fanus sınırları
## içinde (left_bound_x/right_bound_x + HORIZONTAL_MARGIN) hareket eder,
## rehber otomatik olarak aynı x'te kalır ve asla ekran kenarlarına taşmaz.
##
## z_index=3 ile organizmaların ÜSTÜNDE (yığın arkasında kaybolmasın diye)
## ama HUD (UI_Canvas, CanvasLayer layer=10) HER ZAMAN üstünde kalır çünkü
## bu düğüm ayrı, world-space bir CanvasLayer'dadır (layer=0, varsayılan).

const LINE_COLOR: Color = Color("#8FE3D2")  # merge_burst.gd NORMAL_RING_COLOR ile aynı yumuşak mint/teal
const LINE_ALPHA: float = 0.38              # düşük opaklık -- çocuksu parlak/kalın olmasın
const LINE_WIDTH: float = 1.6               # ince
const FADE_IN_SECONDS: float = 0.12

# Main.tscn: Environment/Floor üst yüzeyi global y=1260, Spawner global y=100
# (bkz. merge_burst.gd/qa_driver.gd'deki FLOOR_TOP_Y sabiti ile aynı taban).
# Spawner'ın YEREL uzayında bu yüzden çizgi 0'dan 1160'a kadar uzanır.
const LINE_BOTTOM_Y: float = 1160.0

var _fade_tween: Tween = null

func _ready() -> void:
	z_index = 3
	visible = false
	modulate.a = 0.0
	queue_redraw()
	var spawner: Node = get_parent()
	if spawner != null and spawner.has_signal("drag_state_changed"):
		spawner.drag_state_changed.connect(_on_drag_state_changed)
	# UC-01 kapsamı dışında bir güvenlik önlemi: oyuncu tam sürükleme
	# ORTASINDAYKEN Game Over/Retry tetiklenirse (input artık gelmediği için
	# Spawner bir daha drag_state_changed(false) YAYINLAYAMAZ) rehberin
	# ekranda asılı kalmaması için doğrudan burada da zorla gizleniyor.
	GameManager.game_over_ready.connect(_on_force_hide)
	GameManager.run_reset.connect(_on_force_hide)

func _on_drag_state_changed(is_dragging: bool) -> void:
	if is_dragging:
		_show_with_fade_in()
	else:
		# Kullanıcı talebi: "Canlı bırakıldığında guide hemen kaybolsun" --
		# fade YOK, tween ANINDA öldürülür ve çizgi o karede gizlenir.
		_force_hide_now()

func _show_with_fade_in() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	visible = true
	modulate.a = 0.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_SECONDS)

func _force_hide_now() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	visible = false
	modulate.a = 0.0

## NOT: bu fonksiyon hem game_over_ready(final_stats: Dictionary) hem de
## run_reset() (parametresiz) sinyaline BAĞLI -- Godot'ta bağlı callable'in
## parametre sayısı sinyalin gönderdiği argüman sayısıyla TAM eşleşmezse
## çağrı hiç YAPILMAZ (bkz. merge_burst/chain_toast'ta bulunan ve düzeltilen
## aynı sınıf hata). Varsayılan değerli opsiyonel parametre iki sinyal
## imzasıyla da uyumlu olur.
func _on_force_hide(_final_stats: Dictionary = {}) -> void:
	_force_hide_now()

func _draw() -> void:
	draw_line(Vector2.ZERO, Vector2(0.0, LINE_BOTTOM_Y), Color(LINE_COLOR.r, LINE_COLOR.g, LINE_COLOR.b, LINE_ALPHA), LINE_WIDTH, true)
