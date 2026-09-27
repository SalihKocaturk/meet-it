import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:iconsax/iconsax.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/constants/map_styles.dart';
import 'package:meetit/core/providers/theme_provider.dart';
import 'package:meetit/features/match/models/place_result.dart';
import 'package:meetit/features/match/providers/saved_venues_provider.dart';
import 'package:meetit/features/match/utils/venue_type_pin.dart';
import 'package:meetit/features/match/utils/venue_type_style.dart';
import 'package:meetit/features/reviews/venue_detail_page.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Profil › Kaydedilenler / Tarifi Alınanlar — Harita & Liste Görünümü ─────
//
// Bu dosya iki sekmenin (Kaydedilenler, Tarifi Alınanlar) ortak parçalarını
// içerir:
//   • VenueViewModeToggle   → sağ üstteki Liste / Harita anahtarı
//   • VenueTypeFilterBar    → ekranın altındaki, mekan tipine göre küçük
//                             filtre butonları (Tümü, Kafe, Restoran...)
//   • VenueCollectionMapView→ kaydedilen mekanları tipe özel pinlerle
//                             (bkz. venue_type_pin.dart) gösteren harita;
//                             pine dokununca AttemptMeetPage'deki kartı
//                             örnek alan bir mekan kartı açılır, karta
//                             dokununca VenueDetailPage'e gidilir.

enum VenueCollectionKind { saved, navigated }

/// Liste (false) / Harita (true) tercihi — iki sekme için ortak.
/// Varsayılan: Harita görünümü.
final venueCollectionMapModeProvider = StateProvider<bool>((ref) => true);

/// Alttaki filtre butonları alanının ÖLÇÜLMÜŞ yüksekliği. Butonlar Wrap ile
/// gerekirse birden fazla satıra geçtiği için sabit değil — harita padding'i
/// ve liste alt boşluğu bu değere göre ayarlanıyor.
final venueFilterBarHeightProvider = StateProvider<double>((ref) => 44);

/// Sekme başına seçili tip filtresi (`null` = Tümü).
final venueCollectionFilterProvider =
    StateProvider.family<String?, VenueCollectionKind>((ref, kind) => null);

/// Seçili filtre listede artık hiç mekan eşleştirmiyorsa (örn. o tipteki
/// son mekan kayıtlardan çıkarıldıysa) `null`'a (Tümü) düşer.
String? effectiveVenueFilter(List<PlaceResult> venues, String? key) {
  if (key == null) return null;
  return venues.any((p) => VenueTypeStyle.of(p).key == key) ? key : null;
}

List<PlaceResult> applyVenueFilter(List<PlaceResult> venues, String? key) {
  final k = effectiveVenueFilter(venues, key);
  if (k == null) return venues;
  return venues.where((p) => VenueTypeStyle.of(p).key == k).toList();
}

/// Mekan detay sayfasını açar (liste kartı + harita kartı ortak).
void openVenueDetail(BuildContext context, PlaceResult place) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => VenueDetailPage.fromPlace(place)),
  );
}

/// Google Maps'i mekanın konumuyla açar.
Future<void> launchVenueDirections(PlaceResult place) async {
  final uri = Uri.parse(place.googleMapsUrl);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

bool _hasCoords(PlaceResult p) => p.lat != 0 || p.lng != 0;

// ── Liste / Harita anahtarı ──────────────────────────────────────────────────

class VenueViewModeToggle extends ConsumerWidget {
  const VenueViewModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMap = ref.watch(venueCollectionMapModeProvider);
    const segW = 40.0;
    const h = 32.0;

    Widget segment(IconData icon, bool value, String tooltip) {
      final active = isMap == value;
      return Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () =>
              ref.read(venueCollectionMapModeProvider.notifier).state = value,
          child: SizedBox(
            width: segW,
            height: h,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                key: ValueKey(active),
                size: 17,
                color: active ? Colors.white : context.colors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            left: isMap ? segW : 0,
            top: 0,
            bottom: 0,
            width: segW,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.colors.primary,
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              segment(Icons.view_agenda_rounded, false, 'profile.view_list'.tr()),
              segment(Icons.map_rounded, true, 'profile.view_map'.tr()),
            ],
          ),
        ],
      ),
    );
  }
}

