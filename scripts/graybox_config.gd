extends Node
## GrayboxConfig — Autoload. V4 core-loop/graybox kontrol prototipi için TEK,
## merkezi ayar kaynağı. Hiçbir sihirli sayı başka dosyalara dağılmaz; tüm
## graybox-özel davranış (tempo, görsel ölçek, merge-assist, HUD sadeleştirme,
## intro akışı) buradan AÇILIP KAPATILIR ve buradan AYARLANIR.
##
## ÖNEMLİ: ENABLED=false olduğunda (varsayılan üretim davranışı) tüm bağımlı
## script'ler (organism.gd, organism_visual.gd, hud_root.gd, environment_bounds.gd,
## spawner.gd, game_manager.gd vb.) MEVCUT üretim davranışını AYNEN korur --
## bu dosya hiçbir üretim mantığını (skor/XP/merge/fizik) DEĞİŞTİRMEZ, sadece
## graybox modu etkinken davranışı şartlı olarak DALLANDIRIR.
##
## Bu görev kapsamında (gameplay/core-loop-v4) ENABLED=true olarak QA/video
## amaçlı ayarlanmıştır -- üretime (main/ui-hud-* branch'leri) taşınmayacaktır.

## Graybox prototip modu ana anahtarı.
const ENABLED: bool = true

# --- Tempo (madde 2/3: aim guide + fiziksel zamanlama) --------------------
#
# Kalibrasyon notu: Spawner'ın sabit y=100 konumundan boş bir fanusa (taban
# MAX_PLAY_HEIGHT'ta) düşüş mesafesi ~800px. GRAVITY_MULTIPLIER=1.6 ile
# efektif yerçekimi ~1568px/s² olur → boş-fanus ilk temas süresi ~1.0s
# (hesap: t=sqrt(2*800/1568)). Bu, TİPİK oyun-içi bırakmalar (yığın zaten
# kısmen doluyken, düşüş mesafesi çok daha kısa) için hedef 0.6-0.9s
# aralığına girer; SADECE turun çok ilk (tamamen boş fanus) bırakması bir
# miktar üzerinde ölçülür -- daha yüksek bir çarpan bu boş-fanus süresini
# daha da kısaltabilirdi ama merge anındaki çarpışma enerjisini büyütüp
# fiziği istikrarsızlaştırma riski taşıdığından (kullanıcının açık uyarısı:
# "fiziği bozmadan") kasıtlı olarak seçilmedi. QA'da her iki durum da
# (boş fanus İLK bırakma + tipik yığın-üstü bırakma) ayrı ayrı ölçülüp
# rapor edilir.

## Graybox modunda oynanabilir dikey alanın üst sınırı (environment_bounds.gd
## DESIGN_HEIGHT yerine bunu kullanır ENABLED iken).
##
## GÜNCELLEME (2026-09-24, V02 vertical slice onay turu -- kullanıcı: "720x1650
##'de oyun zemini ekranın ortasında kalmış, altta devasa boş alan oluşmuş;
## oynanabilir alan ekranın TAMAMINI kullanmalı"): eski değer (1000.0) BİLİNÇLİ
## olarak küçük tutulmuştu (aşağıdaki eski not hâlâ geçerli SEBEP olarak
## duruyor -- boş-fanus düşüş mesafesini/süresini sınırlamak), ama 720x1650
## hedef çözünürlükte bu, tabanın ekranın ortasında kalıp ALTINDA ~650px boş
## alan bırakmasına yol açtı -- kullanıcı bunu SIKI biçimde reddetti. Yeni
## değer, tabanı gerçek ekranın (1650) altına YAKLAŞTIRIR (kullanıcı isteği
## VİZÜEL doluluk artık düşüş-süresi endişesinden ÖNCELİKLİ) -- boş-fanus
## düşüş süresindeki artış GRAVITY_MULTIPLIER'ın AYNI oranda büyütülmesiyle
## telafi edilir (bkz. hemen altı).
##
## ESKİ NOT (hâlâ geçerli, SADECE tavan değeri değişti): Spawner'ın sabit
## y=100 konumundan boş bir fanusa düşüş mesafesi artık ~1520px (eskiden
## ~800px, oran ~1.9x) -- GRAVITY_MULTIPLIER de AYNI oranda büyütüldüğünden
## (1.6 -> 2.7) boş-fanus ilk temas süresi hâlâ ~1.0-1.1s civarında kalır
## (hesap: t=sqrt(2*d/g_eff)); TİPİK oyun-içi bırakmalar (yığın zaten kısmen
## doluyken) yine çok daha kısa sürer.
const MAX_PLAY_HEIGHT: float = 1620.0

