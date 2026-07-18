import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/widgets/circular_avatar.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/history/meeting_history_detail_page.dart';
import 'package:meetit/features/history/models/meeting_record.dart';
import 'package:meetit/features/history/providers/meeting_history_provider.dart';
import 'package:iconsax/iconsax.dart';

class MeetingHistoryPage extends ConsumerWidget {
  const MeetingHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(meetingHistoryProvider);
    final myUid = ref.watch(authProvider).user?.uid;

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: context.colors.scaffold,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left_2,
              size: 18, color: context.colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'history.title'.tr(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Iconsax.info_circle,
                    size: 48, color: context.colors.hint),
                const SizedBox(height: 12),
                Text(
                  'common.error'.tr(),
                  style: TextStyle(color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        data: (records) {
          if (records.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _HistoryCard(
                record: records[index],
                myUid: myUid,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MeetingHistoryDetailPage(
                      record: records[index],
                      myUid: myUid,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Boş durum ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.clock,
              size: 72,
              color: context.colors.hint.withOpacity(0.4),
            ),
            const SizedBox(height: 20),
            Text(
              'history.empty_title'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'history.empty_desc'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Geçmiş kartı ───────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final MeetingRecord record;
  final String? myUid;
  final VoidCallback onTap;

  const _HistoryCard({
    required this.record,
    required this.myUid,
    required this.onTap,
  });

  String get _myName {
    if (record.initiatorUid == myUid) return record.initiatorName;
    return record.friendName ?? '?';
  }

  String? get _myPhoto {
    if (record.initiatorUid == myUid) return record.initiatorPhotoUrl;
    return record.friendPhotoUrl;
  }

  String? get _partnerName {
    if (record.isSolo) return null;
    if (record.initiatorUid == myUid) return record.friendName;
    return record.initiatorName;
  }

  String? get _partnerPhoto {
    if (record.isSolo) return null;
    if (record.initiatorUid == myUid) return record.friendPhotoUrl;
    return record.initiatorPhotoUrl;
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('d MMM y', context.locale.languageCode)
        .format(record.createdAt);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Üst kısım: avatarlar + isim/tarih + ok ─────────────────
            Row(
              children: [
                // Çakışan avatarlar
                _AvatarStack(
                  myName: _myName,
                  myPhoto: _myPhoto,
                  partnerName: _partnerName,
                  partnerPhoto: _partnerPhoto,
                  cardColor: context.colors.card,
                ),
                const SizedBox(width: 12),

                // İsim + tarih
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.isSolo
                            ? 'history.solo'.tr()
                            : (_partnerName ?? '?'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Mekan sayısı + ok
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Iconsax.arrow_right_3,
                      size: 13,
                      color: context.colors.hint,
                    ),
                    if (record.venues.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${record.venues.length} mekan',
                        style: TextStyle(
                          fontSize: 10,
                          color: context.colors.hint,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            // ── Aktivite chip'leri ─────────────────────────────────────
            if (record.activities.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children:
                    record.activities.map((a) => _Chip(label: a)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Çakışan avatar çifti ────────────────────────────────────────────────────

class _AvatarStack extends StatelessWidget {
  final String myName;
  final String? myPhoto;
  final String? partnerName;
  final String? partnerPhoto;
  final Color cardColor;

  const _AvatarStack({
    required this.myName,
    required this.myPhoto,
    required this.partnerName,
    required this.partnerPhoto,
    required this.cardColor,
  });

  // Avatar yarıçapı (border halkası dahil için +2)
  static const double _r = 18.0;
  static const double _borderExtra = 2.0;
  static const double _outerR = _r + _borderExtra;     // 20
  static const double _outerD = _outerR * 2;            // 40
  static const double _offset = 22.0; // iki avatar arasındaki yatay kaydırma

  @override
  Widget build(BuildContext context) {
    if (partnerName == null) {
      // Tek başına arama — yalnızca kendi avatarı
      return _ring(myName, photoUrl: myPhoto, color: cardColor);
    }

    // İki katılımcı: sağdaki (arkadaş) arkada, soldaki (ben) önde
    return SizedBox(
      width: _outerD + _offset,   // 40 + 22 = 62
      height: _outerD,             // 40
      child: Stack(
        children: [
          // Arkadaş — sağda, arkada
          Positioned(
            right: 0,
            top: 0,
            child: _ring(partnerName!, photoUrl: partnerPhoto, color: cardColor),
          ),
          // Ben — solda, önde
          Positioned(
            left: 0,
            top: 0,
            child: _ring(myName, photoUrl: myPhoto, color: cardColor),
          ),
        ],
      ),
    );
  }

  Widget _ring(String name, {String? photoUrl, required Color color}) {
    return CircleAvatar(
      radius: _outerR,
      backgroundColor: color,
      child: CircularAvatar(
        name: name,
        photoUrl: photoUrl,
        radius: _r,
      ),
    );
  }
}

// ── Aktivite chip'i ─────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.colors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: context.colors.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
