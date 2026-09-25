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

# gameplay/core-loop-v4 "Evrim Laboratuvarı" vertical slice: organism_visual.gd
# bu bayrağa bakarak evrimle YENİ DOĞMUŞ bir canlıya (spawner'dan gelen sıradan
# bir bırakma DEĞİL) belirgin bir 115-125% "pop" büyütmesi + DNA sarmalı
# beraberliği uygular (bkz. _perform_merge/_perform_fish_part_merge'de
# add_child'dan ÖNCE set edilmesi, organism_visual.gd _play_spawn_pop).
@export var born_from_evolution: bool = false

var _merge_armed: bool = false
var _is_merging: bool = false

# V4 core-loop/graybox (madde 5 -- merge-assist): bu organizmanın şu ana
# kadar merge-assist tarafından "itilmiş" olduğu TOPLAM süre (saniye).
# GrayboxConfig.MERGE_ASSIST_MAX_DURATION'a ulaşınca bu organizma için
# assist KALICI OLARAK durur -- sonsuz/uzun-mesafe çekim YOK.
var _assist_time_used: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _debug_label: Label = get_node_or_null("Label")  # Yer tutucu: gerçek görsel/skin UI/UX rolünün kapsamındadır

func _ready() -> void:
	# V4 core-loop/graybox (madde 4 -- QA aşama numarası): SADECE
	# GrayboxConfig.ENABLED iken, mevcut show_debug_label alanı (önceden
	# yalnızca QA script'lerinin elle açtığı bir alan) varsayılan olarak
	# açılır -- yeni bir autoload/alan EKLENMEDİ, mevcut mekanizma yeniden
	# kullanıldı. Üretimde (ENABLED=false) davranış DEĞİŞMEZ.
	# DÜZELTME (V02 düzeltme turu -- kullanıcı: "Üstteki halka/debug
	# görünümünü kaldır"): önceki teslimatta bu etiket ("Virüs"/"Bakteri" vb.
	# metni her canlının üstünde) her bırakılan/önizlenen canlıda GÖRÜNÜYORDU
	# -- bu, kullanıcının reddettiği "debug görünümün" GERÇEK kaynağıydı
	# (silinen QA video script'inin kendi dokunma göstergesi DEĞİL, bu SABİT
	# üretim-kodu bayrağıydı). "Evrim Laboratuvarı" görsel katmanı (LAB_
	# VISUALS_ENABLED) cilalı/onaya-sunulan bir görünüm hedeflediğinden, QA
	# etiketi ARTIK yalnızca SAF graybox modunda (LAB_VISUALS_ENABLED=false,
	# ör. ileride fizik-only bir QA koşumu) gösterilir -- lab görselleri
	# etkinken hiçbir debug metni render edilmez.
	if GrayboxConfig.ENABLED and GrayboxConfig.SHOW_QA_STAGE_LABEL and not GrayboxConfig.LAB_VISUALS_ENABLED:
		show_debug_label = true
	_apply_stage(stage_id)
	# V4 core-loop/graybox (madde 3 -- tempo): SADECE GrayboxConfig.ENABLED
	# iken, bırakma-ile-ilk-temas arasındaki süreyi kısaltmak için efektif
	# yerçekimi merkezi bir çarpanla artırılır (bkz. graybox_config.gd
	# kalibrasyon notu). Organism.tscn'deki taban gravity_scale=1.0
	# DEĞİŞMEDİ -- bu satır yalnızca ENABLED=true iken devreye girer,
	# üretim/diğer branch'lerde hiçbir etkisi yoktur.
	if GrayboxConfig.ENABLED:
		gravity_scale = GrayboxConfig.GRAVITY_MULTIPLIER
		# V4 core-loop/graybox (madde 5 -- fizik güvenliği, QA'da bulundu):
		# dairesel gövdeler dönüşe kilitlenmezse, düşüp yerleşirken sürtünme
		# kaynaklı yuvarlanma/dönüş küçük yatay kaymalara yol açabiliyor --
		# bu da merge-assist'in (SADECE linear_velocity.x'e dokunan) yumuşak
		# çekimini bastırıp öngörülemez yatay hareket üretebiliyordu (ilk QA
		# koşusunda ölçüldü: aynı-stage çift birbirine yaklaşacağına 82px'den
		# 191px'e ayrıldı). Dönüşü kilitlemek görsel olarak fark edilmez
		# (grayboks şekilleri simetrik daireler) ama yatay hareketi SADECE
		# gerçek çarpışma tepkisi + assist belirler, öngörülemez dönüş kayması
		# değil. Üretimde (ENABLED=false) rotasyon davranışı DEĞİŞMEZ.
		lock_rotation = true
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(MERGE_ARM_DELAY).timeout.connect(_arm_merge)

