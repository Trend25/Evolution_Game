extends Node
class_name MutasyonManager
## MutasyonManager -- gameplay/core-loop-v4 "Evrim Laboratuvarı" V02 vertical
## slice (madde 7 -- Mutasyon kartları). DNA göstergesi (bkz. game_manager.gd
## dna_progress/dna_ready) her 5 gerçek merge'de bir dolar; bu script SADECE
## o anı GÖRSELLEŞTİRİR ve oyuncunun seçtiği kartın ETKİSİNİ uygular --
## GERÇEK DNA sayacı GameManager'de kalır (consume_dna() dışında hiçbir
## sayaç mantığına dokunmaz).
##
## SADECE GrayboxConfig.ENABLED and GrayboxConfig.LAB_VISUALS_ENABLED iken
## etkindir (Main.tscn'e sabit eklenir ama production'da hiçbir sinyale
## bağlanmaz/hiçbir UI kurmaz -- üretim davranışı SIFIR etkilenir).
##
## "Oyun tamamen donmuş hissettirmemeli" (kullanıcı isteği): get_tree().paused
## KULLANILMAZ (bu GameFlow'un kendi menü-duraklatma sistemidir, burada
## KARIŞTIRILMAZ) -- bunun yerine Engine.time_scale kısa süreliğine HAFİFÇE
## düşürülür (dünya hâlâ, yavaşça, hareket eder) ve tam ekran şeffaf bir "dim"
## katmanı (mouse_filter=STOP) Spawner'ın sürükle/bırak girdisini yutarak
## yeni bir bırakmayı ENGELLER -- ikisi birbirinden bağımsız iki mekanizma.

const ORGANISM_SCENE: PackedScene = preload("res://scenes/Organism.tscn")
const MagneticPullEffectScript: GDScript = preload("res://scripts/magnetic_pull_effect.gd")

const SLOW_TIME_SCALE: float = 0.4        # "hafifçe yavaşlasın ama TAMAMEN donmasın"
const CARD_WIDTH: float = 316.0
const CARD_HEIGHT: float = 172.0
const CARD_GAP: float = 14.0
const BOTTOM_MARGIN: float = 28.0
const RISE_DURATION: float = 0.32
const CANCEL_HEIGHT: float = 40.0

const EFFECTS: Array[Dictionary] = [
	{"id": "magnetic", "title": "MANYETİK ALAN", "desc": "En yakın eş çifti birleştirir."},
	{"id": "catalyst", "title": "KATALİZÖR", "desc": "En düşük canlıyı yükseltir."},
]

var _layer: CanvasLayer = null
var _dim: ColorRect = null
var _cards: Array[Button] = []
var _cancel_button: Button = null
var _rest_positions: Array[Vector2] = []
var _cancel_rest_position: Vector2 = Vector2.ZERO
var _is_showing: bool = false
var _active_tween: Tween = null

func _ready() -> void:
	if not (GrayboxConfig.ENABLED and GrayboxConfig.LAB_VISUALS_ENABLED):
		return  # üretimde: hiçbir UI kurulmaz, hiçbir sinyale bağlanılmaz
	_build_ui()
	GameManager.dna_ready.connect(_maybe_show)
	GameManager.organism_merged.connect(_on_organism_merged)
	GameManager.game_over_ready.connect(_on_force_hide)
	GameManager.run_reset.connect(_on_force_hide)

func _on_organism_merged(_position: Vector2, _stage_id: int, _is_bonus: bool, _awarded_score: int, _score_awarded: bool, _combo_count: int = 0) -> void:
	_maybe_show()

