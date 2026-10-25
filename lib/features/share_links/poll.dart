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
// "Nerede buluşsak?" kararı genelde WhatsApp grubunda uzar. Bulunan
// mekanlardan ilk 3-4'ü bir oylamaya dönüşür; link gruba atılır, herkes
// web'den (oylama/) uygulama indirmeden oy verir, sonuçlar canlı güncellenir.
// Firestore: polls/{id} — votes: {voterUid: seçenekIndex}.

abstract final class PollService {
  static final _col = FirebaseFirestore.instance.collection('polls');

  static Future<String> create({
    required String ownerUid,
    required String ownerName,
    required List<PlaceResult> venues,
  }) async {
    final ref = await _col.add({
      'ownerUid': ownerUid,
      'ownerName': ownerName,
      'createdAt': FieldValue.serverTimestamp(),
      'options': [
        for (final v in venues)
          {
            'placeId': v.placeId,
            'name': v.name,
            if (v.vicinity != null) 'address': v.vicinity,
            if (v.rating != null) 'rating': v.rating,
            if (v.userRatingsTotal != null) 'ratingCount': v.userRatingsTotal,
            'mapsUrl': v.googleMapsUrl,
          },
      ],
      'votes': <String, int>{},
      'voterNames': <String, String>{},
    });
    return ref.id;
  }
}

/// Mekanlardan oylama oluşturup paylaşma sayfasını açar.
Future<void> createAndSharePoll(
  BuildContext context,
  WidgetRef ref,
  List<PlaceResult> venues,
) async {
  final user = ref.read(currentUserProvider);
  if (user == null || venues.isEmpty) return;
  final options = venues.take(4).toList();
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
      venues: options,
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
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('poll.create_failed'.tr())));
  }
}
