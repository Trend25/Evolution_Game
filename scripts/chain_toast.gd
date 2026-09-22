extends CanvasLayer
class_name ChainToast
## ChainToast -- feat: add presentation-only merge chain feedback. SADECE
## SUNUM amaclidir: skor odulu veren merge'ler ~2.25 saniye icinde art arda
## gerceklesirse kisa sureli "CHAIN x2" / "CHAIN x3" ... kapsulu gosterir.
## Skor/XP/spawn/bonus ihtimali/cooldown EKONOMISINE HICBIR sekilde
## dokunmaz -- hicbir multiplier UYGULAMAZ, yalnizca
## GameManager.organism_merged sinyalinin (score_awarded=true) ZAMANLAMASINI
## izler. Balik parca tamamlanmasi (score_awarded=false) hem sayaci
## ARTIRMAZ hem de mevcut zinciri BOZMAZ/SIFIRLAMAZ -- tamamen yok sayilir.
##
## LevelUpToast (level_up_toast.gd) ile AYNI kapsul/tween deseni kullanilir
## (bu desen zaten bu projede calisir durumda kanitlanmis), ama gorsel
## cakismayi onlemek icin ScorePanel'in altinda (ekran merkezi x=360 DEGIL)
## konumlanir -- ayni merkezi HUDRoot.compute_panel_layout() fonksiyonunu
## kullanir, ayri/catallanmis sabit koordinat YOK.

const CHAIN_WINDOW_SECONDS: float = 2.25
const FADE_SECONDS: float = 0.25
const DISPLAY_SECONDS: float = 1.0
const SLIDE_DISTANCE: float = 6.0
const CAPSULE_WIDTH: float = 148.0
const CAPSULE_HEIGHT: float = 36.0
const CAPSULE_GAP_BELOW_HUD: float = 12.0

@onready var _capsule: Panel = $Capsule
@onready var _label: Label = $Capsule/Label

var _active_tween: Tween = null
var _rest_position: Vector2 = Vector2.ZERO
var _chain_count: int = 0
var _last_merge_ticks_ms: int = -1

## feat: add start pause and how-to-play flow -- GameFlow'un menu amacli
## (Start/Pause) duraklatmalari sirasinda gecen GERCEK ZAMANLI sureyi
## zincir penceresi hesabindan DUSMEK icin. Zincir SAYISINA/EKONOMISINE
## dokunmaz, yalnizca Time.get_ticks_msec() tabanli zaman OLCUMUNU pause-
## farkinda hale getirir (bkz. _effective_now_ms() ve game_flow.gd).
var _paused_accum_ms: int = 0
var _pause_started_ms: int = -1

func _ready() -> void:
	_capsule.add_theme_stylebox_override("panel", HUDTheme.make_toast_capsule_stylebox())
	HUDTheme.style_label(_label, HUDTheme.make_spaced_variation(HUDTheme.FONT_UI, 1), 16, HUDTheme.MINT_ACCENT)
	_capsule.modulate.a = 0.0
	_position_capsule()
	get_tree().root.size_changed.connect(_position_capsule)
	GameManager.organism_merged.connect(_on_organism_merged)
	GameManager.game_over_ready.connect(_on_reset_state)
	GameManager.run_reset.connect(_on_reset_state)
	GameFlow.pause_state_changed.connect(_on_pause_state_changed)

## ScorePanel'in yatay merkezine hizali, HUD'un hemen altinda -- HUDRoot ile
## AYNI merkezi compute_panel_layout()'u kullanir (LevelUpToast'un kendi
## kapsulunu konumlandirma yaklasimiyla birebir ayni), boylece Score paneli
## genislik/konumu (safe-area) degisirse ikisi asla birbirinden sapmaz.
func _position_capsule() -> void:
	var layout: Dictionary = HUDRoot.compute_panel_layout(SafeArea.get_margins())
	var hud_bottom: float = float(layout.get("top", 20.0)) + float(layout.get("height", 124.0))
	var score_x: float = float(layout.get("score_x", 468.0))
	var score_w: float = float(layout.get("score_w", 224.0))
	var score_center_x: float = score_x + score_w / 2.0
	_rest_position = Vector2(score_center_x - CAPSULE_WIDTH / 2.0, hud_bottom + CAPSULE_GAP_BELOW_HUD)
	_capsule.position = _rest_position
	_capsule.size = Vector2(CAPSULE_WIDTH, CAPSULE_HEIGHT)

