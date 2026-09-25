extends Node2D
class_name DropAimGuide
## DropAimGuide -- feat: add drop aiming and landing feedback. Oyuncu
## bırakma konumunu SEÇERKEN (Spawner sürüklenirken) görsel geri bildirim
## gösterir. SADECE GÖRSEL: collision/fizik/spawn/cooldown/bonus mantığına
## HİÇBİR şekilde katılmaz.
##
## Spawner'ın KENDİ çocuğu olarak durur (Main.tscn) -- bu yüzden x konumunu
## AYRICA takip etmeye gerek yoktur: Spawner zaten yatay fanus sınırları
## içinde (left_bound_x/right_bound_x + HORIZONTAL_MARGIN) hareket eder,
## rehber otomatik olarak aynı x'te kalır ve asla ekran kenarlarına taşmaz.
##
## z_index=3 ile organizmaların ÜSTÜNDE (yığın arkasında kaybolmasın diye)
## ama HUD (UI_Canvas, CanvasLayer layer=10) HER ZAMAN üstünde kalır çünkü
## bu düğüm ayrı, world-space bir CanvasLayer'dadır (layer=0, varsayılan).

const OrganismVisualScript: GDScript = preload("res://scripts/organism_visual.gd")
const LabPreviewHostScript: GDScript = preload("res://scripts/lab_preview_host.gd")

const LINE_COLOR: Color = Color("#8FE3D2")  # merge_burst.gd NORMAL_RING_COLOR ile aynı yumuşak mint/teal
const LINE_ALPHA: float = 0.38              # düşük opaklık -- çocuksu parlak/kalın olmasın
const LINE_WIDTH: float = 1.6               # ince

# V4 core-loop/graybox (madde 2, ESKİ davranış) -- kullanıcı isteği: düz çizgi
# yerine KESİKLİ ("dashed") rehber çizgisi + tahmini iniş noktasında bir
# işaretçi. Bu eski yol artık YALNIZCA "Evrim Laboratuvarı" lab-görselleri
# devre dışıyken (LAB_VISUALS_ENABLED=false, ör. saf üretim derlemesi) ya da
# bu dilimde erişilemeyen bir aşama/balık parçası için GÜVENLİ bir GERİ
# DÖNÜŞ (fallback) olarak korunur -- SİLİNMEDİ, davranışı BİREBİR aynı kalır.
const DASH_LENGTH: float = 14.0
const DASH_GAP: float = 10.0
const LANDING_MARKER_RADIUS: float = 9.0
const LANDING_MARKER_COLOR: Color = Color("#F4C95D")  # amber -- rehber çizgisinden ayrışsın diye farklı ton
const LANDING_MARKER_ALPHA: float = 0.85
const LANDING_MARKER_RING_WIDTH: float = 2.2

# gameplay/core-loop-v4 "Evrim Laboratuvarı" V02 vertical slice (madde 2 --
# kullanıcı: "ekranın tamamından yatay sürükle... fanusa uzanan tam boy ışık
# sütunu/bağlayıcı çizgi OLMASIN; sadece yarı saydam bir Virüs hayaleti + iniş
# noktasında yumuşak bir taban gölgesi; portalın altında EN FAZLA 80-120px
# kısa bir parlama"). Aşağıdaki sabitler bu öğeleri kontrol eder.
# DÜZELTME (V02 İKİNCİ düzeltme turu -- kullanıcı: "Portal çevresindeki üst
# üste binen büyük hayalet şekilleri kaldır"): KÖK NEDEN -- hayalet canlı VE
# portalın parlaması AYNI dikey konumda (eski GHOST_Y_OFFSET=90) çiziliyordu,
# yani TAM ÜST ÜSTE biniyorlardı. Artık ikisi ayrı, paylaşılan TEK bir
# kaynaktan (GrayboxConfig.PORTAL_ANCHOR_Y_OFFSET/AIM_GHOST_Y_OFFSET,
# dna_portal.gd'nin de kullandığı) okunuyor -- hayalet portalın BELİRGİN
# ŞEKİLDE altında durur, aralarında görünür bir boşluk var; eski geniş
# "glow bantları" da (kendi başına bir hayalet şekli gibi okunuyordu) TEK,
# İNCE bir bağlayıcı ışık çizgisiyle DEĞİŞTİRİLDİ (bkz. _draw_portal_glow).
const GHOST_ALPHA: float = 0.46             # "yarı saydam" -- gerçek canlıdan belirgin şekilde soluk
const GHOST_FADE_IN_SECONDS: float = 0.12
const CONNECTOR_WIDTH: float = 3.0          # portal-hayalet arası İNCE bağlayıcı çizgi (geniş bant DEĞİL)
const CONNECTOR_MAX_ALPHA: float = 0.30
const SHADOW_COLOR: Color = Color(0.02, 0.05, 0.05)  # neredeyse siyah, çok hafif teal ton -- "taban gölgesi"
const SHADOW_MAX_ALPHA: float = 0.34
const SHADOW_RADIUS_X_MULT: float = 1.05    # canlının yarıçapına göre -- taban gölgesi yatayda biraz geniş
const SHADOW_RADIUS_Y_MULT: float = 0.36    # -- dikeyde yassı (perspektif "taban" hissi)
const SHADOW_LAYERS: int = 4
const SHADOW_ELLIPSE_SEGMENTS: int = 22

