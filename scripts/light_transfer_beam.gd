extends Node2D
class_name LightTransferBeam
## LightTransferBeam -- gameplay/core-loop-v4 "Evrim Laboratuvarı" V02
## vertical slice (madde 3 -- kullanıcı: "canlı, ONUNLA BİRLİKTE HAREKET EDEN
## kısa bir ışık huzmesi içinde düşsün; ışık 0.4-0.7s içinde sönsün; ışık
## FİZİĞİ/collision/hızı/iniş konumunu ASLA etkilemesin"). SADECE GÖRSEL:
## _process()'te düşen GERÇEK organizmanın global_position'ını her karede
## OKUYUP kendi konumunu ona eşitler -- organizmanın transform/velocity/
## collision'ına HİÇBİR ŞEKİLDE YAZMAZ (tek yönlü, salt-okunur takip).
## DropFeedbackManager tarafından her drop'ta (yalnızca bu dilimin kapsadığı
## aşamalarda) dinamik olarak instantiate edilir; kendi ömür-süresi tween'i
## bitince kendini queue_free() ile kaldırır.

# merge_burst.gd/drop_entry_pop.gd ile AYNI normal/bonus renk paletinden --
# yeni bir renk icat edilmedi, mevcut mint/amber dilinin devamı.
const NORMAL_COLOR: Color = Color("#8FE3D2")
const BONUS_COLOR: Color = Color("#F6D583")
# DÜZELTME (V02 düzeltme turu -- kullanıcı: "ışıklı iniş izi"nin bir
# TEKİL, durağan görüntüde (screenshot) okunacak kadar belirgin olması):
# önceki MAX_ALPHA=0.42 tek başına hareket halindeyken fark ediliyordu ama
# donmuş bir karede zayıf kalıyordu. Bant alfası + parlak ince bir çekirdek
# çizgisi eklenerek iz büyütülmeden (BEAM_UP_LENGTH_MULT/süre AYNI --
# fizik/collision/timing'e dokunulmadı) daha KONTRASTLI hale getirildi.
const MAX_ALPHA: float = 0.62
const CORE_ALPHA: float = 0.85

# DÜZELTME (V02 İKİNCİ düzeltme turu -- kullanıcı: "Portal ile düşen canlı
# arasında 0.4-0.7 saniye görünen, hareket yönünü açıkça anlatan dar bir
# ışık kuyruğu olmalı"): eski tasarım, organizmanın YARIÇAPINA oranlı SABİT
# kısa bir "sütun" çiziyordu -- portalla GÖRSEL bir bağlantısı yoktu. Artık
# huzme, SABİT portal konumundan (dünya uzayında, drop anında yakalanır)
# düşmekte olan organizmanın GÜNCEL konumuna kadar uzanan, organizma
# uzaklaştıkça BÜYÜYEN gerçek bir "kuyruk" çiziyor -- yön (yukarı=portal,
# aşağı=canlı) DÜŞME YÖNÜYLE bire bir örtüşüyor. Fizik/collision/süre/
# timing'e HİÇ dokunulmadı, sadece NASIL çizildiği değişti.
const BEAM_WIDTH_MULT: float = 0.55      # organizmanın yarıçapına oranlı taban genişlik
const CORE_WIDTH_MULT: float = 0.22      # parlak ince çekirdek çizgisi
const BANDS: int = 7
const FADE_IN_FRACTION: float = 0.12   # toplam sürenin ilk %12'si -- ani değil ama hızlı bir "yanma" hissi

var _target: Node2D = null
var _radius: float = 40.0
var _color: Color = NORMAL_COLOR
var _envelope_alpha: float = 0.0
var _portal_anchor_world: Vector2 = Vector2.ZERO

