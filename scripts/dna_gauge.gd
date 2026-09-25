extends Node2D
class_name DnaGauge
## DnaGauge -- gameplay/core-loop-v4 "Evrim Laboratuvarı" V02 vertical slice
## (madde 7 -- kullanıcı: "normal mekanik: her 5 birleşmede DNA göstergesi
## dolar"). SADECE GÖRSEL: GameManager.dna_progress_changed(current, required)
## sinyalini dinleyip ince bir dolum çubuğu + küçük "DNA" başlığı çizer -- DNA
## ilerlemesinin KENDİSİ (dna_progress/_advance_dna/consume_dna) TAMAMEN
## game_manager.gd'de hesaplanır, bu script yalnızca ZATEN hesaplanmış değeri
## GÖSTERİR. XPBar (xp_bar.gd) ile AYNI desen: hiçbir çocuk sahne düğümü
## GEREKMEZ, tamamen _draw() ile kendi kendine yeter -- HUDRoot bu düğümü
## Main.tscn'e XPBar ile aynı şekilde (script'li boş bir Node2D olarak) ekler.
## HUDRoot._layout_left_panel_content(), SADECE GrayboxConfig.ENABLED and
## GrayboxConfig.LAB_VISUALS_ENABLED iken bu düğümü Sol Panel içinde
## konumlandırıp görünür kılar; üretimde hiç gösterilmez (XPBar'a dokunulmaz).

const BAR_HEIGHT: float = 12.0
const LABEL_FONT_SIZE: int = 9
const LABEL_GAP: float = 3.0  # başlık ile çubuk arası
const ROW_HEIGHT: float = LABEL_FONT_SIZE + LABEL_GAP + BAR_HEIGHT  # HUDRoot bu satırın toplam yüksekliğini bilmek için kullanır

const TRACK_COLOR: Color = Color(1.0, 1.0, 1.0, 0.10)
const FILL_COLOR: Color = Color("#8FE3D2")
const READY_FILL_COLOR: Color = Color("#F4C95D")  # dolduğunda amber'e döner -- "hazır" hissi
const LABEL_COLOR: Color = Color(0.86, 0.95, 0.92, 0.72)

const FILL_TWEEN_DURATION: float = 0.4  # "enerjinin DOLMASI" görünsün diye -- anlık sıçrama değil, kısa görünür bir animasyon

var _bar_width: float = 148.0
var _current: int = 0
var _required: int = 5
var _pulse_tween: Tween = null
var _pulse_scale: float = 1.0
# DÜZELTME (V02 İKİNCİ düzeltme turu -- kullanıcı madde 7: "DNA göstergesi
# yalnızca dekor olmamalı ... enerjinin dolması ... gösterilmeli"): eskiden
# _on_progress_changed() doğrudan queue_redraw() çağırıyordu -- yeni oran
# BİR SONRAKİ karede ANİDEN belirirdi (görünür bir "dolma" hareketi YOKTU,
# sadece anlık bir sıçrama). Artık _display_ratio, GERÇEK ilerlemeye
# (_current/_required -- hesaplamanın KENDİSİ game_manager.gd'de, burada
# DEĞİŞMEDİ) kısa bir tween ile YUMUŞAKÇA yaklaşır -- her merge'in DNA
# çubuğunu GÖZLE GÖRÜLÜR şekilde ilerlettiği artık netleşir.
var _display_ratio: float = 0.0
var _fill_tween: Tween = null

func _ready() -> void:
	GameManager.dna_progress_changed.connect(_on_progress_changed)
	GameManager.dna_ready.connect(_on_ready_pulse)
	GameManager.run_reset.connect(_on_run_reset)
	queue_redraw()

## HUDRoot tarafından, XPBar.set_bar_width() ile AYNI sözleşmeyle çağrılır --
## panel daraldıkça/genişledikçe çubuk genişliği otomatik uyum sağlar.
func set_bar_width(width: float) -> void:
	_bar_width = max(40.0, width)
	queue_redraw()

