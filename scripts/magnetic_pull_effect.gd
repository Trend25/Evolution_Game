extends Node
class_name MagneticPullEffect
## MagneticPullEffect -- gameplay/core-loop-v4 "Evrim Laboratuvarı" V02
## vertical slice (madde 7 -- Mutasyon kartı "MANYETİK ALAN": "en yakın eş
## çifti birleştirir"). FİZİK-GÜVENLİ bir "çekim" uygular: DURATION boyunca,
## her fizik karesinde iki organizmanın linear_velocity'sini birbirine doğru
## ayarlar -- organism.gd'nin KENDİ _integrate_forces() tabanlı merge-assist
## desenine BENZER ama daha basit (doğrudan hız ataması) bir varyant (bkz.
## MutasyonManager'daki mimari kararı). GERÇEK merge HİÇBİR ZAMAN doğrudan
## tetiklenmez/simüle edilmez -- yalnızca iki gerçek RigidBody2D'yi birbirine
## yaklaştırır, gerçek çarpışma+organism.gd'nin kendi merge mantığı normal
## şekilde devreye girer. Taraflardan biri süre dolmadan geçersiz olursa
## (ör. başka bir merge'e karışmış/queue_free olmuş) sessizce durur.

const DURATION: float = 0.5
const PULL_SPEED: float = 620.0

var _a: RigidBody2D = null
var _b: RigidBody2D = null
var _elapsed: float = 0.0

func start(a: RigidBody2D, b: RigidBody2D) -> void:
	_a = a
	_b = b

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= DURATION or not is_instance_valid(_a) or not is_instance_valid(_b):
		queue_free()
		return
	var to_b: Vector2 = _b.global_position - _a.global_position
	if to_b.length() > 1.0:
		var dir: Vector2 = to_b.normalized()
		_a.linear_velocity = dir * PULL_SPEED
		_b.linear_velocity = -dir * PULL_SPEED
