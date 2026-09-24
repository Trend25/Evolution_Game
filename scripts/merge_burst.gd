extends Node2D
class_name MergeBurst
## MergeBurst -- feat: add merge burst and floating score feedback. Her
## basarili merge sonucunun GERCEK DUNYA konumunda oynatilan, kisa omurlu,
## SADECE GORSEL bir "juice" efekti: ince genisleyen bir halka + birkac
## yumusak, disariya dogru hafifce yayilan parcacik. Collision/fizik/skor/
## XP/bonus mantigina HICBIR sekilde katilmaz -- bu script'te CollisionShape,
## RigidBody, Area vb. hicbir fizik dugumu yoktur, yalnizca _draw() + Tween.
## Main.tscn'deki EffectsLayer (merge_feedback_manager.gd) tarafindan
## dinamik olarak instantiate edilip play() cagrilir; kendi tween'i bitince
## kendini queue_free() ile kaldirir, sahnede kalici hicbir iz birakmaz.
##
## Ani beyaz flas veya yogun konfeti YOK (kullanici talebi) -- tek bir sakin,
## ince halka genislemesi + 6-10 yumusak parcacik. z_index=5 ile organizma
## sprite'larinin USTUNDE durur, ama HUD (UI_Canvas, CanvasLayer layer=10)
## HER ZAMAN ustunde kalir cunku bu efekt ayri, world-space bir CanvasLayer'da
## (layer=0, varsayilan) -- z_index farkli bir CanvasLayer'i ASLA gecemez.

const DURATION: float = 0.58  # istenen ~0.5-0.65s araliginin ortasi
const RING_WIDTH: float = 2.6
const RING_EXPAND_FACTOR: float = 1.55  # halka, baslangic yaricapinin bu katina genisler
const MIN_RING_RADIUS: float = 22.0
# feat: improve mobile scale and scoring feedback (Bölüm B) -- OrganismTypes
# yeni boyut tablosunda en büyük aşama (T-Rex, id=9) radius=166.0'a çıktı
# (eskiden 144.0); üst sınır aynı oranda büyütüldü ki en büyük evrim
# aşamasında efekt hâlâ orantılı görünsün, eskisi gibi "kırpılmış" kalmasın.
const MAX_RING_RADIUS: float = 180.0    # cok buyuk organizmalarda (Memeli/T-Rex) efekt asiri devasa olmasin
const PARTICLE_COUNT_MIN: int = 6
const PARTICLE_COUNT_MAX: int = 10
const PARTICLE_RADIUS_MIN: float = 2.4
const PARTICLE_RADIUS_MAX: float = 4.2
const PARTICLE_FADE_IN: float = 0.12
const PARTICLE_MAX_DELAY: float = 0.07

# Soft Indie + Cozy Oddball palet -- HUDTheme ailesine yakin, ama kendi
# yerel sabitleri (organism_visual.gd'ye veya HUDTheme'e YENI bir bagimlilik
# eklenmedi/degistirilmedi).
const NORMAL_RING_COLOR: Color = Color("#8FE3D2")     # yumusak mint/teal
const NORMAL_PARTICLE_COLOR: Color = Color("#F6EFD9") # sicak krem
const BONUS_RING_COLOR: Color = Color("#F6D583")      # mevcut altin bonus rengiyle uyumlu amber
const BONUS_PARTICLE_COLOR: Color = Color("#FFE9A8")  # daha acik/sicak amber

var _ring_radius: float = MIN_RING_RADIUS
var _ring_alpha: float = 0.0
var _ring_color: Color = NORMAL_RING_COLOR

class _Particle:
	var current_offset: Vector2 = Vector2.ZERO
	var target_offset: Vector2 = Vector2.ZERO
	var radius: float = 3.0
	var alpha: float = 0.0
	var color: Color = Color.WHITE

var _particles: Array = []