## Organism.gravity_scale'e ENABLED iken uygulanan çarpan -- hedef: bırakma
## (release) ile ilk temas arası 0.6-0.9s (tipik, kısmen dolu yığın için).
## GÜNCELLEME (2026-09-24, V02 vertical slice): MAX_PLAY_HEIGHT 1000->1620
## büyütüldüğü için (bkz. yukarı), düşüş mesafesi ~1.9x arttı -- boş-fanus
## düşüş SÜRESİNİ eski kalibrasyona YAKIN tutmak için bu değer de AYNI oranda
## (1.6 -> 2.7) büyütüldü. MERGE_ASSIST_ACCEL (aşağı) da AYNI oranda
## büyütüldü -- aksi halde artan efektif yerçekimi (980*2.7=2646 px/s²)
## sürtünmeyi merge-assist'in aşamayacağı noktaya taşırdı (bkz. o sabitin
## notu). Gerçek GL fizik QA'sında (merge/stall/çift-spawn) doğrulandı.
const GRAVITY_MULTIPLIER: float = 2.7

# --- Graybox görsel (madde 4) ----------------------------------------------

## Stage id -> düz graybox rengi. Yalnızca ENABLED iken organism_visual.gd
## tarafından okunur; STAGE_TEXTURES/procedural gövde çizimi YERİNE geçer,
## onları SİLMEZ/DEĞİŞTİRMEZ.
const STAGE_COLORS: Dictionary = {
	0: Color("#8FE3D2"),  # mint
	1: Color("#6FB5E0"),  # açık mavi
	2: Color("#F4C95D"),  # amber
	3: Color("#F08A5D"),  # mercan
	4: Color("#B98BE0"),  # eflatun
	5: Color("#7DD87D"),  # yeşil
	6: Color("#E0708F"),  # pembe-kırmızı
	7: Color("#5DD9C1"),  # turkuaz
	8: Color("#E0B45D"),  # altın-kahve
	9: Color("#D9534F"),  # T-Rex kırmızı
}

## Stage id -> büyütme çarpanı. DÜZELTME (kullanıcı geri bildirimi -- "görsel-
## collision uyumu"): eskiden SADECE görseli büyütüyordu, collision/merge/
## landing-marker eski (küçük) radius'ta kalıyordu -- görünüşte büyük ama
## dokunma/çarpışma alanı hâlâ küçük bir organizma ortaya çıkıyordu. Artık bu
## çarpan, effective_radius()/effective_mass() ARACILIĞIYLA TEK bir merkezi
## yarıçap üretir ve bu TEK değer aşağıdakilerin HEPSİNİ besler: graybox görsel
## boyutu (organism_visual.gd), CollisionShape2D (organism.gd _apply_stage),
## Spawner'ın yatay sınır payı (spawner.gd, max yarıçaptan türetilir), merge-
## assist kenar-kenar mesafesi (organism.gd _find_nearest_assist_target,
## collision_shape.shape.radius okur -- artık aynı kaynaktan), landing-marker
## raycast'i (drop_aim_guide.gd -- gerçek collision gövdesine çarptığından
## otomatik doğru), ve (isteğe bağlı) kütle (effective_mass). Kullanıcı
## bulgusu: "erken aşamalar telefonda hâlâ çok küçük" -- stage 0-3 belirgin
## şekilde büyütüldü.
## gameplay/core-loop-v4 "Evrim Laboratuvarı" vertical slice (2026-09-24):
## id 0/1/2 artık Virüs/Bakteri/Tek Hücreli ve organism_types.gd'deki radius
## DEĞERLERİ zaten hedef 720px ekran çaplarına (74/92/112px) ayarlandı -- bu
## yüzden bu üçü için EK bir graybox büyütme çarpanı GEREKMİYOR (1.0), aksi
## halde radius İKİ KERE büyütülmüş olurdu. id 3/4 (bu dilimde erişilemez,
## MAX_SPAWNABLE_STAGE_ID=0 ve VERTICAL_SLICE_FINAL_STAGE_ID=2) eski
## değerleriyle DOKUNULMADAN bırakıldı.
const VISUAL_SCALE_BY_STAGE: Dictionary = {
	0: 1.0,
	1: 1.0,
	2: 1.0,
	3: 1.25,
	4: 1.1,
}
const DEFAULT_VISUAL_SCALE: float = 1.0

