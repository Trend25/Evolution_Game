extends Node2D
## LabPreviewHost -- gameplay/core-loop-v4 "Evrim Laboratuvarı" vertical
## slice. Sadece NextPreview (next_preview.gd) tarafından kullanılan, DÜNYA-
## UZAYINDA hiçbir karşılığı olmayan, fizik/collision/merge'i OLMAYAN bir
## "duck-typed" ev sahibi. organism_visual.gd'nin _ready()'si ebeveynini
## `get_parent().get("stage_id")` vb. ile okuduğundan, gerçek bir Organism
## (RigidBody2D) instantiate ETMEDEN aynı sözleşmeyi (stage_id/tier/is_bonus/
## is_fish_part/fish_part_index) taşıyan hafif bir Node2D burada sağlanır --
## böylece NEXT paneli, organism_visual.gd'nin GERÇEK (tek kaynak, asla
## çatallanmayan) çizim kodunu birebir kullanabilir.
@export var stage_id: int = 0
@export var tier: int = 0
@export var is_bonus: bool = false
@export var is_fish_part: bool = false
@export var fish_part_index: int = 0
## organism_visual.gd _ready()'nin sonunda _play_spawn_pop için okunur --
## NEXT önizlemesi hiçbir zaman "evrimle doğmuş" değildir, her zaman false.
@export var born_from_evolution: bool = false
