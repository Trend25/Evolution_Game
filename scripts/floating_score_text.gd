extends Node2D
class_name FloatingScoreText
## FloatingScoreText -- feat: add merge burst and floating score feedback.
## Skor ODULU VERILEN bir merge'in gercek dunya konumunda kisa sureli
## yukselip saydamlasan "+N" (Bricolage Grotesque, sayi fontu) ve -- yalnizca
## bonus ise -- altinda kucuk "BONUS xN" (Instrument Sans, genel metin fontu)
## etiketi gosterir. GERCEK, zaten hesaplanmis skor degerini disaridan
## (GameManager.organism_merged sinyalinden) parametre olarak alir -- hicbir
## skor sayisi bu script icinde SABIT/yeniden hesaplanmis/KOPYALANMIS
## degildir; bonus carpani da GameManager'in kendi sabitinden
## (BONUS_ORGANISM_SCORE_MULTIPLIER) okunur, burada tekrar yazilmaz.
##
## Organizmalari veya NEXT panelini kapatacak kadar buyuk degildir (kucuk,
## tek satir sayi + kucuk ikinci satir), fizik/collision'a katilmaz.

const RISE_DISTANCE: float = 26.0
const FADE_IN_DURATION: float = 0.12
const HOLD_DELAY: float = 0.16     # fade-in bittikten sonra tam opak kalinan sure
const FADE_OUT_DURATION: float = 0.52
const DURATION: float = FADE_IN_DURATION + HOLD_DELAY + FADE_OUT_DURATION  # ~0.8s (istenen 0.7-0.9s araliginda)

@onready var _score_label: Label = $ScoreLabel
@onready var _bonus_label: Label = $BonusLabel

func _ready() -> void:
	z_index = 6  # MergeBurst'un (z_index=5) her zaman USTUNDE -- sayi halkanin/parcaciklarin altinda kalmasin
	HUDTheme.style_label(_score_label, HUDTheme.FONT_NUMBER, 22, HUDTheme.TEXT_PRIMARY)
	HUDTheme.style_label(_bonus_label, HUDTheme.make_spaced_variation(HUDTheme.FONT_UI, 1), 12, HUDTheme.GOLD_ACCENT)
	_bonus_label.visible = false
	modulate.a = 0.0

## awarded_score: GameManager.add_merge_reward'in ZATEN hesapladigi gercek
## deger -- bu fonksiyon skoru yeniden HESAPLAMAZ, yalnizca GOSTERIR.
## feat: improve mobile scale and scoring feedback (Bölüm C) -- combo_count:
## GameManager._advance_combo()'nun ZATEN hesapladigi, GERCEK skoru etkileyen
## yetkili zincir sayisi (1 = kombo yok). 2+ ise ana etikete " ×N" eklenir
## (kullanici ornegi: "+140 x2") -- ayri bir kombo carpani BURADA yeniden
## HESAPLANMAZ, yalnizca GameManager'in zaten uyguladigi carpanin SONUCU olan
## awarded_score ile birlikte GOSTERILIR.
func play(awarded_score: int, is_bonus: bool, combo_count: int = 1) -> void:
	var score_text: String = "+%s" % HUDTheme.format_thousands(awarded_score)
	if combo_count >= 2:
		score_text += " ×%d" % combo_count
	_score_label.text = score_text
	_score_label.add_theme_color_override("font_color", HUDTheme.GOLD_ACCENT if is_bonus else HUDTheme.TEXT_PRIMARY)
	if is_bonus:
		_bonus_label.text = "BONUS ×%d" % int(GameManager.BONUS_ORGANISM_SCORE_MULTIPLIER)
		_bonus_label.visible = true
	else:
		_bonus_label.visible = false

	modulate.a = 0.0
	var start_pos: Vector2 = position

	var pos_tween: Tween = create_tween()
	pos_tween.tween_property(self, "position", start_pos + Vector2(0.0, -RISE_DISTANCE), DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	pos_tween.finished.connect(queue_free)

	var alpha_tween: Tween = create_tween()
	alpha_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION)
	alpha_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_DURATION).set_delay(HOLD_DELAY)
