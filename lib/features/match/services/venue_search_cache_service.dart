import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meetit/features/match/models/place_result.dart';

/// 💸 MALİYET DÜŞÜRME (2026-06-28): Asıl Places API maliyetinin BÜYÜK kısmı
/// fotoğraflardan değil, Nearby Search çağrısının KENDİSİNDEN geliyor (her
/// arama = 1 faturalanan istek). Önceki önbellekleme çalışması SADECE
/// fotoğrafları kapsıyordu — bu servis, ham Nearby Search SONUÇLARINI
/// (filtrelemeden/skorlamadan ÖNCEKİ havuzu) konum+tip bazlı bir Firestore
/// önbelleğine KALICI olarak yazarak AYNI bölgede AYNI tip kombinasyonuyla
/// yapılan tekrar aramaların Google'a HİÇ gitmemesini sağlar.
///
/// ÖNEMLİ: Burada önbelleğe alınan şey HAM havuzdur (örn. 20 mekan) — final
/// kullanıcıya gösterilen ≤5 mekan listesi DEĞİL. Bu sayede mevcut
/// filtreleme + ağırlıklı rastgele seçim mantığı (her aramada biraz
/// farklı sonuçlar göster) AYNEN çalışmaya devam eder; sadece Google'a
/// gidilen ADIM atlanır, kullanıcı deneyimi (çeşitlilik) BOZULMAZ.
///
/// 🗄️ KALICI ÖNBELLEK (2026-06-28, güncelleme — kullanıcı talebiyle):
/// Önceden 6 saatlik bir TTL vardı — ama uygulama esas olarak İstanbul/
/// Ankara gibi BÜYÜK ve SABİT şehirler için kullanılacağından (mekanlar
/// nadiren açılıp kapanıyor, konumları hiç değişmiyor), süre sınırı
/// TAMAMEN KALDIRILDI: bir bölge+tip kombinasyonu BİR KERE çekildikten
/// sonra sonsuza dek (TTL'siz) önbellekte kalıyor — yani şehir başına, tip
/// kombinasyonu başına Google'a EN FAZLA 1 KERE, hayat boyu gidiliyor.
///
/// Bedeli: rating/yorum sayısı/açık-kapalı gibi alanlar zamanla bayatlayabilir
/// — ama bu bilgiler zaten uygulamanın kendi yorum/puan sistemiyle de
/// besleniyor, salt Google'a bağımlı değil. Tamamen taze Google verisi
/// gerekiyorsa bu önbellek Firestore Console'dan elle silinip o bölge+tip
/// için bir DAHAKİ aramada Google'a yeniden gidilmesi sağlanabilir.
class VenueSearchCacheService {
  VenueSearchCacheService._();

  static final _firestore = FirebaseFirestore.instance;
  static const String _collection = 'venueSearchCache';

  /// Konumu ~1.1km'lik bir ızgaraya yuvarlar — tam aynı koordinatta arama
  /// yapılması gerekmiyor, "aynı civarda" arama bile cache'e düşer. Arama
  /// yarıçapı (genelde birkaç km) bu ızgaradan çok daha büyük olduğu için
  /// bu yuvarlama sonuçların coğrafi doğruluğunu bozmaz.
  static double _gridRound(double value) => (value * 100).roundToDouble() / 100;

  static String _buildKey({
    required double lat,
    required double lng,
    required List<String> types,
    required int radius,
  }) {
    final sortedTypes = [...types]..sort();
    final raw = '${_gridRound(lat)}_${_gridRound(lng)}_r${radius}_'
        '${sortedTypes.join("-")}';
    // Firestore doküman ID'sinde '/' yasak; güvenli olsun diye temizliyoruz.
    return raw.replaceAll('/', '_').replaceAll('.', 'p');
  }

  /// Önbellekte bu konum+tip kombinasyonu için (TTL'siz, KALICI) bir ham
  /// sonuç havuzu varsa onu döner; yoksa null (çağıran taraf Google'a
  /// gitmeli — sadece bu bölge+tip için hayatında İLK KEZ).
  static Future<List<PlaceResult>?> getCached({
    required double lat,
    required double lng,
    required List<String> types,
    required int radius,
  }) async {
    final key = _buildKey(lat: lat, lng: lng, types: types, radius: radius);
    try {
      final snap = await _firestore.collection(_collection).doc(key).get();
      final data = snap.data();
      if (data == null) return null;

      final places = (data['places'] as List<dynamic>? ?? [])
          .map((p) => PlaceResult.fromStorageMap(p as Map<String, dynamic>))
          .toList();
      if (places.isEmpty) return null; // boş kayıt — yine Google'a git
      return places;
    } catch (e) {
      // ignore: avoid_print
      print('[VenueSearchCacheService] okuma hatası: $e');
      return null; // hata durumunda güvenli fallback: Google'dan çek
    }
  }

  /// Google'dan TAZE çekilen ham sonuç havuzunu önbelleğe yazar.
  static Future<void> setCached({
    required double lat,
    required double lng,
    required List<String> types,
    required int radius,
    required List<PlaceResult> places,
  }) async {
    if (places.isEmpty) return; // boş sonucu cache'lemek anlamsız
    final key = _buildKey(lat: lat, lng: lng, types: types, radius: radius);
    try {
      await _firestore.collection(_collection).doc(key).set({
        'places': places.map((p) => p.toStorageMap()).toList(),
        'cachedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // ignore: avoid_print
      print('[VenueSearchCacheService] yazma hatası: $e');
      // Cache yazılamasa da arama sonucu kullanıcıya zaten döndü — sorun yok.
    }
  }
}
