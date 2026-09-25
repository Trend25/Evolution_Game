extends Polygon2D
## OrganismVisual — UC-01/UC-02 görselleştirmesi: ebeveyn Organism'in
## stage_id'sine göre, o evrim aşamasının rengiyle VE gerçek türüne
## benzeyen bir siluet çizer. Tamamen prosedüreldir (dışarıdan görsel varlık
## gerektirmez); oynanış mantığına dokunmaz, sadece Coder'ın ürettiği veriyi
## (Organism.stage_id, OrganismTypes.get_stage) okuyup görselleştirir.
## Gerçek sprite/skin hazır olduğunda bu Polygon2D bir Sprite2D/
## AnimatedSprite2D ile değiştirilebilir.
##
## NOT (kullanıcı isteği — "gerçek yılan solucan amip ... gibi olmalı"): Dört
## ayrı gövde tipi (body_type) var:
##  - "blob": eski davranış — daire + açıya göre çıkıntılar (bumps). Artık
##    hiçbir aşama tarafından kullanılmıyor ama geriye dönük/varsayılan
##    davranış olarak korunuyor (bkz. _ready'deki `_:` dalı).
##  - "cell": Tek Hücreli/Amip için — yarı saydam, çekirdekli VE sürekli
##    şekil değiştiren ("nabız atan" değil, kenarları dalgalanan) canlı bir
##    hücre/uzaylı-organizma hissi verir.
##  - "segmented": Solucan/Yılan için — düz bir oval yerine, hafifçe kıvrılan
##    (S eğrisi) bir omurga boyunca daralan/genişleyen gerçek bir solucan/
##    yılan gövde silueti üretir; ayrıca gövde boyunca halka izleri ekler.
##  - "critter": Balık/Kurbağa/Kertenkele/Kuş/Memeli/Dinozor için — YENİ.
##    Kullanıcı geri bildirimi ("şekiller yuvarlaklarda oluşuyor ... bu
##    şekilleri nasıl benzetmeliyiz"): eski "blob" yaklaşımı (tek çokgenin
##    kenarını yumuşak çıkıntılarla şişirmek) bacak/kanat/gaga gibi AYRI
##    hissedilmesi gereken özellikleri belirsiz tümsekler olarak gösteriyordu.
##    Kullanıcının beğendiği virüs şekli bunun yerine gövdeye AYRI, belirgin
##    parçalar (dikenler) ekliyordu — "critter" bu tekniği genelleştirir:
##    düz bir elips gövdeye, ayrı Polygon2D/Line2D parçalar olarak "wedge"
##    (üçgen — kuyruk/yüzgeç/gaga/sırt dikeni) ve "limb" (oval — bacak/kanat/
##    kol, ucunda opsiyonel "pati" dairesiyle) eklenir. Bu, türün siluetini
##    çok daha net okunur kılar (bkz. STAGE_SHAPES).

# UI/UX bugfix (kullanıcı isteği: "canlılar birkaç renkte olmalı, aynı
# renkliler [birleşmeye] değerli olmalı" — yani hangi canlıların birbiriyle
# eşleştiğini renkten anında anlayabilmeli). Önceki palet, komşu aşamalar
# arasında yumuşak/kademeli bir geçiş yapıyordu (ör. 5-6-7 birbirine çok
# yakın turuncu-kırmızı tonlarıydı) — bu da "hangi ikisi birleşecek?" sorusunu
# gözle cevaplamayı zorlaştırıyordu. Artık her aşama, renk çemberinde birbirine
# geniş açıyla ayrılmış, belirgin şekilde FARKLI bir renk alıyor; böylece aynı
# renk = aynı tür = birleşir ilişkisi ilk bakışta net oluyor. Genel "soğuktan
# sıcağa, sondan derin/asil bir tona" evrim hissi yine korunuyor.
const STAGE_COLORS: Array[Color] = [
	Color(0.24, 0.72, 0.62),  # 0 Virüs — mint/teal (V02: "canlının laboratuvara aktarılması" ışık rengiyle uyumlu)
	Color(0.55, 0.85, 0.70),  # 1 Bakteri — açık, yumuşak mint-yeşil (Virüs'ten belirgin ama aynı aile)
	# 2: bu dilimde İKİ farklı anlamda kullanılır -- (a) LAB_VISUALS_ENABLED
	# iken Tek Hücreli (bkz. LAB_TEK_HUCRELI_SHAPE, _ready dalı) rengi olarak,
	# Virüs/Bakteri'yle AYNI mint-teal ailesinde ama belirgin şekilde daha
	# koyu/mavi bir ton (kullanıcı: "eski fare benzeri asset olmamalı, V02'deki
	# tasarımı kullan" -- eski hardal sarısı, sprite'a özgü olup bu aileye hiç
	# uymuyordu); (b) bu dilimde erişilemeyen eski Solucan verisi (aşağıdaki
	# STAGE_SHAPES[2]) için hâlâ "hardal sarısı" olarak yorumlanabilir ama o
	# yol zaten hiç ÇAĞRILMIYOR (MAX_SPAWNABLE/VERTICAL_SLICE_FINAL_STAGE_ID
	# sınırları dışında).
	Color(0.16, 0.60, 0.70),  # 2 Tek Hücreli (lab) / eski Solucan (erişilemez)
	Color(0.25, 0.55, 0.85),  # 3 Balık — gökyüzü mavisi
	Color(0.90, 0.55, 0.15),  # 4 Kurbağa — turuncu
	Color(0.80, 0.22, 0.22),  # 5 Kertenkele — kırmızı
	Color(0.55, 0.30, 0.75),  # 6 Yılan — mor
	Color(0.85, 0.35, 0.60),  # 7 Kuş — pembe/magenta
	Color(0.50, 0.35, 0.20),  # 8 Memeli — kahverengi
	Color(0.28, 0.10, 0.32),  # 9 Dinozor (T-Rex) — koyu bordo/lacivert (asil final tonu)
]

# Bonus Sistemi: Spawner'ın işaretlediği özel, yüksek puanlı canlıların rengini
# bu altın tona doğru çeker (bkz. _ready / BONUS_TINT_STRENGTH).
const BONUS_TINT_COLOR: Color = Color(1.0, 0.85, 0.25)
const BONUS_TINT_STRENGTH: float = 0.55

# Gözler ve kontur (tüm gövde tiplerinde ortak kullanılır).
# Onüçüncü geri bildirim ("şekillerimiz çok çirkin" — "genel stil ucuz/amatör
# duruyor", yön: "yumuşak/sevimli çizgi film tarzı"): göz büyütüldü + pupil
# hafifçe kaydırılıp parıltı (sparkle) eklendi; kontur incelip yumuşatıldı
# (daha az koyu/sert bir çizgi — bkz. _add_eye, OUTLINE_* ve aşağıdaki
# GLOSS_*/BLUSH_*/WEDGE_TIP_ROUND_RATIO sabitleri).
const EYE_WHITE_COLOR: Color = Color(0.98, 0.98, 0.96)
const EYE_PUPIL_COLOR: Color = Color(0.08, 0.08, 0.1)
const EYE_RADIUS_RATIO: float = 0.15
const EYE_INSET_RATIO: float = 0.62
const EYE_SPACING_RATIO: float = 0.38
const OUTLINE_DARKEN_RATIO: float = 0.22
const OUTLINE_WIDTH: float = 2.2
# Pupil, gözün merkezinden hafifçe kaydırılır ("bakan" bir canlı hissi) ve
# üstüne iki küçük beyaz parıltı eklenir — sevimli maskot çizim tekniği.
const PUPIL_OFFSET_RATIO: Vector2 = Vector2(0.15, 0.08)
const SPARKLE_BIG_RADIUS_RATIO: float = 0.22
const SPARKLE_BIG_OFFSET_RATIO: Vector2 = Vector2(-0.22, -0.24)
const SPARKLE_SMALL_RADIUS_RATIO: float = 0.10
const SPARKLE_SMALL_OFFSET_RATIO: Vector2 = Vector2(0.28, 0.22)

# "Gloss" (parlaklık) vurgusu: gövdenin üst-orta bölgesine, "jöle/plastik"
# hissi veren yumuşak, yarı saydam bir parlaklık ekler. Godot'ta gerçek bir
# radyal gradyan için shader gerekir; bunun yerine üst üste binen, küçüldükçe
# opaklaşan birkaç beyaz elips ile YAKLAŞIK bir yumuşak geçiş üretilir (bkz.
# _add_gloss_highlight).
const GLOSS_OFFSET_X_RATIO: float = -0.12
const GLOSS_OFFSET_Y_RATIO: float = -0.48
const GLOSS_RADIUS_X_RATIO: float = 0.4
const GLOSS_RADIUS_Y_RATIO: float = 0.24
const GLOSS_LAYERS: Array[Dictionary] = [
	{"scale": 1.0, "alpha": 0.10},
	{"scale": 0.6, "alpha": 0.16},
	{"scale": 0.28, "alpha": 0.26},
]

# "Allık" (blush): gözlerin hemen altına, gövde rengiyle karışmayan sabit
# sıcak bir pembe ton — aynı katmanlı-elips tekniğiyle yumuşak kenarlı.
const BLUSH_COLOR: Color = Color(1.0, 0.43, 0.47)
const BLUSH_LAYERS: Array[Dictionary] = [
	{"scale": 1.0, "alpha": 0.08},
	{"scale": 0.6, "alpha": 0.14},
	{"scale": 0.32, "alpha": 0.2},
]
const BLUSH_RADIUS_RATIO: float = 0.95    # eye_radius'a oranla
const BLUSH_DOWN_OFFSET_RATIO: float = 1.3 # eye_radius'a oranla, gözün "altına" kayma

# "cell" gövde tipi (Tek Hücreli/Amip): yarı saydamlık, çekirdek ve sürekli
# kenar dalgalanması ile "canlı, alien bir mikroorganizma" hissi verir.
const CELL_ALPHA: float = 0.88
const CELL_NUCLEUS_COLOR_DARKEN: float = 0.45
const CELL_NUCLEUS_RADIUS_RATIO: float = 0.28
const CELL_WOBBLE_SPEED: float = 1.6
const CELL_WOBBLE_STRENGTH: float = 0.35

# "segmented" gövde tipi (Solucan/Yılan): omurga (spine) boyunca daralan/
# genişleyen kıvrık bir "tüp" siluet + halka izleri + tür-özgü küçük ayrıntı
# (Solucan: anten, Yılan: çatal dil — bkz. _add_segment_accessory).
const SEGMENT_CURVE_SAMPLES: int = 40
const SEGMENT_RING_COUNT: int = 5
const SEGMENT_RING_DARKEN: float = 0.25
const SEGMENT_RING_WIDTH: float = 2.0
const ANTENNA_LENGTH_RATIO: float = 0.35
const ANTENNA_SPREAD_RATIO: float = 0.18
const ANTENNA_WIDTH: float = 1.5
const TONGUE_LENGTH_RATIO: float = 0.28
const TONGUE_FORK_LENGTH_RATIO: float = 0.12
const TONGUE_FORK_SPREAD_RATIO: float = 0.08
const TONGUE_WIDTH: float = 1.5
const TONGUE_COLOR: Color = Color(0.86, 0.16, 0.16, 0.9)

# "critter" gövde tipi (Balık/Kurbağa/Kertenkele/Kuş/Memeli/Dinozor): düz bir
# elips gövdeye ayrı "wedge" (üçgen) ve "limb" (oval) parçalar ekler (bkz.
# dosya başı UI/UX notu, _add_wedge, _add_limb).
const WEDGE_DARKEN_RATIO: float = 0.06
const WEDGE_ACCENT_COLOR: Color = Color(0.96, 0.75, 0.24)  # Kuş gagası gibi vurgu parçaları
# Onüçüncü geri bildirim ("çok çirkin/ucuz duruyor" — sivri üçgen parçalar):
# kuyruk/kanat/gaga gibi wedge'lerin sivri ucu artık yuvarlatılıyor (bkz.
# _add_wedge, _quad_bezier_points) — "w" (genişlik) oranına göre ne kadar
# yuvarlanacağını belirler.
const WEDGE_TIP_ROUND_RATIO: float = 0.32
const WEDGE_TIP_CURVE_SEGMENTS: int = 10
const LIMB_DARKEN_RATIO: float = 0.06
const FOOT_DARKEN_RATIO: float = 0.18
const PART_OUTLINE_WIDTH_RATIO: float = 0.6
# Onikinci geri bildirim ("şekiller biraz daha benzesin"): "pati/pençe"
# parmakları (bkz. _add_limb toes bayrağı).
const TOE_SPREAD_RADIANS: float = 0.42
const TOE_LENGTH_RATIO: float = 0.65
const TOE_WIDTH_RATIO: float = 0.22

