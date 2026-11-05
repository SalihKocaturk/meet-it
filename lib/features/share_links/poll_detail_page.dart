import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/constants/emerald_palette.dart';
import 'package:meetit/core/widgets/app_alert.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/history/meeting_history_detail_page.dart';
import 'package:meetit/features/history/models/meeting_record.dart';
import 'package:meetit/features/history/services/meeting_history_service.dart';
import 'package:meetit/features/share_links/poll.dart';
import 'package:meetit/features/share_links/providers/polls_provider.dart';
import 'package:meetit/features/share_links/web_links.dart';
import 'package:meetit/features/share_links/widgets/poll_status_chip.dart';
import 'package:url_launcher/url_launcher.dart';

enum _PollAction { close, delete }

/// Sahibinin oylamayı canlı izlediği, paylaştığı, kapattığı ve sildiği
/// yönetim detay ekranı.
class PollDetailPage extends ConsumerStatefulWidget {
  final String pollId;

  const PollDetailPage({super.key, required this.pollId});

  @override
  ConsumerState<PollDetailPage> createState() => _PollDetailPageState();
}

class _PollDetailPageState extends ConsumerState<PollDetailPage> {
  final Set<int> _expanded = <int>{};
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pollProvider(widget.pollId));
    final poll = async.valueOrNull;
    final uid = ref.watch(currentUserProvider)?.uid;

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: context.colors.scaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.colors.textPrimary),
        title: Text(
          'poll.detail_title'.tr(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        actions: [
          if (poll != null && poll.isOwner(uid))
            PopupMenuButton<_PollAction>(
              icon: Icon(Iconsax.more, color: context.colors.textPrimary),
              color: context.colors.card,
              onSelected: (action) {
                switch (action) {
                  case _PollAction.close:
                    _confirmClose(poll);
                  case _PollAction.delete:
                    _confirmDelete(poll);
                }
              },
              itemBuilder: (_) => [
                if (poll.isActive)
                  PopupMenuItem<_PollAction>(
                    value: _PollAction.close,
                    child: Text('poll.close_poll'.tr()),
                  ),
                PopupMenuItem<_PollAction>(
                  value: _PollAction.delete,
                  child: Text(
                    'poll.delete_poll'.tr(),
                    style: TextStyle(color: context.colors.error),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: async.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.accentStrong),
        ),
        error: (error, stack) {
          debugPrint(
            '[polls] pollProvider(${widget.pollId}) error: $error\n$stack',
          );
          return _MessageState(
            icon: Iconsax.warning_2,
            text: 'poll.load_failed'.tr(),
            actionLabel: 'common.retry'.tr(),
            onAction: () => ref.invalidate(pollProvider(widget.pollId)),
          );
        },
        data: (poll) {
          if (poll == null) {
            return _MessageState(
              icon: Iconsax.search_status,
              text: 'poll.not_found'.tr(),
            );
          }
          return _buildBody(poll);
        },
      ),
      bottomNavigationBar: poll == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : () => _share(poll),
                          icon: const Icon(
                            Iconsax.share,
                            size: 18,
                            color: Colors.white,
                          ),
                          label: Text(
                            'poll.share_again'.tr(),
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Emerald.base,
                            disabledBackgroundColor: Emerald.base.withValues(
                              alpha: 0.35,
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => _copyLink(poll),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          side: BorderSide(color: context.colors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Icon(
                          Iconsax.copy,
                          size: 19,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBody(Poll poll) {
    final counts = poll.counts;
    final total = poll.totalVotes;
    final leading = poll.leadingIndex;

    return RefreshIndicator(
      color: context.accentStrong,
      backgroundColor: context.colors.card,
      onRefresh: () async {
        ref.invalidate(pollProvider(widget.pollId));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          // ── Başlık / durum ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: context.colors.border.withValues(alpha: 0.7),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PollStatusChip(status: poll.status),
                    const Spacer(),
                    Text(
                      _statusDetail(poll),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (poll.ownerName.isNotEmpty) ...[
                  Text(
                    'poll.owner_asking'.tr(namedArgs: {'name': poll.ownerName}),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  poll.title.isEmpty ? 'poll.untitled'.tr() : poll.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                    color: context.colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Özet sayılar ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: context.colors.border.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              children: [
                _Stat(value: '$total', label: 'poll.total_votes'.tr()),
                _Divider(color: context.colors.border),
                _Stat(
                  value: '${poll.votes.length}',
                  label: 'poll.participants'.tr(),
                ),
                _Divider(color: context.colors.border),
                _Stat(
                  value: '${poll.options.length}',
                  label: 'poll.options_label'.tr(),
                ),
              ],
            ),
          ),

          // ── Kazanan ───────────────────────────────────────────────────
          if (!poll.isActive && leading != null) ...[
            const SizedBox(height: 16),
            _WinnerCard(
              option: poll.options[leading],
              count: counts[leading],
              total: total,
              onMaps: () => _openMaps(poll.options[leading]),
              onSave: () => _saveWinner(poll.options[leading]),
            ),
          ],

          const SizedBox(height: 20),
          Text(
            'poll.options_title'.tr(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'poll.options_hint'.tr(),
            style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < poll.options.length; i++)
            _OptionResultCard(
              index: i,
              option: poll.options[i],
              count: counts[i],
              total: total,
              highlight: leading == i,
              voters: poll.votersFor(
                i,
                anonymousLabel: 'poll.anonymous_voter'.tr(),
              ),
              expanded: _expanded.contains(i),
              onToggle: () => setState(() {
                if (!_expanded.remove(i)) _expanded.add(i);
              }),
            ),
        ],
      ),
    );
  }

  String _statusDetail(Poll poll) {
    switch (poll.status) {
      case PollStatus.closed:
        return 'poll.status_closed_desc'.tr();
      case PollStatus.expired:
        return 'poll.status_expired_desc'.tr();
      case PollStatus.live:
        final expireAt = poll.expireAt;
        if (expireAt == null) return '';
        final left = expireAt.difference(DateTime.now());
        if (left.isNegative) return 'poll.status_expired_desc'.tr();
        if (left.inDays >= 1) {
          return 'poll.days_left'.tr(namedArgs: {'count': '${left.inDays}'});
        }
        if (left.inHours >= 1) {
          return 'poll.hours_left'.tr(namedArgs: {'count': '${left.inHours}'});
        }
        return 'poll.minutes_left'.tr(
          namedArgs: {'count': '${left.inMinutes.clamp(1, 59)}'},
        );
    }
  }

  Future<void> _share(Poll poll) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await PollService.share(context, id: poll.id, options: poll.options);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('poll.action_failed'.tr())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyLink(Poll poll) async {
    await Clipboard.setData(
      ClipboardData(text: WebLinks.poll(poll.id).toString()),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('poll.copied'.tr())));
  }

  void _confirmClose(Poll poll) {
    showAppAlert(
      context: context,
      type: AppAlertType.confirm,
      title: 'poll.close_poll'.tr(),
      text: 'poll.close_confirm'.tr(),
      confirmBtnText: 'poll.close_btn'.tr(),
      cancelBtnText: 'common.cancel'.tr(),
      onConfirmBtnTap: () async {
        Navigator.of(context).pop();
        try {
          await PollService.close(poll.id);
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('poll.closed_done'.tr())));
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('poll.action_failed'.tr())));
        }
      },
    );
  }

  void _confirmDelete(Poll poll) {
    final messenger = ScaffoldMessenger.of(context);
    showAppAlert(
      context: context,
      type: AppAlertType.confirm,
      title: 'poll.delete_poll'.tr(),
      text: 'poll.delete_confirm'.tr(),
      confirmBtnText: 'poll.delete_btn'.tr(),
      cancelBtnText: 'common.cancel'.tr(),
      confirmBtnColor: context.colors.error,
      onConfirmBtnTap: () async {
        Navigator.of(context).pop();
        try {
          await PollService.delete(poll.id);
          if (!mounted) return;
          Navigator.of(context).pop();
          messenger.showSnackBar(
            SnackBar(content: Text('poll.deleted_done'.tr())),
          );
        } catch (_) {
          if (!mounted) return;
          messenger.showSnackBar(
            SnackBar(content: Text('poll.action_failed'.tr())),
          );
        }
      },
    );
  }

  Future<void> _openMaps(PollOption option) async {
    Uri? uri;
    final mapsUrl = option.mapsUrl;
    if (mapsUrl != null && mapsUrl.isNotEmpty) {
      uri = Uri.tryParse(mapsUrl);
    } else if (option.hasCoords) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query='
        '${option.lat},${option.lng}',
      );
    }
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('poll.no_coords'.tr())));
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Kazanan mekanı tek mekanlık bir buluşma kaydı olarak geçmişe ekler ve
  /// haritayı açar.
  Future<void> _saveWinner(PollOption option) async {
    if (_busy) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    if (!option.hasCoords) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('poll.no_coords'.tr())));
      return;
    }
    setState(() => _busy = true);

    final record = MeetingRecord(
      id: '',
      initiatorUid: user.uid,
      initiatorName: user.name,
      initiatorPhotoUrl: user.photoUrl,
      activities: ['poll.history_label'.tr()],
      venues: [
        VenueSnapshot(
          placeId: option.placeId ?? '',
          name: option.name,
          vicinity: option.address,
          lat: option.lat!,
          lng: option.lng!,
          rating: option.rating,
          photoUrls: [if (option.photoUrl != null) option.photoUrl!],
        ),
      ],
      searchLat: option.lat!,
      searchLng: option.lng!,
      hasMidpoint: false,
      createdAt: DateTime.now(),
      participantUids: [user.uid],
    );

    final messenger = ScaffoldMessenger.of(context);
    try {
      await MeetingHistoryService.save(record);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('poll.saved_to_history'.tr())),
      );
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              MeetingHistoryDetailPage(record: record, myUid: user.uid),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('poll.action_failed'.tr())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// ── Parçalar ────────────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final Color color;

  const _Divider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 30, color: color);
  }
}