## Yalnizca SKOR ODULU VEREN merge'lerde islenir (score_awarded=false ise --
## balik parca tamamlanmasi -- hicbir sekilde islenmez: ne sayar ne
## sifirlar). Chain penceresi (CHAIN_WINDOW_SECONDS) disinda gecen sure
## varsa sayac sessizce 1'den yeniden baslar -- kapsul yalnizca count>=2
## iken gorunur oldugundan bu, "timeout sonrasi sayac sifirlaniyor"
## davranisidir (ayri bir Timer node'una gerek yoktur).
func _on_organism_merged(_position: Vector2, _stage_id: int, _is_bonus: bool, _awarded_score: int, score_awarded: bool) -> void:
	if not score_awarded:
		return
	var now_ms: int = _effective_now_ms()
	if _last_merge_ticks_ms >= 0 and float(now_ms - _last_merge_ticks_ms) / 1000.0 <= CHAIN_WINDOW_SECONDS:
		_chain_count += 1
	else:
		_chain_count = 1
	_last_merge_ticks_ms = now_ms
	if _chain_count >= 2:
		_show_chain(_chain_count)

## GameFlow'un menu pause'u sirasinda gecen sureyi disarida birakan
## "efektif" zaman -- iki cagridaki (store/compare) pause araligi ayni
## sekilde dusuldugunden aralarindaki FARK dogru kalir.
func _effective_now_ms() -> int:
	return Time.get_ticks_msec() - _paused_accum_ms

func _on_pause_state_changed(is_paused: bool) -> void:
	if is_paused:
		_pause_started_ms = Time.get_ticks_msec()
	elif _pause_started_ms >= 0:
		_paused_accum_ms += Time.get_ticks_msec() - _pause_started_ms
		_pause_started_ms = -1

func _show_chain(count: int) -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_label.text = "CHAIN ×%d" % count
	_capsule.modulate.a = 0.0
	_capsule.position = _rest_position + Vector2(0.0, SLIDE_DISTANCE)
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.tween_property(_capsule, "modulate:a", 1.0, FADE_SECONDS)
	_active_tween.tween_property(_capsule, "position", _rest_position, FADE_SECONDS)
	_active_tween.chain().tween_interval(DISPLAY_SECONDS)
	_active_tween.chain().tween_property(_capsule, "modulate:a", 0.0, FADE_SECONDS)

## Game Over VE Retry ("Play again") sonrasinda sayac/tween/kapsul TAMAMEN
## sifirlanir -- eski bir zincirin kalintisi yeni turda ASLA gorunmez.
## NOT: bu fonksiyon hem game_over_ready(final_stats: Dictionary) hem de
## run_reset() (parametresiz) sinyaline BAGLI -- Godot'ta bagli callable'in
## parametre sayisi sinyalin gonderdigi arguman sayisiyla TAM eslesmezse
## "Method expected 0 argument(s), but called with 1" hatasiyla cagri hic
## YAPILMAZ (bulundu: game_over_ready tetiklendiginde bu fonksiyon hicbir
## zaman calismiyordu, bu yuzden Game Over sonrasi sayac/kapsul temizlenmiyordu).
## Varsayilan degerli opsiyonel parametre iki sinyal imzasiyla da uyumlu olur.
func _on_reset_state(_final_stats: Dictionary = {}) -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_capsule.modulate.a = 0.0
	_chain_count = 0
	_last_merge_ticks_ms = -1
	_paused_accum_ms = 0
	_pause_started_ms = -1