# Main.tscn: Environment/Floor üst yüzeyi global y=1260, Spawner global y=100
# (bkz. merge_burst.gd/qa_driver.gd'deki FLOOR_TOP_Y sabiti ile aynı taban).
# Spawner'ın YEREL uzayında bu yüzden çizgi 0'dan 1160'a kadar uzanır.
const LINE_BOTTOM_Y: float = 1160.0

var _fade_tween: Tween = null
var _landing_y: float = LINE_BOTTOM_Y  # tahmini iniş noktası (YEREL y) -- aim sırasında her karede güncellenir

# gameplay/core-loop-v4 "Evrim Laboratuvarı": aim başladığında BİR KEZ
# hesaplanır (bekleyen canlı aim sırasında değişmez) -- her _draw() karesinde
# Spawner'a tekrar sormamak için önbelleğe alınır.
var _use_lab_visuals: bool = false
var _ghost_stage_id: int = 0
var _ghost_is_bonus: bool = false
var _ghost_root: Node2D = null

func _ready() -> void:
	z_index = 3
	visible = false
	modulate.a = 0.0
	queue_redraw()
	var spawner: Node = get_parent()
	if spawner != null and spawner.has_signal("drag_state_changed"):
		spawner.drag_state_changed.connect(_on_drag_state_changed)
	# UC-01 kapsamı dışında bir güvenlik önlemi: oyuncu tam sürükleme
	# ORTASINDAYKEN Game Over/Retry tetiklenirse (input artık gelmediği için
	# Spawner bir daha drag_state_changed(false) YAYINLAYAMAZ) rehberin
	# ekranda asılı kalmaması için doğrudan burada da zorla gizleniyor.
	GameManager.game_over_ready.connect(_on_force_hide)
	GameManager.run_reset.connect(_on_force_hide)

func _on_drag_state_changed(is_dragging: bool) -> void:
	if is_dragging:
		_show_with_fade_in()
	else:
		# Kullanıcı talebi: "Canlı bırakıldığında guide hemen kaybolsun" --
		# fade YOK, tween ANINDA öldürülür ve çizgi/hayalet o karede gizlenir.
		_force_hide_now()

func _show_with_fade_in() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	visible = true
	modulate.a = 0.0
	_resolve_pending_visual_state()  # bu aim için hangi aşama/mod gösterileceğini SABİTLE
	_update_landing_marker()  # ilk kare zaten doğru iniş noktasıyla çizilsin
	_sync_ghost_visual()
	queue_redraw()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, GHOST_FADE_IN_SECONDS)

func _force_hide_now() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	visible = false
	modulate.a = 0.0
	if _ghost_root != null:
		_ghost_root.visible = false

## NOT: bu fonksiyon hem game_over_ready(final_stats: Dictionary) hem de
## run_reset() (parametresiz) sinyaline BAĞLI -- Godot'ta bağlı callable'in
## parametre sayısı sinyalin gönderdiği argüman sayısıyla TAM eşleşmezse
## çağrı hiç YAPILMAZ (bkz. merge_burst/chain_toast'ta bulunan ve düzeltilen
## aynı sınıf hata). Varsayılan değerli opsiyonel parametre iki sinyal
## imzasıyla da uyumlu olur.
func _on_force_hide(_final_stats: Dictionary = {}) -> void:
	_force_hide_now()

## Aim sırasında (yalnızca visible=true iken) her karede, mevcut x konumundan
## aşağı doğru bir fizik ışını atarak tahmini iniş noktasını (ilk engel: taban
## ya da başka bir organizma) hesaplar. SADECE GÖRSEL -- hiçbir collision
## katmanına yazmaz, hiçbir RigidBody'yi etkilemez, sadece OKUR.
func _process(_delta: float) -> void:
	if not visible:
		return
	_update_landing_marker()
	queue_redraw()

