import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/widgets/circular_avatar.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/history/meeting_history_detail_page.dart';
import 'package:meetit/features/history/models/meeting_record.dart';
import 'package:meetit/features/history/providers/meeting_history_provider.dart';

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
          icon: Icon(
            Iconsax.arrow_left_2,
            size: 18,
            color: context.colors.textPrimary,
          ),
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
                Icon(Iconsax.info_circle, size: 48, color: context.colors.hint),
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
            return _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: records.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
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
    final dateStr = DateFormat(
      'd MMM y',
      context.locale.languageCode,
    ).format(record.createdAt);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Üst kısım: foto + kişi bilgisi + tarih ─────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                children: [
                  // Avatar / ikon
                  if (record.isSolo)
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.colors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Iconsax.user_rounded,
                        color: context.colors.primary,
                        size: 24,
                      ),
                    )
                  else if (_partnerPhoto != null)
                    CircleAvatar(
                      radius: 22,
                      backgroundImage: NetworkImage(_partnerPhoto!),
                    )
                  else
                    CircularAvatar(name: _partnerName ?? '?', radius: 22),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.isSolo
                              ? 'history.solo'.tr()
                              : (_partnerName ?? '?'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Ok
                  Icon(
                    Iconsax.arrow_right_3,
                    size: 13,
                    color: context.colors.hint,
                  ),
                ],
              ),
            ),

            // ── Aktivite chip'leri ─────────────────────────────────────
            if (record.activities.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: record.activities
                      .map((a) => _Chip(label: a))
                      .toList(),
                ),
              ),

            // ── Mekan sayısı chip ──────────────────────────────────────
            if (record.venues.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Row(
                  children: [
                    Icon(
                      Iconsax.location,
                      size: 13,
                      color: context.colors.hint,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'history.venue_count'.tr(
                        namedArgs: {'count': record.venues.length.toString()},
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.hint,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               