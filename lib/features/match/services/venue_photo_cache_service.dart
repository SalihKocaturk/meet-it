import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:meetit/features/match/models/place_result.dart';

/// 💸 MALİYET DÜŞÜRME (2026-06-28): Google Places "Photo Media" endpoint'i
/// HER çağrıda ayrıca faturalanıyor (Nearby Search'ten BAĞIMSIZ bir SKU).
/// `cached_network_image` paketi sadece CİHAZ-İÇİ (per-device) cache yapıyor;
/// aynı mekanı gören FARKLI kullanıcılar/cihazlar için Google'a HER SEFERİNDE
/// yeni, ayrı faturalanan bir istek gidiyordu — bu, popüler mekanlarda
/// maliyetin "hayvansal" büyümesinin asıl sebebiydi.
///
/// Bu servis, her benzersiz Google foto referansını TÜM kullanıcılar için
/// PAYLAŞIMLI, KALICI bir önbelleğe alır:
///   1) Firestore'da (`venuePhotoCache/{placeId}`) bu foto için zaten
///      çözümlenmiş bir Firebase Storage URL'i var mı diye bakılır.
///   2) Varsa o URL döner — Google'a HİÇ istek atılmaz (0 maliyet).
///   3) Yoksa: Google'dan foto SADECE BİR KERE indirilir, Firebase
///      Storage'a yüklenir, kalıcı bir indirme URL'i alınır ve Firestore'a
///      yazılır — bundan sonra o foto için artık HİÇBİR kullanıcı/cihaz
///      Google'a tekrar istek atmaz.
///
/// Sonuç: Aynı gerçek dünya mekanının fotoğrafı, kaç kullanıcı görürse
/// görsün, Google'a EN FAZLA 1 KERE (global, kalıcı) faturalandırılır.
class VenuePhotoCacheService {
  VenuePhotoCacheService._();

  static final _firestore = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  static const String _collection = 'venuePhotoCache';

