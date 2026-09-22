extends RigidBody2D
class_name Organism
## Organism — UC-01/UC-02: Tek bir canlının fiziksel gövdesi. Aynı evrim
## seviyesinden bir canlıyla temas ettiğinde evrilme (merge) sürecini başlatır.

const MERGE_ARM_DELAY: float = 0.15  # UC-02: Instantiate anındaki iç içe geçme çakışmasını yok saymak için gecikme

@export var stage_id: int = 0

# Görsel katman (organism_visual.gd) ile veri sözleşmesi: bu dört alan şu an
# hiçbir yerde set edilmiyor (varsayılan değerde kalıyor) — organism_visual.gd
# bunları organism.get(...) ile güvenli okuyabilsin diye buradalar. Gerçek
# davranış (tier büyümesi, bonus zamanlayıcısı, balık parça birleşimi) ayrı,
# izole commit'lerde eklenir.
@export var is_bonus: bool = false  # Bonus Sistemi: Spawner'ın zaman zaman işaretlediği özel, yüksek puanlı canlı
@export var tier: int = 0  # Solucan büyüme mekaniği: tier>0 ise fiziksel/görsel boyut büyür (bkz. OrganismTypes.tier_size_multiplier)
@export var is_fish_part: bool = false  # Balık'ın iki parçadan biri mi (bkz. spawner.gd, _perform_fish_part_merge)
@export var fish_part_index: int = 0  # 0 veya 1 — tamamlayıcı parça diğeriyle eşleşir

# Görsel cila (visual-polish/stage-readability): isim etiketleri normal
# oyunda kafa karıştırıcı/gereksiz olduğundan varsayılan olarak gizli.
# QA/test script'leri, organizmayı sahneye eklemeden (add_child/_ready'den)
# ÖNCE bu alanı true yaparak etiketi görünür kılabilir. Yeni bir autoload
# veya project.godot değişikliği kasıtlı olarak eklenmedi.
@export var show_debug_label: bool = false

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
	# Solucan büyüme mekaniği: tier > 0 ise fiziksel çarpışma yarıçapı da
	# görsel boyutla (organism_visual.gd) BİREBİR aynı oranda büyür — ikisi
	# hep OrganismTypes'taki TEK bir çarpandan gelir, aksi halde büyük
	# Solucan'ın gerçek gövdesiyle çarpışma alanı birbirinden sapar.
	var effective_radius: float = stage.get("radius", 16.0) * OrganismTypes.tier_size_multiplier(stage_id, tier)
	if collision_shape:
		var instance_shape := CircleShape2D.new()
		instance_shape.radius = effective_radius
		collision_shape.shape = instance_shape
	for existing_group in get_groups():
		if String(existing_group).begins_with("organism_stage_"):
			remove_from_group(existing_group)
	add_to_group("organism_stage_%d" % stage_id)
	if _debug_label:
		var label_text: String = String(stage.get("name", "?"))
		if tier > 0:
			label_text = "%s (Büyük)" % label_text
		_debug_label.text = label_text
		_debug_label.visible = show_debug_label

## UC-02 Adım 1: Fizik motoru aynı seviyeden bir canlıyla temasını algıladığında çağrılır (body_entered).
func _on_body_entered(body: Node) -> void:
	if not _merge_armed or _is_merging:
		return
	if body == self or not (body is Organism):
		return
	var other: Organism = body as Organism
	if other.stage_id != stage_id or other._is_merging or not other._merge_armed:
		return
	# Balık 2-parça mekaniği: parçalar normal evrim birleşmesine katılmaz.
	# Sadece tamamlayıcı parça (farklı fish_part_index) ile karşılaşınca tek
	# bir tam Balık'a dönüşürler; parça+parça (aynı index) veya parça+gerçek
	# Balık (is_fish_part=false) hiç birleşmez.
	if is_fish_part or other.is_fish_part:
		if is_fish_part and other.is_fish_part and fish_part_index != other.fish_part_index:
			if get_instance_id() < other.get_instance_id():
				_perform_fish_part_merge(other)
		return
	# Çift taraflı tetiklenmeyi (her iki obje de aynı çarpışmayı algılar) önlemek için
	# sadece daha düşük instance ID'ye sahip taraf merge işlemini başlatır.
	if get_instance_id() < other.get_instance_id():
		_perform_merge(other)