# Kurbağa için özel göz stili: gözler düz gövde yüzeyi yerine dışa taşan
# yuvarlak "kabartıların" üstüne oturur (bkz. _add_bulging_eyes).
const BULGE_EYE_INSET_RATIO: float = 0.72
const BULGE_EYE_SPACING_SCALE: float = 1.15
const BULGE_EYE_BUMP_RADIUS_RATIO: float = 0.24

# UC-01 ek mekanik (kullanıcı isteği — "balık 2 parçadan oluşur, her parça
# ayrı ayrı gelir, fanusta birleştirilir"): Bu iki dropped parça artık tam bir
# balık yerine, ortası dişli/çentikli bir kesim hattına sahip TAMAMLAYICI
# yarımlar olarak çizilir (bkz. _build_fish_part) — böylece görsel olarak da
# "iki yapboz parçası birleşiyor" hissi verir (eskiden ikisi de aynı tam
# balığı çiziyordu, bu yanıltıcıydı).
const FISH_STAGE_ID: int = 3
const FISH_CUT_TEETH_COUNT: int = 3
const FISH_CUT_DEPTH_RATIO: float = 0.11

# Cowork uygulama talimati (Faz 2 -- CLAUDE_COWORK_PROMPT_TR.md, README_TR.md,
# evrim-godot-assets-stage-00-07.zip/organism_assets.json ile birebir):
# sanatcidan gercek cizim gelen asamalar icin prosedurel Polygon2D yerine
# merkezlenmis bir Sprite2D kullanilir (bkz. _build_sprite_visual /
# _add_scaled_sprite). Balik'in PARCALARI (is_fish_part) bu sozlukte degil,
# ayri FISH_FRONT_TEXTURE/FISH_BACK_TEXTURE sabitlerinden gelir (asagida).
# Dosya yukleme her zaman preload() ile (parse zamaninda, sabit) yapilir;
# _ready() icinde asla load() cagrilmaz.
#
# art/stage-08-09: Memeli (8) ve T-Rex (9) sanati geldi (bkz.
# evrim-godot-assets-stage-00-09.zip/organism_assets.json) -- sozluge
# EKLENDI, stage_id 8/9 artik bu blok araciligiyla gercek PNG kullaniyor.
# Prosedürel "critter" cizimi (asagidaki `match body_type` dali,
# STAGE_SHAPES[8]/[9]) BILEREK SILINMEDI -- bir stage_id bu sozlukten
# cikarilirsa (ör. sanat regresyonu/geri alma) otomatik olarak o prosedürel
# cizime geri döner, hicbir kod degisikligi gerekmez. Stage 0-7 satirlari
# ve collision/merge/skor/spawn mantigi bu commit'te DOKUNULMADI.
const STAGE_TEXTURES: Dictionary = {
	0: preload("res://assets/organisms/stage_00_cell.png"),
	1: preload("res://assets/organisms/stage_01_amoeba.png"),
	2: preload("res://assets/organisms/stage_02_worm.png"),
	3: preload("res://assets/organisms/stage_03_fish_complete.png"),
	4: preload("res://assets/organisms/stage_04_frog.png"),
	5: preload("res://assets/organisms/stage_05_lizard.png"),
	6: preload("res://assets/organisms/stage_06_snake.png"),
	7: preload("res://assets/organisms/stage_07_bird.png"),
	8: preload("res://assets/organisms/stage_08_mammal.png"),
	9: preload("res://assets/organisms/stage_09_trex.png"),
}

# Balik'in AYRI ON/ARKA parca gorselleri (README_TR.md "Kritik balik notu"):
# ucu gorsel de (on/arka/tam) AYNI 192x112 tuval ve merkez pivotu paylasir,
# bu yuzden _add_scaled_sprite ile TAMAMLANMIS Balik ile birebir ayni
# olcekleme mantigi kullanilir -- ayrica kirpma/yeniden-merkezleme YOK.
const FISH_FRONT_TEXTURE: Texture2D = preload("res://assets/organisms/stage_03_fish_front.png")
const FISH_BACK_TEXTURE: Texture2D = preload("res://assets/organisms/stage_03_fish_back.png")

# DÜZELTME (2026-09-24, V02 vertical slice onay turu -- kullanıcı: "'Tek
# Hücreli' eski fare benzeri asset OLMAMALI, V02'deki asimetrik/yarı saydam/
# çekirdekli tasarımı kullan"): id=2 ARTIK bu sprite'ı KULLANMIYOR (aşağıdaki
# LAB_TEK_HUCRELI_SHAPE ile aynı prosedürel "cell" ailesine geçti, bkz.
# _ready dalı). Sabit ve preload SİLİNMEDİ -- STAGE_TEXTURES sözlüğünde id=0
# hâlâ bu dosyayı kullanıyor (bu dilimde erişilemez ama üretim/gelecek
# genişleme verisiyle uyumluluk için dokunulmadı) ve LAB_VISUALS_ENABLED=false
# durumunda (eski graybox/üretim yolu) hiçbir şey değişmedi.
const LAB_TEK_HUCRELI_TEXTURE: Texture2D = preload("res://assets/organisms/stage_00_cell.png")

# DÜZELTME (2026-09-24, V02 onay turu): Tek Hücreli'nin YENİ prosedürel "cell"
# şekli -- Virüs (3 çıkıntı, hafif asimetri) ve Bakteri'den (1 çıkıntı/kuyruk,
# kapsül) GÖRSEL OLARAK daha KARMAŞIK/OLGUN okunsun diye (evrimsel ilerleme
# hissi): daha fazla ve daha uzun çıkıntı (6 -- silia/kamçı kümesi hissi),
# daha belirgin/çok sayıda yüzey kabartması, hafif daha az yassı bir gövde.
# no_face:true (Virüs/Bakteri ile AYNI kural -- kullanıcı: "minimal/nötr,
# maskot gibi olmasın"). Boyut STAGE_SHAPES/STAGE_COLORS'tan DEĞİL, doğrudan
# GrayboxConfig.effective_radius(2)'ten (108-118px hedefiyle zaten örtüşen
# 56px taban yarıçap) gelir -- TEK merkezi kaynak korunur.
# DÜZELTME (V02 ikinci düzeltme turu -- kullanıcı: "Tek Hücreli: asimetrik
# sitoplazma, belirgin çekirdek ve organel noktaları", ve üçünün "aynı
# damlanın renk varyasyonu" gibi görünmemesi): x/y ölçeği artık BARİZ
# ASİMETRİK (1.08/0.92 -- neredeyse Virüs'le özdeş -- yerine 1.20/0.82),
# çekirdek BÜYÜK ve MERKEZ-DIŞI (nucleus_offset_ratio, Virüs'ün merkezdeki
# küçük çekirdeğinden VE Bakteri'nin çekirdeksizliğinden bariz farklı), ve
# 3 küçük "organel" noktası eklendi (çekirdekten ayrı, farklı boyut/alfa) --
# bu üçü BİRLİKTE, renk hiç görülmese bile Tek Hücreli'yi diğer ikisinden
# ayırt edilebilir kılar.
const LAB_TEK_HUCRELI_SHAPE: Dictionary = {"body_type": "cell", "x_scale": 1.20, "y_scale": 0.82, "no_face": true,
	"nucleus_offset_ratio": Vector2(-0.24, 0.20), "nucleus_radius_ratio": 0.34,
	"organelles": [
		{"offset_ratio": Vector2(0.32, -0.22), "radius_ratio": 0.10, "darken": 0.15},
		{"offset_ratio": Vector2(0.12, 0.36), "radius_ratio": 0.07, "darken": 0.25},
		{"offset_ratio": Vector2(-0.34, -0.30), "radius_ratio": 0.08, "darken": 0.05},
	],
	"bumps": [
	{"angle": 0.5, "width": 0.7, "height": 0.20},
	{"angle": 2.0, "width": 0.6, "height": 0.24},
	{"angle": -1.6, "width": 0.55, "height": 0.16},
	{"angle": -0.4, "width": 0.5, "height": 0.12},
], "protrusions": [
	{"angle": 0.2, "len": 0.36, "curve": 0.16},
	{"angle": 1.1, "len": 0.40, "curve": -0.14},
	{"angle": 1.9, "len": 0.30, "curve": 0.20},
	{"angle": 2.8, "len": 0.34, "curve": -0.18},
]}

# Görsel cila (visual-polish/stage-readability): Stage 0-7 normal sprite
# ölçeklemesi ÖNCEKİ (tuval genişliğine göre) haliyle korunuyor -- bkz.
# _add_scaled_sprite. Yalnızca Balık ön/arka parçaları, okunabilirlik
# şikayeti üzerine ("tek bakışta ayırt edilecek büyüklükte olsun"), bu
# temel ölçeğin üzerine minimal bir `extra_scale` çarpanı alır (bkz.
# _build_sprite_fish_part, FISH_PART_EXTRA_SCALE) -- ön ve arka AYNI
# çarpanı kullanır (ikisinin tuvali aynı boyutta olduğundan kesim hattı
# hizası bozulmaz), ~%64-66 görünür doluluk hedefiyle ölçüldü (bkz. rapor).
# Tam Balık'ın (STAGE_TEXTURES[3]) ölçeği bu çarpandan ETKİLENMEZ.
const FISH_PART_EXTRA_SCALE: float = 1.40

# Bonus Sistemi (editör notu — erişilebilirlik): renk değişimine (altın ton)
# ek olarak, renk körü oyuncular da ayırt edebilsin diye gövdenin arkasında
# sürekli nabız atan yarı saydam bir hale/halka gösterilir.
# Görsel cila (visual-polish/stage-readability): eski düz/opak disk yerine,
# gövdenin arkasında yumuşak, altın renkli bir "halka/glow" -- katmanlı,
# gitgide saydamlaşan ince Line2D çemberler ile (bkz. GLOSS_LAYERS/
# BLUSH_LAYERS ile aynı "gerçek radyal gradyan yerine üst üste katman"
# tekniği). Merkez (gövdenin hemen dışı) kasıtlı olarak en soluk katmanı
# taşır; bant ortasında en belirgin katman var -- düz bir dolgu değil,
# gerçek bir "halka" hissi için.
const BONUS_HALO_COLOR: Color = Color(1.0, 0.85, 0.35)
const BONUS_HALO_BASE_SCALE: float = 1.22
const BONUS_HALO_PULSE_SCALE: float = 1.30
const BONUS_HALO_PULSE_DURATION: float = 0.9
const BONUS_HALO_RING_LAYERS: Array[Dictionary] = [
	{"scale": 1.05, "alpha": 0.09, "width_ratio": 0.09},
	{"scale": 1.14, "alpha": 0.20, "width_ratio": 0.13},
	{"scale": 1.22, "alpha": 0.10, "width_ratio": 0.10},
]