## V4 core-loop/graybox DÜZELTME (kullanıcı: "görsel-collision uyumu" --
## yalnızca görsel büyütme kabul edilmiyor): TEK, merkezi efektif yarıçap
## kaynağı. ENABLED=false iken üretimle (organism.gd/organism_visual.gd'nin
## ESKİ, birbirinden bağımsız ama sayısal olarak AYNI hesabı: stage.radius *
## OrganismTypes.tier_size_multiplier) BİREBİR AYNI değeri döner -- üretim
## davranışı byte-level DEĞİŞMEZ (aynı float değeri, aynı formülden). ENABLED
## iken bu SAME değer -- yalnızca stage-bazlı VISUAL_SCALE_BY_STAGE ile
## büyütülmüş hali -- collision shape, görsel boyut, merge-assist mesafesi VE
## landing-marker raycast'i (collision shape üzerinden dolaylı) besler.
func effective_radius(stage_id: int, tier: int = 0) -> float:
	var stage: Dictionary = OrganismTypes.get_stage(stage_id)
	var base: float = float(stage.get("radius", 16.0)) * OrganismTypes.tier_size_multiplier(stage_id, tier)
	if not ENABLED:
		return base
	var scale: float = float(VISUAL_SCALE_BY_STAGE.get(stage_id, DEFAULT_VISUAL_SCALE))
	return base * scale

## Fizik güvenliği (madde 1 -- "gerekliyse kütle hesabı"): ENABLED iken
## collision/görsel yarıçap büyüdüğü için, TÜM aşamalarda sabit mass=1.0'ı
## (Organism.tscn'in mevcut/DEĞİŞMEMİŞ varsayılanı) korumak yerine, gerçek bir
## 2D disk gibi ALAN (radius^2) oranıyla orantılı kütle döner -- böylece büyük
## graybox daireleri fiziksel olarak da "daha ağır" hisseder, çarpışma/merge-
## assist tepkisi öngörülebilir kalır (bkz. organism.gd _apply_stage).
## ENABLED=false iken HER ZAMAN 1.0 döner -- üretim davranışı DEĞİŞMEZ.
func effective_mass(stage_id: int, _tier: int = 0) -> float:
	if not ENABLED:
		return 1.0
	var scale: float = float(VISUAL_SCALE_BY_STAGE.get(stage_id, DEFAULT_VISUAL_SCALE))
	return scale * scale

## QA-only aşama numarası etiketini (organism.gd show_debug_label) graybox
## modunda otomatik açar -- üretime taşınmaz, sadece ölçüm/QA kolaylığı.
const SHOW_QA_STAGE_LABEL: bool = true

# --- Merge-assist (madde 5) -------------------------------------------------

const MERGE_ASSIST_ENABLED: bool = true
# ÖNEMLİ (QA sırasında bulunan tasarım düzeltmesi): eşik, merkez-merkez
# mesafe DEĞİL, KENAR-KENAR boşluğudur (center_distance - (radius_a+radius_b)).
# Merkez-merkez bir sabit kullanılsaydı (ör. 46px) küçük aşamalarda bu değer
# organizmaların kendi çaplarından (stage0 çapı 50px, stage1 62px...) KÜÇÜK
# kalır ve "yakın ama henüz temas etmemiş" durumu hiç YAKALANAMAZ -- eşiğin
# altındaki her çift zaten fiziksel olarak ÇAKIŞIYOR olurdu. Kenar-kenar
# boşluk kullanmak, aşama boyutundan BAĞIMSIZ, tutarlı bir "yakınlık" tanımı
## verir (bkz. organism.gd _find_nearest_assist_target). Yarıçaplar artık
## GERÇEK collision shape'ten (GrayboxConfig.effective_radius ile büyütülmüş)
## okunur -- görsel-collision uyum düzeltmesinden sonra bu eşik hâlâ geçerli.
const MERGE_ASSIST_GAP: float = 40.0           # bu kenar-kenar boşluğun (px) altındaki AYNI-stage organizmalar için etkin