  /// `photoName` Google'ın "places/ChIJ.../photos/AUf1Q.." formatındaki
  /// foto referansı — bu string'i Storage'da geçerli bir dosya adına
  /// çevirmek için path ayraçlarını temizliyoruz.
  static String _photoKey(String photoName) =>
      photoName.replaceAll('/', '_').replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '');

  /// Tek bir fotoğrafı çözümler: önbellekte varsa onu, yoksa Google'dan
  /// indirip Storage'a yükledikten sonra YENİ Storage URL'ini döner.
  /// Herhangi bir hata durumunda (ağ, izin, vb.) GÜVENLİ FALLBACK olarak
  /// ham Google URL'i (`PlaceResult.buildPhotoUrl(photoName)`) döner —
  /// böylece önbellekleme arızalansa bile uygulama foto göstermeye
  /// devam eder (sadece o anlık maliyet avantajı kaybedilir).
  static Future<String> resolvePhotoUrl({
    required String placeId,
    required String photoName,
  }) async {
    // 📍 KOTA HATASI AYRIMI (2026-06-29): `photoName` boş string olabilir —
    // bu, bir önceki çözümlemede kota hatası yüzünden bilerek '' bırakılmış
    // bir fotoğrafı işaret eder (bkz. PlacesService.searchVenues). Boş bir
    // ada `buildPhotoUrl('')` çağırmak anlamsız/geçersiz bir URL üretirdi —
    // bunun yerine direkt boş döndürüyoruz ki çağıran taraf bunu (diğer
    // tüm kota-hatası durumları gibi) "fotoğraf yok" olarak filtrelesin.
    if (photoName.isEmpty) return '';
    if (placeId.isEmpty) {
      return PlaceResult.buildPhotoUrl(photoName);
    }
    // 📍 GECİKME DÜZELTMESİ (2026-06-28): `photoName` zaten önceden
    // çözümlenmiş bir Storage indirme URL'iyse (http/https ile başlıyorsa —
    // örn. arama sırasında bir kere zaten cache'lendiği için), burada
    // HİÇBİR Firestore/Storage işlemi yapmadan direkt onu döndür. Aksi
    // halde bu URL, orijinal Google foto referansından FARKLI bir cache
    // key'i ile aranıyordu (her zaman "miss"), bu da aynı fotoğrafın
    // Google'dan/Storage'dan tekrar indirilip Storage'a TEKRAR yüklenmesine
    // yol açıyordu — "Tarif Al"/"Haritada Aç" butonuna basıldığında bu
    // gereksiz indirme+yükleme zinciri await edildiği için harita açılışı
    // anlamsız yere gecikiyordu.
    if (photoName.startsWith('http://') || photoName.startsWith('https://')) {
      return photoName;
    }
    final photoKey = _photoKey(photoName);
    final docRef = _firestore.collection(_collection).doc(placeId);

    try {
      final snap = await docRef.get();
      final cachedUrls = (snap.data()?['urls'] as Map<String, dynamic>?) ?? {};
      final cached = cachedUrls[photoKey] as String?;
      if (cached != null && cached.isNotEmpty) {
        return cached; // ✅ cache hit — Google'a HİÇ istek yok
      }
    } catch (e) {
      // ignore: avoid_print
      print('[VenuePhotoCacheService] Firestore okuma hatası: $e');
      // Firestore okunamadıysa bile yükleme denemeye devam edebiliriz,
      // ama tutarlılık için direkt Google fallback'ine düşmek daha güvenli.
      return PlaceResult.buildPhotoUrl(photoName);
    }

    // Cache miss — Google'dan SADECE BU SEFERLİK indir, sonra kalıcı olarak
    // Storage'a yükle ki bir DAHA hiç kimse için Google'a gidilmesin.
    try {
      final googleUrl = PlaceResult.buildPhotoUrl(photoName);
      final response =
          await http.get(Uri.parse(googleUrl)).timeout(const Duration(seconds: 15));

      // 📍 KOTA HATASI AYRIMI (2026-06-29): Kullanıcı talebi — Photo Media
      // API'sine GCP Console'dan günlük 300 isteklik manuel bir kota
      // koyulmuş. Bu kota dolduğunda Google 429 (Too Many Requests) veya
      // 403 (RESOURCE_EXHAUSTED) döner. Bu durumda ham Google URL'ini
      // fallback olarak DÖNDÜRMÜYORUZ — çünkü o URL de AYNI kotaya tabi,
      // UI'da tekrar denenip yine başarısız olacak (gereksiz istek +
      // kırık resim). Bunun yerine boş string dönüyoruz: çağıran taraf
      // (`resolvePhotoUrls`) bunu filtreleyip mekanı "fotoğrafsız" (ama
      // listede, gösterilir durumda) bırakıyor — cache'de varsa o zaten
      // bu noktaya gelmeden üstteki cache-hit kontrolünden dönmüştü.
      final isQuotaExceeded = response.statusCode == 429 ||
          response.statusCode == 403 ||
          response.body.contains('RESOURCE_EXHAUSTED');
      if (isQuotaExceeded) {
        // ignore: avoid_print
        print(
          '[VenuePhotoCacheService] ⚠️ Photo Media kota hatası '
          '(${response.statusCode}) — foto gösterilmeyecek, mekan listede '
          'kalacak.',
        );
        return '';
      }

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return googleUrl; // indirilemedi — ham URL ile devam
      }

      final storageRef =
          _storage.ref().child('venue_photos/$placeId/$photoKey.jpg');
      await storageRef.putData(
        response.bodyBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final downloadUrl = await storageRef.getDownloadURL();

      // Firestore'a kalıcı URL'i yaz (merge: true — diğer foto key'lerini
      // ezmesin, aynı dokümana birden fazla foto eklenebiliyor).
      await docRef.set({
        'placeId': placeId,
        'urls': {photoKey: downloadUrl},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return downloadUrl;
    } catch (e) {
      // ignore: avoid_print
      print('[VenuePhotoCacheService] cache yazma hatası: $e');
      return PlaceResult.buildPhotoUrl(photoName); // güvenli fallback
    }
  }

  /// Birden fazla fotoğrafı PARALEL olarak çözümler (örn. bir mekanın
  /// galerideki tüm fotoları). Sıra korunur.
  ///
  /// 📍 KOTA HATASI AYRIMI (2026-06-29): `resolvePhotoUrl` kota hatasında
  /// boş string ('') dönebiliyor — burada bu boş sonuçlar filtrelenip
  /// listeden çıkarılıyor. Yani kota dolduğunda bu metod hata FIRLATMAZ,
  /// sadece o foto için hiçbir URL döndürmez (mekan fotosuz kalır, arama
  /// sonucu/mekanın kendisi etkilenmez).
  static Future<List<String>> resolvePhotoUrls({
    required String placeId,
    required List<String> photoNames,
  }) async {
    if (photoNames.isEmpty) return [];
    final results = await Future.wait(
      photoNames.map(
        (name) => resolvePhotoUrl(placeId: placeId, photoName: name),
      ),
    );
    return results.where((url) => url.isNotEmpty).toList();
  }

  /// 💸 MALİYET DÜŞÜRME (2026-06-28): SADECE Firestore'a bakar, Google'a
  /// HİÇBİR koşulda istek atmaz. Bir mekanın fotoları daha önce (bir yorum
  /// eklenmesi veya detay sayfasının açılması sonucu) önbelleğe alınmışsa,
  /// bu metod onları döner — böylece `PlacesService.fetchPhotoUrls`'taki
  /// Google "Place Details" çağrısı (kendi başına faturalanan, fotoğraf
  /// indirmeden BAĞIMSIZ bir SKU) TAMAMEN atlanabilir. Önbellekte hiçbir
  /// şey yoksa boş liste döner (çağıran taraf bu durumda Google'a gitmeli).
  static Future<List<String>> getCachedPhotoUrls({
    required String placeId,
    int limit = 3,
  }) async {
    if (placeId.isEmpty) return [];
    try {
      final snap =
          await _firestore.collection(_collection).doc(placeId).get();
      final urls = (snap.data()?['urls'] as Map<String, dynamic>?) ?? {};
      return urls.values.whereType<String>().take(limit).toList();
    } catch (e) {
      // ignore: avoid_print
      print('[VenuePhotoCacheService] getCachedPhotoUrls okuma hatası: $e');
      return [];
    }
  }
}