# Her aşama için siluet tarifi.
# "blob" tipinde (artık kullanılmıyor, geriye dönük varsayılan): x_scale/
# y_scale gövdeyi yönlü esnetir, bumps açıya göre yumuşak dışa çıkıntılar ekler.
# "segmented" tipinde: length/wave/head-tail genişlik oranları omurgayı tarif
# eder (bkz. _spine_sample); antenna/tongue tür-özgü ayrıntı ekler.
# "critter" tipinde: x_scale/y_scale düz elips gövdeyi esnetir; wedges (üçgen)
# ve limbs (oval, opsiyonel "foot") ayrı ekli parçalardır — her biri gövde
# yüzeyindeki "angle" açısından, "dir" yönünde "len"/"w" oranlarında uzanır.
# eye_style: "bulge" ise gözler _add_bulging_eyes ile çizilir.
# Açı 0=sağ, PI/2=aşağı, PI=sol, -PI/2=yukarı.
const STAGE_SHAPES: Array[Dictionary] = [
	# 0 Virüs — gameplay/core-loop-v4 "Evrim Laboratuvarı" V02 tasarımı:
	# asimetrik, yarı saydam gövde + görülebilir bir iç çekirdek + ince,
	# yuvarlak uçlu çıkıntılar (spikes DEĞİL) + YÜZ YOK (kullanıcı: "minimal/
	# nötr yüz, okul öncesi maskot gibi görünmemeli"). "cell" gövde-tipini
	# (yarı saydamlık/çekirdek/dalgalanma) paylaşır ama no_face:true ile
	# _add_face çağrısı atlanır, protrusions ile ayrı ince Line2D çıkıntılar
	# eklenir (bkz. _ready dalı, _add_thin_protrusions).
	# DÜZELTME (V02 ikinci düzeltme turu -- kullanıcı: "Virüs: küçük kapsül/
	# zar ve belirgin çıkıntılar", ve üç aşamanın "aynı damlanın renk
	# varyasyonu" gibi görünmemesi): çekirdek artık KÜÇÜK ve TAM MERKEZDE
	# (viral kapsid çekirdeği hissi -- nucleus_offset_ratio=ZERO,
	# nucleus_radius_ratio küçük) -- Bakteri'nin (çekirdeksiz) ve Tek
	# Hücreli'nin (büyük, MERKEZ-DIŞI) çekirdeğinden bariz farklı. Çıkıntılar
	# düşük "curve" ile DAHA DÜZ/sert -- gerçek diken (spike) hissi, Tek
	# Hücreli'nin kıvrık/organik çıkıntılarından ayrışsın diye.
	{"body_type": "cell", "x_scale": 1.0, "y_scale": 0.96, "no_face": true,
		"nucleus_offset_ratio": Vector2(0.0, 0.0), "nucleus_radius_ratio": 0.16,
		"bumps": [
		{"angle": 0.3, "width": 0.8, "height": 0.22},
		{"angle": 2.2, "width": 0.7, "height": 0.16},
		{"angle": -1.8, "width": 0.6, "height": 0.14},
	], "protrusions": [
		{"angle": 0.9, "len": 0.36, "curve": 0.04},
		{"angle": 2.6, "len": 0.32, "curve": -0.03},
		{"angle": -2.4, "len": 0.30, "curve": 0.05},
		{"angle": -1.1, "len": 0.34, "curve": -0.04},
		{"angle": 0.05, "len": 0.26, "curve": 0.03},
	]},
	# 1 Bakteri — hafif asimetrik kapsül/fasulye gövde + ince bir "flagella"
	# kuyruk + YÜZ YOK. DÜZELTME (V02 ikinci düzeltme turu): ÇEKİRDEKSİZ
	# bırakıldı (no_nucleus=true) -- prokaryot bir hücrenin gerçek çekirdeği
	# yoktur, ve bu Bakteri'yi Virüs'ün (küçük merkez çekirdek) ve Tek
	# Hücreli'nin (büyük merkez-dışı çekirdek) yanında ÜÇÜNCÜ, bariz şekilde
	# farklı bir siluet yapar -- yalnızca uzun kapsül gövde + tek kamçı kuyruk.
	{"body_type": "cell", "x_scale": 1.28, "y_scale": 0.8, "no_face": true, "no_nucleus": true,
		"bumps": [
		{"angle": 0.4, "width": 0.7, "height": 0.1},
		{"angle": -2.6, "width": 0.6, "height": 0.07},
	], "protrusions": [
		{"angle": 0.15, "len": 0.42, "curve": 0.06},
		{"angle": -3.0, "len": 0.14, "curve": -0.03},
	]},
	# 2 Solucan (kullanıcı bulgusu — şekil düzeltmesi): eski tail/head_width_ratio
	# (0.8/0.95) length_ratio'ya (3.2) göre çok genişti, bu da solucanı kısa/tombul
	# bir yumruya benzetiyordu. Artık belirgin şekilde ince ve uzun; baş ucunda
	# ince bir çift anten var (bkz. antenna, _add_segment_accessory).
	{"body_type": "segmented", "length_ratio": 4.6, "wave_amplitude_ratio": 0.22,
		"wave_count": 1.0, "wave_phase": 0.0, "head_width_ratio": 0.62, "tail_width_ratio": 0.3,
		"antenna": true,
		# Onikinci geri bildirim ("solucan biraz daha benzesin"): tekdüze
		# incelen bir tüp yerine, boyunca hafif periyodik "segment şişkinliği"
		# eklenir — gerçek bir tırtıl/solucan gövdesinin halka halka
		# görünümünü taklit eder (bkz. _spine_sample).
		"segment_bulge": 0.16, "segment_bulge_count": 5},
	# 3 Balık — "damla" (teardrop) gövde: ön (baş) tarafı daha dolgun, arka
	# (kuyruk) tarafı incelerek büyük kuyruk yüzgecine (sol) doğal biçimde
	# bağlanır + küçük sırt yüzgeci (üst) + göğüs yüzgeci (alt-sağ); baş
	# sağda. Bu SIRAYLA balık PARÇALARI için de kullanılır (bkz.
	# FISH_STAGE_ID, _build_fish_part — o taraf hâlâ düz elips kullanır).
	{"body_type": "critter", "teardrop": true, "front_x_scale": 1.32, "back_x_scale": 0.8,
		"x_scale": 1.0, "y_scale": 0.78, "face_angle": 0.0,
		"wedges": [
			{"angle": PI, "dir": PI, "len": 1.0, "w": 0.66},
			{"angle": -PI / 2.0 - 0.08, "dir": -PI / 2.0 - 0.3, "len": 0.4, "w": 0.24},
		],
		"limbs": [
			{"angle": 0.7, "dir": 1.2, "len": 0.3, "w": 0.15},
		]},
	# 4 Kurbağa — dört bacak (ikisi büyük arka, ikisi küçük ön), her birinin
	# ucunda "pati"; gerçek kurbağa gözleri gibi dışa taşan çıkık gözler
	# (eye_style: bulge — bkz. _add_bulging_eyes). Baş yukarı bakar.
	{"body_type": "critter", "x_scale": 1.15, "y_scale": 0.88, "face_angle": -PI / 2.0, "eye_style": "bulge",
		"limbs": [
			{"angle": PI / 2.0 - 0.8, "dir": PI / 2.0 - 0.95, "len": 0.68, "w": 0.4, "foot": true, "toes": true},
			{"angle": PI / 2.0 + 0.8, "dir": PI / 2.0 + 0.95, "len": 0.68, "w": 0.4, "foot": true, "toes": true},
			{"angle": PI / 2.0 - 0.24, "dir": PI / 2.0 - 0.55, "len": 0.32, "w": 0.22, "foot": true, "toes": true},
			{"angle": PI / 2.0 + 0.24, "dir": PI / 2.0 + 0.55, "len": 0.32, "w": 0.22, "foot": true, "toes": true},
		]},
	# 5 Kertenkele — "damla" gövde (ince/uzun) + çok belirgin ince/uzun kuyruk
	# (sol) + kısa burun (sağ) + dört ince bacak, hepsinin ucunda parmaklı
	# "pati". Kertenkele SLENDER, Dinozor İRİ/GÜÇLÜ kalsın diye (kullanıcı
	# bulgusu — ikisi çok benziyordu) gövde/bacak oranları belirgin inceltildi.
	{"body_type": "critter", "teardrop": true, "front_x_scale": 0.78, "back_x_scale": 0.92,
		"x_scale": 1.5, "y_scale": 0.52, "face_angle": 0.0,
		"wedges": [
			{"angle": PI, "dir": PI, "len": 1.5, "w": 0.22},
			{"angle": 0.05, "dir": 0.05, "len": 0.26, "w": 0.24},
		],
		"limbs": [
			{"angle": 0.72, "dir": PI / 2.0 - 0.2, "len": 0.4, "w": 0.13, "foot": true, "toes": true},
			{"angle": PI - 0.72, "dir": PI / 2.0 + 0.2, "len": 0.4, "w": 0.13, "foot": true, "toes": true},
			{"angle": 0.5, "dir": PI / 2.0 - 0.15, "len": 0.34, "w": 0.11, "foot": true, "toes": true},
			{"angle": PI - 0.5, "dir": PI / 2.0 + 0.15, "len": 0.34, "w": 0.11, "foot": true, "toes": true},
		]},
	# 6 Yılan — Solucan'dan daha uzun/daha dar, çok daha belirgin S kıvrımlı;
	# ağzından çatal bir dil çıkar (tongue — bkz. _add_segment_accessory).
	{"body_type": "segmented", "length_ratio": 5.2, "wave_amplitude_ratio": 0.55,
		"wave_count": 1.7, "wave_phase": 0.4, "head_width_ratio": 0.8, "tail_width_ratio": 0.16,
		"tongue": true},
	# 7 Kuş — "damla" gövde (baş tarafı incelmiş, kuyruk tarafı dolgun) + sarı
	# vurgu renkli gaga (accent: true) + kuyrukta üç üst üste tüy şekli + bir
	# kanat + parmaklı ince bacaklar (ayakta duran bir kuş hissi). Gaga
	# yönünde (sağa) bakar.
	{"body_type": "critter", "teardrop": true, "front_x_scale": 0.85, "back_x_scale": 1.05,
		"x_scale": 1.0, "y_scale": 1.12, "face_angle": 0.0,
		"wedges": [
			{"angle": 0.0, "dir": 0.0, "len": 0.42, "w": 0.28, "accent": true},
			{"angle": PI - 0.2, "dir": PI - 0.2, "len": 0.5, "w": 0.3},
			{"angle": PI, "dir": PI, "len": 0.58, "w": 0.28},
			{"angle": PI + 0.2, "dir": PI + 0.2, "len": 0.46, "w": 0.26},
		],
		"limbs": [
			{"angle": PI / 2.0 + 0.5, "dir": PI / 2.0 + 0.3, "len": 0.55, "w": 0.32},
			{"angle": PI / 2.0 - 0.15, "dir": PI / 2.0 - 0.05, "len": 0.3, "w": 0.09, "foot": true, "toes": true},
			{"angle": PI / 2.0 + 0.15, "dir": PI / 2.0 + 0.05, "len": 0.3, "w": 0.09, "foot": true, "toes": true},
		]},
	# 8 Memeli — yuvarlak gövde + iki kulak (üst) + kısa küt burun (sağ) +
	# küçük kuyruk (sol) + dört kısa bacak, hepsinin ucunda "pati" — gerçek
	# bir küçük memeli/ayı yavrusu siluet hissi (kullanıcı bulgusu: eskiden
	# sadece kulaklı bir daireydi, memeli gibi durmuyordu).
	{"body_type": "critter", "x_scale": 1.05, "y_scale": 1.0, "face_angle": 0.0,
		"wedges": [
			{"angle": 0.0, "dir": 0.0, "len": 0.22, "w": 0.4},
			{"angle": PI, "dir": PI, "len": 0.3, "w": 0.18},
		],
		"limbs": [
			{"angle": -PI / 2.0 - 0.5, "dir": -PI * 0.8, "len": 0.3, "w": 0.24},
			{"angle": -PI / 2.0 + 0.5, "dir": -PI * 0.2, "len": 0.3, "w": 0.24},
			{"angle": PI / 2.0 - 0.65, "dir": PI / 2.0 - 0.3, "len": 0.34, "w": 0.16, "foot": true},
			{"angle": PI / 2.0 + 0.65, "dir": PI / 2.0 + 0.3, "len": 0.34, "w": 0.16, "foot": true},
			{"angle": PI * 0.78, "dir": PI / 2.0 - 0.45, "len": 0.24, "w": 0.13, "foot": true},
			{"angle": PI * 1.22, "dir": PI / 2.0 + 0.45, "len": 0.24, "w": 0.13, "foot": true},
		]},
	# 9 Dinozor (T-Rex) — Kertenkele'den belirgin şekilde İRİ/DOLGUN gövde
	# (kullanıcı bulgusu: ikisi çok benziyordu) + kalın orta-uzunlukta kuyruk
	# (sol) + büyük çeneli kısa kafa (sağ) + iki minik ön kol (gerçek T-Rex
	# gibi cüce kollar) + iki kalın/parmaklı arka bacak. Baş sağda.
	{"body_type": "critter", "x_scale": 1.2, "y_scale": 1.18, "face_angle": 0.0,
		"wedges": [
			{"angle": PI, "dir": PI, "len": 1.1, "w": 0.62},
			{"angle": 0.0, "dir": 0.0, "len": 0.46, "w": 0.5},
		],
		"limbs": [
			{"angle": 0.1, "dir": 0.85, "len": 0.14, "w": 0.08},
			{"angle": 0.22, "dir": 1.05, "len": 0.12, "w": 0.07},
			{"angle": PI / 2.0 - 0.45, "dir": PI / 2.0 - 0.55, "len": 0.62, "w": 0.44, "foot": true, "toes": true},
			{"angle": PI / 2.0 + 0.6, "dir": PI / 2.0 + 0.65, "len": 0.6, "w": 0.46, "foot": true, "toes": true},
		]},
]

