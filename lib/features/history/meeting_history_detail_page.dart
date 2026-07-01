import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/constants/map_styles.dart';
import 'package:meetit/core/providers/theme_provider.dart';
import 'package:meetit/features/history/models/meeting_record.dart';
import 'package:meetit/features/match/models/place_result.dart';
import 'package:meetit/features/match/utils/map_marker_builder.dart';
import 'package:meetit/features/reviews/venue_detail_page.dart';

/// Kaydedilmiş buluşma geçmişindeki mekanları harita üzerinde gösterir.
///
/// Harita tamamen SALT-OKUNUR'dur — kaydetme/navigasyon butonları yoktur.
/// Kullanıcı bir mekana tıklayınca normal `VenueDetailPage`'e yönlendirilir
/// (orada yorum ekleyebilir, kaydedebilir vb.).
class MeetingHistoryDetailPage extends ConsumerStatefulWidget {
  final MeetingRecord record;
  final String? myUid;

  const MeetingHistoryDetailPage({super.key, required this.record, this.myUid});

  @override
  ConsumerState<MeetingHistoryDetailPage> createState() =>
      _MeetingHistoryDetailPageState();
}

class _MeetingHistoryDetailPageState
    extends ConsumerState<MeetingHistoryDetailPage> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  // -1 = henüz hiçbir kart seçilmedi; ilk tap seçer, ikinci tap detay açar
  int _selectedIndex = -1;

  @override
  void initState() {
    super.initState();
    _buildMarkers();
  }

  Future<void> _buildMarkers() async {
    final venues = widget.record.venues;
    if (venues.isEmpty) return;

    final built = <Marker>{};
    for (int i = 0; i < venues.length; i++) {
      final v = venues[i];
      // VenueSnapshot → minimal PlaceResult (sadece marker için gerekli alanlar)
      final place = PlaceResult(
        placeId: v.placeId,
        name: v.name,
        vicinity: v.vicinity,
        rating: v.rating,
        lat: v.lat,
        lng: v.lng,
        types: v.types,
        priceLevel: v.priceLevel,
      );
      final marker = MapMarkerBuilder.buildVenueMarker(
        place: place,
        rankIndex: i,
        onTap: () => _onMarkerTap(i),
      );
      built.add(marker);
    }

    if (mounted) {
      setState(() => _markers = built);
    }
  }

  void _onMarkerTap(int index) {
    setState(() => _selectedIndex = index);
    final v = widget.record.venues[index];
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(v.lat, v.lng), 15.5),
    );
  }

  void _focusSelected() {
    if (widget.record.venues.isEmpty || _selectedIndex < 0) return;
    final v = widget.record.venues[_selectedIndex];
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(v.lat, v.lng), 15.5),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final venues = widget.record.venues;

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: context.colors.scaffold,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: context.colors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'history.detail_title'.tr(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            Text(
              DateFormat(
                'd MMM y',
                context.locale.languageCode,
              ).format(widget.record.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: venues.isEmpty
          ? Center(
              child: Text(
                'history.no_venues'.tr(),
                style: TextStyle(color: context.colors.textSecondary),
              ),
            )
          : Column(
              children: [
                // ── Harita ──────────────────────────────────────────────
                Expanded(
                  flex: 3,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        widget.record.searchLat,
                        widget.record.searchLng,
                      ),
                      zoom: 13.5,
                    ),
                    markers: _markers,
                    myLocationButtonEnabled: false,
                    myLocationEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    style: isDark ? darkMapStyle : null,
                    onMapCreated: (controller) {
                      _mapController = controller;
                      // İlk mekana odaklan
                      Future.delayed(const Duration(milliseconds: 400), () {
                        if (mounted) _focusSelected();
                      });
                    },
                  ),
                ),

                // ── Alt kaydırmalı mekan listesi ────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: context.colors.card,
                    border: Border(
                      top: BorderSide(color: context.colors.border),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sürükleme göstergesi
                      Container(
                        margin: const EdgeInsets.only(top: 8, bottom: 4),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.colors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Mekan sayısı başlığı
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.place,
                              size: 16,
                              color: context.colors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'history.venue_count'.tr(
                                namedArgs: {'count': venues.length.toString()},
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Yatay kaydırmalı kartlar
                      SizedBox(
                        height: 130,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          scrollDirection: Axis.horizontal,
                          itemCount: venues.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final isSelected = index == _selectedIndex;
                            return _VenueCard(
                              venue: venues[index],
                              isSelected: isSelected,
                              onTap: () {
                                if (!isSelected) {
                                  // İlk tap: haritada seç ve odaklan
                                  _onMarkerTap(index);
                                } else {
                                  // İkinci tap: detay sayfasına git
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => VenueDetailPage(
                                        placeId: venues[index].placeId,
                                        venueName: venues[index].name,
                                        venueAddress: venues[index].vicinity,
                                        venuePhotoUrl:
                                            venues[index].photoUrls.isNotEmpty
                                            ? venues[index].photoUrls.first
                                            : null,
                                        venuePhotoUrls:
                                            venues[index].photoUrls,
                                        googleRating: venues[index].rating,
                                        lat: venues[index].lat,
                                        lng: venues[index].lng,
                                      ),
                                    ),
                                  );
                                }
                              },
                            );
                          },
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

// ── Mekan kartı (yatay liste içinde) ───────────────────────────────────────

class _VenueCard extends StatelessWidget {
  final VenueSnapshot venue;
  final bool isSelected;
  final VoidCallback onTap;

  const _VenueCard({
    required this.venue,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 200,
        decoration: BoxDecoration(
          color: context.colors.scaffold,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? context.colors.primary : context.colors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: context.colors.primary.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fotoğraf
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
              child: venue.photoUrls.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: venue.photoUrls.first,
                      height: 70,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) =>
                          _PlaceholderPhoto(types: venue.types),
                    )
                  : _PlaceholderPhoto(types: venue.types),
            ),
            // Mekan adı
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Text(
                venue.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderPhoto extends StatelessWidget {
  final List<String> types;
  const _PlaceholderPhoto({required this.types});

  IconData get _icon {
    if (types.contains('cafe')) return Icons.coffee_rounded;
    if (types.contains('restaurant')) return Icons.restaurant_rounded;
    if (types.contains('park')) return Icons.park_rounded;
    if (types.contains('museum')) return Icons.museum_rounded;
    if (types.contains('night_club') || types.contains('bar')) {
      return Icons.nightlife_rounded;
    }
    return Icons.place_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      width: double.infinity,
      color: context.colors.primary.withOpacity(0.08),
      child: Icon(
        _icon,
        size: 28,
        color: context.colors.primary.withOpacity(0.4),
      ),
    );
  }
}
                                    