/// Liste görünümünün üstündeki satır: solda mekan sayısı, sağda anahtar.
class VenueCollectionToolbar extends StatelessWidget {
  final int count;
  const VenueCollectionToolbar({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Text(
            'profile.venue_count'.tr(namedArgs: {'count': '$count'}),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colors.textSecondary,
            ),
          ),
          const Spacer(),
          const VenueViewModeToggle(),
        ],
      ),
    );
  }
}

// ── Tip filtre butonları ──────────────────────────────────────────────────────

class VenueTypeFilterBar extends ConsumerWidget {
  final VenueCollectionKind kind;

  /// FİLTRELENMEMİŞ tam liste — butonlar ve sayılar bundan üretilir.
  final List<PlaceResult> venues;

  const VenueTypeFilterBar({
    super.key,
    required this.kind,
    required this.venues,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = effectiveVenueFilter(
      venues,
      ref.watch(venueCollectionFilterProvider(kind)),
    );

    // Tip → adet; en kalabalık tip en solda.
    final counts = <String, int>{};
    for (final p in venues) {
      final k = VenueTypeStyle.of(p).key;
      counts[k] = (counts[k] ?? 0) + 1;
    }
    final keys = counts.keys.toList()
      ..sort((a, b) {
        if (a == 'other') return 1;
        if (b == 'other') return -1;
        return counts[b]!.compareTo(counts[a]!);
      });

    void select(String? key) =>
        ref.read(venueCollectionFilterProvider(kind).notifier).state = key;

    // Wrap: butonlar ekrana sığmazsa alt satıra geçer (yana kaydırmalı
    // tek satırda ekran dışına taşıyordu).
    return _MeasureSize(
      onChange: (size) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final notifier = ref.read(venueFilterBarHeightProvider.notifier);
          if (notifier.state != size.height) notifier.state = size.height;
        });
      },
      // Tam genişlik: harita görünümünde üstteki Column sağa hizalı
      // (crossAxisAlignment.end) — aksi halde Wrap sağa yaslanırdı.
      child: SizedBox(
        width: double.infinity,
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _FilterChip(
              icon: Icons.grid_view_rounded,
              label: 'profile.filter_all'.tr(),
              count: venues.length,
              color: context.colors.primary,
              selected: selected == null,
              onTap: () => select(null),
            ),
            for (final k in keys)
              _FilterChip(
                icon: VenueTypeStyle.byKey(k).icon,
                label: VenueTypeStyle.byKey(k).label,
                count: counts[k]!,
                color: VenueTypeStyle.byKey(k).colorDark,
                selected: selected == k,
                onTap: () => select(selected == k ? null : k),
              ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Çocuğunun yerleşim sonrası boyutunu bildiren küçük yardımcı.
class _MeasureSize extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> onChange;
  const _MeasureSize({required this.onChange, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureSize(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderMeasureSize renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  ValueChanged<Size> onChange;
  Size? _last;
  _RenderMeasureSize(this.onChange);

  @override
  void performLayout() {
    super.performLayout();
    if (_last != size) {
      _last = size;
      onChange(size);
    }
  }
}

class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : context.colors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? color : context.colors.card,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? color : context.colors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: (selected ? color : Colors.black).withValues(
                alpha: selected ? 0.30 : 0.06,
              ),
              blurRadius: selected ? 10 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected
                    ? Colors.white.withValues(alpha: 0.85)
                    : context.colors.hint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Harita görünümü ───────────────────────────────────────────────────────────

class VenueCollectionMapView extends ConsumerStatefulWidget {
  final VenueCollectionKind kind;

  /// FİLTRELENMEMİŞ tam liste — filtre bu widget içinde uygulanır.
  final List<PlaceResult> venues;

  const VenueCollectionMapView({
    super.key,
    required this.kind,
    required this.venues,
  });

  @override
  ConsumerState<VenueCollectionMapView> createState() =>
      _VenueCollectionMapViewState();
}

class _VenueCollectionMapViewState
    extends ConsumerState<VenueCollectionMapView> {
  GoogleMapController? _ctrl;
  String? _selectedId;
  final Map<String, BitmapDescriptor> _icons = {};

  static const _cardHeight = 176.0;

  @override
  void initState() {
    super.initState();
    _prepareIcons();
  }

  @override
  void didUpdateWidget(covariant VenueCollectionMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.venues, widget.venues)) _prepareIcons();
    if (oldWidget.kind != widget.kind) {
      _selectedId = null;
      _scheduleFit();
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  /// Listedeki her tip için normal + seçili pin bitmap'lerini hazırlar
  /// (VenueTypePin kendi içinde önbellekli — tekrar çizim yapılmaz).
  Future<void> _prepareIcons() async {
    final styles = {for (final p in widget.venues) VenueTypeStyle.of(p)};
    for (final s in styles) {
      for (final sel in const [false, true]) {
        final k = '${s.key}|$sel';
        if (_icons.containsKey(k)) continue;
        final icon = await VenueTypePin.get(s, selected: sel);
        if (!mounted) return;
        setState(() => _icons[k] = icon);
      }
    }
  }

  List<PlaceResult> get _filtered => applyVenueFilter(
        widget.venues,
        ref.read(venueCollectionFilterProvider(widget.kind)),
      ).where(_hasCoords).toList();

  void _scheduleFit() {
    // newLatLngBounds harita yerleşimi tamamlanmadan çağrılırsa Android'de
    // hata fırlatabiliyor — kısa bir gecikmeyle çağrılıyor.
    Future.delayed(const Duration(milliseconds: 300), _fitAll);
  }

  Future<void> _fitAll() async {
    final ctrl = _ctrl;
    if (ctrl == null || !mounted) return;
    final list = _filtered;
    if (list.isEmpty) return;
    try {
      if (list.length == 1) {
        await ctrl.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(list.first.lat, list.first.lng), 15),
        );
        return;
      }
      var minLat = list.first.lat, maxLat = list.first.lat;
      var minLng = list.first.lng, maxLng = list.first.lng;
      for (final p in list) {
        if (p.lat < minLat) minLat = p.lat;
        if (p.lat > maxLat) maxLat = p.lat;
        if (p.lng < minLng) minLng = p.lng;
        if (p.lng > maxLng) maxLng = p.lng;
      }
      // Hepsi aynı noktadaysa bounds sıfır alanlı olur → zoom'a düş.
      if (minLat == maxLat && minLng == maxLng) {
        await ctrl.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 15),
        );
        return;
      }
      await ctrl.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          64,
        ),
      );
    } catch (_) {}
  }

  void _select(PlaceResult place) {
    setState(() => _selectedId = place.placeId);
    // Kart açılınca harita padding'i değişiyor; bir kare sonra odakla ki
    // pin kartın ALTINDA kalmasın.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl?.animateCamera(
        CameraUpdate.newLatLng(LatLng(place.lat, place.lng)),
      );
    });
  }

  Marker _buildMarker(PlaceResult p) {
    final style = VenueTypeStyle.of(p);
    final isSel = p.placeId == _selectedId;
    final custom = _icons['${style.key}|$isSel'];
    return Marker(
      markerId: MarkerId(p.placeId),
      position: LatLng(p.lat, p.lng),
      // Özel pin henüz çizilmediyse (ilk kareler) tipin renk tonunda
      // standart pin gösterilir; hazır olunca kendiliğinden değişir.
      icon: custom ??
          BitmapDescriptor.defaultMarkerWithHue(
            HSVColor.fromColor(style.color).hue,
          ),
      anchor: custom != null
          ? VenueTypePin.anchorFor(selected: isSel)
          : const Offset(0.5, 1.0),
      zIndex: isSel ? 2.0 : 1.0,
      consumeTapEvents: true,
      onTap: () => _select(p),
    );
  }

  void _deselect() {
    if (_selectedId == null) return;
    setState(() => _selectedId = null);
  }

  @override
  Widget build(BuildContext context) {
    // Filtre değişince: seçim filtre dışında kaldıysa kapat, kamerayı
    // yeni kümeye göre yeniden sığdır.
    ref.listen(venueCollectionFilterProvider(widget.kind), (_, _) {
      final ids = _filtered.map((p) => p.placeId).toSet();
      if (_selectedId != null && !ids.contains(_selectedId)) {
        setState(() => _selectedId = null);
      }
      _fitAll();
    });

    final isDark = isEffectivelyDark(ref.watch(themeModeProvider));
    final filter = ref.watch(venueCollectionFilterProvider(widget.kind));
    final filtered =
        applyVenueFilter(widget.venues, filter).where(_hasCoords).toList();

    final selectedIndex = filtered.indexWhere((p) => p.placeId == _selectedId);
    final selected = selectedIndex >= 0 ? filtered[selectedIndex] : null;

    final markers = <Marker>{for (final p in filtered) _buildMarker(p)};

    final initial = filtered.isNotEmpty
        ? LatLng(filtered.first.lat, filtered.first.lng)
        : const LatLng(41.0082, 28.9784); // İstanbul varsayılan

    final chipsBarHeight = ref.watch(venueFilterBarHeightProvider) + 6;
    final bottomOverlay =
        chipsBarHeight + (selected != null ? _cardHeight : 0);

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: initial, zoom: 13),
          style: isDark ? darkMapStyle : null,
          markers: markers,
          padding: EdgeInsets.only(top: 52, bottom: bottomOverlay),
          onMapCreated: (ctrl) {
            _ctrl = ctrl;
            _scheduleFit();
          },
          onTap: (_) => _deselect(),
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
        ),

        // ── Üst: mekan sayısı (sol) + Liste/Harita anahtarı (sağ) ─────────
        Positioned(
          top: 10,
          left: 12,
          right: 12,
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: context.colors.card,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.kind == VenueCollectionKind.saved
                          ? Iconsax.save_2
                          : Iconsax.send_2,
                      size: 14,
                      color: context.colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'profile.venue_count'
                          .tr(namedArgs: {'count': '${filtered.length}'}),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const VenueViewModeToggle(),
            ],
          ),
        ),

        // ── Alt: tümünü göster butonu + seçili mekan kartı + filtreler ───
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 4),
                child: _RoundMapButton(
                  icon: Icons.zoom_out_map_rounded,
                  onTap: _fitAll,
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.25),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.bottomCenter,
                  children: [...previous, if (current != null) current],
                ),
                child: selected == null
                    ? const SizedBox(width: double.infinity)
                    : _MapVenueCard(
                        key: ValueKey(selected.placeId),
                        kind: widget.kind,
                        place: selected,
                        index: selectedIndex,
                        total: filtered.length,
                        onPrev: selectedIndex > 0
                            ? () => _select(filtered[selectedIndex - 1])
                            : null,
                        onNext: selectedIndex < filtered.length - 1
                            ? () => _select(filtered[selectedIndex + 1])
                            : null,
                        onClose: _deselect,
                      ),
              ),
              VenueTypeFilterBar(kind: widget.kind, venues: widget.venues),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundMapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundMapButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: context.colors.card,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(icon, size: 17, color: context.colors.textPrimary),
      ),
    );
  }
}