func _update_landing_marker() -> void:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var from: Vector2 = global_position
	var to: Vector2 = global_position + Vector2(0.0, LINE_BOTTOM_Y)
	var query := PhysicsRayQueryParameters2D.create(from, to)
	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		_landing_y = LINE_BOTTOM_Y
	else:
		_landing_y = to_local(result.position).y

## gameplay/core-loop-v4 "Evrim Laboratuvarı": aim başlangıcında Spawner'ın
## ZATEN dışa verdiği (feat: add dedicated next organism preview) salt-okunur
## get_pending_preview_data() sözleşmesini okur -- yeni bir sinyal/bağımlılık
## EKLEMEZ. "Lab görselleri" yalnızca bu dilimin gerçekten kapsadığı
## aşamalarda (Virüs/Bakteri/Tek Hücreli) ve balık parçası DEĞİLKEN devreye
## girer; aksi halde eski kesikli-çizgi/amber-halka yoluna GÜVENLE düşülür.
func _resolve_pending_visual_state() -> void:
	var pending: Dictionary = {}
	var spawner: Node = get_parent()
	if spawner != null and spawner.has_method("get_pending_preview_data"):
		pending = spawner.get_pending_preview_data()
	_ghost_stage_id = int(pending.get("stage_id", 0))
	_ghost_is_bonus = bool(pending.get("is_bonus", false))
	var is_fish_part: bool = bool(pending.get("is_fish_part", false))
	_use_lab_visuals = (
		not pending.is_empty()
		and GrayboxConfig.ENABLED
		and GrayboxConfig.LAB_VISUALS_ENABLED
		and _ghost_stage_id <= OrganismTypes.VERTICAL_SLICE_FINAL_STAGE_ID
		and not is_fish_part
	)

func _ensure_ghost_root() -> void:
	if _ghost_root != null:
		return
	_ghost_root = Node2D.new()
	_ghost_root.set_script(LabPreviewHostScript)
	_ghost_root.name = "GhostRoot"
	_ghost_root.z_index = 1  # portal parlamasının/gölgenin ÜSTÜNDE (bu düğümün kendi _draw()'ından sonra çizilsin)
	add_child(_ghost_root)

## Yarı saydam "Virüs hayaleti": organism_visual.gd'nin GERÇEK çizim kodunu
## (NEXT önizlemesinde de kullanılan aynı LabPreviewHost dizeni ile) portalın
## TAM konumunda (Vector2.ZERO -- Spawner'ın yerel merkezi), GERÇEK boyutunda
## (ölçek normalize edilmeden -- burada oyuncunun az sonra bırakacağı canlının
## GERÇEK dünya-uzayı boyutu önemli) gösterir. modulate.a ile tek seferde
## saydamlaştırılır (Node2D modulate'i tüm çocuklara -- Polygon2D dahil --
## otomatik yayılır, organism_visual.gd'nin kendi alfa/renk mantığına hiç
## dokunulmaz).
func _sync_ghost_visual() -> void:
	if not _use_lab_visuals:
		if _ghost_root != null:
			_ghost_root.visible = false
		return
	_ensure_ghost_root()
	_ghost_root.visible = true
	_ghost_root.modulate.a = GHOST_ALPHA
	_ghost_root.scale = Vector2.ONE
	_ghost_root.position = Vector2(0.0, GrayboxConfig.AIM_GHOST_Y_OFFSET)
	_ghost_root.stage_id = _ghost_stage_id
	_ghost_root.tier = 0
	_ghost_root.is_bonus = _ghost_is_bonus
	_ghost_root.is_fish_part = false
	_ghost_root.fish_part_index = 0
	_ghost_root.born_from_evolution = false

	# organism_visual.gd _ready() stage_id'yi yalnızca instantiate anında
	# okur -- bir önceki aim'den kalma görsel çocuğu at, yenisini kur (bkz.
	# next_preview.gd _show_lab_preview() -- AYNI desen).
	for child in _ghost_root.get_children():
		_ghost_root.remove_child(child)
		child.free()
	var visual := Polygon2D.new()
	visual.name = "Visual"
	visual.set_script(OrganismVisualScript)
	_ghost_root.add_child(visual)

func _draw() -> void:
	if _use_lab_visuals:
		_draw_portal_glow()
		_draw_landing_shadow()
	else:
		_draw_dashed_line(Vector2.ZERO, Vector2(0.0, _landing_y), Color(LINE_COLOR.r, LINE_COLOR.g, LINE_COLOR.b, LINE_ALPHA), LINE_WIDTH)
		_draw_landing_marker()

