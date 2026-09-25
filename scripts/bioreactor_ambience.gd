extends Node2D
class_name BioreactorAmbience
## BioreactorAmbience -- gameplay/core-loop-v4 "Evrim Laboratuvarı" V02
## vertical slice (madde 6 -- kullanıcı: "fanus ilk saniyelerde TAMAMEN boş
## görünmesin; biyoreaktör duvarları, jel/sıvı taban, yavaş mikro-parçacıklar,
## silik ölçüm çizgileri, ÇOK HAFİF sıvı hareketi -- TAMAMEN DEKORATİF (fizik/
## collision/oynanışı hiçbir şekilde ETKİLEMEZ); oynanabilir alanı GEREKSİZ
## YERE genişletme, 0.6-0.9s düşüş süresi hedefine dokunma").
##
## SADECE GÖRSEL: bu script'te CollisionShape/RigidBody/Area/StaticBody YOK,
## yalnızca _draw() + _process() ile çizer. Environment/WallLeft, WallRight,
## Floor node'larının (environment_bounds.gd tarafından zaten yönetilen)
## GERÇEK konumlarını SALT-OKUNUR izler -- kendi boyutlandırma/genişletme
## mantığı YOKTUR, yalnızca zaten var olan sınırların görsel karşılığını
## sağlar. Environment ile aynı ebeveynin ("Main") çocuğu olarak durur.

@onready var _wall_left: Node2D = get_node("../Environment/WallLeft")
@onready var _wall_right: Node2D = get_node("../Environment/WallRight")
@onready var _floor: Node2D = get_node("../Environment/Floor")

const WALL_INNER_INSET: float = 10.0   # WallLeft/WallRight'ın RectangleShape2D size.x=20 -- iç yüzey merkezden bu kadar içeride
const WALL_VISUAL_WIDTH: float = 26.0  # cam duvar dekorunun görünür kalınlığı
const GEL_FLOOR_HEIGHT: float = 90.0   # taban üstünde görünen "jel/sıvı" katmanının yüksekliği
const TICK_SPACING: float = 90.0
const TICK_MAJOR_EVERY: int = 3
const PARTICLE_COUNT: int = 14

# DÜZELTME (V02 İKİNCİ düzeltme turu -- kullanıcı madde 1: "Ekran çok boş.
# Biyoreaktör atmosferini güçlendir: görünür kavisli cam sınırlar, düşük
# yoğunluklu hareketli hücre/parçacıklar, tabandan gelen jel parıltısı ve
# hafif derinlik katmanları ekle. Okunabilirliği bozacak kalabalık yaratma."):
# eski WALL_COLOR alfa=0.09 tek başına DURAĞAN bir ekran görüntüsünde fark
# edilmiyordu -- biraz artırıldı (0.09->0.16) ve duvarlar artık DÜZ dikdörtgen
# değil, hafif dışa kavisli (bkz. _draw_curved_wall) -- kullanıcının "kavisli
# cam sınırlar" talebi. Yeni CELL_PARTICLE_* / DEPTH_BLOB_* / GEL_GLOW_*
# sabitleri AŞAĞIDA -- hepsi DÜŞÜK yoğunlukta (az sayıda, düşük alfa) kalarak
# "kalabalık yaratma" uyarısına uyar.
const WALL_COLOR: Color = Color(0.42, 0.80, 0.74, 0.16)
const WALL_HIGHLIGHT_COLOR: Color = Color(0.75, 0.98, 0.94, 0.20)
const WALL_OUTLINE_COLOR: Color = Color(0.60, 0.92, 0.86, 0.24)
const WALL_CURVE_BULGE: float = 16.0    # duvarın dikey ortada dışa doğru büzüldüğü en fazla mesafe -- "fanus" hissi
const TICK_COLOR: Color = Color(0.55, 0.85, 0.80, 0.14)
const TICK_MAJOR_COLOR: Color = Color(0.58, 0.90, 0.84, 0.26)
const GEL_TOP_COLOR: Color = Color(0.20, 0.55, 0.50, 0.20)
const GEL_BOTTOM_COLOR: Color = Color(0.08, 0.26, 0.24, 0.40)
const GEL_SURFACE_LINE_COLOR: Color = Color(0.55, 0.90, 0.82, 0.50)
const PARTICLE_COLOR: Color = Color(0.75, 0.95, 0.90, 0.32)