func _on_progress_changed(current: int, required: int) -> void:
	_current = current
	_required = required
	var target_ratio: float = 0.0 if _required <= 0 else clamp(float(_current) / float(_required), 0.0, 1.0)
	if _fill_tween != null and _fill_tween.is_valid():
		_fill_tween.kill()
	if target_ratio <= _display_ratio:
		# consume_dna()/run_reset ile SIFIRLANMA (ya da teorik bir azalma) --
		# oyuncunun kartı SEÇTİĞİ an zaten mutasyon sayfası kendi geçişini
		# oynatıyor, burada da AYNI hızlı geri-sıfırlanma yeterli (yavaş
		# "boşalma" beklenmez, yalnızca DOLMA animasyonu istendi).
		_display_ratio = target_ratio
		queue_redraw()
		return
	_fill_tween = create_tween()
	_fill_tween.tween_method(_set_display_ratio, _display_ratio, target_ratio, FILL_TWEEN_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

func _set_display_ratio(value: float) -> void:
	_display_ratio = value
	queue_redraw()

## NOT: game_manager.gd reset_run()'da dna_progress_changed HER ZAMAN run_reset'ten
## ÖNCE yayınlanır -- bu yüzden buraya geldiğimizde _current/_required ZATEN
## yeni turun gerçek başlangıç değerini taşır (normalde 0, dna_qa_demo_start_at_4
## açıkken DNA_REQUIRED_MERGES-1). Burada 0.0'a SABİT sıfırlamak (önceki hatalı
## davranış) bu değeri GEÇERSİZ kılıp demo kısayolunu bozardı -- artık
## _current/_required'dan YENİDEN hesaplanan orana ANINDA (tween'siz) atlanır,
## yeni turun ilk karesi baştan yanlış/eski bir animasyonun ortasında görünmez.
func _on_run_reset(_final_stats: Dictionary = {}) -> void:
	if _fill_tween != null and _fill_tween.is_valid():
		_fill_tween.kill()
	_display_ratio = 0.0 if _required <= 0 else clamp(float(_current) / float(_required), 0.0, 1.0)
	queue_redraw()

## DNA tam dolduğunda kısa bir "nefes" (scale pulse) -- kullanıcı isteği:
## "oyun hiç durmuyormuş gibi hissettirmeli" -- donmuş bir simge yerine kısa,
## kendiliğinden biten bir tween.
func _on_ready_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.tween_method(_set_pulse_scale, 1.0, 1.18, 0.12).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_method(_set_pulse_scale, 1.18, 1.0, 0.18).set_ease(Tween.EASE_IN)

func _set_pulse_scale(value: float) -> void:
	_pulse_scale = value
	queue_redraw()

func _draw() -> void:
	draw_string(HUDTheme.FONT_UI, Vector2(0.0, LABEL_FONT_SIZE), "DNA", HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, LABEL_COLOR)

	var bar_y: float = LABEL_FONT_SIZE + LABEL_GAP
	var track_rect := Rect2(Vector2(0.0, bar_y), Vector2(_bar_width, BAR_HEIGHT))
	draw_rect(track_rect, TRACK_COLOR, true)
	# _display_ratio -- GERÇEK orana (_current/_required) kısa bir tween ile
	# yaklaşan, GÖRÜNÜR animasyonlu değer (bkz. _on_progress_changed). Sadece
	# ÇİZİM için kullanılır -- hiçbir DNA/skor mantığı bu değeri OKUMAZ.
	if _display_ratio <= 0.0:
		return
	var is_ready: bool = _current >= _required
	var fill_color: Color = READY_FILL_COLOR if is_ready else FILL_COLOR
	var fill_width: float = _bar_width * _display_ratio
	if not is_ready:
		draw_rect(Rect2(Vector2(0.0, bar_y), Vector2(fill_width, BAR_HEIGHT)), fill_color, true)
		return
	# Dolu (is_ready): pulse ölçeği çubuğun KENDİ merkezine göre uygulanır ki
	# taşma sol/sağ dengeli olsun.
	var center: Vector2 = Vector2(fill_width / 2.0, bar_y + BAR_HEIGHT / 2.0)
	draw_set_transform(center, 0.0, Vector2.ONE * _pulse_scale)
	draw_rect(Rect2(-fill_width / 2.0, -BAR_HEIGHT / 2.0, fill_width, BAR_HEIGHT), fill_color, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
