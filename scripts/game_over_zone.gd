extends Area2D
class_name GameOverZone
## GameOverZone — UC-03: Can Kaybı. Fanusun üst kısmındaki "Tehlike Çizgisi"ni
## bir canlının DANGER_DURATION_SECONDS'tan uzun süre kesintisiz ihlal etmesini
## algılar ve GameManager üzerinden can kaybını tetikler.

const DANGER_DURATION_SECONDS: float = 2.0  # UC-03 Adım 1: İhlal eşiği (3.1)

var _overlap_durations: Dictionary = {}  # Organism -> birikmiş ihlal süresi (saniye)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

## UC-03 Adım 1: Tehlike çizgisine giren bir canlı için süre sayacını başlatır.
func _on_body_entered(body: Node) -> void:
	if body is Organism:
		_overlap_durations[body] = 0.0

## Tehlike çizgisinden çıkan (veya merge ile yok olan) canlının süre sayacını temizler.
func _on_body_exited(body: Node) -> void:
	_overlap_durations.erase(body)

## UC-03 Adım 1: Her karede, çizgiyi ihlal eden canlıların süresini artırır;
## eşik aşılırsa can kaybını tetikler ve sayaçları sıfırlar.
func _process(delta: float) -> void:
	if _overlap_durations.is_empty():
		return
	for body in _overlap_durations.keys():
		if not is_instance_valid(body):
			_overlap_durations.erase(body)
			continue
		_overlap_durations[body] += delta
		if _overlap_durations[body] >= DANGER_DURATION_SECONDS:
			_overlap_durations.clear()
			GameManager.lose_life()
			break
