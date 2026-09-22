extends Node2D
class_name Main
## Main — UC-03 Adım 2: Can kaybı gerçekleştiğinde fanustaki canlıları temizleyen
## koordinatör ("Ekrandaki canlıların bir kısmı temizlenir... fanus sıfırdan
## doldurulmaya devam eder").
##
## NOT: Mimari belge "kısmi" temizlik ile tam mı yoksa seçili canlıların mı
## kaldırılacağını netleştirmiyor. En güvenli/deterministik yorum olarak burada
## fanustaki tüm canlılar temizlenir; Tester rolünün UC-03'ü doğrularken bu
## kararı kullanıcıyla teyit etmesi önerilir.

@onready var organism_container: Node = $OrganismContainer
@onready var _spawner: Spawner = $Spawner
@onready var _next_preview: NextPreview = $UI_Canvas/HUDRoot/NextPanel

func _ready() -> void:
	GameManager.life_lost.connect(_on_life_lost)
	GameManager.run_reset.connect(_clear_organism_container)
	# feat: add dedicated next organism preview -- Spawner sinyalini NEXT
	# UI'a bagla, VE ilk kare icin bekleyen canliyi elle senkronize et (Godot
	# _ready() cocuktan-ebeveyne dogru calisir; Spawner._ready() ilk
	# next_organism_ready'i Main._ready() BAGLANMADAN once yayinlar --
	# bu satir o yarisi onler). Oynanis/spawn mantigina dokunmaz.
	_spawner.next_organism_ready.connect(_next_preview.update_preview)
	_next_preview.update_preview(_spawner.get_pending_preview_data())

## UC-03 Adım 2: Can kaybında fanustaki tüm canlıları kaldırır.
func _on_life_lost(_lives_remaining: int) -> void:
	_clear_organism_container()

## Fanustaki tüm canlıları kaldırır. Hem UC-03 (can kaybı) hem de
## GameManager.run_reset ("Tekrar Oyna") tarafından tetiklenir.
func _clear_organism_container() -> void:
	for organism in organism_container.get_children():
		organism.queue_free()
