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

@onready var _preview_rect: TextureRect = $PreviewRect
@onready var _label: Label = $NextLabel

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
		return
	var stage_id: int = int(data.get("stage_id", 0))
	var is_bonus: bool = bool(data.get("is_bonus", false))
	var is_fish_part: bool = bool(data.get("is_fish_part", false))
	var fish_part_index: int = int(data.get("fish_part_index", 0))

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
