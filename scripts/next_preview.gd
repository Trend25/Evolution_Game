extends Panel
class_name NextPreview
## NextPreview — feat: add dedicated next organism preview. UI_Canvas/HUDRoot
## altındaki "NEXT" panelinin GÖRSEL-SADECE önizlemesi. Spawner'dan gelen
## stage_id/is_bonus/is_fish_part/fish_part_index verisini okuyup uygun
## dokuyu gösterir -- KENDİ fizik/collision/merge'i YOKTUR, _physics_process
## çalışmaz, dünya-uzayında hiçbir karşılığı yoktur, hiçbir organizmayla
## birleşemez. organism_visual.gd'nin STAGE_TEXTURES/FISH_FRONT_TEXTURE/
## FISH_BACK_TEXTURE/BONUS_TINT_* sabitlerini (preload edilmiş script kaynağı
## üzerinden, class_name olmadan da const'lara böyle erişilebilir) OKUR --
## doku eşlemesi TEK bir yerde (organism_visual.gd) kalır, burada tekrar
## edilmez/çatallanmaz; büyük/riskli bir organism_visual refactor'ı yapılmadı.

const OrganismVisualScript: GDScript = preload("res://scripts/organism_visual.gd")
const LabPreviewHostScript: GDScript = preload("res://scripts/lab_preview_host.gd")

# gameplay/core-loop-v4 "Evrim Laboratuvarı" vertical slice -- kullanıcı
# talebi: "NEXT önizlemesindeki canlı en az 48-56 px görünür büyüklükte
# olmalı; küçük bir nokta gibi görünmemeli". Üç aşamanın GERÇEK fiziksel
# çapı farklı olduğundan (74/92/112px), önizleme burada SABİT bir hedef
# görünür çapa (bu payın üzerinde) normalize edilir -- HUD'ta tutarlı bir
# önizleme boyutu için.
const LAB_PREVIEW_TARGET_DIAMETER: float = 60.0

@onready var _preview_rect: TextureRect = $PreviewRect
@onready var _label: Label = $NextLabel

var _lab_preview_root: Node2D = null

func _ready() -> void:
	_apply_style()

func _apply_style() -> void:
	add_theme_stylebox_override("panel", HUDTheme.make_next_panel_stylebox())
	HUDTheme.style_label(_label, HUDTheme.make_spaced_variation(HUDTheme.FONT_UI, 2), 13, HUDTheme.MINT_ACCENT)
	_label.text = "NEXT"

## Spawner.next_organism_ready sinyali VE Main.gd'nin ilk senkronizasyon
## çağrısı tarafından tetiklenir (bkz. main.gd -- _ready() sıra riskine karşı).
## Yalnızca GÖRSEL günceller: hiçbir fizik/collision/merge nesnesi oluşturmaz
## veya taşımaz, spawn/cooldown/bonus/fish-pairing mantığına dokunmaz.
func update_preview(data: Dictionary) -> void:
	if data.is_empty():
		_preview_rect.texture = null
		_hide_lab_preview()
		return
	var stage_id: int = int(data.get("stage_id", 0))
	var is_bonus: bool = bool(data.get("is_bonus", false))
	var is_fish_part: bool = bool(data.get("is_fish_part", false))
	var fish_part_index: int = int(data.get("fish_part_index", 0))

	# gameplay/core-loop-v4 "Evrim Laboratuvarı" vertical slice (madde 4 --
	# "NEXT önizlemesindeki canlı en az 48-56px görünür olmalı"): id 0/1/2
	# (Virüs/Bakteri/Tek Hücreli) için artık organism_visual.gd'nin GERÇEK
	# çizim kodu, LabPreviewHost üzerinden, sabit bir hedef görünür çapa
	# (LAB_PREVIEW_TARGET_DIAMETER) normalize edilerek kullanılır -- eski
	# düz renkli graybox dairesi/PreviewRect dokusu bu üç aşama için ARTIK
	# gösterilmez. Bu dilimde erişilemeyen diğer stage_id'ler ve balık
	# parçaları bu dala hiç girmez, aşağıdaki eski yollara düşer.
	if GrayboxConfig.ENABLED and GrayboxConfig.LAB_VISUALS_ENABLED and stage_id <= OrganismTypes.VERTICAL_SLICE_FINAL_STAGE_ID and not is_fish_part:
		_show_lab_preview(stage_id, is_bonus)
		return
	_hide_lab_preview()

	# V4 core-loop/graybox (madde 4 -- tutarlılık): NEXT paneli önceden
	# GrayboxConfig'ten HABERSİZDİ -- fanustaki canlılar graybox renkli
	# dairelere dönüşse bile NEXT hep gerçek üretim sanatını gösteriyordu
	# (video kaydında fark edildi). STAGE_TEXTURES eşlemesinin KENDİSİNE
	# dokunulmadı (madde 4/kullanıcı isteği: mevcut sanat görsellerine
	# dokunma) -- yalnızca bu panelin HANGİ kaynağı GÖSTERECEĞİ, SADECE
	# ENABLED iken, dallandırıldı.
	if GrayboxConfig.ENABLED:
		_apply_graybox_preview(stage_id, is_bonus)
		return

	var texture: Texture2D = null
	if is_fish_part:
		texture = OrganismVisualScript.FISH_FRONT_TEXTURE if fish_part_index == 0 else OrganismVisualScript.FISH_BACK_TEXTURE
	else:
		texture = OrganismVisualScript.STAGE_TEXTURES.get(stage_id, null)

	_preview_rect.texture = texture
	if is_bonus:
		_preview_rect.modulate = Color.WHITE.lerp(OrganismVisualScript.BONUS_TINT_COLOR, OrganismVisualScript.BONUS_TINT_STRENGTH)
	else:
		_preview_rect.modulate = Color.WHITE

