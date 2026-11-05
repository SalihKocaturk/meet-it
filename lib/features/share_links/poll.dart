import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/services/analytics_service.dart';
import 'package:meetit/core/utils/text_utils.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/match/models/place_result.dart';
import 'package:meetit/features/share_links/web_links.dart';
import 'package:share_plus/share_plus.dart';

// ── Grup oylaması ────────────────────────────────────────────────────────────
//
// "Nerede buluşsak?" kararı genelde WhatsApp grubunda uzar. Kullanıcı
// oylamayı PollComposerPage'de hazırlar (bulunan / kaydedilen / gidilen
// mekanlar, Google araması veya serbest metin; 2-6 seçenek); link gruba
// atılır, herkes web'den (oylama/) uygulama indirmeden oy verir.
// Firestore: polls/{id} — votes: {voterUid: seçenekIndex}.
// Oylamalar 7 gün sonra Firestore TTL politikasıyla (alan: expireAt)
// otomatik silinir — gizlilik politikası bu süreyi taahhüt ediyor.
//
// Oluşturan kişi uygulamadan "Oylamalarım" ekranıyla bu oylamaları canlı
// izleyebilir, paylaşabilir, kapatabilir ve silebilir (bkz.
// poll_management_page.dart / poll_detail_page.dart).

const _kPollLifetime = Duration(days: 7);

/// Oylamada en az / en fazla seçenek (Firestore kuralı da aynı sınırı uygular).
const kPollMinOptions = 2;
const kPollMaxOptions = 6;

/// Oylama seçeneği: Google mekanı ya da elle yazılmış serbest metin
/// ("Bende film gecesi" gibi — adres/harita linki yok).
class PollOption {
  final String? placeId;
  final String name;
  final String? address;
  final double? rating;
  final int? ratingCount;
  final String? mapsUrl;

  /// Mekan koordinatları — kazanan mekanı haritada açmak ve buluşma
  /// geçmişine kaydetmek için. Serbest metin seçeneklerinde null olabilir;
  /// bu alanlar eklenmeden önce oluşturulmuş eski oylamalarda da null gelir.
  final double? lat;
  final double? lng;

  /// Mekanın önbelleklenmiş kapak fotoğrafı (varsa).
  final String? photoUrl;

  const PollOption({
    this.placeId,
    required this.name,
    this.address,
    this.rating,
    this.ratingCount,
    this.mapsUrl,
    this.lat,
    this.lng,
    this.photoUrl,
  });

  factory PollOption.fromPlace(PlaceResult v) {
    String? photo;
    for (final ref in v.photoReferences) {
      if (ref.startsWith('https://')) {
        photo = ref;
        break;
      }
    }
    return PollOption(
      placeId: v.placeId,
      name: v.name,
      address: v.vicinity,
      rating: v.rating,
      ratingCount: v.userRatingsTotal,
      mapsUrl: v.googleMapsUrl,
      lat: v.lat,
      lng: v.lng,
      photoUrl: photo,
    );
  }

  factory PollOption.text(String name) => PollOption(name: name.trim());

  factory PollOption.fromMap(Map<String, dynamic> map) => PollOption(
    placeId: map['placeId'] as String?,
    name: map['name'] as String? ?? '',
    address: map['address'] as String?,
    rating: (map['rating'] as num?)?.toDouble(),
    ratingCount: (map['ratingCount'] as num?)?.toInt(),
    mapsUrl: map['mapsUrl'] as String?,
    lat: (map['lat'] as num?)?.toDouble(),
    lng: (map['lng'] as num?)?.toDouble(),
    photoUrl: map['photoUrl'] as String?,
  );

  bool get isCustom => placeId == null || placeId!.isEmpty;

  /// Haritada açmak için kullanılabilir mi?
  bool get hasCoords => lat != null && lng != null;

  /// Aynı seçeneği iki kez eklememek için anahtar.
  String get key => isCustom ? 'text:${name.toLowerCase()}' : 'place:$placeId';

