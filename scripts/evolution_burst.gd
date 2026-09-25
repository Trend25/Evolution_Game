extends Node2D
class_name EvolutionBurst
## EvolutionBurst -- gameplay/core-loop-v4 "Evrim Laboratuvarı" V02 İKİNCİ
## düzeltme turu (kullanıcı madde 4): "Birleşme anını ödül haline getir: iki
## canlının merkeze çekilmesi → kısa DNA sarmalı → ışık patlaması → yeni
## canlının pop animasyonu. Dönüşüm 0.6–0.9 saniyede okunmalı."
##
## "Merkeze çekilme" kısmı ZATEN organism.gd/_integrate_forces'taki merge-
## assist fiziği tarafından, çarpışmadan ÖNCE gerçek zamanlı olarak sağlanıyor
## (bkz. GrayboxConfig.MERGE_ASSIST_ACCEL) -- bu script'e o kısmı TEKRAR
## eklemek fizik sistemini iki kez etkiler ve kararsızlaştırabilir, bu yüzden
## KASITLI OLARAK dokunulmadı. Bu script SADECE merge ANINDAN (contact_point,
## iki eski canlı queue_free() olduktan hemen sonra) İTİBAREN oynayan iki
## fazlı SALT GÖRSEL bir efekttir:
##   Faz A (0 -> HELIX_DURATION saniye): kısa, içe doğru büzülen/dönen bir
##     DNA çift-sarmalı (dna_portal.gd'nin KALICI helix ipucuyla AYNI çizim
##     ailesi, ama burada GEÇİCİ ve ANİMASYONLU).
##   Faz B (helix'in sonuna hafifçe bindirilerek): merkezden dışa yayılan,
##     hedef aşamanın rengine boyanmış parlak bir ışık patlaması + birkaç
##     yön ışını -- yeni canlının (organism_visual.gd _play_spawn_pop,
##     born_from_evolution=true dalı, GrayboxConfig.EVOLUTION_TRANSFORM_
##     DURATION=0.6s) TAM O SIRADA oynayan büyüme animasyonunu "ortaya çıkarır".
##
## Toplam süre TOTAL_DURATION -- kullanıcının istediği 0.6-0.9s penceresi
## içinde SABİT. Collision/fizik/skor/XP/spawn mantığına HİÇBİR şekilde
## katılmaz (bu dosyada CollisionShape/RigidBody/Area yok, yalnızca _draw()+
## Tween) -- merge_feedback_manager.gd tarafından, YALNIZCA gerçek bir evrim
## (üst aşamaya geçiş) gerçekleştiğinde, mevcut MergeBurst'e (her merge'de
## değişmeden çalışmaya devam eder) EK olarak instantiate edilir.

const TOTAL_DURATION: float = 0.72  # 0.6-0.9s penceresinin ortasına yakın
const HELIX_DURATION: float = 0.30
const FLASH_START_FRACTION: float = 0.62  # helix'in son ~%38'iyle flaş hafifçe ÇAKIŞIR (ani kesişme yerine yumuşak devir)

const HELIX_START_RADIUS: float = 30.0
const HELIX_STRAND_SEGMENTS: int = 14
const HELIX_TURNS: float = 2.2
const HELIX_SPIN_SPEED: float = 10.0  # radyan/saniye -- "içe doğru dönerek büzülme" hissi
const HELIX_COLOR: Color = Color(0.90, 0.99, 0.97, 1.0)  # dna_portal.gd HELIX_COLOR ailesiyle aynı dil, opak taban (alfa ayrı çarpanla uygulanır)

const FLASH_MAX_RADIUS_MULT: float = 1.35  # hedef organizmanın yarıçapına oranlı
const FLASH_RAY_COUNT: int = 8
const FLASH_RAY_LENGTH_MULT: float = 1.9
const BONUS_ACCENT: Color = Color("#F6D583")  # mevcut altın bonus rengiyle uyumlu (bkz. light_transfer_beam.gd/merge_burst.gd)

var _t: float = 0.0
var _radius: float = 60.0
var _target_color: Color = Color.WHITE
var _is_bonus: bool = false

## world_position: contact_point (iki eski canlının orta noktası -- merge_
## feedback_manager.gd'nin _spawn_burst() için ZATEN kullandığı AYNI değer).
## target_radius: YENİ (evrilecek) aşamanın GrayboxConfig.effective_radius'u
## -- flaşın boyutu bu aşamaya göre ölçeklenir. target_color: yeni aşamanın
## GrayboxConfig.STAGE_COLORS rengi -- Virüs/Bakteri/Tek Hücreli'nin artık
## birbirinden farklı siluetleriyle (organism_visual.gd) AYNI kimliği taşır.
func start(world_position: Vector2, target_radius: float, target_color: Color, is_bonus: bool) -> void:
	global_position = world_position
	z_index = 6  # MergeBurst (5)/DropEntryPop (4)'ün ÜSTÜNDE -- "ödül anı" en belirgin katman olsun, ama HUD CanvasLayer'ının (her zaman üstte) asla üstüne geçemez
	_radius = max(target_radius, 20.0)
	_target_color = target_color
	_is_bonus = is_bonus

	var tw: Tween = create_tween()
	tw.tween_method(_set_t, 0.0, 1.0, TOTAL_DURATION).set_trans(Tween.TRANS_LINEAR)
	tw.finished.connect(queue_free)
	queue_redraw()

func _set_t(value: float) -> void:
	_t = value * TOTAL_DURATION  # tween_method 0..1 aralığında ilerliyor -- _draw()'daki tüm süre sabitleri SANİYE cinsinden, burada geri ölçekleniyor
	queue_redraw()

func _draw() -> void:
	_draw_helix()
	_draw_flash()