func _maybe_show() -> void:
	if _is_showing or not GameManager.is_dna_ready():
		return
	_show_sheet()

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "MutasyonLayer"
	_layer.layer = 22  # Spawner intro-hint(21)'in üstünde, FirstRunTutorial(25)'in altında
	add_child(_layer)

	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0.0, 0.0, 0.0, 0.0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP  # kullanıcı isteği: kart açıkken YENİ bir bırakma başlatılmasın
	_dim.visible = false
	_layer.add_child(_dim)

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var total_width: float = CARD_WIDTH * 2.0 + CARD_GAP
	var start_x: float = (max(720.0, viewport_size.x) - total_width) / 2.0
	var rest_y: float = max(720.0, viewport_size.y) - BOTTOM_MARGIN - CARD_HEIGHT - CANCEL_HEIGHT - 10.0

	for i in range(EFFECTS.size()):
		var effect: Dictionary = EFFECTS[i]
		var card: Button = Button.new()
		card.name = "Card_%s" % String(effect.get("id", "?"))  # QA/debug için okunabilir NodePath (ör. Main/MutasyonManager/MutasyonLayer/Card_catalyst)
		card.text = ""
		card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
		card.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
		card.add_theme_stylebox_override("normal", HUDTheme.make_button_stylebox(false))
		card.add_theme_stylebox_override("hover", HUDTheme.make_button_stylebox(false))
		card.add_theme_stylebox_override("pressed", HUDTheme.make_button_stylebox(true))
		card.focus_mode = Control.FOCUS_NONE
		var rest_pos: Vector2 = Vector2(start_x + float(i) * (CARD_WIDTH + CARD_GAP), rest_y)
		card.position = rest_pos
		_rest_positions.append(rest_pos)
		_layer.add_child(card)
		_cards.append(card)

		var title_label := Label.new()
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		title_label.offset_top = 22.0
		title_label.offset_bottom = 52.0
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		HUDTheme.style_label(title_label, HUDTheme.make_spaced_variation(HUDTheme.FONT_UI, 1), 17, HUDTheme.BUTTON_TEXT_DARK)
		title_label.text = String(effect.get("title", ""))
		card.add_child(title_label)

		var desc_label := Label.new()
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		desc_label.anchor_left = 0.0
		desc_label.anchor_right = 1.0
		desc_label.anchor_top = 0.0
		desc_label.anchor_bottom = 0.0
		desc_label.offset_left = 18.0
		desc_label.offset_right = -18.0
		desc_label.offset_top = 66.0
		desc_label.offset_bottom = 150.0
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		HUDTheme.style_label(desc_label, HUDTheme.FONT_UI, 14, HUDTheme.BUTTON_TEXT_DARK)
		desc_label.text = String(effect.get("desc", ""))
		card.add_child(desc_label)

		var effect_id: String = String(effect.get("id", ""))
		card.pressed.connect(_on_card_pressed.bind(effect_id))

	_cancel_button = Button.new()
	_cancel_button.name = "CancelButton"
	_cancel_button.text = "Vazgeç"
	_cancel_button.custom_minimum_size = Vector2(total_width, CANCEL_HEIGHT)
	_cancel_button.size = Vector2(total_width, CANCEL_HEIGHT)
	_cancel_button.flat = true
	_cancel_button.focus_mode = Control.FOCUS_NONE
	# HUDTheme.style_label() bir Label bekler -- Button için AYNI üç override
	# (font/boyut/renk) doğrudan uygulanır, yeni bir yardımcı fonksiyon icat edilmedi.
	_cancel_button.add_theme_font_override("font", HUDTheme.FONT_UI)
	_cancel_button.add_theme_font_size_override("font_size", 14)
	_cancel_button.add_theme_color_override("font_color", HUDTheme.TEXT_SECONDARY)
	_cancel_button.add_theme_color_override("font_hover_color", HUDTheme.TEXT_PRIMARY)
	_cancel_button.add_theme_color_override("font_pressed_color", HUDTheme.TEXT_PRIMARY)
	_cancel_rest_position = Vector2(start_x, rest_y + CARD_HEIGHT + 6.0)
	_cancel_button.position = _cancel_rest_position
	_layer.add_child(_cancel_button)
	_cancel_button.pressed.connect(_on_cancel_pressed)

	for card in _cards:
		card.modulate.a = 0.0
	_cancel_button.modulate.a = 0.0

