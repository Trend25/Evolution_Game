extends RigidBody2D
class_name Organism
## Organism — UC-01/UC-02: Tek bir canlının fiziksel gövdesi. Aynı evrim
## seviyesinden bir canlıyla temas ettiğinde evrilme (merge) sürecini başlatır.

const MERGE_ARM_DELAY: float = 0.15  # UC-02: Instantiate anındaki iç içe geçme çakışmasını yok saymak için gecikme

@export var stage_id: int = 0

var _merge_armed: bool = false
var _is_merging: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _debug_label: Label = get_node_or_null("Label")  # Yer tutucu: gerçek görsel/skin UI/UX rolünün kapsamındadır

func _ready() -> void:
	_apply_stage(stage_id)
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(MERGE_ARM_DELAY).timeout.connect(_arm_merge)

## MERGE_ARM_DELAY süresi dolduğunda bu canlının merge tespitine katılmasına izin verir.
func _arm_merge() -> void:
	_merge_armed = true

## stage_id'ye göre çarpışma yarıçapını, evrim grubunu ve (varsa) yer tutucu etiketi ayarlar.
## NOT (bugfix): Organism.tscn'deki CircleShape2D, resource_local_to_scene
## işaretlenmemiş bir sub-resource olduğundan tüm Organism instance'ları
## arasında PAYLAŞILIR. Bu yüzden mevcut shape'in radius'unu mutate etmek
## yerine her instance için ayrı bir CircleShape2D oluşturulur; aksi halde
## bir organizmanın boyutu tüm diğer organizmaları da etkiler.
func _apply_stage(new_stage_id: int) -> void:
	stage_id = new_stage_id
	var stage: Dictionary = OrganismTypes.get_stage(stage_id)
	if stage.is_empty():
		return
	if collision_shape:
		var instance_shape := CircleShape2D.new()
		instance_shape.radius = stage.get("radius", 16.0)
		collision_shape.shape = instance_shape
	for existing_group in get_groups():
		if String(existing_group).begins_with("organism_stage_"):
			remove_from_group(existing_group)
	add_to_group("organism_stage_%d" % stage_id)
	if _debug_label:
		_debug_label.text = String(stage.get("name", "?"))

## UC-02 Adım 1: Fizik motoru aynı seviyeden bir canlıyla temasını algıladığında çağrılır (body_entered).
func _on_body_entered(body: Node) -> void:
	if not _merge_armed or _is_merging:
		return
	if body == self or not (body is Organism):
		return
	var other: Organism = body as Organism
	if other.stage_id != stage_id or other._is_merging or not other._merge_armed:
		return
	# Çift taraflı tetiklenmeyi (her iki obje de aynı çarpışmayı algılar) önlemek için
	# sadece daha düşük instance ID'ye sahip taraf merge işlemini başlatır.
	if get_instance_id() < other.get_instance_id():
		_perform_merge(other)

## UC-02 Adım 2-3: İki eski canlıyı kaldırır (queue_free), bir üst aşamayı temas
## noktasında instantiate eder, skor/XP ödülünü ve merge bildirimini GameManager
## üzerinden yayınlar (Tween/ses/parçacık tetiklemesi UI/UX rolünün kapsamındadır).
func _perform_merge(other: Organism) -> void:
	_is_merging = true
	other._is_merging = true

	var contact_point: Vector2 = (global_position + other.global_position) / 2.0
	var merged_stage_id: int = stage_id
	var next_stage: Dictionary = OrganismTypes.get_next_stage(merged_stage_id)
	var container: Node = get_tree().get_first_node_in_group("organism_container")

	GameManager.add_merge_reward(merged_stage_id, contact_point)

	queue_free()
	other.queue_free()

	if next_stage.is_empty() or container == null:
		return  # UC-02: Son aşama (T-Rex) evrilmeye devam etmez — sadece ödül verilir.

	# load() kasıtlı: preload() kullanılırsa bu script kendi sahnesini derleme
	# zamanında önceden yükler ve döngüsel (cyclic) bağımlılık hatası oluşur.
	var evolved: Organism = load("res://scenes/Organism.tscn").instantiate()
	evolved.stage_id = int(next_stage.get("id", merged_stage_id + 1))
	container.add_child(evolved)
	evolved.global_position = contact_point