var _outline: Line2D = null
var _cell_cfg: Dictionary = {}     # "cell" gövdesi için _process'te dalgalanma hesaplarken okunur (asla mutate edilmez)
var _cell_radius: float = 16.0
var _cell_wobble_time: float = 0.0

func _ready() -> void:
	var organism: Node = get_parent()
	var stage_id: int = organism.get("stage_id")
	var stage: Dictionary = OrganismTypes.get_stage(stage_id)
	var tier: int = int(organism.get("tier"))
	# Onbirinci geri bildirim ("solucan küçük başlasın, üst üste geldikçe
	# büyümeye başlasın"): tier > 0 ise (bkz. organism.gd/organism_types.gd
	# TIERED_GROWTH_STAGE_ID notu) görsel boyut da fiziksel gövdeyle birebir
	# aynı oranda büyür — ikisi hep OrganismTypes'taki TEK bir çarpandan gelir.
	# DÜZELTME (kullanıcı: "görsel-collision uyumu"): TEK, merkezi
	# GrayboxConfig.effective_radius() kaynağından okunur -- organism.gd
	# _apply_stage() ile BİREBİR AYNI fonksiyon/formül (ENABLED=false iken
	# eski "stage.radius * tier_size_multiplier" ile sayısal olarak özdeş,
	# üretim davranışı değişmez; ENABLED iken collision shape'le TAM aynı
	# büyütülmüş yarıçap -- artık görsel boyut collision'dan asla sapmaz).
	var radius: float = GrayboxConfig.effective_radius(stage_id, tier)
	var is_bonus: bool = bool(organism.get("is_bonus"))
	var is_fish_part: bool = bool(organism.get("is_fish_part")) and stage_id == FISH_STAGE_ID
	var cfg: Dictionary = STAGE_SHAPES[stage_id % STAGE_SHAPES.size()]
	var body_type: String = String(cfg.get("body_type", "blob"))

	var base_color: Color = STAGE_COLORS[stage_id % STAGE_COLORS.size()]
	if is_bonus:
		# Bonus Sistemi: normal canlılardan ayırt edilsin diye altın rengine çekilir.
		base_color = base_color.lerp(BONUS_TINT_COLOR, BONUS_TINT_STRENGTH)

	if GrayboxConfig.ENABLED and GrayboxConfig.LAB_VISUALS_ENABLED and stage_id <= OrganismTypes.VERTICAL_SLICE_FINAL_STAGE_ID and not is_fish_part:
		# gameplay/core-loop-v4 "Evrim Laboratuvarı" V02 vertical slice: id
		# 0/1/2 (Virüs/Bakteri/Tek Hücreli) artık eski düz-renkli graybox
		# dairesi YERİNE gerçek "lab" görselini kullanır (bkz. _ready dalı
		# altındaki "cell"/sprite kolları, no_face/protrusions cfg alanları).
		# Bu dal, diğer stage_id'ler (bu dilimde erişilemez) ve balık parçaları
		# için eski graybox/sprite/prosedürel yollara HİÇ dokunmaz.
		# DÜZELTME (2026-09-24, V02 onay turu -- kullanıcı: "Tek Hücreli eski
		# fare benzeri asset OLMAMALI"): id=2 ARTIK stage_00_cell.png sprite'ını
		# KULLANMIYOR -- Virüs/Bakteri ile AYNI prosedürel "cell" çizim yolunu,
		# kendi (LAB_TEK_HUCRELI_SHAPE) şekil/çıkıntı yapılandırmasıyla
		# paylaşır (görsel-collision uyumu KORUNUR: radius hâlâ TEK merkezi
		# GrayboxConfig.effective_radius(2) kaynağından).
		var lab_cfg: Dictionary = LAB_TEK_HUCRELI_SHAPE if stage_id == OrganismTypes.VERTICAL_SLICE_FINAL_STAGE_ID else cfg
		_cell_cfg = lab_cfg
		_cell_radius = radius
		_cell_wobble_time = randf() * TAU
		var alpha: float = float(lab_cfg.get("alpha", CELL_ALPHA))
		polygon = _build_shape(lab_cfg, radius)
		color = Color(base_color.r, base_color.g, base_color.b, alpha)
		_outline = _add_outline(base_color)
		# DÜZELTME (V02 İKİNCİ düzeltme turu -- madde 3: "Virüs, Bakteri ve Tek
		# Hücreli aynı damlanın renk varyasyonu olmamalı ... Silüetleri, yalnızca
		# renklerine bakmadan ayırt edilebilmeli"): bu SATIR asıl lab-mode çizim
		# yoludur (yukarıdaki `if` dalı) -- STAGE_SHAPES/LAB_TEK_HUCRELI_SHAPE'e
		# eklenen nucleus_offset_ratio/nucleus_radius_ratio/no_nucleus/organelles
		# alanları eskiden SADECE match body_type=="cell" dalına (aşağıda, bu
		# dilimde hiç ÇALIŞMAYAN bir kod yoluna) yazılmıştı -- görsel HİÇBİR
		# etkisi olmuyordu (kök neden). Artık lab_cfg BURADA, gerçekten
		# render edilen yolda okunuyor.
		if not bool(lab_cfg.get("no_nucleus", false)):
			_add_nucleus(radius, base_color, lab_cfg)
		for organelle in lab_cfg.get("organelles", []):
			_add_organelle_dot(organelle, radius, base_color)
		if not bool(lab_cfg.get("no_face", false)):
			_add_face(lab_cfg, radius)
		for protrusion in lab_cfg.get("protrusions", []):
			_add_thin_protrusion(protrusion, radius, base_color)
	elif GrayboxConfig.ENABLED:
		# V4 core-loop/graybox (madde 4): gerçek sanat (STAGE_TEXTURES/
		# prosedürel gövde çizimi) yoluna HİÇ DOKUNMADAN, düz renkli basit bir
		# graybox şekli çizer. Balık parçaları için de AYNI yol kullanılır --
		# collision/merge/complementary-index mantığı bundan ETKİLENMEZ,
		# sadece görsel temsil basitleşir.
		_build_graybox_visual(stage_id, radius, is_bonus)
	elif is_fish_part:
		# Faz 2: Balik'in PARCALARI da artik gercek sanat (on/arka PNG) kullanir --
		# eski prosedurel _build_fish_part hala asagida duruyor (kullanilmiyor,
		# geri donus/referans icin), fish_part_index 0=on (front), 1=arka (back).
		var part_index: int = int(organism.get("fish_part_index"))
		_build_sprite_fish_part(part_index == 0, radius, is_bonus)
	elif STAGE_TEXTURES.has(stage_id):
		# Sadece TAMAMLANMIS Balik (ve sanati hazir diger asamalar) buraya duser --
		# Balik'in PARCALARI yukaridaki is_fish_part dalinda zaten ele alindi.
		_build_sprite_visual(stage_id, radius, is_bonus)
	else:
		match body_type:
			"segmented":
				polygon = _build_segmented_shape(cfg, radius)
				color = base_color
				_outline = _add_outline(base_color)
				# Onüçüncü geri bildirim ("çok çirkin/ucuz duruyor"): baş ucuna
				# yakın (omurga t≈0.72) hafif bir parlaklık ekler.
				var gloss_sample: Dictionary = _spine_sample(cfg, radius, 0.72)
				var gloss_center: Vector2 = Vector2(gloss_sample.position.x * 0.4, gloss_sample.position.y * 0.4 - gloss_sample.half_width * 0.3)
				_add_gloss_highlight(gloss_sample.half_width * 1.6, 1.0, 1.0, gloss_center)
				_add_segment_rings(cfg, radius, base_color)
				_add_face_segmented(cfg, radius)
				_add_segment_accessory(cfg, radius, base_color)
			"cell":
				_cell_cfg = cfg
				_cell_radius = radius
				_cell_wobble_time = randf() * TAU
				polygon = _build_shape(cfg, radius)
				color = Color(base_color.r, base_color.g, base_color.b, CELL_ALPHA)
				_outline = _add_outline(base_color)  # kontur tam opak kalsın, saydam dolgudan net ayrılsın
				# NOT: bu dal (match body_type=="cell") yalnızca lab-mode DIŞI
				# (üretim, ENABLED=false) durumlarda çalışır -- yukarıdaki `lab_cfg`
				# (LAB_VISUALS_ENABLED dalına özel, farklı bir blok kapsamı) BURADA
				# ERİŞİLEMEZ; bu yüzden AYNI cfg-tabanlı çekirdek/organel mantığı
				# burada fonksiyon kapsamındaki `cfg`yi okur (GDScript 2.0 blok
				# kapsamı -- `if` içinde tanımlanan `var` yalnızca o bloğa özeldir).
				if not bool(cfg.get("no_nucleus", false)):
					_add_nucleus(radius, base_color, cfg)
				for organelle in cfg.get("organelles", []):
					_add_organelle_dot(organelle, radius, base_color)
				_add_face(cfg, radius)
			"critter":
				polygon = _build_critter_body_shape(cfg, radius)
				color = base_color
				_outline = _add_outline(base_color)
				_add_gloss_highlight(radius, _effective_x_scale(cfg, 0.0), cfg.get("y_scale", 1.0))
				for wedge in cfg.get("wedges", []):
					_add_wedge(radius, cfg, wedge, base_color)
				for limb in cfg.get("limbs", []):
					_add_limb(radius, cfg, limb, base_color)
				if String(cfg.get("eye_style", "")) == "bulge":
					_add_bulging_eyes(cfg, radius, base_color)
				else:
					_add_face(cfg, radius)
			_:
				polygon = _build_shape(cfg, radius)
				color = base_color
				_outline = _add_outline(base_color)
				_add_face(cfg, radius)

	# V4 core-loop/graybox (madde 6 -- geri bildirim sadeleştirme): kullanıcı
	# bulgusu ("sürekli sarı hale kafa karıştırıcı") -- graybox modunda bu
	# SÜREKLİ nabız atan halo hiç eklenmez. Bonus renk tint'i (base_color
	# BONUS_TINT_COLOR'a çekilmesi, yukarıda zaten uygulandı) ve merge anındaki
	# kısa (~0.58s, merge_burst.gd) flaş KORUNUR -- yalnızca bu SONSUZ döngülü
	# halo/pulse kaldırılır. Üretimde (ENABLED=false) davranış DEĞİŞMEZ.
	var suppress_halo: bool = GrayboxConfig.ENABLED and GrayboxConfig.SUPPRESS_PERSISTENT_BONUS_HALO
	if is_bonus and not suppress_halo:
		_add_bonus_halo(radius)

	# gameplay/core-loop-v4 "Evrim Laboratuvarı" vertical slice: evrimle
	# (merge SONUCU) doğan canlılar -- organism.gd _perform_merge'de
	# add_child'dan ÖNCE set edilen born_from_evolution -- kullanıcı talebi
	# ("yeni canlı %115-125 ölçeğe kısa süre çıksın") uyarınca sıradan drop
	# pop-in'inden (Vector2.ONE'a TRANS_BACK overshoot, ~%10) AYRI, belirgin
	# bir tepe-sonra-otur animasyonu alır (bkz. _play_spawn_pop).
	_play_spawn_pop(is_bonus and not suppress_halo, bool(organism.get("born_from_evolution")))

