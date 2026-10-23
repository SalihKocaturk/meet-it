import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/services/notification_service.dart';
import 'package:meetit/features/auth/models/user_model.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/friends/models/friendship_model.dart';
import 'package:meetit/features/friends/providers/friends_provider.dart';

/// Davet linkiyle gelen kullanıcıyı davet edenle otomatik arkadaş yapar.
///
/// Linke tıklamak daveti kabul etmek sayılır (ürün kararı): istek/onay
/// adımı yok, arkadaşlık doğrudan `accepted` yazılır. Firestore kuralları
/// buna izin veriyor (oluşturan `fromUid` kendisi olmalı; mevcut kayıtta
/// taraflardan biri güncelleyebilir; engelli çiftlerde reddedilir).
abstract final class InviteService {
  static final _db = FirebaseFirestore.instance;

  /// Daveti uygular. Başarılıysa davet edenin profilini döner; kendi linki,
  /// silinmiş kullanıcı veya engelli çift gibi durumlarda null.
  static Future<UserModel?> accept(WidgetRef ref, String inviterUid) async {
    final me = ref.read(authProvider).user;
    if (me == null || inviterUid == me.uid) return null;
    if (ref.read(friendsProvider.notifier).isBlocked(inviterUid)) return null;

    try {
      final inviterDoc = await _db.collection('users').doc(inviterUid).get();
      final data = inviterDoc.data();
      if (data == null) return null;
      final inviter = UserModel.fromMap(data);

      final docId = FriendshipModel.docId(me.uid, inviterUid);
      final docRef = _db.collection('friendships').doc(docId);
      var created = false;

      await _db.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (snap.exists) {
          final existing = FriendshipModel.fromMap(docId, snap.data()!);
          if (existing.status == FriendshipStatus.accepted) return;
          tx.update(docRef, {'status': FriendshipStatus.accepted.name});
        } else {
          tx.set(
            docRef,
            FriendshipModel(
              id: docId,
              fromUid: me.uid,
              toUid: inviterUid,
              status: FriendshipStatus.accepted,
              createdAt: DateTime.now(),
            ).toMap(),
          );
        }
        created = true;
      });

      if (created) {
        // Davet edene haber ver; test zaten çözülmüşse uyum da bildirilir.
        final myProfile = me.personalityProfile;
        final theirProfile = inviter.personalityProfile;
        NotificationService.sendNotification(
          toUid: inviterUid,
          type: 'invite_joined',
          fromName: me.name,
          fromUid: me.uid,
          extra: {
            if (myProfile != null && theirProfile != null)
              'compat': myProfile.compatibilityWith(theirProfile),
          },
        ).ignore();
      }
      return inviter;
    } catch (e) {
      debugPrint('[InviteService] accept hatası: $e');
      return null;
    }
  }

  /// Davetli kişilik testini bitirdiğinde davet edene uyumu bildirir.
  static Future<void> notifyCompat({
    required UserModel me,
    required String inviterUid,
    required int compat,
  }) =>
      NotificationService.sendNotification(
        toUid: inviterUid,
        type: 'invite_joined',
        fromName: me.name,
        fromUid: me.uid,
        extra: {'compat': compat},
      );
}
