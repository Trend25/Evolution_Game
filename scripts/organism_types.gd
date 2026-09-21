extends Node
## OrganismTypes — Autoload. UC-02: Evrimleşme (Merge) için sıralı evrim
## aşaması verilerini tutar (Tek Hücreliden Dinozora / T-Rex'e kadar).
## Mimari Belge Bölüm 1 & UC-02 tablosuna referanstır.

# Her aşama: id (sıra), name, radius (çarpışma yarıçapı, px), score_value, xp_value.
# Sihirli sayı kullanılmaması için tüm değerler bu tabloda merkezileştirilmiştir.
const STAGES: Array[Dictionary] = [
	{"id": 0, "name": "Tek Hücreli", "radius": 16.0, "score_value": 1, "xp_value": 1},
	{"id": 1, "name": "Amip", "radius": 22.0, "score_value": 2, "xp_value": 2},
	{"id": 2, "name": "Solucan", "radius": 30.0, "score_value": 4, "xp_value": 4},
	{"id": 3, "name": "Balık", "radius": 40.0, "score_value": 8, "xp_value": 8},
	{"id": 4, "name": "Kurbağa", "radius": 52.0, "score_value": 16, "xp_value": 16},
	{"id": 5, "name": "Kertenkele", "radius": 66.0, "score_value": 32, "xp_value": 32},
	{"id": 6, "name": "Yılan", "radius": 82.0, "score_value": 64, "xp_value": 64},
	{"id": 7, "name": "Kuş", "radius": 100.0, "score_value": 128, "xp_value": 128},
	{"id": 8, "name": "Memeli", "radius": 120.0, "score_value": 256, "xp_value": 256},
	{"id": 9, "name": "Dinozor (T-Rex)", "radius": 144.0, "score_value": 512, "xp_value": 512},
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
