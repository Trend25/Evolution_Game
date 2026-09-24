extends Node
## OrganismTypes — Autoload. UC-02: Evrimleşme (Merge) için sıralı evrim
## aşaması verilerini tutar (Tek Hücreliden Dinozora / T-Rex'e kadar).
## Mimari Belge Bölüm 1 & UC-02 tablosuna referanstır.

# Her aşama: id (sıra), name, radius (çarpışma yarıçapı, px), score_value, xp_value.
# Sihirli sayı kullanılmaması için tüm değerler bu tabloda merkezileştirilmiştir.
#
# feat: improve mobile scale and scoring feedback (Bölüm B+C) --
#
# BOYUT (radius): kullanıcı sahada "oyun alanının ~%70'i boş görünüyor,
# canlılar çok küçük" bulgusunu bildirdi. organism.gd._apply_stage() (fiziksel
# collision shape) ve organism_visual.gd._add_scaled_sprite() (görsel sprite)
# İKİSİ DE aynı bu radius değerini kullandığından (tek kaynak, ayrıca
# doğrulandı) burada SADECE veri değiştirmek sprite+collision+merge mesafesini
# birlikte, orantılı şekilde büyütmeye yeter -- ayrı bir ölçekleme sistemi
# GEREKMEDİ. 720px genişlikte hedeflenen çap aralıkları (kullanıcı isteği):
# stage0 ≥48px, stage1 58-64px, stage2 70-78px, stage3 84-94px, sonraki
# aşamalar net ve kademeli büyümeye devam etmeli. Yeni tablo (çap = radius*2):
# id0=50px, id1=62px, id2=76px, id3=92px (dördü de hedef aralıkta), id4..id9
# eski değerlerin belirgin şekilde üzerinde, kademeli artan bir eğriyle
# büyütüldü (id9/T-Rex çapı 288px'den 332px'e). Evrim sırası/mevcut sanat
# eserleri DEĞİŞMEDİ, yalnızca ölçek.
#
# SKOR (score_value): kullanıcı "tek tek +1 skorlaması çok yavaş, ödül hissi
# yok" bulgusunu bildirdi ve TAM 9 değerden oluşan yeni bir merkezi tablo
# istedi: "Stage 1: +20 ... Stage 9: +1000". DÜZELTME (kullanıcı geri
# bildirimi, ilk sürümdeki id=N-1 eşlemesi ve id=9 için ekstrapole edilen
# +1500 GERİ ALINDI): Stage 0 ("başlangıç canlısı") bir birleşme ÖDÜLÜ
# DEĞİLDİR -- yalnızca sabit +5 bırakma ödülüyle (GameManager.add_drop_reward,
# bkz. spawner.gd) ilişkilidir. "Birleşme SONUCUNDA Stage 1-9 oluşur, T-Rex
# Stage 9'dur": bu projede id DEĞERİ doğrudan kullanıcının "Stage" numarasıyla
# eşleşir (id=1 → "Stage 1" = +20, ..., id=9/T-Rex → "Stage 9" = +1000) --
# id=0'ın KENDİ score_value'su hiç ödül olarak okunmaz (0 bırakıldı, yanlış
# kullanılırsa hemen fark edilsin diye).
#
# Birleşme ödülü hâlâ ÖN-birleşme stage_id'sinden hesaplanır
# (add_merge_reward(stage_id, ...), bkz. organism.gd _perform_merge --
# ÇAĞRI İMZASI DEĞİŞMEDİ), ama GameManager.add_merge_reward artık SKORU
# stage_id+1'in (son aşama 9'da SABİTLENİR: min(stage_id+1, 9)) score_value'
# sundan okuyor (bkz. game_manager.gd -- reward_stage_id), çünkü iki id=K
# canlının birleşmesi id=K+1'i ÜRETİR ve ödül o SONUÇ aşamasına aittir.
# Örnek: iki id=0 birleşince id=1 üretilir → ödül = STAGES[1] = +20 ("Stage
# 1"). İki id=8 birleşince id=9/T-Rex üretilir → ödül = STAGES[9] = +1000
# ("Stage 9"). İki id=9/T-Rex birleşince (son aşama evrilmeye devam etmez,
# "sadece ödül verilir") min(9+1,9)=9 sabitlemesiyle YİNE STAGES[9] = +1000
# okunur -- kullanıcının "T-Rex Stage 9'dur, puanı +1000 olmalı" ifadesiyle
# BİREBİR örtüşür. Kullanıcının verdiği 9 değerin TAMAMI (Stage 1..9) burada
# birebir kullanılır -- ekstrapolasyon YOKTUR, eksik değer yoktur.
#
# xp_value skor tablosuyla KARIŞTIRILMADI -- XP ekonomisi (seviye/kalıcı
# ödül sistemi, UC-05) bu değişikliğin kapsamı dışında bırakıldı, eski
# xp_value'lar AYNEN korundu (xp_value hâlâ ÖN-birleşme stage_id'sinden
# doğrudan okunur, score_value'nun aksine KAYDIRILMAZ).
const STAGES: Array[Dictionary] = [
	{"id": 0, "name": "Tek Hücreli", "radius": 25.0, "score_value": 0, "xp_value": 1},
	{"id": 1, "name": "Amip", "radius": 31.0, "score_value": 20, "xp_value": 2},
	{"id": 2, "name": "Solucan", "radius": 38.0, "score_value": 40, "xp_value": 4},
	{"id": 3, "name": "Balık", "radius": 46.0, "score_value": 70, "xp_value": 8},
	{"id": 4, "name": "Kurbağa", "radius": 60.0, "score_value": 110, "xp_value": 16},
	{"id": 5, "name": "Kertenkele", "radius": 76.0, "score_value": 170, "xp_value": 32},
	{"id": 6, "name": "Yılan", "radius": 94.0, "score_value": 260, "xp_value": 64},
	{"id": 7, "name": "Kuş", "radius": 115.0, "score_value": 400, "xp_value": 128},
	{"id": 8, "name": "Memeli", "radius": 138.0, "score_value": 650, "xp_value": 256},
	{"id": 9, "name": "Dinozor (T-Rex)", "radius": 166.0, "score_value": 1000, "xp_value": 512},
]