## world_position: ilk kare çizilmeden önce yanlış yerde parlamasın diye
## başlangıç konumu (Spawner/organism_dropped sinyalinden gelen GERÇEK drop
## konumu, HUD altına klemplenmiş -- DropFeedbackManager _visible_min_y ile
## AYNI hesap). target: takip edilecek GERÇEK Organism -- geçersiz/queue_free
## olursa (ör. çok hızlı bir merge) sessizce takibi bırakır, son konumunda
## sönerek kaybolur. portal_anchor_world: DnaPortal'ın GÖRSEL konumuyla AYNI
## noktayı işaret eden, drop anında SABİTLENEN dünya konumu (bkz.
## drop_feedback_manager.gd) -- kuyruğun "kaynağı".
func start(world_position: Vector2, target: Node2D, radius: float, is_bonus: bool, portal_anchor_world: Vector2) -> void:
	global_position = world_position
	_target = target
	_radius = radius
	_color = BONUS_COLOR if is_bonus else NORMAL_COLOR
	_portal_anchor_world = portal_anchor_world
	z_index = 2  # DropEntryPop (z_index=4)/MergeBurst (5)'in ALTINDA, organizmaların biraz üstünde

	var duration: float = randf_range(GrayboxConfig.TRANSFER_LIGHT_MIN_DURATION, GrayboxConfig.TRANSFER_LIGHT_MAX_DURATION)
	var fade_in_time: float = duration * FADE_IN_FRACTION
	var fade_out_time: float = duration - fade_in_time
	var tw: Tween = create_tween()
	tw.tween_method(_set_envelope_alpha, 0.0, 1.0, fade_in_time)
	tw.tween_method(_set_envelope_alpha, 1.0, 0.0, fade_out_time).set_ease(Tween.EASE_IN)
	tw.finished.connect(queue_free)
	queue_redraw()

func _process(_delta: float) -> void:
	if is_instance_valid(_target):
		global_position = _target.global_position
	queue_redraw()  # kuyruk uzunluğu her karede DEĞİŞİR (organizma uzaklaştıkça), sabit tween'den bağımsız yeniden çizim gerekir

func _set_envelope_alpha(value: float) -> void:
	_envelope_alpha = value
	queue_redraw()

## Portaldan (SABİT dünya konumu) organizmanın GÜNCEL konumuna (Vector2.ZERO,
## bu düğüm _process'te organizmayı takip ettiğinden) kadar uzanan, giderek
## kalınlaşan/parlaklaşan bir kuyruk -- yön netliği için taban (organizma
## ucu) GENİŞ/PARLAK, kaynak (portal ucu) İNCE/SOLUK. Yumuşak sönümleme,
## çok sayıda ince banda bölünüp azalan alfa verilerek TAKLİT edilir (blur/
## shader olmadan) -- aynı teknik ailesi drop_aim_guide.gd'de de kullanılır.
func _draw() -> void:
	if _envelope_alpha <= 0.001:
		return
	var local_anchor: Vector2 = to_local(_portal_anchor_world)
	if local_anchor.length() < 1.0:
		return  # organizma tam portal noktasındaysa (ör. ilk kare) çizecek bir kuyruk yok
	var half_width: float = _radius * BEAM_WIDTH_MULT
	for i in range(BANDS):
		var t0: float = float(i) / float(BANDS)        # 0 = portalda (kaynak), 1'e yakın = organizmada
		var t1: float = float(i + 1) / float(BANDS)
		var p0: Vector2 = local_anchor.lerp(Vector2.ZERO, t0)
		var p1: Vector2 = local_anchor.lerp(Vector2.ZERO, t1)
		var band_alpha: float = MAX_ALPHA * _envelope_alpha * t1 * t1
		if band_alpha <= 0.004:
			continue
		var w: float = half_width * (0.25 + 0.85 * t1)
		draw_line(p0, p1, Color(_color.r, _color.g, _color.b, band_alpha), w, true)

	# Parlak ince çekirdek çizgisi -- huzmenin durağan bir karede de net
	# görünmesi için (kullanıcı: "hareket yönünü açıkça anlatan dar bir ışık
	# kuyruğu"). Uzunluk/süre/fizik AYNI kalır -- sadece görsel kontrast.
	var core_alpha: float = CORE_ALPHA * _envelope_alpha
	if core_alpha > 0.004:
		var near_white: Color = _color.lerp(Color(1.0, 1.0, 1.0), 0.55)
		draw_line(local_anchor, Vector2.ZERO, Color(near_white.r, near_white.g, near_white.b, core_alpha), half_width * CORE_WIDTH_MULT, true)

	# Organizmanın etrafında küçük bir "varış" parıltısı -- kuyruğun ucunun
	# nereye bağlandığını netleştirir.
	var glow_alpha: float = MAX_ALPHA * 0.55 * _envelope_alpha
	if glow_alpha > 0.004:
		draw_circle(Vector2.ZERO, _radius * 0.5, Color(_color.r, _color.g, _color.b, glow_alpha))