class _OptionResultCard extends StatelessWidget {
  final int index;
  final PollOption option;
  final int count;
  final int total;
  final bool highlight;
  final List<String> voters;
  final bool expanded;
  final VoidCallback onToggle;

  const _OptionResultCard({
    required this.index,
    required this.option,
    required this.count,
    required this.total,
    required this.highlight,
    required this.voters,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : count / total;
    final percent = (fraction * 100).round();
    final subtitle = _subtitle(option);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? context.accentStrong.withValues(alpha: 0.45)
              : context.colors.border.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Emerald.base.withValues(
                    alpha: context.isDarkTheme ? 0.20 : 0.14,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.accentStrong,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: context.colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.accentStrong,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 7,
              backgroundColor: context.colors.border.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(context.accentStrong),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '%$percent',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textSecondary,
                ),
              ),
              const Spacer(),
              if (voters.isNotEmpty)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggle,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'poll.show_voters'.tr(
                          namedArgs: {'count': '${voters.length}'},
                        ),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: context.accentStrong,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        expanded ? Iconsax.arrow_up_2 : Iconsax.arrow_down_1,
                        size: 12,
                        color: context.accentStrong,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (expanded && voters.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in voters)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.border.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _subtitle(PollOption option) {
    final rating = option.rating == null
        ? ''
        : '★ ${option.rating!.toStringAsFixed(1)}';
    return [
      rating,
      option.address ?? '',
    ].where((s) => s.isNotEmpty).join(' · ');
  }
}

class _WinnerCard extends StatelessWidget {
  final PollOption option;
  final int count;
  final int total;
  final VoidCallback onMaps;
  final VoidCallback onSave;

  const _WinnerCard({
    required this.option,
    required this.count,
    required this.total,
    required this.onMaps,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0 : (count * 100 / total).round();
    final canMap =
        option.hasCoords ||
        (option.mapsUrl != null && option.mapsUrl!.isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Emerald.base.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Emerald.base.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.crown_1, size: 18, color: context.accentStrong),
              const SizedBox(width: 6),
              Text(
                'poll.winner'.tr(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: context.accentStrong,
                ),
              ),
              const Spacer(),
              Text(
                '%$percent',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: context.accentStrong,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            option.name,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.3,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'poll.votes_count'.tr(namedArgs: {'count': '$count'}),
            style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
          ),
          if (canMap) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onMaps,
                icon: Icon(
                  Iconsax.map_1,
                  size: 17,
                  color: context.accentStrong,
                ),
                label: Text('poll.open_maps'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.accentStrong,
                  side: BorderSide(
                    color: context.accentStrong.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
          if (option.hasCoords) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onSave,
                icon: const Icon(
                  Iconsax.calendar_add,
                  size: 17,
                  color: Colors.white,
                ),
                label: Text('poll.save_to_history'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Emerald.base,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageState({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: context.colors.textSecondary),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: context.colors.textSecondary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.colors.border),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