const MAX_SPAWNABLE_STAGE_ID: int = 4  # UC-01: Spawner yalnızca ilk aşamaları üretir; T-Rex elle bırakılmaz.

## Verilen aşama id'sinin bir üst evrim aşamasını döndürür; son aşamadaysa boş Dictionary döner.
func get_next_stage(stage_id: int) -> Dictionary:
	var next_id: int = stage_id + 1
	if next_id < 0 or next_id >= STAGES.size():
		return {}
	return STAGES[next_id]

## Verilen id'ye ait aşama verisini döndürür; geçersiz id'de boş Dictionary döner.
func get_stage(stage_id: int) -> Dictionary:
	if stage_id < 0 or stage_id >= STAGES.size():
		return {}
	return STAGES[stage_id]

## UC-01: Spawner için rastgele bir başlangıç aşaması seçer (0..MAX_SPAWNABLE_STAGE_ID arası).
func get_random_spawnable_stage_id() -> int:
	return randi() % (MAX_SPAWNABLE_STAGE_ID + 1)

# Solucan büyüme mekaniği (kullanıcı isteği — "solucan küçük başlasın, üst
# üste geldikçe büyümeye başlasın"): TIERED_GROWTH_STAGE_ID aşamasında iki
# tier-0 canlı birleştiğinde bir üst aşamaya ATLAMAZ, sadece daha BÜYÜK
# (tier 1) aynı-aşama bir canlı olur (bkz. organism.gd
# _should_grow_instead_of_evolve/_perform_merge). Bu tablo hem organism.gd
# (fiziksel boyut/merge kararı) hem organism_visual.gd (görsel boyut)
# tarafından paylaşılır ki ikisi asla birbirinden sapmasın.
const TIERED_GROWTH_STAGE_ID: int = 2      # Solucan
const TIER_SIZE_SCALE_STEP: float = 0.35   # tier 1: %35 daha büyük fiziksel/görsel boyut

## Verilen aşama+tier için fiziksel/görsel boyut çarpanını döndürür. Diğer
## tüm aşamalarda (tier hep 0 kaldığından) her zaman 1.0 döner.
func tier_size_multiplier(for_stage_id: int, tier: int) -> float:
	if for_stage_id != TIERED_GROWTH_STAGE_ID or tier <= 0:
		return 1.0
	return 1.0 + float(tier) * TIER_SIZE_SCALE_STEP
