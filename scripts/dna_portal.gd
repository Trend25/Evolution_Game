extends Node2D
class_name DnaPortal
## DnaPortal -- gameplay/core-loop-v4 V02 düzeltme turu (kullanıcı: "Üstteki
## halka/debug görünümünü kaldır; DNA kapsülü portalını ... uygula"). NOT:
## önceki teslimattaki "halka/debug görünüm" aslında geçici QA video
## çekim script'inin (silinmiş qa_v5_lab_slice_video.gd) kendi dokunma
## göstergesiydi -- gerçek oyunda hiç var olmayan bir hata idi. Ama bu
## düzeltme SIRASINDA gerçek eksiklik de netleşti: aim sırasında GÖRÜNEN
## geçici ışık huzmesi/parıltının (drop_aim_guide.gd _draw_portal_glow)
## DIŞINDA, Spawner'ın konumunu SÜREKLİ işaretleyen KALICI bir görsel
## öğe hiç yoktu -- boş fanusun üst kısmı aim yokken tamamen çıplaktı.
##
## Bu script Spawner'ın ÇOCUĞU olarak, KÜÇÜK ve yumuşakça "nefes alan" bir
## DNA kapsülü (hap) siluetini HER ZAMAN (aim olsun olmasın) çizer --
## Spawner yatayda hareket ettikçe otomatik onunla birlikte kayar. SADECE
## GÖRSEL: bu script'te CollisionShape/RigidBody/Area YOK, yalnızca
## _draw()+_process() ile çizer, drop/cooldown/spawn/aim mantığının HİÇBİR
## parçasına dokunmaz. SADECE lab modunda (GrayboxConfig.ENABLED and
## LAB_VISUALS_ENABLED) etkindir -- üretim/graybox davranışını etkilemez.

const CAPSULE_WIDTH: float = 20.0
const CAPSULE_HEIGHT: float = 38.0
# DÜZELTME (V02 ikinci düzeltme turu -- kullanıcı: "Portalı HUD'dan biraz
# aşağı indir; NEXT paneliyle görsel olarak birleşmemeli"): artık TEK,
# merkezi bir kaynaktan (GrayboxConfig.PORTAL_ANCHOR_Y_OFFSET) okunuyor --
# aynı sabit drop_aim_guide.gd'nin ışık kuyruğu anchor'ı ve drop_feedback_
# manager.gd'nin release-beam anchor'ı tarafından da paylaşılıyor, üçü hep
# AYNI noktayı işaret etsin diye (bkz. o dosyalardaki notlar). SADECE
# GÖRSEL bir konum kaydırması -- Spawner'ın GERÇEK (fizik/drop) y=100
# konumuna HİÇ dokunulmadı.
const PULSE_SPEED: float = 1.6

const CORE_COLOR: Color = Color(0.62, 0.95, 0.90, 0.90)
const SHELL_COLOR: Color = Color(0.45, 0.82, 0.92, 0.40)
const SHELL_OUTLINE_COLOR: Color = Color(0.72, 0.98, 0.94, 0.55)
const GLOW_COLOR: Color = Color(0.55, 0.92, 0.86, 0.14)
const HELIX_COLOR: Color = Color(0.85, 0.98, 0.95, 0.35)

var _time: float = 0.0
var _lab_mode: bool = false

func _ready() -> void:
	z_index = 1  # organizmaların (varsayılan 0) hemen üstünde, HUD katmanının (CanvasLayer) çok altında
	_lab_mode = GrayboxConfig.ENABLED and GrayboxConfig.LAB_VISUALS_ENABLED
	visible = _lab_mode
	set_process(_lab_mode)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	if not _lab_mode:
		return
	var pulse: float = 0.5 + 0.5 * sin(_time * PULSE_SPEED)
	var center: Vector2 = Vector2(0.0, GrayboxConfig.PORTAL_ANCHOR_Y_OFFSET)

	# Dış yumuşak parıltı -- "nefes alan" his, aynı banded-alpha tekniği
	# (bkz. drop_aim_guide.gd _draw_portal_glow) blur/shader olmadan.
	var glow_bands: int = 5
	var glow_radius: float = CAPSULE_WIDTH * (1.1 + pulse * 0.4)
	for i in range(glow_bands):
		var t: float = float(i) / float(glow_bands)
		var r: float = glow_radius * (1.0 - t)
		var a: float = GLOW_COLOR.a * (t + 0.15)
		draw_circle(center, r, Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, a))

	# Kapsül gövdesi -- dikey hap şekli (iki yarım daire + dikdörtgen gövde).
	var half_w: float = CAPSULE_WIDTH * 0.5
	var half_h: float = CAPSULE_HEIGHT * 0.5 - half_w
	draw_rect(Rect2(center + Vector2(-half_w, -half_h), Vector2(CAPSULE_WIDTH, (CAPSULE_HEIGHT - CAPSULE_WIDTH))), SHELL_COLOR, true)
	draw_circle(center + Vector2(0.0, -half_h), half_w, SHELL_COLOR)
	draw_circle(center + Vector2(0.0, half_h), half_w, SHELL_COLOR)
	# İnce dış hat -- kapsülün "cam/kristal" hissini netleştirir.
	draw_arc(center + Vector2(0.0, -half_h), half_w, PI, TAU, 16, SHELL_OUTLINE_COLOR, 1.4, true)
	draw_arc(center + Vector2(0.0, half_h), half_w, 0.0, PI, 16, SHELL_OUTLINE_COLOR, 1.4, true)
	draw_line(center + Vector2(-half_w, -half_h), center + Vector2(-half_w, half_h), SHELL_OUTLINE_COLOR, 1.4)
	draw_line(center + Vector2(half_w, -half_h), center + Vector2(half_w, half_h), SHELL_OUTLINE_COLOR, 1.4)

	# İçindeki basit DNA-sarmal ipuçları -- iki dalgalı çizgi (gerçek anlamda
	# bir helix, ama en az geometriyle -- tamamen dekoratif küçük bir detay).
	var strand_segments: int = 10
	for i in range(strand_segments):
		var t0: float = float(i) / float(strand_segments)
		var t1: float = float(i + 1) / float(strand_segments)
		var y0: float = lerp(-half_h * 0.85, half_h * 0.85, t0)
		var y1: float = lerp(-half_h * 0.85, half_h * 0.85, t1)
		var x0: float = sin(t0 * TAU * 1.4 + _time * 1.2) * half_w * 0.42
		var x1: float = sin(t1 * TAU * 1.4 + _time * 1.2) * half_w * 0.42
		draw_line(center + Vector2(x0, y0), center + Vector2(x1, y1), HELIX_COLOR, 1.2, true)
		draw_line(center + Vector2(-x0, y0), center + Vector2(-x1, y1), HELIX_COLOR, 1.2, true)

	# Parlayan çekirdek noktası -- pulse ile parlaklık artar/azalır.
	var core_alpha: float = CORE_COLOR.a * (0.55 + pulse * 0.45)
	draw_circle(center, half_w * 0.34, Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, core_alpha))
