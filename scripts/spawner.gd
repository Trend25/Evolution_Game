extends Node2D
class_name Spawner
## Spawner — UC-01: Canlı Bırakma. Oyuncunun parmağını/imlecini yatay eksende
## takip eder, bıraktığında canlıyı serbest bırakır ve ardından bekleme
## süresi (cooldown) uygular.

const DROP_COOLDOWN_SECONDS: float = 1.0    # UC-01 Adım 3: Spam koruması
const HORIZONTAL_MARGIN: float = 40.0       # Canlının fanus duvarlarına gömülmesini engelleyen kenar payı
const ORGANISM_SCENE: PackedScene = preload("res://scenes/Organism.tscn")

@export var left_bound_x: float = 0.0
@export var right_bound_x: float = 720.0

var _is_dragging: bool = false
var _cooldown_remaining: float = 0.0
var _pending_organism: Organism = null

func _ready() -> void:
	_prepare_next_organism()

## Cooldown süresini her karede azaltır.
func _process(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining = max(0.0, _cooldown_remaining - delta)

## UC-01: Dokunma/tıklama ve sürükleme girdilerini yakalar (mobil dokunma + editör test için fare).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_set_dragging(event.pressed, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_set_dragging(event.pressed, event.position)
	elif event is InputEventScreenDrag:
		_handle_drag(event.position)
	elif event is InputEventMouseMotion and _is_dragging:
		_handle_drag(event.position)

## UC-01 Adım 1/2: Basılı tutma sürüklemeyi başlatır; parmağı/imleci çekme canlıyı düşürür.
func _set_dragging(pressed: bool, event_position: Vector2) -> void:
	_is_dragging = pressed
	if pressed:
		_handle_drag(event_position)
	else:
		_drop_current_organism()

## UC-01 Adım 1: Spawner'ı yatay eksende, fanus sınırları içinde parmağa/imlece göre konumlandırır.
## Bekleyen canlı Spawner'ın çocuğu olduğundan otomatik olarak onunla birlikte hareket eder.
func _handle_drag(screen_position: Vector2) -> void:
	global_position.x = clamp(screen_position.x, left_bound_x + HORIZONTAL_MARGIN, right_bound_x - HORIZONTAL_MARGIN)

## UC-01 Adım 2-3: Gösterilen canlıyı serbest bırakır (yerçekimine bırakır), fanusun
## OrganismContainer'ına taşır ve 1 saniyelik bırakma cooldown'ını başlatır.
func _drop_current_organism() -> void:
	if _cooldown_remaining > 0.0 or _pending_organism == null:
		return
	var organism_container: Node = get_tree().get_first_node_in_group("organism_container")
	if organism_container == null:
		return
	var dropped: Organism = _pending_organism
	_pending_organism = null
	dropped.freeze = false
	dropped.reparent(organism_container)
	_cooldown_remaining = DROP_COOLDOWN_SECONDS
	_prepare_next_organism()

## UC-01: Bir sonraki bırakılacak canlıyı rastgele seçer ve Spawner'ın altında
## dondurulmuş (freeze) halde, ekranda "sıradaki canlı" olarak bekletir.
func _prepare_next_organism() -> void:
	var stage_id: int = OrganismTypes.get_random_spawnable_stage_id()
	_pending_organism = ORGANISM_SCENE.instantiate()
	_pending_organism.stage_id = stage_id
	_pending_organism.freeze = true
	add_child(_pending_organism)
	_pending_organism.position = Vector2.ZERO