# DÜZELTME (kullanıcı: "physics-safe merge assist" -- doğrudan position/
# global_position atamasına dayalı önceki yaklaşım KALDIRILDI, fizik motorunu
# baypas ediyordu). Artık organism.gd._integrate_forces() içinde SADECE
# apply_central_force() ile, motorun kendi temas/sürtünme çözücüsüyle TAM
# entegre bir kuvvet uygulanır. MERGE_ASSIST_ACCEL, bu gövdenin KENDİ
# kütlesiyle çarpılıp bir kuvvete dönüştürülür (F=kütle*ACCEL) -- böylece
# effective_mass() ile büyüyen kütleden BAĞIMSIZ, tutarlı bir ivme hissi
# sağlanır. Kalibrasyon notu: varsayılan proje sürtünmesi (PhysicsMaterial
# atanmamış -- Godot varsayılanı) + GRAVITY_MULTIPLIER=1.6 altında dururken
# statik sürtünmeyi aşmak için gereken ivme yaklaşık gravity*GRAVITY_MULTIPLIER
# (980*1.6=1568 px/s²) mertebesindedir; ACCEL bunun belirgin ÜZERİNDE
## tutulur ki sürtünme tarafından her zaman iptal edilmesin (izole diagnostic
## script ile QA'da ölçülüp doğrulandı).
## GÜNCELLEME (2026-09-24, V02 vertical slice): GRAVITY_MULTIPLIER 1.6->2.7
## büyütüldüğü için (bkz. o sabitin notu) AYNI oranda (~1.69x) büyütüldü --
## eski oran (2400/1568≈1.53x güvenlik payı) korunsun diye: 2400*1.69≈4050.
const MERGE_ASSIST_ACCEL: float = 4050.0       # px/s² -- kütleyle çarpılıp apply_central_force'a verilir
const MERGE_ASSIST_MAX_SPEED: float = 70.0     # px/s -- kuvvet bu hıza ulaşınca KESİLİR (hız-sınırlı, teleport/aşırı hızlanma YOK)
const MERGE_ASSIST_MAX_DURATION: float = 0.6   # saniye -- bu süreden uzun çekilemez (uzun-mesafe/sonsuz çekim YOK)
## DİKEY hız (|linear_velocity.y|) bu değerin ÜZERİNDEYKEN (hâlâ serbest
## düşüyor) assist devre dışıdır -- yalnızca yerleşmeye yakın/durmuş
## organizmalara uygulanır. Assist SADECE yatay kuvvet (apply_central_force
## x-bileşeni) uygular, dikey hıza (düşme fiziği) HİÇ dokunmaz/okumaz dışında
## bu tek eşik kontrolü (bkz. organism.gd _integrate_forces fizik-güvenliği
## notu).
const MERGE_ASSIST_MIN_SPEED_TO_ARM: float = 140.0

# --- Geri bildirim (madde 6) ------------------------------------------------

## Bonus canlıların SÜREKLİ nabız halosu graybox modunda kapatılır -- kullanıcı
## bulgusu: "sürekli sarı hale kafa karıştırıcı". Bonus tint/renk KORUNUR,
## sadece sonsuz döngülü pulse animasyonu iptal edilir.
const SUPPRESS_PERSISTENT_BONUS_HALO: bool = true

# --- HUD sadeleştirme (madde 7) --------------------------------------------

## LivesUI'ı GÖRSEL olarak gizler (hud_root.gd) -- GameManager.lives_changed
## bağlantısı ve can mantığının KENDİSİ SİLİNMEZ, sadece kalp ikonları render
## edilmez ve Sol Panel içeriği yeniden ortalanır.
const HIDE_LIVES_UI: bool = true

# --- İlk 30 saniye akışı (madde 9) -----------------------------------------

## Deterministik/tekrarlanabilir QA ölçümü için sabit seed. run_reset()
## sırasında ENABLED iken uygulanır.
const INTRO_SEED: int = 20260924