## V4 core-loop/graybox (madde 4 -- graybox görsel boyutlandırma): gerçek
## sanata veya prosedürel gövde çizimine HİÇ dokunmadan, tek renkli basit bir
## daire çizer. DÜZELTME (kullanıcı: "görsel-collision uyumu"): `radius`
## parametresi artık zaten yukarıdaki _ready()'de GrayboxConfig.effective_radius()
## ile hesaplanmış, organism.gd _apply_stage()'in collision shape'i için
## kullandığı TAM AYNI (büyütülmüş) değerdir -- burada AYRICA bir görsel
## çarpan uygulanmaz (önceki sürümde büyütme SADECE burada yapılıyordu,
## collision hâlâ küçük kalıyordu; artık büyütme tek kaynakta, yukarıda). Bonus
## canlılar için renk BONUS_TINT_COLOR'a doğru çekilir (üretimdeki tint
## davranışıyla tutarlı) -- sürekli nabız halosu ayrı olarak
## SUPPRESS_PERSISTENT_BONUS_HALO ile _add_bonus_halo/_play_bonus_pulse
## içinde ele alınır.
func _build_graybox_visual(stage_id: int, radius: float, is_bonus: bool) -> void:
	var base_color: Color = GrayboxConfig.STAGE_COLORS.get(stage_id, Color.WHITE)
	if is_bonus:
		base_color = base_color.lerp(BONUS_TINT_COLOR, BONUS_TINT_STRENGTH)
	polygon = _circle_points(radius, 40)
	color = base_color
	_outline = _add_outline(base_color)

## Cowork uygulama talimati: gercek sanat eseri (PNG) olan bir asama icin
## prosedurel cizimin YERINE, merkezlenmis tek bir Sprite2D ekler. Sprite'in
## ham piksel boyutunu ASLA carpisma boyutu sanma -- collision (CircleShape2D,
## Coder'in ayarladigi) hic degismez; sadece bu gorsel kok, dokunun GERCEK
## genisligini `radius` (fizik yaricapi) ile eslesecek sekilde olceklenir, ki
## sanatci her canli icin farkli bir tuval orani kullanmis olsa bile (bkz.
## organism_assets.json "canvas") ekrandaki boyut hep fizik govdesiyle uyumlu
## kalsin. Bonus tint ve nabiz atan halo (_add_bonus_halo, ustte zaten
## cagriliyor) PNG'ye bake edilmez -- modulate ile canli canli uygulanir.
func _build_sprite_visual(stage_id: int, radius: float, is_bonus: bool) -> void:
	_add_scaled_sprite(STAGE_TEXTURES[stage_id], radius, is_bonus)

## Faz 2 -- Balik'in TEK bir parcasi (on veya arka) icin merkezlenmis Sprite2D
## ekler; on/arka/tam gorseller ayni tuval+pivotu paylastigi icin
## _add_scaled_sprite'a AYNEN _build_sprite_visual gibi delege eder (kirpma/
## yeniden-merkezleme yok -- README_TR.md "Kritik balik notu" ile birebir).
func _build_sprite_fish_part(is_front: bool, radius: float, is_bonus: bool) -> void:
	var texture: Texture2D = FISH_FRONT_TEXTURE if is_front else FISH_BACK_TEXTURE
	_add_scaled_sprite(texture, radius, is_bonus, FISH_PART_EXTRA_SCALE)

## Cowork uygulama talimati ("Sprite olcegini merkezi bir yapidan yonet; her
## karakter icin kod icine dagilmis rastgele scale degerleri yazma"): TUM
## sprite tabanli asamalar (STAGE_TEXTURES + Balik on/arka parcalari) buraya
## delege eder -- fit_scale hesabi (fizik yaricapi / dokunun GERCEK piksel
## genisligi) TEK bir yerden yonetilir. Sprite'in ham piksel boyutunu ASLA
## carpisma boyutu sanma -- collision (CircleShape2D, Coder'in ayarladigi)
## hic degismez; sadece bu gorsel kok radius'a eslenir. Bonus tint ve nabiz
## atan halo (_add_bonus_halo, cagiran _ready() icinde zaten cagriliyor)
## PNG'ye bake edilmez -- modulate ile canli canli uygulanir.
func _add_scaled_sprite(texture: Texture2D, radius: float, is_bonus: bool, extra_scale: float = 1.0) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.position = Vector2.ZERO
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var tex_width: float = max(float(texture.get_width()), 1.0)
	var fit_scale: float = (radius * 2.0) / tex_width * extra_scale
	sprite.scale = Vector2(fit_scale, fit_scale)
	sprite.modulate = Color.WHITE.lerp(BONUS_TINT_COLOR, BONUS_TINT_STRENGTH) if is_bonus else Color.WHITE
	add_child(sprite)
	return sprite

## "cell" gövdeleri için her karede kenarları hafifçe dalgalandırır — sabit
## dursaydı yarı saydam+çekirdekli görünüm bile cansız kalırdı; bu sürekli,
## hafif şekil değişimi "canlı bir mikroorganizma/uzaylı" hissini verir.
## Diğer gövde tiplerinde (_cell_cfg boşsa) hiçbir şey yapmaz.
func _process(delta: float) -> void:
	if _cell_cfg.is_empty():
		return
	_cell_wobble_time += delta
	var animated_bumps: Array = []
	for bump in _cell_cfg.get("bumps", []):
		var base_height: float = bump.get("height", 0.0)
		var ang: float = bump.get("angle", 0.0)
		var wobble: float = 1.0 + CELL_WOBBLE_STRENGTH * sin(_cell_wobble_time * CELL_WOBBLE_SPEED + ang * 2.3)
		animated_bumps.append({"angle": ang, "width": bump.get("width", 0.5), "height": base_height * wobble})
	var animated_cfg: Dictionary = {
		"x_scale": _cell_cfg.get("x_scale", 1.0),
		"y_scale": _cell_cfg.get("y_scale", 1.0),
		"bumps": animated_bumps,
	}
	polygon = _build_shape(animated_cfg, _cell_radius)
	if _outline:
		var closed: PackedVector2Array = polygon.duplicate()
		closed.append(polygon[0])
		_outline.points = closed

## Gövdeyi çevreleyen ince, koyu tonlu bir kontur çizgisi ekler ve referansını
## döndürür (bkz. "cell" dalgalanmasında konturu güncel tutmak için _outline).
func _add_outline(body_color: Color) -> Line2D:
	var outline := Line2D.new()
	var closed_points: PackedVector2Array = polygon.duplicate()
	closed_points.append(polygon[0])
	outline.points = closed_points
	outline.width = OUTLINE_WIDTH
	outline.default_color = body_color.darkened(OUTLINE_DARKEN_RATIO)
	outline.z_index = -1
	add_child(outline)
	return outline

## "cell" gövdesine gerçek bir hücre çekirdeği gibi merkezden hafif kaymış,
## koyu tonlu bir iç daire ekler.
## DÜZELTME (V02 ikinci düzeltme turu -- "aynı damlanın renk varyasyonu
## olmamalı"): çekirdek konumu/boyutu artık SABİT değil, isteğe bağlı
## `cfg` ("nucleus_offset_ratio": Vector2, "nucleus_radius_ratio": float)
## üzerinden özelleştirilebilir -- cfg boş/alan yoksa ESKİ sabit değerler
## (radius*0.18,-radius*0.12 / CELL_NUCLEUS_RADIUS_RATIO) AYNEN korunur, bu
## yüzden mevcut çağrı yerleri (varsayılan cfg={}) davranışça DEĞİŞMEZ.
func _add_nucleus(radius: float, body_color: Color, cfg: Dictionary = {}) -> void:
	var nucleus := Polygon2D.new()
	var radius_ratio: float = float(cfg.get("nucleus_radius_ratio", CELL_NUCLEUS_RADIUS_RATIO))
	var nucleus_radius: float = radius * radius_ratio
	nucleus.polygon = _circle_points(nucleus_radius)
	var nucleus_color: Color = body_color.darkened(CELL_NUCLEUS_COLOR_DARKEN)
	nucleus.color = nucleus_color
	var offset_ratio: Vector2 = cfg.get("nucleus_offset_ratio", Vector2(0.18, -0.12))
	nucleus.position = Vector2(radius * offset_ratio.x, radius * offset_ratio.y)
	add_child(nucleus)

## DÜZELTME (V02 ikinci düzeltme turu -- "Tek Hücreli: ... belirgin çekirdek
## ve organel noktaları"): çekirdekten AYRI, daha küçük, dağınık noktalar --
## ökaryot bir hücrenin organelleri hissi. SADECE cfg'sinde "organelles"
## dizisi tanımlı aşamalarda (şu an yalnızca Tek Hücreli) çizilir; Virüs/
## Bakteri bu diziyi tanımlamadığından hiçbir görsel/davranış değişikliği
## YOK onlarda.
func _add_organelle_dot(organelle: Dictionary, radius: float, body_color: Color) -> void:
	var offset_ratio: Vector2 = organelle.get("offset_ratio", Vector2.ZERO)
	var dot_radius_ratio: float = float(organelle.get("radius_ratio", 0.09))
	var darken: float = float(organelle.get("darken", 0.3))
	var dot := Polygon2D.new()
	dot.polygon = _circle_points(radius * dot_radius_ratio)
	dot.color = body_color.darkened(darken)
	dot.position = Vector2(radius * offset_ratio.x, radius * offset_ratio.y)
	add_child(dot)

## "blob" ve "cell" gövdeleri için STAGE_SHAPES'teki face_angle yönünde, gövde
## yüzeyinin biraz içine çekilmiş iki basit "tatlı" göz (beyaz + göz bebeği) ekler.
## "critter" gövdeleri de (eye_style bulge değilse) bumps=[] ile bu fonksiyonu
## paylaşır — o durumda surface_r doğrudan radius'a eşittir (düz elips yüzeyi).
func _add_face(cfg: Dictionary, radius: float) -> void:
	var face_angle: float = cfg.get("face_angle", -PI / 2.0)
	var x_scale: float = _effective_x_scale(cfg, face_angle)
	var y_scale: float = cfg.get("y_scale", 1.0)
	var bumps: Array = cfg.get("bumps", [])
	var surface_r: float = _radius_at_angle(face_angle, radius, bumps)
	var facing: Vector2 = Vector2(cos(face_angle) * x_scale, sin(face_angle) * y_scale)
	var face_center: Vector2 = facing * surface_r * EYE_INSET_RATIO
	var perpendicular: Vector2 = Vector2(-facing.y, facing.x)
	if perpendicular.length() > 0.0001:
		perpendicular = perpendicular.normalized()
	var spacing: float = radius * EYE_SPACING_RATIO
	var eye_radius: float = max(radius * EYE_RADIUS_RATIO, 1.5)
	var blush_down: Vector2 = Vector2(0.0, eye_radius * BLUSH_DOWN_OFFSET_RATIO)
	_add_blush(face_center + perpendicular * spacing + blush_down, eye_radius * BLUSH_RADIUS_RATIO)
	_add_blush(face_center - perpendicular * spacing + blush_down, eye_radius * BLUSH_RADIUS_RATIO)
	_add_eye(face_center + perpendicular * spacing, eye_radius)
	_add_eye(face_center - perpendicular * spacing, eye_radius)

