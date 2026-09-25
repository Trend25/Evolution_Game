extends Node2D
class_name CollectionStrip
## CollectionStrip -- gameplay/core-loop-v4 "Evrim Laboratuvarı" V02 vertical
## slice (madde 5 -- kullanıcı: "Bakteri koleksiyon aşaması yanar"). SADECE
## GÖRSEL: bu dilimin kapsadığı 3 aşamayı (Virüs/Bakteri/Tek Hücreli) küçük
## dairecikler olarak gösterir -- KEŞFEDİLMEMİŞ aşama soluk bir ana hatla,
## KEŞFEDİLMİŞ aşama kendi rengiyle dolu çizilir. Keşif durumunun KENDİSİ
## (discovered_stage_ids) TAMAMEN game_manager.gd'de tutulur, bu script
## yalnızca GameManager.new_life_discovered sinyalinden ZATEN hesaplanmış
## veriyi GÖSTERİR. XPBar/DnaGauge ile AYNI desen: hiçbir çocuk sahne düğümü
## GEREKMEZ, tamamen _draw() ile kendi kendine yeter.

const STAGE_IDS: Array[int] = [0, 1, 2]  # bu dilimin TAMAMI -- OrganismTypes.VERTICAL_SLICE_FINAL_STAGE_ID ile birebir
const ICON_RADIUS: float = 9.0
const ROW_HEIGHT: float = ICON_RADIUS * 2.0 + 4.0  # HUDRoot bu satırın toplam yüksekliğini bilmek için kullanır

const UNDISCOVERED_RING_COLOR: Color = Color(1.0, 1.0, 1.0, 0.22)
const UNDISCOVERED_RING_WIDTH: float = 1.6
const DISCOVERED_OUTLINE_COLOR: Color = Color(0.04, 0.08, 0.07, 0.55)
const DISCOVERED_OUTLINE_WIDTH: float = 1.2

const OrganismVisualScript: GDScript = preload("res://scripts/organism_visual.gd")

var _row_width: float = 96.0
var _discovered: Dictionary = {}  # stage_id -> true, GameManager.discovered_stage_ids'in KENDİ kopyası değil -- sadece bu düğümün render önbelleği
var _pulse_tween: Tween = null
var _pulse_stage_id: int = -1
var _pulse_scale: float = 1.0

func _ready() -> void:
	GameManager.new_life_discovered.connect(_on_new_life_discovered)
	GameManager.run_reset.connect(_on_run_reset)
	queue_redraw()

## HUDRoot tarafından, XPBar/DnaGauge.set_bar_width() ile AYNI sözleşmeyle çağrılır.
func set_row_width(width: float) -> void:
	_row_width = max(float(STAGE_IDS.size()) * ICON_RADIUS * 2.0, width)
	queue_redraw()

func _on_new_life_discovered(stage_id: int, _stage_name: String, is_first_ever: bool) -> void:
	if not is_first_ever or not STAGE_IDS.has(stage_id):
		return
	_discovered[stage_id] = true
	_pulse_stage_id = stage_id
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.tween_method(_set_pulse_scale, 1.0, 1.35, 0.14).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_method(_set_pulse_scale, 1.35, 1.0, 0.22).set_ease(Tween.EASE_IN)
	queue_redraw()

func _on_run_reset(_final_stats: Dictionary = {}) -> void:
	_discovered.clear()
	_pulse_stage_id = -1
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	queue_redraw()

func _set_pulse_scale(value: float) -> void:
	_pulse_scale = value
	queue_redraw()

func _draw() -> void:
	var count: int = STAGE_IDS.size()
	if count == 0:
		return
	var slot_width: float = _row_width / float(count)
	for i in range(count):
		var stage_id: int = STAGE_IDS[i]
		var center: Vector2 = Vector2(slot_width * (float(i) + 0.5), ICON_RADIUS)
		var is_discovered: bool = _discovered.has(stage_id)
		var base_color: Color = OrganismVisualScript.STAGE_COLORS[stage_id % OrganismVisualScript.STAGE_COLORS.size()]
		if is_discovered:
			var r: float = ICON_RADIUS * (_pulse_scale if stage_id == _pulse_stage_id else 1.0)
			draw_circle(center, r, base_color)
			draw_arc(center, r, 0.0, TAU, 20, DISCOVERED_OUTLINE_COLOR, DISCOVERED_OUTLINE_WIDTH, true)
		else:
			draw_arc(center, ICON_RADIUS * 0.72, 0.0, TAU, 20, UNDISCOVERED_RING_COLOR, UNDISCOVERED_RING_WIDTH, true)
