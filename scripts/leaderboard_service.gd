extends Node
## LeaderboardService — Autoload. UC-07: Liderlik Tablosu için ince bir
## soyutlama katmanı. Gerçek Google Play Games Services (Android) / Game
## Center (iOS) bağlantısı platforma özel eklenti (plugin) ve export ayarı
## gerektirir; bu proje henüz o eklentileri içermediğinden burada sadece
## arayüz/stub bulunur — eklentiler kurulduğunda içi doldurulmalı (UC-07).

## UC-04 Adım 3 / UC-07: Final skoru liderlik tablosu servisine gönderir.
func submit_score(final_score: int) -> void:
	# TODO (UC-07): Play Games Services / Game Center eklentisi kurulduğunda
	# burada gerçek report_score/submit_score API çağrısı yapılmalı.
	print("[LeaderboardService] Skor gönderilecek (stub): %d" % final_score)
