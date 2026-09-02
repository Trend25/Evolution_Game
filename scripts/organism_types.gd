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