## Kurbağa için özel göz stili (eye_style: "bulge"): gerçek kurbağaların çıkık
## gözlerini anımsatan, gövdeden dışa taşan iki yuvarlak "kabartı" çizip
## gözleri bu kabartıların üstüne yerleştirir (bkz. STAGE_SHAPES[4]).
func _add_bulging_eyes(cfg: Dictionary, radius: float, body_color: Color) -> void:
	var face_angle: float = cfg.get("face_angle", -PI / 2.0)
	var x_scale: float = _effective_x_scale(cfg, face_angle)
	var y_scale: float = cfg.get("y_scale", 1.0)
	var facing: Vector2 = Vector2(cos(face_angle) * x_scale, sin(face_angle) * y_scale)
	var base: Vector2 = facing * radius * BULGE_EYE_INSET_RATIO
	var perpendicular: Vector2 = Vector2(-facing.y, facing.x)
	if perpendicular.length() > 0.0001:
		perpendicular = perpendicular.normalized()
	var spacing: float = radius * EYE_SPACING_RATIO * BULGE_EYE_SPACING_SCALE
	var bump_radius: float = radius * BULGE_EYE_BUMP_RADIUS_RATIO
	var eye_radius: float = max(radius * EYE_RADIUS_RATIO * BULGE_EYE_SPACING_SCALE, 2.0)
	for side in [1.0, -1.0]:
		var bump_center: Vector2 = base + perpendicular * spacing * side
		var bump := Polygon2D.new()
		bump.polygon = _circle_points(bump_radius)
		bump.color = body_color
		bump.position = bump_center
		add_child(bump)
		var bump_outline := Line2D.new()
		var closed: PackedVector2Array = bump.polygon.duplicate()
		closed.append(bump.polygon[0])
		bump_outline.points = closed
		bump_outline.width = OUTLINE_WIDTH * PART_OUTLINE_WIDTH_RATIO
		bump_outline.default_color = body_color.darkened(OUTLINE_DARKEN_RATIO)
		bump_outline.position = bump_center
		add_child(bump_outline)
		_add_blush(bump_center + Vector2(0.0, eye_radius * BLUSH_DOWN_OFFSET_RATIO * 1.05), eye_radius * BLUSH_RADIUS_RATIO)
		_add_eye(bump_center, eye_radius)

## "segmented" gövdeleri (Solucan/Yılan) için, omurganın baş ucuna (t≈0.85)
## gözleri yerleştirir — _add_face'in blob için yaptığının omurga eşdeğeri.
func _add_face_segmented(cfg: Dictionary, radius: float) -> void:
	var s: Dictionary = _spine_sample(cfg, radius, 0.85)
	var eye_radius: float = max(radius * EYE_RADIUS_RATIO, 1.5)
	var spacing: float = s.half_width * 0.6
	var face_center: Vector2 = s.position + s.tangent * (s.half_width * 0.1)
	var blush_down: Vector2 = Vector2(0.0, eye_radius * BLUSH_DOWN_OFFSET_RATIO)
	_add_blush(face_center + s.perpendicular * spacing + blush_down, eye_radius * BLUSH_RADIUS_RATIO)
	_add_blush(face_center - s.perpendicular * spacing + blush_down, eye_radius * BLUSH_RADIUS_RATIO)
	_add_eye(face_center + s.perpendicular * spacing, eye_radius)
	_add_eye(face_center - s.perpendicular * spacing, eye_radius)

## "segmented" gövdelere STAGE_SHAPES'te işaretliyse tür-özgü küçük ayrıntılar
## ekler: Solucan için baş ucunda ince bir çift anten, Yılan için ağzından
## çıkan çatal bir dil.
func _add_segment_accessory(cfg: Dictionary, radius: float, body_color: Color) -> void:
	if bool(cfg.get("antenna", false)):
		var s: Dictionary = _spine_sample(cfg, radius, 0.98)
		for side in [1.0, -1.0]:
			var tip: Vector2 = s.position + s.tangent * radius * ANTENNA_LENGTH_RATIO + s.perpendicular * side * radius * ANTENNA_SPREAD_RATIO
			var antenna := Line2D.new()
			antenna.points = PackedVector2Array([s.position, tip])
			antenna.width = ANTENNA_WIDTH
			antenna.default_color = body_color.darkened(SEGMENT_RING_DARKEN)
			antenna.z_index = 1
			add_child(antenna)
	if bool(cfg.get("tongue", false)):
		var s3: Dictionary = _spine_sample(cfg, radius, 1.0)
		var base_pt: Vector2 = s3.position + s3.tangent * 2.0
		var mid_pt: Vector2 = base_pt + s3.tangent * radius * TONGUE_LENGTH_RATIO
		var tongue := Line2D.new()
		tongue.points = PackedVector2Array([base_pt, mid_pt])
		tongue.width = TONGUE_WIDTH
		tongue.default_color = TONGUE_COLOR
		tongue.z_index = 1
		add_child(tongue)
		for side in [1.0, -1.0]:
			var fork_tip: Vector2 = mid_pt + s3.tangent * radius * TONGUE_FORK_LENGTH_RATIO + s3.perpendicular * side * radius * TONGUE_FORK_SPREAD_RATIO
			var fork := Line2D.new()
			fork.points = PackedVector2Array([mid_pt, fork_tip])
			fork.width = TONGUE_WIDTH
			fork.default_color = TONGUE_COLOR
			fork.z_index = 1
			add_child(fork)

## gameplay/core-loop-v4 "Evrim Laboratuvarı" V02 vertical slice (Virüs):
## kullanıcı talebi -- "ince dış çıkıntılar (körelmiş dikenler DEĞİL)". Eski
## "critter" wedge'leri (düz/yuvarlatılmış üçgen, gövdeyle aynı opak renk)
## yerine, gövde yüzeyinden dışa doğru hafifçe kıvrılan İNCE bir Line2D +
## ucunda küçük, daha açık tonlu bir daire ("yuvarlak uçlu") -- _add_segment_
## accessory'nin anten tekniğiyle aynı ailede, ama kavisli (quad-bezier).
func _add_thin_protrusion(protrusion: Dictionary, radius: float, body_color: Color) -> void:
	var angle: float = float(protrusion.get("angle", 0.0))
	var length_ratio: float = float(protrusion.get("len", 0.3))
	var curve_ratio: float = float(protrusion.get("curve", 0.1))
	var dir_vec: Vector2 = Vector2(cos(angle), sin(angle))
	var base: Vector2 = dir_vec * radius * 0.94
	var tip: Vector2 = base + dir_vec * radius * length_ratio
	var perp: Vector2 = Vector2(-dir_vec.y, dir_vec.x)
	var control: Vector2 = base.lerp(tip, 0.5) + perp * radius * curve_ratio
	var line := Line2D.new()
	line.points = _quad_bezier_points(base, control, tip, 8)
	line.width = max(radius * 0.045, 1.4)
	line.default_color = body_color.darkened(0.12)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.z_index = -1
	add_child(line)
	var tip_dot := Polygon2D.new()
	tip_dot.polygon = _circle_points(max(radius * 0.055, 1.6))
	tip_dot.color = body_color.lightened(0.3)
	tip_dot.position = line.points[line.points.size() - 1]
	tip_dot.z_index = -1
	add_child(tip_dot)

## Tek bir göz (beyaz taban + hafifçe kaydırılmış göz bebeği + iki küçük
## parıltı) oluşturup verilen konuma ekler. Onüçüncü geri bildirim ("çok
## çirkin/ucuz duruyor"): pupilin merkezden kayması "bakan" bir canlı hissi
## verir, parıltılar (sparkle) sevimli/çizgi film gözü tekniğidir.
func _add_eye(local_position: Vector2, eye_radius: float) -> void:
	var white := Polygon2D.new()
	white.polygon = _circle_points(eye_radius)
	white.color = EYE_WHITE_COLOR
	white.position = local_position
	white.z_index = 1
	add_child(white)

	var pupil_offset: Vector2 = PUPIL_OFFSET_RATIO * eye_radius
	var pupil := Polygon2D.new()
	pupil.polygon = _circle_points(eye_radius * 0.55)
	pupil.color = EYE_PUPIL_COLOR
	pupil.position = pupil_offset
	pupil.z_index = 1
	white.add_child(pupil)

	var sparkle_big := Polygon2D.new()
	sparkle_big.polygon = _circle_points(eye_radius * SPARKLE_BIG_RADIUS_RATIO)
	sparkle_big.color = Color(1.0, 1.0, 1.0, 0.9)
	sparkle_big.position = pupil_offset + SPARKLE_BIG_OFFSET_RATIO * eye_radius
	sparkle_big.z_index = 2
	white.add_child(sparkle_big)

	var sparkle_small := Polygon2D.new()
	sparkle_small.polygon = _circle_points(eye_radius * SPARKLE_SMALL_RADIUS_RATIO)
	sparkle_small.color = Color(1.0, 1.0, 1.0, 0.55)
	sparkle_small.position = pupil_offset + SPARKLE_SMALL_OFFSET_RATIO * eye_radius
	sparkle_small.z_index = 2
	white.add_child(sparkle_small)

## Verilen yarıçapta, merkezi (0,0) olan basit bir daire çokgeni üretir (göz/çekirdek için).
func _circle_points(circle_radius: float, segments: int = 16) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle: float = TAU * i / segments
		points.append(Vector2(cos(angle), sin(angle)) * circle_radius)
	return points

## Verilen yarı-uzunluk/yarı-genişlikte, merkezi (0,0) olan bir elips çokgeni
## üretir ("critter" uzuv/yüzgeç şekilleri için — bkz. _add_limb).
func _oval_points(half_length: float, half_width: float, segments: int = 16) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle: float = TAU * i / segments
		points.append(Vector2(cos(angle) * half_length, sin(angle) * half_width))
	return points

## Onüçüncü geri bildirim ("çok çirkin/ucuz duruyor" — "yumuşak/sevimli
## çizgi film tarzı" isteği): gövdenin üst-orta bölgesine "jöle/plastik"
## hissi veren yumuşak bir parlaklık ekler. Godot Polygon2D gerçek bir radyal
## gradyanı desteklemediği için (shader gerekir), küçüldükçe opaklaşan birkaç
## yarı saydam beyaz elips üst üste bindirilerek YAKLAŞIK bir yumuşak geçiş
## üretilir (bkz. GLOSS_* sabitleri). "center_override" verilirse (segmented
## gövdeler için) merkez hesaplanmaz, doğrudan o nokta kullanılır.
func _add_gloss_highlight(radius: float, x_scale: float, y_scale: float, center_override = null) -> void:
	var center: Vector2
	if center_override != null:
		center = center_override
	else:
		center = Vector2(radius * x_scale * GLOSS_OFFSET_X_RATIO, radius * y_scale * GLOSS_OFFSET_Y_RATIO)
	var base_rx: float = radius * x_scale * GLOSS_RADIUS_X_RATIO
	var base_ry: float = radius * y_scale * GLOSS_RADIUS_Y_RATIO
	for layer in GLOSS_LAYERS:
		var layer_scale: float = layer.get("scale", 1.0)
		var alpha: float = layer.get("alpha", 0.1)
		var gloss := Polygon2D.new()
		gloss.polygon = _oval_points(base_rx * layer_scale, base_ry * layer_scale)
		gloss.color = Color(1.0, 1.0, 1.0, alpha)
		gloss.position = center
		gloss.z_index = 1
		add_child(gloss)

## Onüçüncü geri bildirim: gözlerin hemen altına, aynı katmanlı-elips
## tekniğiyle (bkz. _add_gloss_highlight) yumuşak kenarlı sıcak bir "allık"
## ekler — sevimli maskot çiziminin klasik bir dokunuşu.
func _add_blush(pos: Vector2, base_radius: float) -> void:
	for layer in BLUSH_LAYERS:
		var layer_scale: float = layer.get("scale", 1.0)
		var alpha: float = layer.get("alpha", 0.1)
		var blush := Polygon2D.new()
		blush.polygon = _circle_points(base_radius * layer_scale)
		blush.color = Color(BLUSH_COLOR.r, BLUSH_COLOR.g, BLUSH_COLOR.b, alpha)
		blush.position = pos
		blush.z_index = 1
		add_child(blush)