# "tabandan gelen jel parıltısı" -- gel yüzeyinden YUKARI doğru sönen, yavaşça
# nabız atan bir ışık sızıntısı (bkz. _draw_gel_glow). Gel bantlarının
# (GEL_FLOOR_HEIGHT=90) ÜSTÜNE, daha yükseğe (GLOW_HEIGHT=150) taşar.
const GEL_GLOW_COLOR: Color = Color(0.45, 0.95, 0.85, 0.16)
const GEL_GLOW_HEIGHT: float = 150.0
const GEL_GLOW_PULSE_SPEED: float = 0.5

# "düşük yoğunluklu hareketli hücre" -- mevcut toz zerrecikleri (_particles,
# aşağı yukarı süzülen) DIŞINDA, az sayıda (CELL_PARTICLE_COUNT) daha büyük,
# zar+çekirdek ipucu taşıyan, YERİNDE yavaşça süzülen (sabit bir "ev" noktası
# etrafında sinüs sürüklenmesi -- ASLA ani "pop"/teleport yok) canlı-hücre
# siluetleri. Toz zerreciklerinden (PARTICLE_COLOR, radius 1.3-3.0) kasıtlı
# olarak ayrı bir görsel dil (daha büyük, zarı olan) kullanır.
const CELL_PARTICLE_COUNT: int = 5
const CELL_MEMBRANE_COLOR: Color = Color(0.62, 0.94, 0.88, 0.20)
const CELL_NUCLEUS_COLOR: Color = Color(0.55, 0.88, 0.96, 0.28)

# "hafif derinlik katmanları" -- az sayıda (DEPTH_BLOB_COUNT), ÇOK büyük, ÇOK
# soluk (alfa tavanı ~0.06), sabit konumlu (yalnızca çok hafif sinüs
# sürüklenmesi) yumuşak lekeler -- gerçek bir arka/orta plan hissi verir,
# ama o kadar soluktur ki asla oyun okunabilirliğini bozmaz/dikkat çekmez.
const DEPTH_BLOB_COLOR: Color = Color(0.35, 0.78, 0.72, 0.055)
const DEPTH_BLOB_COUNT: int = 3

var _time: float = 0.0
var _particles: Array[Dictionary] = []  # {x_ratio, y_ratio, speed, drift_phase, radius}
var _cell_particles: Array[Dictionary] = []  # {home_x_ratio, home_y_ratio, radius, drift_amp, drift_speed, drift_phase, bob_phase, bob_speed}
var _depth_blobs: Array[Dictionary] = []  # {x_ratio, y_ratio, radius, drift_speed, phase}

func _ready() -> void:
	# BackgroundImage (z_index=-10)'un ÜSTÜNDE, ama organizmaların/DropAimGuide'ın
	# (varsayılan z_index=0 / 3) ALTINDA kalır -- hiçbir zaman oynanışı gölgelemez.
	z_index = -5
	_init_particles()
	_init_cell_particles()
	_init_depth_blobs()
	get_tree().root.size_changed.connect(_init_particles)

func _init_particles() -> void:
	_particles.clear()
	for i in range(PARTICLE_COUNT):
		_particles.append({
			"x_ratio": randf(),
			"y_ratio": randf(),
			"speed": randf_range(4.0, 10.0),  # px/sn -- ÇOK YAVAŞ, "hafif" süzülme
			"drift_phase": randf() * TAU,
			"radius": randf_range(1.3, 3.0),
		})

## Ekran boyutuna bağlı DEĞİL (home_x_ratio/home_y_ratio sabit kalır) -- bu
## yüzden _ready()'de BİR KEZ üretilir, size_changed'da YENİDEN üretilmez
## (mevcut _particles'ın aksine); pozisyonlar zaten oransal (ratio), farklı
## ekran boyutunda otomatik doğru yerde kalır.
func _init_cell_particles() -> void:
	_cell_particles.clear()
	for i in range(CELL_PARTICLE_COUNT):
		_cell_particles.append({
			"home_x_ratio": randf_range(0.12, 0.88),
			"home_y_ratio": randf_range(0.18, 0.82),
			"radius": randf_range(7.0, 13.0),
			"drift_amp": randf_range(0.03, 0.07),
			"drift_speed": randf_range(0.08, 0.18),
			"drift_phase": randf() * TAU,
			"bob_speed": randf_range(0.25, 0.45),
			"bob_phase": randf() * TAU,
		})