## gameplay/core-loop-v4 "Evrim Laboratuvarı": LabPreviewHost + üzerine
## organism_visual.gd bağlı bir Polygon2D çocuğu -- ilk çağrıda oluşturulur,
## sonraki her çağrıda (stage_id değişmiş olabileceğinden, organism_visual.gd
## _ready() TEK SEFERLİK okuduğundan) görsel çocuk atılıp yeniden kurulur.
## PreviewRect (eski doku tabanlı önizleme) bu süre boyunca gizlenir.
func _ensure_lab_preview_root() -> void:
	if _lab_preview_root != null:
		return
	_lab_preview_root = Node2D.new()
	_lab_preview_root.set_script(LabPreviewHostScript)
	_lab_preview_root.name = "LabPreviewRoot"
	add_child(_lab_preview_root)

func _show_lab_preview(stage_id: int, is_bonus: bool) -> void:
	_ensure_lab_preview_root()
	_preview_rect.visible = false
	_lab_preview_root.visible = true
	_lab_preview_root.stage_id = stage_id
	_lab_preview_root.tier = 0
	_lab_preview_root.is_bonus = is_bonus
	_lab_preview_root.is_fish_part = false
	_lab_preview_root.fish_part_index = 0
	_lab_preview_root.born_from_evolution = false

	# Eski görsel çocuğunu at -- organism_visual.gd _ready() stage_id'yi
	# yalnızca instantiate anında okur, bu yüzden aşama değiştiğinde çocuk
	# yeniden kurulmalı (queue_free yerine ANINDA free -- burası fizik
	# query-flushing anı DEĞİL, HUD sinyal callback'i, deferred'a gerek yok).
	for child in _lab_preview_root.get_children():
		_lab_preview_root.remove_child(child)
		child.free()

	var visual := Polygon2D.new()
	visual.name = "Visual"
	visual.set_script(OrganismVisualScript)
	_lab_preview_root.add_child(visual)

	# Üç aşamanın GERÇEK fiziksel çapı farklı (74/92/112px) -- burada SABİT
	# bir hedef görünür çapa (LAB_PREVIEW_TARGET_DIAMETER) normalize edilir,
	# Node2D.scale ile (organism_visual.gd'nin çizim koduna hiç dokunmadan).
	var radius: float = GrayboxConfig.effective_radius(stage_id, 0)
	var diameter: float = radius * 2.0
	var scale_factor: float = LAB_PREVIEW_TARGET_DIAMETER / diameter if diameter > 0.0 else 1.0
	_lab_preview_root.scale = Vector2.ONE * scale_factor
	# PreviewRect'in mevcut kutusuyla (anchor 0.5,0 / offset -62..62 / 28..118)
	# aynı merkeze hizalanır: yatayda panel genişliğinin ortası, dikeyde 73px.
	_lab_preview_root.position = Vector2(size.x / 2.0, 73.0)

func _hide_lab_preview() -> void:
	if _lab_preview_root != null:
		_lab_preview_root.visible = false
	_preview_rect.visible = true

## V4 core-loop/graybox: NEXT panelinde, fanustaki graybox dairelerle AYNI
## renk paletini (GrayboxConfig.STAGE_COLORS) kullanan basit, düz renkli bir
## daire dokusu üretip gösterir. STAGE_TEXTURES/gerçek sanata dokunmaz --
## yalnızca bu panelin küçük önizleme dokusunu ÇALIŞMA ZAMANINDA üretir.
func _apply_graybox_preview(stage_id: int, is_bonus: bool) -> void:
	var color: Color = GrayboxConfig.STAGE_COLORS.get(stage_id, Color.WHITE)
	if is_bonus:
		color = color.lerp(OrganismVisualScript.BONUS_TINT_COLOR, OrganismVisualScript.BONUS_TINT_STRENGTH)
	_preview_rect.texture = _make_circle_texture(color)
	_preview_rect.modulate = Color.WHITE

const _GRAYBOX_PREVIEW_SIZE: int = 96
var _graybox_texture_cache: Dictionary = {}  # Color -> ImageTexture, aynı rengi tekrar tekrar üretmemek için

func _make_circle_texture(color: Color) -> ImageTexture:
	if _graybox_texture_cache.has(color):
		return _graybox_texture_cache[color]
	var size: int = _GRAYBOX_PREVIEW_SIZE
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	var radius: float = size / 2.0 - 2.0
	for y in range(size):
		for x in range(size):
			if Vector2(x, y).distance_to(center) <= radius:
				img.set_pixel(x, y, color)
			else:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_graybox_texture_cache[color] = tex
	return tex