## İki nokta arasında "control" noktasına doğru çekilen bir kuadratik Bezier
## eğrisini örnekleyip noktalar dizisi döndürür — wedge uçlarını yuvarlatmak
## için kullanılır (bkz. _add_wedge). p0/p1 dahil edilir.
func _quad_bezier_points(p0: Vector2, control: Vector2, p1: Vector2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var one_minus_t: float = 1.0 - t
		var point: Vector2 = p0 * (one_minus_t * one_minus_t) + control * (2.0 * one_minus_t * t) + p1 * (t * t)
		points.append(point)
	return points

## "critter" gövde tipi için bumpsuz, düz yönlü esnetilmiş bir elips siluet
## üretir; gerçek türe benzeyen ayrıntılar (bacak/kanat/kuyruk) ayrı ekli
## şekillerle sağlanır (bkz. dosya başı UI/UX notu, _add_wedge, _add_limb).
## NOT: "teardrop" cfg'li aşamalarda artık _build_critter_body_shape kullanılır;
## bu fonksiyon düz (teardrop olmayan) critter gövdeleri için hâlâ geçerlidir.
func _build_ellipse_shape(cfg: Dictionary, radius: float, segments: int = 48) -> PackedVector2Array:
	var x_scale: float = cfg.get("x_scale", 1.0)
	var y_scale: float = cfg.get("y_scale", 1.0)
	var points := PackedVector2Array()
	for i in range(segments):
		var angle: float = TAU * i / segments
		points.append(Vector2(cos(angle) * radius * x_scale, sin(angle) * radius * y_scale))
	return points

## Onikinci geri bildirim ("şekiller biraz daha benzesin"): "teardrop" işaretli
## critter aşamalarında (Balık/Kertenkele/Kuş), düz elips yerine ön (angle≈0)
## ve arka (angle≈PI) tarafta FARKLI x_scale kullanan asimetrik "damla" gövde
## üretir — baştan kuyruğa doğru doğal bir incelme/genişleme hissi verir.
## _effective_x_scale ile aynı ağırlıklandırmayı kullanır ki gövde ile ona
## eklenen wedge/limb'lerin kök noktaları birbirinden asla sapmasın.
func _build_teardrop_shape(cfg: Dictionary, radius: float, segments: int = 48) -> PackedVector2Array:
	var y_scale: float = cfg.get("y_scale", 1.0)
	var points := PackedVector2Array()
	for i in range(segments):
		var angle: float = TAU * i / segments
		var x_scale: float = _effective_x_scale(cfg, angle)
		points.append(Vector2(cos(angle) * radius * x_scale, sin(angle) * radius * y_scale))
	return points

## _build_ellipse_shape / _build_teardrop_shape arasında cfg.teardrop'a göre
## seçim yapan tek giriş noktası (bkz. _ready "critter" dalı).
func _build_critter_body_shape(cfg: Dictionary, radius: float) -> PackedVector2Array:
	if bool(cfg.get("teardrop", false)):
		return _build_teardrop_shape(cfg, radius)
	return _build_ellipse_shape(cfg, radius)

## Verilen açıda geçerli x_scale'i döndürür: "teardrop" cfg'lerde ön (angle=0,
## front_x_scale) ve arka (angle=PI, back_x_scale) arası kosinüs ağırlıklı
## yumuşak geçiş; diğer critter'larda sabit "x_scale". _build_teardrop_shape,
## _add_wedge, _add_limb, _add_face ve _add_bulging_eyes tarafından paylaşılır
## ki gövde ile ona eklenen parçaların kök noktaları asla birbirinden sapmasın.
func _effective_x_scale(cfg: Dictionary, angle: float) -> float:
	if not bool(cfg.get("teardrop", false)):
		return cfg.get("x_scale", 1.0)
	var front_x_scale: float = cfg.get("front_x_scale", 1.0)
	var back_x_scale: float = cfg.get("back_x_scale", 1.0)
	var front_weight: float = (cos(angle) + 1.0) / 2.0  # angle=0'da 1, angle=PI'de 0
	return front_x_scale * front_weight + back_x_scale * (1.0 - front_weight)

## "critter" gövdesine gövde yüzeyinden dışa doğru uzanan, ucu YUVARLATILMIŞ
## bir çıkıntı (kuyruk/yüzgeç/gaga/sırt dikeni) ekler. "angle" çıkıntının
## gövde üzerindeki kök noktasını, "dir" uzandığı yönü, "len"/"w" (radius'a
## oranla) uzunluk/genişliğini belirler. accent=true ise (ör. Kuş gagası)
## gövdeden belirgin şekilde farklı bir vurgu rengi kullanılır.
## Onüçüncü geri bildirim ("çok çirkin/ucuz duruyor" — sivri üçgen parçalar):
## eskiden düz bir üçgendi (base_left, tip, base_right); artık tepe noktası
## bir kuadratik Bezier ile yuvarlatılıyor (bkz. WEDGE_TIP_ROUND_RATIO,
## _quad_bezier_points) — "sevimli çizgi film" hissi için.
func _add_wedge(radius: float, body_cfg: Dictionary, wedge: Dictionary, body_color: Color) -> void:
	var angle: float = wedge.get("angle", 0.0)
	var x_scale: float = _effective_x_scale(body_cfg, angle)
	var y_scale: float = body_cfg.get("y_scale", 1.0)
	var dir_angle: float = wedge.get("dir", angle)
	var anchor: Vector2 = Vector2(cos(angle) * radius * x_scale, sin(angle) * radius * y_scale)
	var dir_vec: Vector2 = Vector2(cos(dir_angle), sin(dir_angle))
	var perp: Vector2 = Vector2(-dir_vec.y, dir_vec.x)
	var length: float = radius * float(wedge.get("len", 0.4))
	var width: float = radius * float(wedge.get("w", 0.3))
	var tip: Vector2 = anchor + dir_vec * length
	var base_left: Vector2 = anchor + perp * (width * 0.5)
	var base_right: Vector2 = anchor - perp * (width * 0.5)
	var is_accent: bool = bool(wedge.get("accent", false))
	var wedge_color: Color = WEDGE_ACCENT_COLOR if is_accent else body_color.darkened(WEDGE_DARKEN_RATIO)

	var tip_round: float = width * WEDGE_TIP_ROUND_RATIO
	var tip_back_l: Vector2 = tip - dir_vec * tip_round + perp * (tip_round * 0.55)
	var tip_back_r: Vector2 = tip - dir_vec * tip_round - perp * (tip_round * 0.55)
	var rounded_cap: PackedVector2Array = _quad_bezier_points(tip_back_l, tip, tip_back_r, WEDGE_TIP_CURVE_SEGMENTS)

	var poly_points := PackedVector2Array([base_left, tip_back_l])
	for p in rounded_cap:
		poly_points.append(p)
	poly_points.append(base_right)

	var shape := Polygon2D.new()
	shape.polygon = poly_points
	shape.color = wedge_color
	add_child(shape)

	var outline_points: PackedVector2Array = poly_points.duplicate()
	outline_points.append(poly_points[0])
	var outline := Line2D.new()
	outline.points = outline_points
	outline.width = OUTLINE_WIDTH * PART_OUTLINE_WIDTH_RATIO
	outline.default_color = body_color.darkened(OUTLINE_DARKEN_RATIO)
	add_child(outline)

## "critter" gövdesine gövde yüzeyinden dışa doğru uzanan OVAL bir uzuv
## (bacak/kol/yüzgeç) ekler; foot=true ise ucuna küçük bir "pati" dairesi de
## eklenir (bkz. Kurbağa/Kertenkele/Dinozor bacakları). Parametreler _add_wedge
## ile aynı mantıkta ("angle" kök nokta, "dir" yön, "len"/"w" oran).
func _add_limb(radius: float, body_cfg: Dictionary, limb: Dictionary, body_color: Color) -> void:
	var angle: float = limb.get("angle", 0.0)
	var x_scale: float = _effective_x_scale(body_cfg, angle)
	var y_scale: float = body_cfg.get("y_scale", 1.0)
	var dir_angle: float = limb.get("dir", angle)
	var anchor: Vector2 = Vector2(cos(angle) * radius * x_scale, sin(angle) * radius * y_scale)
	var dir_vec: Vector2 = Vector2(cos(dir_angle), sin(dir_angle))
	var length: float = radius * float(limb.get("len", 0.3))
	var width: float = radius * float(limb.get("w", 0.16))
	var center: Vector2 = anchor + dir_vec * (length * 0.5)

	var oval := Polygon2D.new()
	oval.polygon = _oval_points(length * 0.5, width * 0.5)
	oval.color = body_color.darkened(LIMB_DARKEN_RATIO)
	oval.position = center
	oval.rotation = dir_angle
	add_child(oval)

	var outline := Line2D.new()
	var closed: PackedVector2Array = oval.polygon.duplicate()
	closed.append(oval.polygon[0])
	outline.points = closed
	outline.width = OUTLINE_WIDTH * PART_OUTLINE_WIDTH_RATIO
	outline.default_color = body_color.darkened(OUTLINE_DARKEN_RATIO)
	outline.position = center
	outline.rotation = dir_angle
	add_child(outline)

	if bool(limb.get("foot", false)):
		var foot_pos: Vector2 = anchor + dir_vec * length
		var foot := Polygon2D.new()
		foot.polygon = _circle_points(width * 0.55)
		foot.color = body_color.darkened(FOOT_DARKEN_RATIO)
		foot.position = foot_pos
		add_child(foot)
		# Onikinci geri bildirim ("şekiller biraz daha benzesin"): patinin
		# ucuna üç kısa parmak çizgisi ekler — Kurbağa/Kertenkele/Dinozor/Kuş
		# ayaklarının düz bir daireden çok gerçek bir "pati/pençe" gibi
		# okunmasını sağlar (bkz. toes bayrağı, STAGE_SHAPES).
		if bool(limb.get("toes", false)):
			for side in [-1.0, 0.0, 1.0]:
				var toe_dir: float = dir_angle + side * TOE_SPREAD_RADIANS
				var toe_tip: Vector2 = foot_pos + Vector2(cos(toe_dir), sin(toe_dir)) * width * TOE_LENGTH_RATIO
				var toe := Line2D.new()
				toe.points = PackedVector2Array([foot_pos, toe_tip])
				toe.width = max(width * TOE_WIDTH_RATIO, 1.5)
				toe.default_color = body_color.darkened(FOOT_DARKEN_RATIO + 0.1)
				add_child(toe)

## UC-01 ek mekanik (kullanıcı isteği — "balık 2 parçadan oluşur"): Balık'ın
## tek bir parçası için tam gövde yerine, ortadan çentikli/dişli bir kesim
## hattına sahip YARIM bir gövde çizer (bkz. _build_fish_half_shape); iki
## parça yan yana geldiğinde görsel olarak "birbirini tamamlayan iki yapboz
## parçası" hissi verir. is_front=true ön (baş+göğüs yüzgeci) yarı, false ise
## arka (kuyruk) yarıdır.
func _build_fish_part(cfg: Dictionary, radius: float, body_color: Color, is_front: bool) -> void:
	polygon = _build_fish_half_shape(cfg, radius, is_front)
	color = body_color
	_outline = _add_outline(body_color)
	# _build_fish_half_shape her zaman DÜZ x_scale kullanır (teardrop'suz —
	# yarım gövde zaten kendi asimetrisini taşıyor). Balık'ın tam gövdesi
	# "teardrop" işaretli olduğundan (bkz. STAGE_SHAPES[3]), _add_limb/_add_wedge
	# çağrılarında AYNI cfg doğrudan kullanılırsa yüzgeç/kuyruk kök noktası
	# _effective_x_scale ile bu düz gövdeden sapar. Bu yüzden burada teardrop
	# işareti kaldırılmış bir kopya kullanılır ki ek parçalar tam olarak
	# gövdenin gerçek (düz) kenarına otursun.
	var part_cfg: Dictionary = cfg.duplicate()
	part_cfg.erase("teardrop")
	if is_front:
		var x_scale: float = part_cfg.get("x_scale", 1.0)
		var y_scale: float = part_cfg.get("y_scale", 1.0)
		var eye_pos: Vector2 = Vector2(radius * x_scale * 0.5, -radius * y_scale * 0.15)
		_add_eye(eye_pos, max(radius * EYE_RADIUS_RATIO, 2.0))
		var limbs: Array = part_cfg.get("limbs", [])
		if limbs.size() > 0:
			_add_limb(radius, part_cfg, limbs[0], body_color)
	else:
		var wedges: Array = part_cfg.get("wedges", [])
		if wedges.size() > 0:
			_add_wedge(radius, part_cfg, wedges[0], body_color)

## _build_fish_part için: yarım-elips dış hat + ortadaki dişli/çentikli kesim
## hattından oluşan kapalı bir çokgen üretir. is_front=true ise sağ (baş)
## yarısı, false ise sol (kuyruk) yarısı — bkz. STAGE_SHAPES[FISH_STAGE_ID]
## (face_angle 0.0 = baş sağda, kuyruk wedge'i angle PI = solda).
func _build_fish_half_shape(cfg: Dictionary, radius: float, is_front: bool) -> PackedVector2Array:
	var x_scale: float = cfg.get("x_scale", 1.0)
	var y_scale: float = cfg.get("y_scale", 1.0)
	var segments: int = 40
	var half_segments: int = segments / 2
	var points := PackedVector2Array()
	var start_angle: float = -PI / 2.0 if is_front else PI / 2.0
	for i in range(half_segments + 1):
		var a: float = start_angle + PI * float(i) / float(half_segments)
		points.append(Vector2(cos(a) * radius * x_scale, sin(a) * radius * y_scale))
	var half_h: float = radius * y_scale
	var y_from: float = half_h if is_front else -half_h
	var y_to: float = -half_h if is_front else half_h
	var teeth: int = FISH_CUT_TEETH_COUNT
	var depth: float = radius * FISH_CUT_DEPTH_RATIO
	var steps: int = teeth * 2
	for i in range(1, steps):
		var t: float = float(i) / float(steps)
		var y: float = lerp(y_from, y_to, t)
		var x: float = depth if i % 2 == 0 else -depth
		points.append(Vector2(x, y))
	return points

## Bonus Sistemi (editör notu — erişilebilirlik): gövdenin arkasına (z_index=-2)
## nabız gibi büyüyüp küçülen yarı saydam bir hale ekler; sadece altın renk
## tonuna güvenmeyen, ikinci ve bağımsız bir "bu canlı özel" ipucu sağlar.
func _add_bonus_halo(radius: float) -> void:
	var halo_root := Node2D.new()
	halo_root.z_index = -2
	add_child(halo_root)
	for layer in BONUS_HALO_RING_LAYERS:
		var ring := Line2D.new()
		var pts: PackedVector2Array = _circle_points(radius * float(layer.get("scale", 1.0)), 32)
		var closed_pts: PackedVector2Array = pts.duplicate()
		closed_pts.append(pts[0])
		ring.points = closed_pts
		ring.width = max(radius * float(layer.get("width_ratio", 0.08)), 1.0)
		ring.default_color = Color(BONUS_HALO_COLOR.r, BONUS_HALO_COLOR.g, BONUS_HALO_COLOR.b, float(layer.get("alpha", 0.1)))
		ring.joint_mode = Line2D.LINE_JOINT_ROUND
		ring.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ring.end_cap_mode = Line2D.LINE_CAP_ROUND
		halo_root.add_child(ring)
	var pulse_scale: float = BONUS_HALO_PULSE_SCALE / BONUS_HALO_BASE_SCALE
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(halo_root, "scale", Vector2(pulse_scale, pulse_scale), BONUS_HALO_PULSE_DURATION)
	tween.tween_property(halo_root, "scale", Vector2.ONE, BONUS_HALO_PULSE_DURATION)

## Canlı belirdiğinde (bırakılan ya da evrimle oluşan) küçükten büyüyerek
## "patlar gibi" beliren kısa bir hareket katar. Sadece görseldir; çarpışma
## yarıçapını (Coder'ın ayarladığı CircleShape2D) etkilemez. Bonus canlıysa
## pop-in bitince sürekli nabız animasyonuna geçer (bkz. _play_bonus_pulse).
func _play_spawn_pop(start_bonus_pulse: bool = false, born_from_evolution: bool = false) -> void:
	scale = Vector2(0.35, 0.35)
	var tween: Tween = create_tween()
	if born_from_evolution:
		# gameplay/core-loop-v4 "Evrim Laboratuvarı" vertical slice -- kullanıcı
		# talebi: "yeni canlı %115-125 ölçeğe kısa süre çıksın" (EVOLUTION_POP_
		# SCALE), sonra normal boyuta otursun -- toplam süre EVOLUTION_TRANSFORM_
		# DURATION ile aynı ailede (bkz. evolution_burst.gd, aynı anda oynar).
		var peak: float = GrayboxConfig.EVOLUTION_POP_SCALE
		var total: float = GrayboxConfig.EVOLUTION_TRANSFORM_DURATION
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector2(peak, peak), total * 0.55)
		tween.tween_property(self, "scale", Vector2.ONE, total * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector2.ONE, 0.28)
	if start_bonus_pulse:
		tween.tween_callback(_play_bonus_pulse)