## organism_types.gd'deki GERCEK stage radius'u kullanilarak (buyuk
## organizmalarda efekt de biraz daha buyuk, ama MAX_RING_RADIUS ile
## sinirli) halka+parcacik gorunumunu baslatir ve animasyonu oynatir.
func play(is_bonus: bool, stage_radius: float) -> void:
	z_index = 5

	var base_radius: float = clamp(stage_radius * 0.95, MIN_RING_RADIUS, MAX_RING_RADIUS)
	_ring_radius = base_radius
	_ring_alpha = 0.85
	_ring_color = BONUS_RING_COLOR if is_bonus else NORMAL_RING_COLOR
	var particle_color: Color = BONUS_PARTICLE_COLOR if is_bonus else NORMAL_PARTICLE_COLOR

	_particles.clear()
	var particle_count: int = randi_range(PARTICLE_COUNT_MIN, PARTICLE_COUNT_MAX)
	for i in range(particle_count):
		var angle: float = (TAU / float(particle_count)) * float(i) + randf_range(-0.25, 0.25)
		var distance: float = base_radius * randf_range(0.55, 1.05)
		var p := _Particle.new()
		p.target_offset = Vector2.from_angle(angle) * distance
		p.radius = randf_range(PARTICLE_RADIUS_MIN, PARTICLE_RADIUS_MAX)
		p.color = particle_color
		_particles.append(p)
	queue_redraw()

	var ring_tween: Tween = create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_method(_set_ring_radius, base_radius, base_radius * RING_EXPAND_FACTOR, DURATION).set_ease(Tween.EASE_OUT)
	ring_tween.tween_method(_set_ring_alpha, 0.85, 0.0, DURATION).set_ease(Tween.EASE_IN)
	# Bu tek tween (ring_tween), DURATION suresince calisan en uzun animasyon
	# oldugu icin "finished" sinyali dogru anda ates lenir -- ayri bir
	# SceneTreeTimer/queue_free callback'i GEREKMEZ (parcacik tween'leri bu
	# node'a baglidir/bound, node queue_free olunca onlar da otomatik iptal
	# edilir, dangling callback riski yoktur).
	ring_tween.finished.connect(queue_free)

	for i in range(_particles.size()):
		var delay: float = randf_range(0.0, PARTICLE_MAX_DELAY)
		var fade_out_duration: float = max(0.08, DURATION - delay - PARTICLE_FADE_IN)

		var offset_tween: Tween = create_tween()
		offset_tween.tween_method(_set_particle_offset.bind(i), Vector2.ZERO, _particles[i].target_offset, DURATION - delay).set_delay(delay).set_ease(Tween.EASE_OUT)

		var alpha_tween: Tween = create_tween()
		alpha_tween.tween_method(_set_particle_alpha.bind(i), 0.0, 1.0, PARTICLE_FADE_IN).set_delay(delay)
		alpha_tween.tween_method(_set_particle_alpha.bind(i), 1.0, 0.0, fade_out_duration)

func _set_ring_radius(value: float) -> void:
	_ring_radius = value
	queue_redraw()

func _set_ring_alpha(value: float) -> void:
	_ring_alpha = value
	queue_redraw()

# NOT: parametre sirasi (value, index) -- Callable.bind(i), bound argumani
# tween'in OTOMATIK gecirdigi animasyon degerinden SONRAYA ekler, yani
# gercek cagri her zaman (tween_degeri, bind_edilen_deger) seklindedir.
# (index, value) sirasiyla yazilmis onceki hali her adimda "Cannot convert
# argument 1 from Vector2/float to int" hatasi uretiyordu -- parcaciklar
# hicbir zaman gorunmuyordu ve engine performansi hata log hacmiyle
# ciddi olcude dusuyordu; bu duzeltmeyle birlikte cozuldu.
func _set_particle_alpha(value: float, index: int) -> void:
	if index < 0 or index >= _particles.size():
		return
	_particles[index].alpha = value
	queue_redraw()

func _set_particle_offset(value: Vector2, index: int) -> void:
	if index < 0 or index >= _particles.size():
		return
	_particles[index].current_offset = value
	queue_redraw()

func _draw() -> void:
	if _ring_alpha > 0.001:
		draw_arc(Vector2.ZERO, _ring_radius, 0.0, TAU, 64, Color(_ring_color.r, _ring_color.g, _ring_color.b, _ring_alpha), RING_WIDTH, true)
	for p in _particles:
		if p.alpha > 0.001:
			draw_circle(p.current_offset, p.radius, Color(p.color.r, p.color.g, p.color.b, p.alpha * 0.9), true, -1.0, true)
