import 'package:cloud_firestore/cloud_firestore.dart';

/// Hangi Google Places API'sinin ("New" veya "Legacy") kullanılacağını
/// Firestore'daki tek bir alandan okuyan servis.
///
/// 📍 NEDEN (2026-06-28): Google Places API (New) ve Legacy Places API,
/// AYRI SKU'lara (birbirinden bağımsız ücretsiz aylık kotalara) sahip —
/// bkz. app_config.dart üstündeki not. Bu iki ayrı kotayı pratikte TEK bir
/// kombine kota gibi kullanabilmek için, hangi API'nin kullanılacağı KOD
/// DEĞİŞTİRMEDEN / uygulamayı yeniden derlemeden Firestore'dan kontrol
/// edilebiliyor: biri aylık kotasına yaklaşınca (Google Cloud Console'dan
/// elle takip edilip) bu alan diğerine çevrilir, dolan kota dinlenirken
/// diğeri devreye girer.
///
/// Firestore şekli:
///   Doküman: `appConfig/placesApi`
///   Alan:    `activeVersion` (String) — "new" veya "legacy"
///
/// ⚠️ VARSAYILAN DAVRANIŞ (kasıtlı, talep üzerine): Firestore alanı YOKSA,
/// okunamazsa (izin hatası, ağ hatası, doküman hiç yok vb.) veya tanınmayan
/// bir değer içeriyorsa HER ZAMAN [PlacesApiVersion.newApi] döner. Legacy
/// endpoint Google tarafından uzun vadede tamamen kapatılabileceğinden,
/// sessiz bir okuma hatası asla uygulamayı kırılgan/kapatılmış bir API'ye
/// düşürmemeli — "new" güvenli/varsayılan taraf.
enum PlacesApiVersion { newApi, legacy }

class PlacesApiVersionService {
  PlacesApiVersionService._();

  static final _firestore = FirebaseFirestore.instance;

  static const String _collection = 'appConfig';
  static const String _docId = 'placesApi';
  static const String _field = 'activeVersion';

  // Firestore'a HER aramada gitmemek için kısa süreli bellek-içi cache —
  // alan değiştirildiğinde en fazla bu süre kadar bir gecikmeyle yansır.
  // Maliyet açısından önemsiz (Firestore okuma ücretsiz kotası çok yüksek),
  // bu sadece gereksiz tekrar okumayı azaltan bir optimizasyon.
  static const Duration _cacheTtl = Duration(minutes: 5);

  static PlacesApiVersion? _cachedVersion;
  static DateTime? _cachedAt;

  /// Aktif olarak kullanılması gereken Places API sürümünü döner.
  /// Firestore'a SADECE cache süresi dolduğunda/ilk çağrıda gidilir.
  static Future<PlacesApiVersion> getActiveVersion() async {
    final now = DateTime.now();
    if (_cachedVersion != null &&
        _cachedAt != null &&
        now.difference(_cachedAt!) < _cacheTtl) {
      return _cachedVersion!;
    }

    try {
      final snap =
          await _firestore.collection(_collection).doc(_docId).get();
      final raw = snap.data()?[_field] as String?;

      final resolved = switch (raw) {
        'legacy' => PlacesApiVersion.legacy,
        'new' => PlacesApiVersion.newApi,
        _ => PlacesApiVersion.newApi, // alan yok/boş/tanınmıyor → varsayılan
      };

      _cachedVersion = resolved;
      _cachedAt = now;
      return resolved;
    } catch (e) {
      // ignore: avoid_print
      print(
        '[PlacesApiVersionService] Firestore okuma hatası, "new" '
        'varsayılanına dönülüyor: $e',
      );
      // Hata durumunda cache'e YAZMIYORUZ — bir sonraki arama tekrar
      // okumayı denesin (geçici bir ağ sorunuysa hemen kendini düzeltsin).
      return PlacesApiVersion.newApi;
    }
  }
}
