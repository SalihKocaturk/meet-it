import 'package:meetit/features/reviews/models/venue_review_model.dart';

/// Statik "bot" yorumları — gerçek, tanınan mekanlar için.
///
/// Uygulama henüz az kullanıcılı olduğundan Ana Sayfa'daki mekan carousel'i
/// boş/tenha görünebiliyor. Bu liste, gerçek Firestore yorumlarıyla birlikte
/// `topReviewsProvider`'a eklenerek alt kısmın her zaman dolu görünmesini
/// sağlıyor.
///
/// Mekanlar gerçek, bilinen, İstanbul ve Kocaeli'de yer alan mekanlar
/// (Pierre Loti Kahvesi, Çiya Sofrası, Karaköy Lokantası, Mikla, Kahve
/// Dünyası, Seka Park) — adres/koordinatlar yaklaşıktır.
///
/// NOT: `venuePhotoUrl` kasıtlı olarak boş bırakıldı. Bu oturumda canlı web
/// erişimi çalışmadığından mekanların gerçek fotoğrafı çekilemedi; rastgele
/// stok görseller kullanmak yapay/sahte bir görünüme yol açıyordu, bu yüzden
/// fotoğrafsız bırakılması tercih edildi (UI zaten venuePhotoUrl null
/// olduğunda otomatik olarak şık bir konum ikonu placeholder'ı gösteriyor).
/// Gerçek Google Places fotoğrafı edinilebildiğinde bu alana eklenebilir.
final List<VenueReviewModel> botReviews = [
  VenueReviewModel(
    id: 'bot_1',
    authorUid: 'bot_uid_1',
    authorName: 'Elif K.',
    placeId: 'bot_place_pierre_loti',
    venueName: 'Pierre Loti Kahvesi',
    venueAddress: 'Eyüpsultan, İstanbul',
    lat: 41.0556,
    lng: 28.9344,
    rating: 5,
    comment: 'Haliç manzarası eşliğinde çay içmek için İstanbul\'un en güzel yeri. Teleferikle çıkmak da ayrı bir keyif.',
    createdAt: DateTime(2026, 5, 12),
  ),
  VenueReviewModel(
    id: 'bot_2',
    authorUid: 'bot_uid_2',
    authorName: 'Mert A.',
    placeId: 'bot_place_pierre_loti',
    venueName: 'Pierre Loti Kahvesi',
    venueAddress: 'Eyüpsultan, İstanbul',
    lat: 41.0556,
    lng: 28.9344,
    rating: 4,
    comment: 'Gün batımında gelmenizi öneririm, manzara muhteşem oluyor. Hafta sonu biraz kalabalık olabiliyor.',
    createdAt: DateTime(2026, 5, 18),
  ),
  VenueReviewModel(
    id: 'bot_3',
    authorUid: 'bot_uid_3',
    authorName: 'Zeynep Y.',
    placeId: 'bot_place_ciya_sofrasi',
    venueName: 'Çiya Sofrası',
    venueAddress: 'Caferağa, Kadıköy, İstanbul',
    lat: 40.9833,
    lng: 29.0264,
    rating: 5,
    comment: 'Anadolu mutfağının en otantik halini burada buluyorsunuz. Künefe ve etli ekmek harika.',
    createdAt: DateTime(2026, 5, 22),
  ),
  VenueReviewModel(
    id: 'bot_4',
    authorUid: 'bot_uid_4',
    authorName: 'Burak D.',
    placeId: 'bot_place_ciya_sofrasi',
    venueName: 'Çiya Sofrası',
    venueAddress: 'Caferağa, Kadıköy, İstanbul',
    lat: 40.9833,
    lng: 29.0264,
    rating: 5,
    comment: 'Arkadaşlarla buluşup farklı bölgesel yemekleri paylaşa paylaşa yemek için ideal.',
    createdAt: DateTime(2026, 5, 28),
  ),
  VenueReviewModel(
    id: 'bot_5',
    authorUid: 'bot_uid_5',
    authorName: 'Selin T.',
    placeId: 'bot_place_karakoy_lokantasi',
    venueName: 'Karaköy Lokantası',
    venueAddress: 'Kemankeş, Karaköy, İstanbul',
    lat: 41.0244,
    lng: 28.9764,
    rating: 4,
    comment: 'Şık bir mekan, mezeler ve balık çok taze. Karaköy\'de buluşmak için güzel bir seçenek.',
    createdAt: DateTime(2026, 6, 1),
  ),
  VenueReviewModel(
    id: 'bot_6',
    authorUid: 'bot_uid_6',
    authorName: 'Can Ö.',
    placeId: 'bot_place_mikla',
    venueName: 'Mikla',
    venueAddress: 'Meşrutiyet Cd., Beyoğlu, İstanbul',
    lat: 41.0345,
    lng: 28.9770,
    rating: 5,
    comment: 'Çatı katından şehrin 360 derece manzarası eşliğinde unutulmaz bir akşam yemeği.',
    createdAt: DateTime(2026, 6, 4),
  ),
  VenueReviewModel(
    id: 'bot_7',
    authorUid: 'bot_uid_7',
    authorName: 'Aslı M.',
    placeId: 'bot_place_kahve_dunyasi_bagdat',
    venueName: 'Kahve Dünyası (Bağdat Caddesi)',
    venueAddress: 'Caddebostan, Kadıköy, İstanbul',
    lat: 40.9650,
    lng: 29.0710,
    rating: 4,
    comment: 'Bağdat Caddesi\'nde yürüyüş sonrası oturup kahve içmek için klasik bir durak. Türk kahvesi gerçekten lezzetli.',
    createdAt: DateTime(2026, 6, 8),
  ),
  VenueReviewModel(
    id: 'bot_8',
    authorUid: 'bot_uid_8',
    authorName: 'Onur Ş.',
    placeId: 'bot_place_seka_park',
    venueName: 'Seka Park',
    venueAddress: 'İzmit, Kocaeli',
    lat: 40.7800,
    lng: 29.9200,
    rating: 5,
    comment: 'Körfez manzarasında geniş yeşil alan, arkadaşlarla piknik ve yürüyüş için mükemmel bir buluşma noktası.',
    createdAt: DateTime(2026, 6, 11),
  ),
  VenueReviewModel(
    id: 'bot_9',
    authorUid: 'bot_uid_9',
    authorName: 'Defne C.',
    placeId: 'bot_place_seka_park',
    venueName: 'Seka Park',
    venueAddress: 'İzmit, Kocaeli',
    lat: 40.7800,
    lng: 29.9200,
    rating: 4,
    comment: 'Akşamüstü deniz kenarında yürüyüş yapıp kafelerinde oturmak için çok güzel bir alan.',
    createdAt: DateTime(2026, 6, 14),
  ),
  VenueReviewModel(
    id: 'bot_10',
    authorUid: 'bot_uid_10',
    authorName: 'Kerem B.',
    placeId: 'bot_place_kahve_dunyasi_izmit',
    venueName: 'Kahve Dünyası (İzmit)',
    venueAddress: 'İzmit, Kocaeli',
    lat: 40.7656,
    lng: 29.9408,
    rating: 4,
    comment: 'İzmit\'te arkadaşlarla buluşmak için sakin, rahat bir kahve mekanı.',
    createdAt: DateTime(2026, 6, 17),
  ),
];
