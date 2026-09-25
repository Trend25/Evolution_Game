extends Control
class_name HUDRoot
## HUDRoot — style: apply polished HUD and run summary. UI_Canvas altındaki
## Sol (Lives+LVL/XP) / NEXT (feat: add dedicated next organism preview) /
## Sağ (Score) panellerinin TEK, merkezi yerleşim ve stil köküdür. SafeArea'dan
## okuduğu kenar paylarını üç panelin konum/boyutuna uygular -- panel
## GENİŞLİKLERİ "yaklaşık" (kullanıcı talebi) olduğundan, safe-area çok büyük
## bir kenar payı isterse Sol/Sağ panel GENİŞLİĞİ (yüksekliği veya NEXT'in
## x=360 merkezini ASLA) daraltılarak barındırılır -- NEXT panel merkezi hep
## SABİT x=360'ta kalır (kullanıcı talebi: "tam oturmalı"). Oynanış/organizma/
## skor/XP/can mantığına dokunmaz, yalnızca konumlandırır+stil uygular.
##
## compute_panel_layout() STATIC'tir ve LevelUpToast (bkz. level_up_toast.gd)
## tarafından da çağrılır -- toast'ın "HUD'un hemen altında" konumu bu HUDRoot
## ile ÇATALLANMAZ, aynı tek fonksiyondan gelir.
##
## Tam ekranı kaplayan bir Control olduğu için mouse_filter=IGNORE (hem
## kendisinde hem üç panelinde, bkz. Main.tscn'deki node override'ları)
## ZORUNLU: aksi halde Spawner'ın _unhandled_input ile dinlediği sürükle-bırak
## dokunma/fare girdisini sessizce yutar ve oynanışı kırar.

const PANEL_HEIGHT: float = 124.0        # kullanıcı talebi: üç panel de bu yükseklikte
const LEFT_PANEL_WIDTH: float = 224.0    # kullanıcı talebi: "yaklaşık"
const NEXT_PANEL_WIDTH: float = 184.0    # kullanıcı talebi: "yaklaşık", SABİT (daralmaz)
const SCORE_PANEL_WIDTH: float = 224.0   # kullanıcı talebi: "yaklaşık"
const PANEL_GAP: float = 16.0
const NEXT_CENTER_X: float = 360.0       # kullanıcı talebi: "x=360 eksenine tam oturmalı"
const OUTER_MIN_MARGIN: float = 12.0     # kullanıcı talebi: "safe-area + minimum 12px"
const TOP_MIN_MARGIN: float = 16.0

const LEFT_INNER_PADDING: float = 16.0
const HEARTS_ROW_HEIGHT: float = 28.0
const LEFT_ROW_GAP: float = 10.0
const LEVEL_LABEL_WIDTH: float = 50.0
const LEVEL_XP_ROW_HEIGHT: float = 20.0
const LAB_ROW_GAP: float = 6.0  # gameplay/core-loop-v4 "Evrim Laboratuvarı": DnaGauge/CollectionStrip satırları arası boşluk

@onready var _left_panel: Panel = $LeftPanel
@onready var _next_panel: Panel = $NextPanel
@onready var _score_panel: Panel = $ScorePanel
@onready var _lives_ui: Node2D = $LeftPanel/LivesUI
@onready var _level_label: Label = $LeftPanel/LevelLabel
@onready var _xp_bar: Node2D = $LeftPanel/XPBar
# gameplay/core-loop-v4 "Evrim Laboratuvarı" V02 vertical slice (madde 5/7/99
# -- "DNA göstergesi" + "koleksiyon aşaması yanar"): XPBar'a EK olarak
# (SİLİNMEDEN, üretim davranışı DEĞİŞMEDEN), SADECE lab modunda Sol Panel'e
# iki yeni satır eklenir.
@onready var _dna_gauge: Node2D = $LeftPanel/DnaGauge
@onready var _collection_strip: Node2D = $LeftPanel/CollectionStrip
@onready var _score_caption: Label = $ScorePanel/ScoreCaption

func _ready() -> void:
	_left_panel.add_theme_stylebox_override("panel", HUDTheme.make_hud_panel_stylebox())
	_score_panel.add_theme_stylebox_override("panel", HUDTheme.make_hud_panel_stylebox())
	HUDTheme.style_label(_score_caption, HUDTheme.make_spaced_variation(HUDTheme.FONT_UI, 2), 14, HUDTheme.TEXT_SECONDARY)
	_score_caption.text = "SCORE"
	_apply_safe_area()
	get_tree().root.size_changed.connect(_apply_safe_area)

## Safe-area kenar paylarını okuyup üç panelin konum/boyutuna VE Sol Panel
## içindeki LivesUI/LevelLabel/XPBar'ın yerleşimine uygular. Yalnızca bu
## fonksiyon SafeArea'yı çağırır -- alt bileşenler (lives_ui.gd, xp_bar.gd,
## score_label.gd, level_label.gd) bundan tamamen habersizdir.
func _apply_safe_area() -> void:
	var layout: Dictionary = compute_panel_layout(SafeArea.get_margins())

	var top: float = layout.get("top", TOP_MIN_MARGIN)
	var height: float = layout.get("height", PANEL_HEIGHT)

	_left_panel.position = Vector2(layout.get("left_x", 28.0), top)
	_left_panel.size = Vector2(layout.get("left_w", LEFT_PANEL_WIDTH), height)

	_next_panel.position = Vector2(layout.get("next_x", 268.0), top)
	_next_panel.size = Vector2(layout.get("next_w", NEXT_PANEL_WIDTH), height)

	_score_panel.position = Vector2(layout.get("score_x", 468.0), top)
	_score_panel.size = Vector2(layout.get("score_w", SCORE_PANEL_WIDTH), height)

	_layout_left_panel_content(layout.get("left_w", LEFT_PANEL_WIDTH), height)