## MERGE_ARM_DELAY süresi dolduğunda bu canlının merge tespitine katılmasına izin verir.
func _arm_merge() -> void:
	_merge_armed = true

## V4 core-loop/graybox DÜZELTME (kullanıcı: "physics-safe merge assist" --
## önceki position/global_position atamasına dayalı yaklaşım KALDIRILDI, bu
## fizik motorunu baypas ediyordu). Gerçek assist kuvveti artık SADECE
## _integrate_forces() içinde uygulanır (bkz. aşağı) -- RigidBody2D UYUYAN
## durumdayken _integrate_forces() motor tarafından HİÇ ÇAĞRILMAZ, bu yüzden
## bu fonksiyonun TEK işi, assist için uygun olabilecek UYUYAN bir gövdeyi
## UYANDIRMAKTIR (sleeping=false). Hiçbir konum/hız/transform buradan
## YAZILMAZ -- sadece okuma (linear_velocity.y, sleeping) yapılır.
func _physics_process(_delta: float) -> void:
	if not GrayboxConfig.ENABLED or not GrayboxConfig.MERGE_ASSIST_ENABLED:
		return
	if _is_merging or not _merge_armed or freeze or is_fish_part:
		return
	if _assist_time_used >= GrayboxConfig.MERGE_ASSIST_MAX_DURATION:
		return
	if not sleeping:
		return  # zaten uyanık -- _integrate_forces() bu gövde için zaten her fizik karesinde çağrılıyor
	if abs(linear_velocity.y) > GrayboxConfig.MERGE_ASSIST_MIN_SPEED_TO_ARM:
		return  # hâlâ düşüyor sayılır -- assist yalnızca yerleşmeye yakın/durmuş organizmalara uygulanır
	if _find_nearest_assist_target() == null:
		return  # yakında uygun bir hedef yoksa uyandırmaya bile gerek yok
	sleeping = false  # SADECE uyandırma -- hız/konum burada ASLA yazılmaz

## V4 core-loop/graybox DÜZELTME -- fizik motoruyla TAM entegre, hız-sınırlı
## yatay "yumuşak çekim". `state` (PhysicsDirectBodyState2D), Godot'un bu
## gövde için TEMAS/SÜRTÜNME çözücüsünü çalıştırmadan HEMEN ÖNCE okuduğu/
## yazdığı resmi arayüzdür (RigidBody2D "Custom integrator" KAPALI/varsayılan
## bırakıldı -- bu fonksiyon motorun normal entegrasyonunun YERİNE değil,
## YANINDA ek bir kuvvet ekler). Burada apply_central_force() ile uygulanan
## kuvvet, motorun aynı çözüm adımında yerçekimi/sürtünme/temas tepkisiyle
## BİRLİKTE işlenir -- önceki position-nudge yaklaşımının aksine motoru ASLA
## baypas etmez, transform/global_position'a HİÇ dokunmaz, çarpışma içinden
## geçme veya teleport imkanı yoktur (fizik çözücüsü normal temas/penetrasyon
## kısıtlarını her zaman uygulamaya devam eder). SADECE yatay bileşen
## (apply_central_force'un x'i) değiştirilir -- state.linear_velocity.y bu
## fonksiyon tarafından HİÇBİR ZAMAN okunmaz/yazılmaz, düşme fiziği bu
## kuvvetten etkilenmez.
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not GrayboxConfig.ENABLED or not GrayboxConfig.MERGE_ASSIST_ENABLED:
		return
	if _is_merging or not _merge_armed or freeze or is_fish_part:
		return
	if _assist_time_used >= GrayboxConfig.MERGE_ASSIST_MAX_DURATION:
		return
	if abs(state.linear_velocity.y) > GrayboxConfig.MERGE_ASSIST_MIN_SPEED_TO_ARM:
		return  # hâlâ düşüyor -- assist yalnızca yerleşmeye yakın/durmuş organizmalara uygulanır
	var target: Organism = _find_nearest_assist_target()
	if target == null:
		return
	var dx: float = target.global_position.x - global_position.x
	if abs(dx) < 1.0:
		return
	var direction: float = signf(dx)
	var current_vx: float = state.linear_velocity.x
	# Hız-sınırlı: yatay hız zaten hedef yöndeki MAX_SPEED'e ulaştıysa/geçtiyse
	# BİR DAHA kuvvet uygulanmaz -- teleport/aşırı hızlanma yok, motorun kendi
	# sürtünme/temas tepkisi geri kalanı normal şekilde yönetir.
	if direction > 0.0 and current_vx >= GrayboxConfig.MERGE_ASSIST_MAX_SPEED:
		return
	if direction < 0.0 and current_vx <= -GrayboxConfig.MERGE_ASSIST_MAX_SPEED:
		return
	# Kuvvet bu gövdenin KENDİ kütlesiyle (F=kütle*ivme) orantılı uygulanır --
	# effective_mass() ile büyüyen/küçülen graybox organizmaları AYNI ivmeyi
	# (MERGE_ASSIST_ACCEL) yaşar, kütleden BAĞIMSIZ tutarlı bir "çekim hissi"
	# için (bkz. GrayboxConfig effective_mass/MERGE_ASSIST_ACCEL notu).
	var force: Vector2 = Vector2(direction * GrayboxConfig.MERGE_ASSIST_ACCEL * mass, 0.0)
	state.apply_central_force(force)
	_assist_time_used += state.step