## Balık 2-parça mekaniği: iki TAMAMLAYICI Balık Parçası (index 0 + 1)
## birbirine değince normal evrim biriminin aksine bir üst aşamaya ATLAMAZ —
## sadece kendi aşamalarını (Balık) TAMAMLARLAR. Mevcut oyun ekonomisi
## kontrol edildi: committed add_merge_reward SADECE _perform_merge'den
## (gerçek stage-to-stage evrim/büyüme) çağrılıyor; parça tamamlama farklı
## bir kategori (aynı aşamanın iki yarısını birleştirme, evrim değil) ve
## bunun için mevcut ekonomide açık bir kural yok. Bu yüzden burada YENİ bir
## ödül EKLENMEDİ — tasarım kararı açık olmadığından skor/XP verilmiyor
## (bkz. commit mesajı ve final rapor).
func _perform_fish_part_merge(other: Organism) -> void:
	_is_merging = true
	other._is_merging = true

	var contact_point: Vector2 = (global_position + other.global_position) / 2.0
	var container: Node = get_tree().get_first_node_in_group("organism_container")
	var combined_is_bonus: bool = is_bonus or other.is_bonus  # Bonus Sistemi: iki taraftan biri yeterli

	# feat: add merge burst and floating score feedback -- bu yol
	# GameManager.add_merge_reward'i HIC CAGIRMAZ (Balik parca tamamlanmasi
	# skor vermiyor, bkz. yukaridaki yorum), bu yuzden organism_merged
	# sinyali BURADA, score_awarded=false ve awarded_score=0 ile, AYRICA
	# yayinlanir -- aksi halde Balik tamamlaninca hicbir burst gorunmezdi.
	# Skor/XP EKONOMISINE dokunmaz (add_merge_reward hala cagrilmiyor).
	GameManager.organism_merged.emit(contact_point, stage_id, combined_is_bonus, 0, false)

	queue_free()
	other.queue_free()

	if container == null:
		return

	var completed: Organism = load("res://scenes/Organism.tscn").instantiate()
	# fix: preserve bonus state across merges -- TÜM başlangıç alanları
	# add_child()'dan ÖNCE set edilir (organism_visual.gd'nin _ready()'si
	# is_bonus/is_fish_part/fish_part_index/tier'ı tam bu anda, senkron
	# olarak okur; sonradan atama görsel tint/halo'yu KAÇIRIR).
	completed.stage_id = stage_id  # Balık — parçalar zaten bu id'yi taşıyordu, sadece tamamlanıyor
	completed.tier = 0  # Balık'ta tier kullanılmıyor (TIERED_GROWTH_STAGE_ID değil) — nötr/varsayılan değer
	completed.is_bonus = combined_is_bonus  # zaten doğruydu (bu yolda hep add_child'dan önceydi) -- açıklık için korunuyor
	completed.is_fish_part = false  # artık tamamlanmış tam bir Balık -- parça değil (önceden zaten varsayılan değerle doğruydu, artık açık)
	completed.fish_part_index = 0  # nötr/varsayılan değer (tamamlanmış Balık'ta anlamsız)
	container.add_child(completed)
	completed.global_position = contact_point

## UC-02 Adım 2-3: İki eski canlıyı kaldırır (queue_free), bir üst aşamayı temas
## noktasında instantiate eder, skor/XP ödülünü ve merge bildirimini GameManager
## üzerinden yayınlar (Tween/ses/parçacık tetiklemesi UI/UX rolünün kapsamındadır).
func _perform_merge(other: Organism) -> void:
	_is_merging = true
	other._is_merging = true

	var contact_point: Vector2 = (global_position + other.global_position) / 2.0
	var merged_stage_id: int = stage_id
	var container: Node = get_tree().get_first_node_in_group("organism_container")
	# Solucan büyüme mekaniği: iki tier-0 Solucan birleşince üst aşamaya
	# ATLAMAZ, sadece daha büyük (tier 1) aynı-aşama bir canlı olur.
	var grow_instead_of_evolve: bool = _should_grow_instead_of_evolve(other)
	var combined_is_bonus: bool = is_bonus or other.is_bonus  # Bonus Sistemi: iki taraftan biri yeterli

	GameManager.add_merge_reward(merged_stage_id, contact_point, combined_is_bonus)

	queue_free()
	other.queue_free()

	if container == null:
		return

	if grow_instead_of_evolve:
		var grown: Organism = load("res://scenes/Organism.tscn").instantiate()
		# fix: preserve bonus state across merges -- TÜM başlangıç alanları
		# add_child()'dan ÖNCE set edilir (bkz. yukarıdaki not / final rapor:
		# organism_visual.gd _ready() is_bonus'u add_child anında, tek seferlik
		# okur -- sonradan atarsak halo/tint hiç oluşmaz, gameplay alanı doğru
		# görünse bile).
		grown.stage_id = merged_stage_id
		grown.tier = 1
		grown.is_bonus = combined_is_bonus  # KÖK NEDEN DÜZELTMESİ -- önceden hiç atanmıyordu, bonus statüsü burada kayboluyordu
		grown.is_fish_part = false  # nötr/varsayılan değer -- Solucan büyümesi balık parçası değildir
		grown.fish_part_index = 0  # nötr/varsayılan değer
		container.add_child(grown)
		grown.global_position = contact_point
		return

	var next_stage: Dictionary = OrganismTypes.get_next_stage(merged_stage_id)
	if next_stage.is_empty():
		return  # UC-02: Son aşama (T-Rex) evrilmeye devam etmez — sadece ödül verilir.

	# load() kasıtlı: preload() kullanılırsa bu script kendi sahnesini derleme
	# zamanında önceden yükler ve döngüsel (cyclic) bağımlılık hatası oluşur.
	var evolved: Organism = load("res://scenes/Organism.tscn").instantiate()
	# fix: preserve bonus state across merges -- TÜM başlangıç alanları
	# add_child()'dan ÖNCE set edilir (bkz. yukarıdaki not / final rapor).
	evolved.stage_id = int(next_stage.get("id", merged_stage_id + 1))
	evolved.tier = 0  # Yeni aşama her zaman tier 0'dan başlar
	evolved.is_bonus = combined_is_bonus  # KÖK NEDEN DÜZELTMESİ -- önceden hiç atanmıyordu, bonus statüsü burada kayboluyordu
	evolved.is_fish_part = false  # nötr/varsayılan değer -- normal evrimle oluşan canlı balık parçası değildir
	evolved.fish_part_index = 0  # nötr/varsayılan değer
	container.add_child(evolved)
	evolved.global_position = contact_point

## Solucan büyüme mekaniği: sadece OrganismTypes.TIERED_GROWTH_STAGE_ID
## aşamasında VE iki taraf da hâlâ tier 0 ise true döner (→ büyüme, evrim
## yok). Diğer tüm durumlarda false döner (→ normal evrim, eski davranış).
func _should_grow_instead_of_evolve(other: Organism) -> bool:
	return stage_id == OrganismTypes.TIERED_GROWTH_STAGE_ID and tier == 0 and other.tier == 0