## Sol Panel'in İÇİNDEKİ hearts row + LVL/XP row grubunu dikey ortalar; XP
## barının ÇİZİM genişliğini panel daralırsa/genişlerse yeniden hesaplar.
## LivesUI/LevelLabel her zaman sol içe hizalıdır (genişlik onları etkilemez).
##
## V4 core-loop/graybox (madde 7 -- HUD sadeleştirme): GrayboxConfig.
## HIDE_LIVES_UI iken LivesUI SADECE GÖRSEL olarak gizlenir (kod/sinyal
## bağlantısı silinmez, bkz. lives_ui.gd -- GameManager.lives_changed hâlâ
## dinlenir, sadece render edilmiyor) ve LVL/XP satırı boşalan yere kayar.
func _layout_left_panel_content(panel_width: float, panel_height: float) -> void:
	var hide_lives: bool = GrayboxConfig.ENABLED and GrayboxConfig.HIDE_LIVES_UI
	_lives_ui.visible = not hide_lives
	var hearts_block_height: float = 0.0 if hide_lives else HEARTS_ROW_HEIGHT + LEFT_ROW_GAP

	# gameplay/core-loop-v4 "Evrim Laboratuvarı" V02 vertical slice (madde
	# 5/7/99): SADECE lab modunda (ENABLED and LAB_VISUALS_ENABLED), HIDE_
	# LIVES_UI'nin zaten boşalttığı dikey alana DnaGauge + CollectionStrip
	# satırları eklenir. Üretimde (ya da LAB_VISUALS_ENABLED=false iken) bu
	# iki düğüm tamamen gizlenir ve eski (XPBar-tek-satır) yerleşim BİREBİR
	# korunur.
	var lab_mode: bool = GrayboxConfig.ENABLED and GrayboxConfig.LAB_VISUALS_ENABLED
	_dna_gauge.visible = lab_mode
	_collection_strip.visible = lab_mode

	var lab_rows_height: float = 0.0
	if lab_mode:
		lab_rows_height = LAB_ROW_GAP + DnaGauge.ROW_HEIGHT + LAB_ROW_GAP + CollectionStrip.ROW_HEIGHT

	var content_height: float = hearts_block_height + LEVEL_XP_ROW_HEIGHT + lab_rows_height
	var top_offset: float = max(12.0, (panel_height - content_height) / 2.0)

	_lives_ui.position = Vector2(LEFT_INNER_PADDING, top_offset)

	var row_y: float = top_offset + hearts_block_height
	_level_label.position = Vector2(LEFT_INNER_PADDING, row_y)
	_level_label.size = Vector2(LEVEL_LABEL_WIDTH, LEVEL_XP_ROW_HEIGHT)

	var xp_bar_x: float = LEFT_INNER_PADDING + LEVEL_LABEL_WIDTH + 8.0
	var xp_bar_width: float = max(40.0, panel_width - xp_bar_x - LEFT_INNER_PADDING)
	_xp_bar.position = Vector2(xp_bar_x, row_y + (LEVEL_XP_ROW_HEIGHT - XPBar.BAR_HEIGHT) / 2.0)
	if _xp_bar.has_method("set_bar_width"):
		_xp_bar.set_bar_width(xp_bar_width)

	if not lab_mode:
		return

	var full_row_width: float = max(40.0, panel_width - LEFT_INNER_PADDING * 2.0)

	var dna_y: float = row_y + LEVEL_XP_ROW_HEIGHT + LAB_ROW_GAP
	_dna_gauge.position = Vector2(LEFT_INNER_PADDING, dna_y)
	_dna_gauge.set_bar_width(full_row_width)

	var collection_y: float = dna_y + DnaGauge.ROW_HEIGHT + LAB_ROW_GAP
	_collection_strip.position = Vector2(LEFT_INNER_PADDING, collection_y)
	_collection_strip.set_row_width(full_row_width)

## Verilen safe-area kenar paylarına göre üç panelin konum/boyutunu hesaplar.
## STATIC: LevelUpToast da (kendi capsule'ünü HUD'un hemen altına koymak için)
## bu AYNI fonksiyonu çağırır -- konum mantığı çatallanmaz. Oyun dünyası
## koordinatlarına dokunmaz.
static func compute_panel_layout(margins: Dictionary) -> Dictionary:
	var safe_left: float = max(float(margins.get("left", 0.0)), OUTER_MIN_MARGIN)
	var safe_right: float = max(float(margins.get("right", 0.0)), OUTER_MIN_MARGIN)
	var safe_top: float = max(float(margins.get("top", 0.0)), TOP_MIN_MARGIN)

	var next_left: float = NEXT_CENTER_X - NEXT_PANEL_WIDTH / 2.0
	var next_right: float = NEXT_CENTER_X + NEXT_PANEL_WIDTH / 2.0

	var left_right_edge: float = next_left - PANEL_GAP
	var ideal_left_x: float = left_right_edge - LEFT_PANEL_WIDTH
	var left_x: float = max(safe_left, ideal_left_x)
	var left_w: float = max(80.0, left_right_edge - left_x)

	var score_left_edge: float = next_right + PANEL_GAP
	var score_right_edge_max: float = 720.0 - safe_right
	var score_w: float = max(80.0, min(SCORE_PANEL_WIDTH, score_right_edge_max - score_left_edge))

	return {
		"top": safe_top,
		"height": PANEL_HEIGHT,
		"left_x": left_x, "left_w": left_w,
		"next_x": next_left, "next_w": NEXT_PANEL_WIDTH,
		"score_x": score_left_edge, "score_w": score_w,
	}