func _init_depth_blobs() -> void:
	_depth_blobs.clear()
	var configs: Array[Dictionary] = [
		{"x_ratio": 0.10, "y_ratio": 0.20, "radius": 170.0},
		{"x_ratio": 0.90, "y_ratio": 0.52, "radius": 210.0},
		{"x_ratio": 0.22, "y_ratio": 0.86, "radius": 150.0},
	]
	for c in configs:
		c["drift_speed"] = randf_range(0.03, 0.07)
		c["phase"] = randf() * TAU
		_depth_blobs.append(c)

func _process(delta: float) -> void:
	_time += delta
	var play_height: float = max(_current_floor_top_y(), 1.0)
	for p in _particles:
		p["y_ratio"] = float(p["y_ratio"]) + (float(p["speed"]) * delta) / play_height
		if float(p["y_ratio"]) > 1.03:
			p["y_ratio"] = -0.03
			p["x_ratio"] = randf()
	queue_redraw()

func _current_floor_top_y() -> float:
	if _floor == null:
		return 1000.0
	return _floor.position.y - 10.0  # Floor.position.y taban MERKEZİ (FLOOR_THICKNESS/2=10 aşağıda) -- üst yüzey bunun 10px üstünde

func _draw() -> void:
	if _wall_left == null or _wall_right == null or _floor == null:
		return
	var left_x: float = _wall_left.position.x + WALL_INNER_INSET
	var right_x: float = _wall_right.position.x - WALL_INNER_INSET
	var floor_top_y: float = _current_floor_top_y()
	# Katman sırası (arkadan öne): derinlik lekeleri -> kavisli cam duvarlar ->
	# ölçüm çizgileri -> jel parıltısı -> jel taban -> toz zerrecikleri -> hücreler.
	# En belirgin/canlı öğeler (hücreler) EN ÜSTTE -- ama hepsi bu node'un kendi
	# z_index=-5'i içinde kalır, organizmaların/HUD'un asla önüne geçmez.
	_draw_depth_layers(left_x, right_x, floor_top_y)
	_draw_walls(left_x, right_x, floor_top_y)
	_draw_measurement_ticks(left_x, right_x, floor_top_y)
	_draw_gel_glow(left_x, right_x, floor_top_y)
	_draw_gel_floor(left_x, right_x, floor_top_y)
	_draw_particles(left_x, right_x, floor_top_y)
	_draw_cell_particles(left_x, right_x, floor_top_y)

## Biyoreaktörün cam duvarlarının hissi -- fiziksel WallLeft/WallRight
## (görünmez StaticBody2D) TAM konumunda, ama artık DÜZ dikey şerit değil,
## dikey ortada dışa doğru hafifçe şişen (sin(t*PI) ile 0->tepe->0) bir kavis
## -- kullanıcı madde 1: "görünür kavisli cam sınırlar". İnce bir iç parlaklık
## (WALL_HIGHLIGHT_COLOR) + dış kontur (WALL_OUTLINE_COLOR) camın "hacimli"
## hissini güçlendirir. Yalnızca GÖRSEL -- fiziksel WallLeft/WallRight
## StaticBody'sinin KENDİSİ hâlâ düz (collision şekli DEĞİŞMEDİ), bu sadece
## dekoratif bir dış hat.
func _draw_walls(left_x: float, right_x: float, floor_top_y: float) -> void:
	_draw_curved_wall(left_x, floor_top_y, -1.0)
	_draw_curved_wall(right_x, floor_top_y, 1.0)

func _draw_curved_wall(inner_x: float, floor_top_y: float, outward_sign: float) -> void:
	var segments: int = 20
	var inner_points := PackedVector2Array()
	var outer_points := PackedVector2Array()
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var y: float = floor_top_y * t
		var bulge: float = sin(t * PI) * WALL_CURVE_BULGE  # uçlarda 0, dikey ortada tepe -- "fanus" büzülmesi
		inner_points.append(Vector2(inner_x, y))
		outer_points.append(Vector2(inner_x + outward_sign * (WALL_VISUAL_WIDTH + bulge), y))
	var fill_poly := PackedVector2Array()
	for p in inner_points:
		fill_poly.append(p)
	for i in range(outer_points.size() - 1, -1, -1):
		fill_poly.append(outer_points[i])
	draw_colored_polygon(fill_poly, WALL_COLOR)
	draw_polyline(outer_points, WALL_OUTLINE_COLOR, 1.4, true)
	var highlight_points := PackedVector2Array()
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var y: float = floor_top_y * t
		var bulge: float = sin(t * PI) * WALL_CURVE_BULGE
		highlight_points.append(Vector2(inner_x + outward_sign * (WALL_VISUAL_WIDTH * 0.35 + bulge * 0.5), y))
	draw_polyline(highlight_points, WALL_HIGHLIGHT_COLOR, 1.3, true)

