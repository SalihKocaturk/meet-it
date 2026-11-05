import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/constants/emerald_palette.dart';
import 'package:meetit/features/main/main_page.dart';
import 'package:meetit/features/share_links/poll.dart';
import 'package:meetit/features/share_links/poll_detail_page.dart';
import 'package:meetit/features/share_links/providers/polls_provider.dart';
import 'package:meetit/features/share_links/widgets/poll_status_chip.dart';

/// Kullanıcının oluşturduğu grup oylamalarının yönetim ekranı.
///
/// Liste gövdesi [PollManagementBody] olarak ayrıldı; aynı gövde Arkadaşlar
/// sekmesindeki "Oylamalar" sekmesinde gömülü olarak kullanılıyor.
class PollManagementPage extends StatelessWidget {
  const PollManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: context.colors.scaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'poll.manage_title'.tr(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        iconTheme: IconThemeData(color: context.colors.textPrimary),
      ),
      body: const PollManagementBody(),
    );
  }
}

/// Oylama listesi + filtreleri.
///
/// [embedded] true iken dıştaki (Arkadaşlar sekmesi) `RefreshIndicator` ve
/// alt navigasyon boşluğu kullanılır; kendi sayfasında ise kendi yenileme
/// göstergesini kurar.
class PollManagementBody extends ConsumerStatefulWidget {
  final bool embedded;

  const PollManagementBody({super.key, this.embedded = false});

  @override
  ConsumerState<PollManagementBody> createState() => _PollManagementBodyState();
}

class _PollManagementBodyState extends ConsumerState<PollManagementBody> {
  /// 0 = canlı, 1 = kapananlar, 2 = tümü
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final pollsAsync = ref.watch(myPollsProvider);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, widget.embedded ? 0 : 4, 20, 0),
          child: _FilterTabs(
            index: _filter,
            labels: [
              'poll.filter_live'.tr(),
              'poll.filter_closed'.tr(),
              'poll.filter_all'.tr(),
            ],
            onChanged: (i) => setState(() => _filter = i),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: pollsAsync.when(
            loading: () => Center(
              child: CircularProgressIndicator(color: context.accentStrong),
            ),
            error: (error, stack) {
              // Teşhis için: konsolda gerçek Firestore hatasını ve izini
              // göster (index eksikliği / izin hatası ayrımı buradan
              // görülebilir).
              debugPrint('[polls] myPollsProvider error: $error\n$stack');
              return _ErrorState(
                onRetry: () => ref.invalidate(myPollsProvider),
              );
            },
            data: (polls) {
              final filtered = switch (_filter) {
                0 => polls.where((p) => p.isActive).toList(),
                1 => polls.where((p) => !p.isActive).toList(),
                _ => polls,
              };
              if (filtered.isEmpty) {
                return _EmptyState(
                  hasPolls: polls.isNotEmpty,
                  onExplore: _goToSearch,
                );
              }
              final list = ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  widget.embedded
                      ? MediaQuery.paddingOf(context).bottom + 16
                      : 32,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, i) => _PollCard(
                  poll: filtered[i],
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PollDetailPage(pollId: filtered[i].id),
                    ),
                  ),
                ),
              );
              if (widget.embedded) return list;
              return RefreshIndicator(
                color: context.accentStrong,
                backgroundColor: context.colors.card,
                onRefresh: () async {
                  ref.invalidate(myPollsProvider);
                  await Future<void>.delayed(const Duration(milliseconds: 500));
                },
                child: list,
              );
            },
          ),
        ),
      ],
    );
  }

  void _goToSearch() {
    ref.read(mainTabIndexProvider.notifier).state = 1;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

// ── Filtre sekmeleri ────────────────────────────────────────────────────────

class _FilterTabs extends StatelessWidget {
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  const _FilterTabs({
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? Emerald.base : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: i == index
                            ? Colors.white
                            : context.colors.textPrimary.withValues(
                                alpha: 0.75,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Oylama kartı ────────────────────────────────────────────────────────────

class _PollCard extends StatelessWidget {
  final Poll poll;
  final VoidCallback onTap;

  const _PollCard({required this.poll, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final counts = poll.counts;
    final leading = poll.leadingIndex;
    final leadingPercent = (leading != null && poll.totalVotes > 0)
        ? (counts[leading] * 100 / poll.totalVotes).round()
        : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.7)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PollStatusChip(status: poll.status),
                    const Spacer(),
                    if (poll.createdAt != null) ...[
                      Text(
                        DateFormat(
                          'd MMM',
                          context.locale.languageCode,
                        ).format(poll.createdAt!),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: context.colors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Icon(
                      Iconsax.arrow_right_3,
                      size: 16,
                      color: context.colors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  poll.title.isEmpty ? 'poll.untitled'.tr() : poll.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${'poll.votes_count'.tr(namedArgs: {'count': '${poll.totalVotes}'})}'
                  ' · '
                  '${'poll.participants_count'.tr(namedArgs: {'count': '${poll.votes.length}'})}'
                  ' · '
                  '${'poll.options_count'.tr(namedArgs: {'count': '${poll.options.length}'})}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                if (leading == null)
                  Text(
                    'poll.no_votes_yet'.tr(),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textSecondary,
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'poll.leader'.tr(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          '${poll.options[leading].name} · %$leadingPercent',
                          maxLines: 1,
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.accentStrong,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: poll.totalVotes == 0
                          ? 0
                          : counts[leading] / poll.totalVotes,
                      minHeight: 6,
                      backgroundColor: context.colors.border.withValues(
                        alpha: 0.5,
                      ),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        context.accentStrong,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Boş / hata durumları ────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  /// Kullanıcının hiç oylaması yok mu? (Filtre boşluğundan ayırmak için)
  final bool hasPolls;
  final VoidCallback onExplore;

  const _EmptyState({required this.hasPolls, required this.onExplore});

  @override
  Widget build(BuildContext context) {
    final isFirstRun = !hasPolls;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
      children: [
        Icon(
          Iconsax.people,
          size: 52,
          color: context.colors.textSecondary.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 16),
        Text(
          isFirstRun ? 'poll.empty_my_polls'.tr() : 'poll.empty_filter'.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isFirstRun
              ? 'poll.empty_my_polls_desc'.tr()
              : 'poll.empty_filter_desc'.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: context.colors.textSecondary,
          ),
        ),
        if (isFirstRun) ...[
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton.icon(
              onPressed: onExplore,
              icon: const Icon(
                Iconsax.search_normal_1,
                size: 18,
                color: Colors.white,
              ),
              label: Text(
                'poll.go_search'.tr(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Emerald.base,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.warning_2,
              size: 40,
              color: context.colors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              'poll.load_failed'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: context.colors.border),
              ),
              child: Text('common.retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