func _show_sheet() -> void:
	_is_showing = true
	Engine.time_scale = SLOW_TIME_SCALE
	_dim.visible = true
	AudioManager.play_ui_tick()  # feat: add sound haptics -- SADECE ses, DNA/skor mantığına dokunmaz
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.tween_property(_dim, "color:a", 0.45, RISE_DURATION)
	for i in range(_cards.size()):
		var card: Button = _cards[i]
		var rest: Vector2 = _rest_positions[i]
		card.position = rest + Vector2(0.0, CARD_HEIGHT * 0.6)
		card.modulate.a = 0.0
		_active_tween.tween_property(card, "position", rest, RISE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		_active_tween.tween_property(card, "modulate:a", 1.0, RISE_DURATION)
	_cancel_button.position = _cancel_rest_position + Vector2(0.0, 10.0)
	_cancel_button.modulate.a = 0.0
	_active_tween.tween_property(_cancel_button, "position", _cancel_rest_position, RISE_DURATION)
	_active_tween.tween_property(_cancel_button, "modulate:a", 1.0, RISE_DURATION)

func _hide_sheet(instant: bool) -> void:
	_is_showing = false
	Engine.time_scale = 1.0
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	if instant:
		_dim.visible = false
		_dim.color.a = 0.0
		for card in _cards:
			card.modulate.a = 0.0
		_cancel_button.modulate.a = 0.0
		return
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.tween_property(_dim, "color:a", 0.0, 0.18)
	for card in _cards:
		_active_tween.tween_property(card, "modulate:a", 0.0, 0.18)
	_active_tween.tween_property(_cancel_button, "modulate:a", 0.0, 0.18)
	_active_tween.chain().tween_callback(func(): _dim.visible = false)

func _on_card_pressed(effect_id: String) -> void:
	if not _is_showing:
		return
	GameManager.consume_dna()
	_hide_sheet(false)
	_apply_effect(effect_id)

func _on_cancel_pressed() -> void:
	if not _is_showing:
		return
	_hide_sheet(false)  # DNA BİLİNÇLİ OLARAK tüketilmez -- kullanıcı isteği: "Vazgeç seçeneği kalabilir"

## NOT: hem game_over_ready(final_stats: Dictionary) hem de run_reset()
## (parametresiz) sinyaline BAĞLI -- bkz. chain_toast.gd/level_up_toast.gd
## AYNI notu (varsayılan değerli opsiyonel parametre iki imzayla da uyumlu olur).
func _on_force_hide(_final_stats: Dictionary = {}) -> void:
	_hide_sheet(true)

func _apply_effect(effect_id: String) -> void:
	match effect_id:
		"magnetic":
			_apply_magnetic_field()
		"catalyst":
			_apply_catalyst()

## "MANYETİK ALAN": fanustaki AYNI aşamadan en yakın çifti bulup MagneticPullEffect
## ile birbirine çeker -- gerçek merge yine organism.gd'nin kendi çarpışma
## mantığıyla, DOĞAL olarak gerçekleşir (bkz. magnetic_pull_effect.gd).
func _apply_magnetic_field() -> void:
	var container: Node = get_tree().get_first_node_in_group("organism_container")
	if container == null:
		return
	var candidates: Array = []
	for child in container.get_children():
		if child is RigidBody2D and is_instance_valid(child) and not bool(child.get("is_fish_part")):
			candidates.append(child)
	var best_a: RigidBody2D = null
	var best_b: RigidBody2D = null
	var best_dist: float = INF
	for i in range(candidates.size()):
		for j in range(i + 1, candidates.size()):
			var a: RigidBody2D = candidates[i]
			var b: RigidBody2D = candidates[j]
			if int(a.get("stage_id")) != int(b.get("stage_id")):
				continue
			var d: float = a.global_position.distance_to(b.global_position)
			if d < best_dist:
				best_dist = d
				best_a = a
				best_b = b
	if best_a == null or best_b == null:
		return  # eş çift yok -- DNA yine de tüketildi (kullanıcı isteği dışında bir garanti verilmedi), sessizce no-op
	var puller := Node.new()
	puller.set_script(MagneticPullEffectScript)
	add_child(puller)
	puller.start(best_a, best_b)

## "KATALİZÖR": fanustaki EN DÜŞÜK aşamalı canlıyı bulup bir üst aşamaya
## yükseltir -- GameManager.add_merge_reward() ÇAĞRILARAK skor/xp/DNA/
## collection/toast/burst/ses/haptic ZATEN VAR OLAN TEK yoldan (normal bir
## merge ile BİREBİR AYNI ödül/sinyal zinciri) tetiklenir, yeni bir paralel
## ödül mantığı İCAT EDİLMEZ.
func _apply_catalyst() -> void:
	var container: Node = get_tree().get_first_node_in_group("organism_container")
	if container == null:
		return
	var lowest: RigidBody2D = null
	var lowest_stage: int = 9999
	for child in container.get_children():
		if not (child is RigidBody2D) or not is_instance_valid(child) or bool(child.get("is_fish_part")):
			continue
		var sid: int = int(child.get("stage_id"))
		if sid < lowest_stage:
			lowest_stage = sid
			lowest = child
	if lowest == null or lowest_stage >= OrganismTypes.VERTICAL_SLICE_FINAL_STAGE_ID:
		return  # yükseltilecek aday yok / zaten bu dilimin tavanında -- sessiz no-op
	var next_stage: int = lowest_stage + 1
	var spawn_position: Vector2 = lowest.global_position
	var is_bonus: bool = bool(lowest.get("is_bonus"))
	lowest.queue_free()

	var upgraded: RigidBody2D = ORGANISM_SCENE.instantiate()
	upgraded.stage_id = next_stage
	upgraded.is_bonus = is_bonus
	upgraded.freeze = false
	upgraded.born_from_evolution = true
	container.add_child(upgraded)
	upgraded.global_position = spawn_position

	GameManager.add_merge_reward(lowest_stage, spawn_position, is_bonus)
