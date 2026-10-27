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

  const PollOption({
    this.placeId,
    required this.name,
    this.address,
    this.rating,
    this.ratingCount,
    this.mapsUrl,
  });

  factory PollOption.fromPlace(PlaceResult v) => PollOption(
        placeId: v.placeId,
        name: v.name,
        address: v.vicinity,
        rating: v.rating,
        ratingCount: v.userRatingsTotal,
        mapsUrl: v.googleMapsUrl,
      );

  factory PollOption.text(String name) => PollOption(name: name.trim());

  bool get isCustom => placeId == null || placeId!.isEmpty;

  /// Aynı seçeneği iki kez eklememek için anahtar.
  String get key =>
      isCustom ? 'text:${name.toLowerCase()}' : 'place:$placeId';

  Map<String, dynamic> toMap() => {
        if (!isCustom) 'placeId': placeId,
        'name': name,
        if (address != null) 'address': address,
        if (rating != null) 'rating': rating,
        if (ratingCount != null) 'ratingCount': ratingCount,
        if (mapsUrl != null) 'mapsUrl': mapsUrl,
      };
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
}

/// Seçilen seçeneklerle oylama oluşturur ve paylaşım penceresini açar.
/// Başarılıysa true döner.
Future<bool> createAndSharePoll(
  BuildContext context,
  WidgetRef ref,
  List<PollOption> options,
) async {
  final user = ref.read(currentUserProvider);
  if (user == null || options.length < kPollMinOptions) return false;
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  final messenger = ScaffoldMessenger.of(context);
  final tr = context.locale.languageCode == 'tr';

  try {
    final ownerName = user.isGuest
        ? ''
        : titleCaseName(user.name.split(' ').first, turkish: tr);
    final id = await PollService.create(
      ownerUid: user.uid,
      ownerName: ownerName,
      options: options,
    );
    AnalyticsService.pollCreated(options.length).ignore();
    final link = WebLinks.poll(id);
    final list = [
      for (var i = 0; i < options.length; i++) '${i + 1}. ${options[i].name}',
    ].join('\n');
    await SharePlus.instance.share(ShareParams(
      text: 'poll.share_text'.tr(namedArgs: {
        'list': list,
        'link': link.toString(),
      }),
      sharePositionOrigin: origin,
    ));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('poll.create_failed'.tr())));
    return false;
  }
}