## "hafif derinlik katmanları" -- büyük, çok soluk, neredeyse sabit lekeler.
## Banded-alpha tekniğiyle (blur/shader olmadan) yumuşak bir kenar taklit
## edilir (bkz. drop_aim_guide.gd/dna_portal.gd'de kullanılan AYNI teknik).
func _draw_depth_layers(left_x: float, right_x: float, floor_top_y: float) -> void:
	var width: float = right_x - left_x
	for b in _depth_blobs:
		var drift: float = sin(_time * float(b["drift_speed"]) + float(b["phase"])) * 12.0
		var x: float = left_x + width * float(b["x_ratio"]) + drift
		var y: float = floor_top_y * float(b["y_ratio"])
		var r: float = float(b["radius"])
		var bands: int = 3
		for i in range(bands):
			var t: float = float(i) / float(bands)
			draw_circle(Vector2(x, y), r * (1.0 - t * 0.4), Color(DEPTH_BLOB_COLOR.r, DEPTH_BLOB_COLOR.g, DEPTH_BLOB_COLOR.b, DEPTH_BLOB_COLOR.a * (0.4 + t * 0.6)))

## "tabandan gelen jel parıltısı" -- gel yüzeyinden yukarı doğru sönen,
## GEL_GLOW_PULSE_SPEED ile yavaşça nabız atan bir ışık sızıntısı. _draw_gel_
## floor()'un (aşağıda, katı gradyan bantlar) ÜSTÜNE çağrılmadan ÖNCE çizilir
## ki gel taban bunun üstünde net kalsın, parıltı sadece daha YÜKSEĞE (150px)
## taşan yumuşak bir "hale" olsun.
func _draw_gel_glow(left_x: float, right_x: float, floor_top_y: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * GEL_GLOW_PULSE_SPEED)
	var bands: int = 6
	for i in range(bands):
		var t0: float = float(i) / float(bands)
		var t1: float = float(i + 1) / float(bands)
		var y0: float = floor_top_y - GEL_GLOW_HEIGHT * t1
		var y1: float = floor_top_y - GEL_GLOW_HEIGHT * t0
		var a: float = GEL_GLOW_COLOR.a * (1.0 - t0) * (0.55 + pulse * 0.45)
		draw_rect(Rect2(Vector2(left_x, y0), Vector2(right_x - left_x, y1 - y0 + 1.0)), Color(GEL_GLOW_COLOR.r, GEL_GLOW_COLOR.g, GEL_GLOW_COLOR.b, a), true)

## "düşük yoğunluklu hareketli hücre" -- toz zerreciklerinden (_draw_particles)
## AYRI bir görsel dil: daha büyük, zar+çekirdek ipucu taşıyan, sabit bir "ev"
## noktası etrafında YAVAŞÇA sürüklenen (x/y sinüs -- asla ani sıçrama/"pop"
## yok) beş adet canlı-hücre silueti. CELL_PARTICLE_COUNT düşük tutulur
## (kullanıcı: "okunabilirliği bozacak kalabalık yaratma").
func _draw_cell_particles(left_x: float, right_x: float, floor_top_y: float) -> void:
	var width: float = right_x - left_x
	for c in _cell_particles:
		var x: float = left_x + width * (float(c["home_x_ratio"]) + sin(_time * float(c["drift_speed"]) + float(c["drift_phase"])) * float(c["drift_amp"]))
		var y: float = floor_top_y * (float(c["home_y_ratio"]) + sin(_time * float(c["bob_speed"]) + float(c["bob_phase"])) * 0.035)
		var r: float = float(c["radius"])
		draw_circle(Vector2(x, y), r, CELL_MEMBRANE_COLOR)
		draw_arc(Vector2(x, y), r, 0.0, TAU, 16, Color(CELL_MEMBRANE_COLOR.r, CELL_MEMBRANE_COLOR.g, CELL_MEMBRANE_COLOR.b, min(CELL_MEMBRANE_COLOR.a * 1.8, 1.0)), 1.2, true)
		draw_circle(Vector2(x, y) + Vector2(r * 0.15, -r * 0.1), r * 0.38, CELL_NUCLEUS_COLOR)

