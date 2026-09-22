extends Node2D
class_name DropEntryPop
## DropEntryPop -- feat: add drop aiming and landing feedback. Canlı fanusa
## GİRERKEN (drop anında, gerçek bırakma konumunda) çok kısa ve küçük bir
## "giriş" geri bildirimi: soluk, hızlı genişleyen bir halka (~0.26s).
## MergeBurst'ten (ödül/skor anı) BİLİNÇLİ olarak küçük/kısa/soluk tutulur ki
## görsel ağırlıkça onunla YARIŞMASIN -- yalnızca "az önce buraya bir şey
## girdi" hissi verir. Collision/fizik/skor/XP/spawn/cooldown/bonus
## mantığına HİÇBİR şekilde katılmaz: bu script'te CollisionShape,
## RigidBody, Area vb. hiçbir fizik düğümü yoktur, yalnızca _draw() + Tween.
## Main.tscn'deki DropFeedbackManager tarafından dinamik olarak instantiate
## edilip play() çağrılır; kendi tween'i bitince kendini queue_free() ile
## kaldırır, sahnede kalıcı hiçbir iz bırakmaz.

const DURATION: float = 0.26                  # istenen ~0.2-0.3s aralığının ortası
const START_RADIUS: float = 6.0
const END_RADIUS: float = 20.0
const RING_WIDTH: float = 2.0
const MAX_ALPHA: float = 0.55                  # MergeBurst'ün 0.85 tepe alfasından bilinçli olarak daha soluk

# merge_burst.gd'deki NORMAL_RING_COLOR/BONUS_RING_COLOR ile AYNI paletten --
# yeni bir renk icat edilmedi, mevcut normal/bonus dilinin devamı.
const NORMAL_COLOR: Color = Color("#8FE3D2")
const BONUS_COLOR: Color = Color("#F6D583")

var _radius: float = START_RADIUS
var _alpha: float = 0.0
var _color: Color = NORMAL_COLOR

## Organism.is_bonus, Spawner.organism_dropped sinyalinden ZATEN hesaplanmış
## haliyle gelir -- burada yeniden hesaplanmaz/kopyalanmaz.
func play(is_bonus: bool) -> void:
	z_index = 4  # MergeBurst (z_index=5)'in hemen altında, organizmaların üstünde
	_color = BONUS_COLOR if is_bonus else NORMAL_COLOR
	_radius = START_RADIUS
	_alpha = MAX_ALPHA
	queue_redraw()

	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_method(_set_radius, START_RADIUS, END_RADIUS, DURATION).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_alpha, MAX_ALPHA, 0.0, DURATION).set_ease(Tween.EASE_IN)
	# Tek başına DURATION boyunca çalışan bu tween grubu bitince kendini
	# kaldırır -- ayrı bir SceneTreeTimer/queue_free çağrısına gerek yoktur.
	tw.finished.connect(queue_free)

func _set_radius(value: float) -> void:
	_radius = value
	queue_redraw()

func _set_alpha(value: float) -> void:
	_alpha = value
	queue_redraw()

func _draw() -> void:
	if _alpha > 0.001:
		draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 48, Color(_color.r, _color.g, _color.b, _alpha), RING_WIDTH, true)