## Kullanıcı isteği (ESKİ davranış, fallback): düz çizgi yerine kesikli
## ("dashed") rehber çizgisi.
func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var total_length: float = to.y - from.y
	if total_length <= 0.0:
		return
	var step: float = DASH_LENGTH + DASH_GAP
	var y: float = from.y
	while y < to.y:
		var segment_end: float = min(y + DASH_LENGTH, to.y)
		draw_line(Vector2(from.x, y), Vector2(from.x, segment_end), color, width, true)
		y += step

## Tahmini iniş noktasında küçük, dolgusuz bir halka işaretçisi çizer --
## çizginin ucuyla karışmasın diye çizgiden farklı (amber) bir tonda.
## (ESKİ davranış, fallback.)
func _draw_landing_marker() -> void:
	var marker_color := Color(LANDING_MARKER_COLOR.r, LANDING_MARKER_COLOR.g, LANDING_MARKER_COLOR.b, LANDING_MARKER_ALPHA)
	draw_arc(Vector2(0.0, _landing_y), LANDING_MARKER_RADIUS, 0.0, TAU, 24, marker_color, LANDING_MARKER_RING_WIDTH, true)

## DÜZELTME (V02 İKİNCİ düzeltme turu -- kullanıcı: "Portal çevresindeki üst
## üste binen büyük hayalet şekilleri kaldır"): eski geniş, çok-bantlı
## dikdörtgen "glow" kendisi bir hayalet şekli gibi okunuyordu. Artık
## portalın (GrayboxConfig.PORTAL_ANCHOR_Y_OFFSET) alt ucundan hayaletin
## (AIM_GHOST_Y_OFFSET) üst ucuna kadar TEK, İNCE bir bağlayıcı ışık çizgisi
## -- birkaç üst üste binen, giderek incelen/soluklaşan çizgiyle yumuşak bir
## parıltı TAKLİT edilir (gerçek blur/shader olmadan), ama sonuç bir "çizgi",
## geniş bir "blok" değil.
func _draw_portal_glow() -> void:
	var portal_bottom: float = GrayboxConfig.PORTAL_ANCHOR_Y_OFFSET + 20.0  # kapsülün alt ucu civarı
	var ghost_top: float = GrayboxConfig.AIM_GHOST_Y_OFFSET - GrayboxConfig.effective_radius(_ghost_stage_id) * 0.9
	if ghost_top <= portal_bottom:
		return
	var layers: Array = [
		{"width": CONNECTOR_WIDTH * 2.4, "alpha": CONNECTOR_MAX_ALPHA * 0.35},
		{"width": CONNECTOR_WIDTH * 1.3, "alpha": CONNECTOR_MAX_ALPHA * 0.65},
		{"width": CONNECTOR_WIDTH * 0.6, "alpha": CONNECTOR_MAX_ALPHA},
	]
	for layer in layers:
		draw_line(Vector2(0.0, portal_bottom), Vector2(0.0, ghost_top), Color(LINE_COLOR.r, LINE_COLOR.g, LINE_COLOR.b, float(layer.alpha)), float(layer.width), true)

## gameplay/core-loop-v4 "Evrim Laboratuvarı" (madde 2 -- "iniş noktasında
## yumuşak bir taban gölgesi"): tahmini iniş konumunda ( _landing_y ),
## gösterilen canlının GERÇEK yarıçapına (GrayboxConfig.effective_radius)
## oranlı, yassı (Y ekseninde sıkıştırılmış) bir elips. İç içe SHADOW_LAYERS
## adet elips, dıştan içe küçülüp koyulaşarak yumuşak bir kenar sönümü verir
## (gerçek blur/shader olmadan).
func _draw_landing_shadow() -> void:
	var radius: float = GrayboxConfig.effective_radius(_ghost_stage_id)
	var rx: float = radius * SHADOW_RADIUS_X_MULT
	var ry: float = radius * SHADOW_RADIUS_Y_MULT
	var center := Vector2(0.0, _landing_y)
	for i in range(SHADOW_LAYERS, 0, -1):
		var t: float = float(i) / float(SHADOW_LAYERS)  # 1.0 (en dış, en soluk) -> 1/SHADOW_LAYERS (en iç, en koyu)
		var layer_alpha: float = SHADOW_MAX_ALPHA * (1.0 - t) + SHADOW_MAX_ALPHA * 0.22
		_draw_filled_ellipse(center, rx * t, ry * t, Color(SHADOW_COLOR.r, SHADOW_COLOR.g, SHADOW_COLOR.b, layer_alpha))

func _draw_filled_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	if rx <= 0.0 or ry <= 0.0:
		return
	var points := PackedVector2Array()
	for i in range(SHADOW_ELLIPSE_SEGMENTS):
		var angle: float = TAU * float(i) / float(SHADOW_ELLIPSE_SEGMENTS)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	draw_colored_polygon(points, color)