## Silik ölçüm çizgileri -- laboratuvar kabının kenarındaki hacim işaretleri
## hissi. Tamamen dekoratif, hiçbir değeri/etiketi yok (kullanıcı isteği:
## "kısa mobil metin" -- burada metin bile yok, sadece çizgiler).
func _draw_measurement_ticks(left_x: float, right_x: float, floor_top_y: float) -> void:
	var index: int = 0
	var y: float = floor_top_y
	while y > 0.0:
		var is_major: bool = index % TICK_MAJOR_EVERY == 0
		var length: float = 22.0 if is_major else 12.0
		var color: Color = TICK_MAJOR_COLOR if is_major else TICK_COLOR
		draw_line(Vector2(left_x, y), Vector2(left_x + length, y), color, 1.4)
		draw_line(Vector2(right_x - length, y), Vector2(right_x, y), color, 1.4)
		y -= TICK_SPACING
		index += 1

## Jel/sıvı taban -- katmanlı (üstten alta koyulaşan) yarı saydam bantlar +
## ÇOK HAFİF dalgalanan (sin, genlik ~2-3px) tek bir yüzey çizgisi. Gerçek bir
## blur/shader OLMADAN, çok sayıda ince banda bölünüp azalan/artan alfa
## verilerek yumuşak bir gradyan TAKLİT edilir (bkz. drop_aim_guide.gd AYNI
## teknik).
func _draw_gel_floor(left_x: float, right_x: float, floor_top_y: float) -> void:
	var wave: float = sin(_time * 0.6) * 3.0
	var bands: int = 5
	for i in range(bands):
		var t0: float = float(i) / float(bands)
		var t1: float = float(i + 1) / float(bands)
		var y0: float = floor_top_y - GEL_FLOOR_HEIGHT * (1.0 - t0) + wave * (1.0 - t0)
		var y1: float = floor_top_y - GEL_FLOOR_HEIGHT * (1.0 - t1) + wave * (1.0 - t1)
		var color: Color = GEL_TOP_COLOR.lerp(GEL_BOTTOM_COLOR, t0)
		draw_rect(Rect2(Vector2(left_x, y0), Vector2(right_x - left_x, y1 - y0 + 1.0)), color, true)

	var segments: int = 24
	for i in range(segments):
		var t_a: float = float(i) / float(segments)
		var t_b: float = float(i + 1) / float(segments)
		var x_a: float = lerp(left_x, right_x, t_a)
		var x_b: float = lerp(left_x, right_x, t_b)
		var y_a: float = floor_top_y + sin(_time * 0.6 + t_a * 6.0) * 2.5
		var y_b: float = floor_top_y + sin(_time * 0.6 + t_b * 6.0) * 2.5
		draw_line(Vector2(x_a, y_a), Vector2(x_b, y_b), GEL_SURFACE_LINE_COLOR, 1.6, true)

## Yavaş süzülen mikro-parçacıklar (spor/mikroorganizma hissi) -- tabandan
## yukarı doğru ağır ağır yükselir, ekranın üstüne ulaşınca alttan tekrar
## belirir. Uçlarda (doğuş/kayboluş anında) alfa YUMUŞAKÇA sıfıra iner ki ani
## "pop" hissi olmasın.
func _draw_particles(left_x: float, right_x: float, floor_top_y: float) -> void:
	var width: float = right_x - left_x
	for p in _particles:
		var x_ratio: float = float(p["x_ratio"])
		var y_ratio: float = float(p["y_ratio"])
		var x: float = left_x + width * x_ratio + sin(_time * 0.4 + float(p["drift_phase"])) * 5.0
		var y: float = floor_top_y - y_ratio * floor_top_y
		var edge_fade: float = clamp(min(y_ratio * 5.0, (1.0 - y_ratio) * 5.0), 0.0, 1.0)
		var alpha: float = PARTICLE_COLOR.a * edge_fade
		if alpha <= 0.005:
			continue
		draw_circle(Vector2(x, y), float(p["radius"]), Color(PARTICLE_COLOR.r, PARTICLE_COLOR.g, PARTICLE_COLOR.b, alpha))