## Bonus Sistemi: Dikkat çekmesi için ölçeği yavaşça büyütüp küçülterek sonsuz
## döngüde "nabız atar" gibi hafifçe büyüyüp küçülür.
func _play_bonus_pulse() -> void:
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.45)
	tween.tween_property(self, "scale", Vector2.ONE, 0.45)

## "blob" gövde tarifini (STAGE_SHAPES cfg) kullanarak tek parça, yumuşak
## hatlı bir çokgen üretir: temel daire, yönlü esnetme (x/y_scale) ve açıya
## göre yumuşak çıkıntılarla (bumps) o türe az çok benzer bir görünüm alır.
## "cell" gövdesi de aynı fonksiyonu kullanır (bkz. _process — animasyonlu cfg ile).
## NOT: artık hiçbir STAGE_SHAPES girdisi "blob" kullanmıyor (bkz. dosya başı
## UI/UX notu) — bu fonksiyon "cell" için ve geriye dönük varsayılan olarak korunuyor.
func _build_shape(cfg: Dictionary, radius: float, segments: int = 48) -> PackedVector2Array:
	var x_scale: float = cfg.get("x_scale", 1.0)
	var y_scale: float = cfg.get("y_scale", 1.0)
	var bumps: Array = cfg.get("bumps", [])
	var points := PackedVector2Array()
	for i in range(segments):
		var angle: float = TAU * i / segments
		var r: float = _radius_at_angle(angle, radius, bumps)
		points.append(Vector2(cos(angle) * r * x_scale, sin(angle) * r * y_scale))
	return points

## Verilen açıda, bumps listesine göre hesaplanan yarıçapı döndürür. Hem
## _build_shape (gövde silueti) hem _add_face (göz konumu, yüzey üzerinde
## olsun diye) tarafından paylaşılır.
func _radius_at_angle(angle: float, radius: float, bumps: Array) -> float:
	var r: float = radius
	for bump in bumps:
		var diff: float = _angle_diff(angle, bump.get("angle", 0.0))
		var width: float = max(bump.get("width", 0.5), 0.001)
		var falloff: float = clamp(1.0 - abs(diff) / width, 0.0, 1.0)
		falloff = falloff * falloff
		r += radius * bump.get("height", 0.0) * falloff
	return r

## İki açı arasındaki en kısa farkı [-PI, PI] aralığında döndürür.
func _angle_diff(a: float, b: float) -> float:
	var d: float = fmod(a - b, TAU)
	if d > PI:
		d -= TAU
	elif d < -PI:
		d += TAU
	return d

## "segmented" gövde tipi (Solucan/Yılan) için omurga üzerindeki t∈[0,1]
## noktasına ait konum, teğet (tangent), dikey (perpendicular) yön ve o
## noktadaki yarım genişliği hesaplar. _build_segmented_shape, _add_segment_rings,
## _add_face_segmented ve _add_segment_accessory tarafından paylaşılır —
## omurga matematiği tek yerde.
func _spine_sample(cfg: Dictionary, radius: float, t: float) -> Dictionary:
	var half_len: float = radius * float(cfg.get("length_ratio", 3.0)) / 2.0
	var amp: float = radius * float(cfg.get("wave_amplitude_ratio", 0.3))
	var waves: float = float(cfg.get("wave_count", 1.0))
	var phase: float = float(cfg.get("wave_phase", 0.0))
	var head_w: float = radius * float(cfg.get("head_width_ratio", 1.0))
	var tail_w: float = radius * float(cfg.get("tail_width_ratio", 0.6))

	var x: float = lerp(-half_len, half_len, t)
	var y: float = amp * sin(t * PI * waves + phase)
	var next_t: float = min(t + 0.01, 1.0)
	var next_x: float = lerp(-half_len, half_len, next_t)
	var next_y: float = amp * sin(next_t * PI * waves + phase)
	var tangent: Vector2 = Vector2(next_x, next_y) - Vector2(x, y)
	tangent = tangent.normalized() if tangent.length() > 0.0001 else Vector2(1, 0)
	var perpendicular: Vector2 = Vector2(-tangent.y, tangent.x)

	var half_width: float = lerp(tail_w, head_w, t)
	# Uçlara yaklaşınca genişliği daraltarak yuvarlak baş/kuyruk hissi ver.
	var end_taper: float = min(min(t * 6.0, (1.0 - t) * 6.0), 1.0)
	half_width *= max(end_taper, 0.15)
	# Onikinci geri bildirim ("solucan biraz daha benzesin"): işaretliyse
	# (bkz. STAGE_SHAPES[2] segment_bulge) boyunca hafif periyodik bir
	# genişlik dalgalanması ekler — tekdüze incelen bir tüp yerine gerçek bir
	# tırtıl/solucan gövdesinin halka halka görünümünü taklit eder.
	var bulge_amplitude: float = float(cfg.get("segment_bulge", 0.0))
	if bulge_amplitude > 0.0:
		var bulge_count: float = float(cfg.get("segment_bulge_count", 5))
		half_width *= 1.0 + bulge_amplitude * sin(t * bulge_count * PI)

	return {
		"position": Vector2(x, y),
		"tangent": tangent,
		"perpendicular": perpendicular,
		"half_width": half_width,
	}

## "segmented" gövde tipi için omurga boyunca daralan/genişleyen, hafifçe
## kıvrılan (S eğrisi) kapalı bir tüp/gövde çokgeni üretir.
func _build_segmented_shape(cfg: Dictionary, radius: float) -> PackedVector2Array:
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for i in range(SEGMENT_CURVE_SAMPLES + 1):
		var t: float = float(i) / float(SEGMENT_CURVE_SAMPLES)
		var s: Dictionary = _spine_sample(cfg, radius, t)
		top.append(s.position + s.perpendicular * s.half_width)
		bottom.append(s.position - s.perpendicular * s.half_width)
	var points := PackedVector2Array()
	for p in top:
		points.append(p)
	for i in range(bottom.size() - 1, -1, -1):
		points.append(bottom[i])
	return points

## "segmented" gövdelere, gerçek bir solucan/yılanın halka/pul izlerini
## anımsatan birkaç ince, koyu tonlu enine çizgi ekler.
func _add_segment_rings(cfg: Dictionary, radius: float, body_color: Color) -> void:
	var ring_color: Color = body_color.darkened(SEGMENT_RING_DARKEN)
	for i in range(1, SEGMENT_RING_COUNT + 1):
		var t: float = float(i) / float(SEGMENT_RING_COUNT + 1)
		var s: Dictionary = _spine_sample(cfg, radius, t)
		var w: float = s.half_width * 0.85
		var ring := Line2D.new()
		ring.points = PackedVector2Array([s.position + s.perpendicular * w, s.position - s.perpendicular * w])
		ring.width = SEGMENT_RING_WIDTH
		ring.default_color = ring_color
		ring.z_index = 1
		add_child(ring)