## Faz A: iki dalgalı şerit, merkeze doğru büzülürken (yarıçap küçülür) hızla
## döner -- dna_portal.gd'nin kalıcı (sabit hızda) helix ipucundan farklı
## olarak burada HEM yarıçap HEM görünürlük zamanla değişir, "sarmalın
## kendini merkeze topladığı" kısa bir an hissi verir. Az sayıda segment
## (HELIX_STRAND_SEGMENTS) -- kullanıcı uyarısı "okunabilirliği bozacak
## kalabalık yaratma" burada da geçerli.
func _draw_helix() -> void:
	var t_a: float = clamp(_t / HELIX_DURATION, 0.0, 1.0)
	if _t > HELIX_DURATION * 1.05:
		return  # tamamen bitti, gereksiz çizimden kaçın
	# alfa: ilk %15 hızlı beliriş, son %35 büzülürken sönme
	var alpha: float
	if t_a < 0.15:
		alpha = t_a / 0.15
	else:
		alpha = 1.0 - clamp((t_a - 0.65) / 0.35, 0.0, 1.0)
	if alpha <= 0.01:
		return
	var cur_radius: float = HELIX_START_RADIUS * (1.0 - t_a * 0.92)  # asla tam sıfıra inmesin -- son karede de ince bir iz kalsın
	var spin: float = _t * HELIX_SPIN_SPEED
	var col: Color = HELIX_COLOR.lerp(_target_color, 0.35)
	for i in range(HELIX_STRAND_SEGMENTS):
		var t0: float = float(i) / float(HELIX_STRAND_SEGMENTS)
		var t1: float = float(i + 1) / float(HELIX_STRAND_SEGMENTS)
		var a0: float = t0 * TAU * HELIX_TURNS + spin
		var a1: float = t1 * TAU * HELIX_TURNS + spin
		var y0: float = lerp(-cur_radius, cur_radius, t0)
		var y1: float = lerp(-cur_radius, cur_radius, t1)
		var x0: float = sin(a0) * cur_radius * 0.55
		var x1: float = sin(a1) * cur_radius * 0.55
		var seg_alpha: float = alpha * (0.35 + 0.65 * t0)  # merkeze yakın segmentler biraz daha parlak
		draw_line(Vector2(x0, y0), Vector2(x1, y1), Color(col.r, col.g, col.b, seg_alpha), 2.2, true)
		draw_line(Vector2(-x0, y0), Vector2(-x1, y1), Color(col.r, col.g, col.b, seg_alpha), 2.2, true)
		# iki şerit arasında ince "baz çifti" çizgileri -- gerçek bir DNA
		# görselinin en tanınabilir ipucu, ama az sayıda (kalabalık yaratma)
		if i % 3 == 0:
			draw_line(Vector2(x0, y0), Vector2(-x0, y0), Color(col.r, col.g, col.b, seg_alpha * 0.5), 1.2, true)

## Faz B: merkezden dışa yayılan, hedef aşamanın rengine boyanmış bir flaş --
## çekirdek neredeyse beyaz, dışa doğru hedef renge ve sönen alfaya geçer.
## Birkaç kısa yön ışını (FLASH_RAY_COUNT) net bir "patlama" hissi verir --
## MergeBurst'ün sakin, tek renkli halkasından KASITLI olarak daha belirgin
## (kullanıcı: "ışık patlaması", sıradan bir merge juice'i değil).
func _draw_flash() -> void:
	var flash_start: float = HELIX_DURATION * FLASH_START_FRACTION
	if _t < flash_start:
		return
	var t_b: float = clamp((_t - flash_start) / (TOTAL_DURATION - flash_start), 0.0, 1.0)
	var ease_out: float = 1.0 - pow(1.0 - t_b, 2.0)  # hızlı büyüme, yumuşak sönme
	var alpha: float = (1.0 - t_b * t_b) * (1.0 if _is_bonus else 0.92)
	if alpha <= 0.01:
		return
	var accent: Color = _target_color.lerp(BONUS_ACCENT, 0.5) if _is_bonus else _target_color
	var core: Color = accent.lerp(Color.WHITE, 0.6)
	var max_r: float = _radius * FLASH_MAX_RADIUS_MULT
	var cur_r: float = max_r * (0.12 + 0.88 * ease_out)

	# yumuşak dış parıltı -- banded-alpha tekniği (blur/shader olmadan, bkz.
	# drop_aim_guide.gd/dna_portal.gd'de kullanılan AYNI teknik ailesi)
	var glow_bands: int = 4
	for i in range(glow_bands):
		var bt: float = float(i) / float(glow_bands)
		var r: float = cur_r * (1.0 - bt * 0.55)
		var a: float = alpha * (0.10 + bt * 0.10)
		draw_circle(Vector2.ZERO, r, Color(accent.r, accent.g, accent.b, a))

	# parlak çekirdek
	draw_circle(Vector2.ZERO, cur_r * 0.32, Color(core.r, core.g, core.b, alpha * 0.9))

	# yön ışınları -- "patlama" okunabilirliğini artırır, ama sadece
	# FLASH_RAY_COUNT kadar (kalabalaştırmaz)
	var ray_len: float = cur_r * FLASH_RAY_LENGTH_MULT
	for i in range(FLASH_RAY_COUNT):
		var angle: float = (TAU / float(FLASH_RAY_COUNT)) * float(i) + 0.3
		var dir: Vector2 = Vector2.from_angle(angle)
		var inner: Vector2 = dir * cur_r * 0.4
		var outer: Vector2 = dir * ray_len
		draw_line(inner, outer, Color(accent.r, accent.g, accent.b, alpha * 0.4), 2.0, true)