## İlk N bırakma her zaman Stage 0 (Virüs) -- ilk merge'in erken ve
## garanti gerçekleşmesi için (hedef: ≤10s, kullanıcı talebi).
const INTRO_FORCED_STAGE0_COUNT: int = 2

# --- "Evrim Laboratuvarı" V02 vertical slice (2026-09-24) ------------------
#
# Kullanıcı V02 tasarım yönünü koşullu onayladı ve grayboks/debug görünümünü
# TAMAMEN reddetti ("prototip hâlâ sıradan, sıkıcı ve temadan kopuk") --
# bu yüzden yukarıdaki ESKİ graybox davranışları (madde 2/4/6/7 -- kesikli
## nişan çizgisi, düz renkli daireler, sürekli bonus halosu bastırma, HUD
## sadeleştirme) korunmakla birlikte, GÖRSEL/ETKİLEŞİM katmanı için AYRI bir
## anahtarla yeni "lab" davranışına geçilir. ENABLED hâlâ tempo/merge-assist/
## flushing-queries-düzeltmesi/intro-seed gibi SAF FİZİK/ZAMANLAMA
## mekanizmalarını yönetir (DEĞİŞMEDİ) -- LAB_VISUALS_ENABLED SADECE hangi
## görsel/UI katmanının (eski düz graybox daire+kesikli çizgi VS yeni
## Virüs/Bakteri/Tek Hücreli organik görselleri+hayalet nişan+ışıklı aktarım)
## kullanılacağını seçer (bkz. organism_visual.gd, next_preview.gd,
## drop_aim_guide.gd).
const LAB_VISUALS_ENABLED: bool = true

## Mutasyon: her kaç GERÇEK evrim (stage-up) merge'inde DNA göstergesi dolar
## (bkz. game_manager.gd _advance_dna, mutation_sheet.gd).
const DNA_REQUIRED_MERGES: int = 5

## Işıklı aktarım (release anı): huzme bu aralıkta söner -- fizik/collision/
## hız/iniş konumuna HİÇ dokunmaz, SADECE görsel (bkz. light_transfer_beam.gd).
## GÜNCELLEME (kullanıcı: "bırakma sırasında 0.4-0.7 saniyelik kısa ışıklı
## iniş izi"): üst sınır 0.6'dan 0.7'ye çıkarıldı, tam istenen aralık.
const TRANSFER_LIGHT_MIN_DURATION: float = 0.4
const TRANSFER_LIGHT_MAX_DURATION: float = 0.7

## Evrim dönüşümü: yeni canlının kısa süreliğine büyüdüğü tepe ölçek (%115-125
## hedefi) ve dönüşüm/DNA-sarmalı efektinin toplam süresi (bkz.
## organism_visual.gd _play_spawn_pop, evolution_burst.gd).
const EVOLUTION_POP_SCALE: float = 1.2
const EVOLUTION_TRANSFORM_DURATION: float = 0.6

# --- "Evrim Laboratuvarı" V02 İKİNCİ düzeltme turu (2026-09-25) -----------
#
# Kullanıcı ilk düzeltme turunu da reddetti: "Portal çevresindeki üst üste
# binen büyük hayalet şekilleri kaldır" + "Portalı HUD'dan biraz aşağı
# indir; NEXT paneliyle görsel olarak birleşmemeli". KÖK NEDEN: önceki turda
# dna_portal.gd (kalıcı portal) VE drop_aim_guide.gd (aim hayaleti) AYNI
# sabit (90.0) dikey kaymayı kullanıyordu -- yani ikisi TAM AYNI noktada,
# üst üste çiziliyordu. Artık TEK, merkezi bir kaynaktan iki AYRI değer:
## portal HUD'un biraz altında SABİT KALIR, hayalet/canlı önizlemesi onun
## BELİRGİN ŞEKİLDE altında durur -- aralarında görünür bir boşluk var.
## Spawner'ın GERÇEK (fizik) y=100 konumuna dokunulmadı, bu SADECE görsel
## bir kayma (bkz. dna_portal.gd, drop_aim_guide.gd, drop_feedback_manager.gd).
const PORTAL_ANCHOR_Y_OFFSET: float = 110.0
const AIM_GHOST_Y_OFFSET: float = 240.0