## _physics_process için: KENAR-KENAR boşluğu MERGE_ASSIST_GAP altında olan
## (ama henüz ÇAKIŞMAYAN -- boşluk > 0), aynı stage_id grubundaki
## (organism_stage_%d), henüz merge olmayan/armed olmuş, balık-parçası
## OLMAYAN en yakın organizmayı döndürür; yoksa null. Kenar-kenar boşluk
## kullanımının gerekçesi için bkz. graybox_config.gd MERGE_ASSIST_GAP notu.
func _find_nearest_assist_target() -> Organism:
	var self_radius: float = (collision_shape.shape as CircleShape2D).radius if collision_shape and collision_shape.shape is CircleShape2D else 16.0
	var closest: Organism = null
	var closest_gap: float = GrayboxConfig.MERGE_ASSIST_GAP
	for node in get_tree().get_nodes_in_group("organism_stage_%d" % stage_id):
		if node == self or not (node is Organism):
			continue
		var other: Organism = node as Organism
		if other._is_merging or not other._merge_armed or other.freeze or other.is_fish_part:
			continue
		var other_radius: float = (other.collision_shape.shape as CircleShape2D).radius if other.collision_shape and other.collision_shape.shape is CircleShape2D else 16.0
		var center_dist: float = global_position.distance_to(other.global_position)
		var gap: float = center_dist - (self_radius + other_radius)
		if gap > 0.0 and gap < closest_gap:
			closest_gap = gap
			closest = other
	return closest

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
	# DÜZELTME (kullanıcı: "görsel-collision uyumu"): yarıçap artık TEK, merkezi
	# GrayboxConfig.effective_radius() kaynağından okunur -- ENABLED=false iken
	# bu, eski "stage.radius * tier_size_multiplier" hesabıyla BİREBİR aynı
	# değeri döner (üretim davranışı byte-level değişmez); ENABLED iken ise
	# büyütülmüş graybox yarıçapını döner ve bu TEK değer collision shape'i,
	# organism_visual.gd'nin görsel boyutunu, merge-assist mesafesini (bu
	# shape'in radius'undan okunur) VE landing-marker raycast'ini (gerçek
	# collision gövdesine çarptığından dolaylı olarak) besler.
	var effective_radius: float = GrayboxConfig.effective_radius(stage_id, tier)
	if collision_shape:
		var instance_shape := CircleShape2D.new()
		instance_shape.radius = effective_radius
		# fix: "flushing queries" motor uyarısı (final rapor bilinen sorun --
		# ÖNCEDEN VAR OLAN, üretim koduyla paylaşılan bir hata; ENABLED=false
		# iken de aynen düzelir). Bu atama bazen fizik sorgu-flush penceresi
		# içinde (bir merge sonucu instantiate edilirken, body_entered sinyal
		# dispatch'i ortasında) senkron çalışıyordu ve "Can't change this state
		# while flushing queries" uyarısını tetikliyordu. set_deferred() ile
		# (spawner.gd'nin collision_layer/mask için ZATEN kullandığı, kanıtlanmış
		# AYNI desen) kare sonuna ertelenir -- NİHAİ değer/davranış DEĞİŞMEZ,
		# yalnızca zamanlama fizik motoru için güvenli hale gelir.
		collision_shape.set_deferred("shape", instance_shape)
	# V4 core-loop/graybox (madde 1 -- "gerekliyse kütle hesabı"): SADECE
	# ENABLED iken, büyüyen collision/görsel boyutla orantılı kütle uygulanır
	# (bkz. GrayboxConfig.effective_mass notu). ENABLED=false iken bu satır hiç
	# çalışmaz -- Organism.tscn'in mevcut/DEĞİŞMEMİŞ mass=1.0 varsayılanı
	# üretimde AYNEN korunur. set_deferred() kullanılır -- flushing-queries
	# riskiyle AYNI sebep/AYNI desen (RigidBody2D.mass da fizik sunucusuna
	# senkronize edilen bir özelliktir).
	if GrayboxConfig.ENABLED:
		set_deferred("mass", GrayboxConfig.effective_mass(stage_id, tier))
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
	# feat: improve mobile scale and scoring feedback (Bölüm C) -- combo_count
	# sabit 0 gecilir: skor vermeyen bu birlesme GameManager'in yetkili kombo
	# sayacini HICBIR sekilde ilerletmez/bozmaz (bkz. game_manager.gd
	# _advance_combo, yalnizca add_merge_reward icinden cagrilir).
	GameManager.organism_merged.emit(contact_point, stage_id, combined_is_bonus, 0, false, 0)

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
	# fix: "flushing queries" motor uyarısı (KÖK NEDEN -- önceki rapordan daha
	# geniş kapsamlı: yalnızca organism.gd _apply_stage()'in collision shape
	# ataması DEĞİL, add_child()'in KENDİSİ de -- yeni eklenen CollisionShape2D
	# çocuğunun ağaca girerken fizik sunucusuna kendini KAYDETMESİ -- bu merge
	# body_entered sinyal dispatch'i/sorgu-flush penceresi içinde SENKRON
	# çalıştığında AYNI motor uyarısını tetikliyordu; izole diagnostic script'te
	# doğrulandı). Çözüm: add_child()'in KENDİSİ ertelenir (call_deferred) --
	# böylece bu yeni organizmanın TÜM _ready()'si (collision shape, mass,
	# gravity_scale, lock_rotation dahil) flush penceresi dışında, güvenli
	# bir karede çalışır. `position` (global_position DEĞİL) add_child'dan
	# ÖNCE atanır -- OrganismContainer (Main'in altında, transform'suz düz bir
	# Node) ve Main (Node2D, konum (0,0)) zincirinde local position=global
	# position olduğundan bu, ağaca henüz girmemiş bir düğüm için de doğru
	# dünya konumunu verir; add_child sonrası AYRICA bir global_position
	# ataması gerekmez.
	completed.position = contact_point
	container.call_deferred("add_child", completed)

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
		grown.born_from_evolution = true
		# fix: "flushing queries" -- bkz. _perform_fish_part_merge'deki AYNI notu
		# (add_child()'in kendisi ertelenir, position add_child'dan önce atanır).
		grown.position = contact_point
		container.call_deferred("add_child", grown)
		return

	# gameplay/core-loop-v4 "Evrim Laboratuvarı" vertical slice: bu görev
	# kapsamı SADECE ilk üç aşamayı (0 Virüs, 1 Bakteri, 2 Tek Hücreli)
	# oynanabilir kılıyor -- iki Tek Hücreli birleşince T-Rex'in (son aşama)
	# davranışıyla AYNI desenle evrim burada durur (ödül YİNE verildi, yukarı
	# add_merge_reward çağrısı zaten çalıştı). Zincirin geri kalanı (id 3+)
	# bu görevin kapsamı dışında bırakıldı, veri/kod silinmedi.
	if merged_stage_id >= OrganismTypes.VERTICAL_SLICE_FINAL_STAGE_ID:
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
	evolved.born_from_evolution = true
	# fix: "flushing queries" -- bkz. _perform_fish_part_merge'deki AYNI notu
	# (add_child()'in kendisi ertelenir, position add_child'dan önce atanır).
	evolved.position = contact_point
	container.call_deferred("add_child", evolved)

## Solucan büyüme mekaniği: sadece OrganismTypes.TIERED_GROWTH_STAGE_ID
## aşamasında VE iki taraf da hâlâ tier 0 ise true döner (→ büyüme, evrim
## yok). Diğer tüm durumlarda false döner (→ normal evrim, eski davranış).
func _should_grow_instead_of_evolve(other: Organism) -> bool:
	return stage_id == OrganismTypes.TIERED_GROWTH_STAGE_ID and tier == 0 and other.tier == 0
