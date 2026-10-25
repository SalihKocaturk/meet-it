import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/constants/emerald_palette.dart';
import 'package:meetit/core/services/analytics_service.dart';
import 'package:meetit/core/utils/important_action_guard.dart';
import 'package:meetit/core/utils/text_utils.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/match/pages/venue_search_loading_page.dart';
import 'package:meetit/features/match/providers/match_provider.dart';
import 'package:meetit/features/match/providers/venue_search_provider.dart';
import 'package:meetit/features/personality/models/personality_model.dart';
import 'package:meetit/features/share_links/location_request.dart';
import 'package:meetit/features/share_links/web_links.dart';
import 'package:share_plus/share_plus.dart';

/// Buluşma ekranında "uygulaması olmayan biriyle" buluşma kartı:
///  • İstek yok    → "Konum linki gönder"
///  • Bekleniyor   → linki tekrar paylaş / iptal
///  • Paylaşıldı   → "Ortadaki mekanları bul" (arama + sonuçları web'e yaz)
///  • Tamamlandı   → öneriler paylaşıldı, yeni istek
class LocationRequestCard extends ConsumerStatefulWidget {
  const LocationRequestCard({super.key});

  @override
  ConsumerState<LocationRequestCard> createState() =>
      _LocationRequestCardState();
}

class _LocationRequestCardState extends ConsumerState<LocationRequestCard> {
  bool _busy = false;

  String _ownerFirstName() {
    final user = ref.read(currentUserProvider);
    if (user == null || user.isGuest) return '';
    return titleCaseName(
      user.name.split(' ').first,
      turkish: context.locale.languageCode == 'tr',
    );
  }

  Future<void> _shareLink(String id, {Rect? origin}) async {
    final link = WebLinks.locationRequest(id, ownerFirstName: _ownerFirstName());
    await SharePlus.instance.share(ShareParams(
      text: 'location_link.share_text'.tr(namedArgs: {'link': link.toString()}),
      sharePositionOrigin: origin,
    ));
  }