// ── Harita üzerindeki seçili mekan kartı ─────────────────────────────────────
//
// AttemptMeetPage'deki VenueBottomBar örnek alındı: gezinme okları + sayaç,
// foto/isim/tip/puan, altında iki aksiyon butonu. Farkı: tip etiketi pinle
// aynı renk ve ikonu taşıyor; aksiyonlar sekmeye göre değişiyor
// (Kaydedilenler: Kaydet/Kaldır + Tarif Al — Tarifi Alınanlar: Yorum Ekle +
// Tarif Al). Kartın gövdesine dokununca mekan detay sayfası açılır.
class _MapVenueCard extends ConsumerWidget {
  final VenueCollectionKind kind;
  final PlaceResult place;
  final int index;
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onClose;

  const _MapVenueCard({
    super.key,
    required this.kind,
    required this.place,
    required this.index,
    required this.total,
    required this.onPrev,
    required this.onNext,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = VenueTypeStyle.of(place);
    final isSaved = ref.watch(
      savedVenuesProvider.select(
        (list) => list.any((p) => p.placeId == place.placeId),
      ),
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gezinme + sayaç + kapat
          Row(
            children: [
              IconButton(
                onPressed: onPrev,
                icon: const Icon(Iconsax.arrow_left_2, size: 18),
                color: onPrev == null
                    ? context.colors.hint
                    : context.colors.primary,
                visualDensity: VisualDensity.compact,
              ),
              Text(
                '${index + 1} / $total',
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textSecondary,
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Iconsax.arrow_right_3, size: 18),
                color: onNext == null
                    ? context.colors.hint
                    : context.colors.primary,
                visualDensity: VisualDensity.compact,
              ),
              const Spacer(),
              IconButton(
                onPressed: onClose,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: context.colors.hint,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          // Gövde → mekan detay
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => openVenueDetail(context, place),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: place.photoUrl != null
                        ? CachedNetworkImage(
                            imageUrl: place.photoUrl!,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) =>
                                VenueTypeIconBox(style: style, size: 64),
                          )
                        : VenueTypeIconBox(style: style, size: 64),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        if (place.vicinity != null)
                          Text(
                            place.vicinity!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        const SizedBox(height: 5),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            VenueTypeBadge(style: style),
                            if (place.rating != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  RatingBarIndicator(
                                    rating: place.rating!,
                                    itemBuilder: (context, _) => const Icon(
                                      Icons.star_rounded,
                                      color: Color(0xFFFFB800),
                                    ),
                                    itemCount: 5,
                                    itemSize: 10,
                                    unratedColor:
                                        Colors.grey.withValues(alpha: 0.3),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    place.ratingText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: context.colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            if (place.priceLabelText != null)
                              Text(
                                place.priceLabelText!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4CAF50),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Iconsax.arrow_right_3,
                    size: 16,
                    color: context.colors.hint,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: kind == VenueCollectionKind.saved
                      ? _CardAction(
                          icon: Iconsax.save_add,
                          label: isSaved
                              ? 'match.saved'.tr()
                              : 'match.save'.tr(),
                          highlighted: isSaved,
                          onTap: () => ref
                              .read(savedVenuesProvider.notifier)
                              .toggle(place),
                        )
                      : _CardAction(
                          icon: Iconsax.message_add_1,
                          label: 'profile.add_review'.tr(),
                          highlighted: true,
                          onTap: () => showAddReviewSheet(context, ref, place),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CardAction(
                    icon: Iconsax.routing,
                    label: 'profile.directions'.tr(),
                    filled: true,
                    onTap: () => launchVenueDirections(place),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final bool highlighted;
  final VoidCallback onTap;

  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    final fg = filled
        ? Colors.white
        : highlighted
        ? primary
        : context.colors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: filled
              ? primary
              : highlighted
              ? primary.withValues(alpha: 0.12)
              : context.colors.scaffold,
          borderRadius: BorderRadius.circular(8),
          border: filled
              ? null
              : Border.all(
                  color: highlighted ? primary : context.colors.border,
                ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tipin renk + ikonunu taşıyan küçük etiket (liste ve harita kartında).
class VenueTypeBadge extends StatelessWidget {
  final VenueTypeStyle style;
  const VenueTypeBadge({super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 11, color: style.colorDark),
          const SizedBox(width: 3),
          Text(
            style.label,
            style: TextStyle(
              fontSize: 10,
              color: style.colorDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fotoğrafı olmayan mekanlar için tip ikonlu yumuşak gradyan kutu.
class VenueTypeIconBox extends StatelessWidget {
  final VenueTypeStyle style;
  final double size;
  const VenueTypeIconBox({super.key, required this.style, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            style.color.withValues(alpha: 0.30),
            style.colorDark.withValues(alpha: 0.18),
          ],
        ),
      ),
      child: Icon(style.icon, color: style.colorDark, size: size * 0.42),
    );
  }
}