  Map<String, dynamic> toMap() => {
    if (!isCustom) 'placeId': placeId,
    'name': name,
    if (address != null) 'address': address,
    if (rating != null) 'rating': rating,
    if (ratingCount != null) 'ratingCount': ratingCount,
    if (mapsUrl != null) 'mapsUrl': mapsUrl,
    if (lat != null) 'lat': lat,
    if (lng != null) 'lng': lng,
    if (photoUrl != null) 'photoUrl': photoUrl,
  };
}

/// Oylamanın yaşam döngüsü.
enum PollStatus { live, closed, expired }

/// Firestore'daki `polls/{id}` dokümanının uygulama modeli.
class Poll {
  final String id;
  final String ownerUid;
  final String ownerName;
  final List<PollOption> options;
  final Map<String, int> votes;
  final Map<String, String> voterNames;
  final DateTime? createdAt;
  final DateTime? expireAt;
  final bool closed;

  const Poll({
    required this.id,
    required this.ownerUid,
    required this.ownerName,
    required this.options,
    required this.votes,
    required this.voterNames,
    this.createdAt,
    this.expireAt,
    this.closed = false,
  });

  factory Poll.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? const <String, dynamic>{};

    final options = <PollOption>[];
    final rawOptions = map['options'];
    if (rawOptions is List) {
      for (final item in rawOptions) {
        if (item is Map) {
          options.add(PollOption.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    final votes = <String, int>{};
    final rawVotes = map['votes'];
    if (rawVotes is Map) {
      rawVotes.forEach((key, value) {
        if (value is num) votes[key.toString()] = value.toInt();
      });
    }

    final names = <String, String>{};
    final rawNames = map['voterNames'];
    if (rawNames is Map) {
      rawNames.forEach((key, value) {
        if (value is String) names[key.toString()] = value;
      });
    }

    return Poll(
      id: doc.id,
      ownerUid: map['ownerUid'] as String? ?? '',
      ownerName: map['ownerName'] as String? ?? '',
      options: options,
      votes: votes,
      voterNames: names,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      expireAt: (map['expireAt'] as Timestamp?)?.toDate(),
      closed: map['closed'] == true,
    );
  }

  bool get isExpired => expireAt != null && expireAt!.isBefore(DateTime.now());

  PollStatus get status {
    if (closed) return PollStatus.closed;
    if (isExpired) return PollStatus.expired;
    return PollStatus.live;
  }

  bool get isActive => status == PollStatus.live;

  bool isOwner(String? uid) => uid != null && uid == ownerUid;

  int get totalVotes => votes.length;

  /// Seçenek başına oy sayısı.
  List<int> get counts {
    final result = List<int>.filled(options.length, 0);
    for (final index in votes.values) {
      if (index >= 0 && index < result.length) result[index]++;
    }
    return result;
  }

  /// En çok oy alan seçenek (oy yoksa null; eşitlikte ilk seçenek).
  int? get leadingIndex {
    if (options.isEmpty) return null;
    final c = counts;
    var best = 0;
    for (var i = 1; i < c.length; i++) {
      if (c[i] > c[best]) best = i;
    }
    return c[best] == 0 ? null : best;
  }

  PollOption? get leadingOption {
    final index = leadingIndex;
    return index == null ? null : options[index];
  }

  /// Liste kartlarında gösterilen kısa başlık: ilk iki seçenek.
  String get title => options.take(2).map((o) => o.name).join(' · ');

  /// Belirli bir seçeneğe oy verenlerin adları.
  List<String> votersFor(int optionIndex, {String anonymousLabel = ''}) {
    final result = <String>[];
    votes.forEach((uid, index) {
      if (index != optionIndex) return;
      final name = voterNames[uid] ?? '';
      result.add(name.trim().isEmpty ? anonymousLabel : name.trim());
    });
    return result;
  }
}

abstract final class PollService {
  static final _col = FirebaseFirestore.instance.collection('polls');

  static Future<String> create({
    required String ownerUid,
    required String ownerName,
    required List<PollOption> options,
  }) async {
    final ref = await _col.add({
      'ownerUid': ownerUid,
      'ownerName': ownerName,
      'createdAt': FieldValue.serverTimestamp(),
      'expireAt': Timestamp.fromDate(DateTime.now().add(_kPollLifetime)),
      'options': [for (final o in options) o.toMap()],
      'votes': <String, int>{},
      'voterNames': <String, String>{},
    });
    return ref.id;
  }

  /// Kullanıcının oluşturduğu oylamalar — en yeniden eskiye.
  ///
  /// Sıralama BİLEREK istemci tarafında: `ownerUid` eşitliği + `createdAt`
  /// sıralaması birleşik bir Firestore index'i gerektiriyordu ve index
  /// deploy edilmediğinde sorgu `FAILED_PRECONDITION ("Oylamalar
  /// yüklenemedi")` ile düşüyordu. Tek alanlı eşitlik sorgusu otomatik
  /// index'lerle çalışır; 7 günlük oylamalar az sayıda olduğu için yerel
  /// sıralama maliyetsiz.
  static Stream<List<Poll>> watchMine(String uid) {
    return _col.where('ownerUid', isEqualTo: uid).snapshots().map((snap) {
      final polls = <Poll>[];
      for (final doc in snap.docs) {
        // Tek bir bozuk doküman tüm listeyi düşürmesin; sebebini logla.
        try {
          polls.add(Poll.fromDoc(doc));
        } catch (e, st) {
          debugPrint('[polls] watchMine parse failed for ${doc.id}: $e\n$st');
        }
      }
      polls.sort((a, b) {
        final aDate = a.createdAt;
        final bDate = b.createdAt;
        if (aDate == null && bDate == null) return a.id.compareTo(b.id);
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
      return polls;
    });
  }

  /// Tek oylamanın canlı akışı; doküman silinmişse null döner.
  static Stream<Poll?> watch(String id) {
    return _col
        .doc(id)
        .snapshots()
        .map((doc) => doc.exists ? Poll.fromDoc(doc) : null);
  }

  static Future<void> close(String id) {
    return _col.doc(id).update({
      'closed': true,
      'closedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> delete(String id) => _col.doc(id).delete();

  /// Oylama linkini paylaşım penceresinde açar.
  static Future<void> share(
    BuildContext context, {
    required String id,
    required List<PollOption> options,
  }) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final link = WebLinks.poll(id);
    final list = [
      for (var i = 0; i < options.length; i++) '${i + 1}. ${options[i].name}',
    ].join('\n');
    await SharePlus.instance.share(
      ShareParams(
        text: 'poll.share_text'.tr(
          namedArgs: {'list': list, 'link': link.toString()},
        ),
        sharePositionOrigin: origin,
      ),
    );
  }
}

/// Seçilen seçeneklerle oylama oluşturur ve paylaşım penceresini açar.
/// Başarılıysa oylama ID'sini, oluşturulamazsa null döner.
Future<String?> createAndSharePoll(
  BuildContext context,
  WidgetRef ref,
  List<PollOption> options,
) async {
  final user = ref.read(currentUserProvider);
  if (user == null || options.length < kPollMinOptions) return null;
  final messenger = ScaffoldMessenger.of(context);
  final tr = context.locale.languageCode == 'tr';

  final String id;
  try {
    final ownerName = user.isGuest
        ? ''
        : titleCaseName(user.name.split(' ').first, turkish: tr);
    id = await PollService.create(
      ownerUid: user.uid,
      ownerName: ownerName,
      options: options,
    );
    AnalyticsService.pollCreated(options.length).ignore();
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('poll.create_failed'.tr())));
    return null;
  }

  // Oylama oluştu; paylaşım penceresi açılamazsa bile ID'yi döndür ki
  // kullanıcı "Oylamalarım" ekranından linki yeniden paylaşabilsin.
  if (!context.mounted) return id;
  try {
    await PollService.share(context, id: id, options: options);
  } catch (_) {
    // Paylaşım iptal edildi / paylaşım sayfası açılamadı — yönetim ekranı
    // linki kopyalama seçeneği sunuyor.
  }
  return id;
}