  Future<void> _create() async {
    if (_busy) return;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _busy = true);
    try {
      final id =
          await ref.read(activeLocationRequestIdProvider.notifier).createNew();
      if (id == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('location_link.create_failed'.tr())),
          );
        }
        return;
      }
      AnalyticsService.locationRequestCreated().ignore();
      await _shareLink(id, origin: origin);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(String id) async {
    await LocationRequestService.delete(id);
    await ref.read(activeLocationRequestIdProvider.notifier).set(null);
  }

  Future<void> _findVenues(LocationRequest req) async {
    if (_busy) return;
    final canProceed = await ensureEmailVerified(context, ref) &&
        await ensurePersonalityReady(context, ref);
    if (!canProceed || !mounted) return;

    setState(() => _busy = true);
    try {
      final me = ref.read(currentUserProvider);
      final userProfile =
          me?.personalityProfile ?? PersonalityProfile.neutral();
      final userLoc = ref.read(userLocationProvider);
      // Seçili bir uygulama-içi arkadaş varsa bu arama onunla karışmasın.
      ref.read(selectedFriendUidProvider.notifier).state = null;

      AnalyticsService.venueSearch('location_link').ignore();
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => VenueSearchLoadingPage(
            userProfile: userProfile,
            // Arkadaşın testi yok — öneriler kullanıcıya göre şekillenir.
            friendProfile: userProfile,
            selectedActivities:
                ref.read(selectedActivitiesProvider).toList(),
            friendUid: null,
            priceLevel: ref.read(selectedPriceLevelProvider),
            userLat: userLoc?.lat,
            userLng: userLoc?.lng,
            maxVenueDistanceKm: ref.read(selectedMaxDistanceKmProvider),
            friendLat: req.friendLat,
            friendLng: req.friendLng,
            friendName: req.friendName,
          ),
        ),
      );
      if (!mounted) return;

      final result = ref.read(venueSearchProvider);
      if (!result.hasResults) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.errorMessage ?? 'match.no_venues_found'.tr(),
            ),
          ),
        );
        return;
      }
      final venues = [...result.midpointVenues, ...result.allVenues];
      AnalyticsService.venuesShown(venues.length, 'location_link').ignore();
      // Arkadaş web sayfasında önerileri görsün.
      await LocationRequestService.publishResults(req.id, venues);
      ref.read(showMapViewProvider.notifier).state = true;
      ref.read(showVenuesProvider.notifier).state = true;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = ref.watch(activeLocationRequestIdProvider);
    final req = ref.watch(activeLocationRequestProvider).valueOrNull;

    // İstek yok (ya da silinmiş) → davet satırı
    if (id == null || (req == null && !ref.watch(activeLocationRequestProvider).isLoading)) {
      if (id != null) {
        // Doküman silinmişse yerel kaydı da temizle.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(activeLocationRequestIdProvider.notifier).set(null);
        });
      }
      return _Shell(
        icon: Iconsax.location_add,
        title: 'location_link.cta_title'.tr(),
        subtitle: 'location_link.cta_desc'.tr(),
        trailing: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.ios_share_rounded, color: context.accentStrong),
        onTap: _busy ? null : _create,
      );
    }
    if (req == null) return const SizedBox(height: 4);

    final friendName = (req.friendName?.isNotEmpty ?? false)
        ? req.friendName!
        : 'location_link.your_friend'.tr();

    switch (req.status) {
      case LocationRequestStatus.waiting:
        return _Shell(
          icon: Iconsax.clock,
          title: 'location_link.waiting_title'.tr(),
          subtitle: 'location_link.waiting_desc'.tr(),
          actions: [
            _SmallButton(
              label: 'location_link.share_again'.tr(),
              onTap: () => _shareLink(req.id),
            ),
            _SmallButton(
              label: 'common.cancel'.tr(),
              subtle: true,
              onTap: () => _cancel(req.id),
            ),
          ],
        );
      case LocationRequestStatus.shared:
        return _Shell(
          icon: Iconsax.location_tick,
          highlighted: true,
          title: 'location_link.shared_title'.tr(namedArgs: {'name': friendName}),
          subtitle: 'location_link.shared_desc'.tr(),
          actions: [
            _SmallButton(
              label: 'location_link.find_midpoint'.tr(),
              primary: true,
              busy: _busy,
              onTap: () => _findVenues(req),
            ),
            _SmallButton(
              label: 'common.cancel'.tr(),
              subtle: true,
              onTap: () => _cancel(req.id),
            ),
          ],
        );
      case LocationRequestStatus.done:
        return _Shell(
          icon: Iconsax.tick_circle,
          title: 'location_link.done_title'.tr(namedArgs: {'name': friendName}),
          subtitle: 'location_link.done_desc'.tr(),
          actions: [
            _SmallButton(
              label: 'location_link.search_again'.tr(),
              onTap: () => _findVenues(req),
            ),
            _SmallButton(
              label: 'location_link.new_request'.tr(),
              subtle: true,
              onTap: () => ref
                  .read(activeLocationRequestIdProvider.notifier)
                  .set(null),
            ),
          ],
        );
    }
  }
}

class _Shell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final List<Widget> actions;
  final bool highlighted;

  const _Shell({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.actions = const [],
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final body = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: highlighted
          ? Emerald.tint(radius: 14)
          : BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colors.border),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Emerald.base.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: context.accentStrong),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
    if (onTap == null) return body;
    return GestureDetector(onTap: onTap, child: body);
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool subtle;
  final bool busy;

  const _SmallButton({
    required this.label,
    required this.onTap,
    this.primary = false,
    this.subtle = false,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = primary
        ? Emerald.base
        : subtle
            ? Colors.transparent
            : Emerald.base.withOpacity(0.15);
    final Color fg = primary
        ? Colors.white
        : subtle
            ? context.colors.textSecondary
            : context.accentOnTint;
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: subtle || primary
              ? null
              : Border.all(color: Emerald.base.withOpacity(0.45)),
        ),
        child: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
      ),
    );
  }
}
