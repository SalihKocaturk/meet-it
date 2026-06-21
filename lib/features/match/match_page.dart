import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/constants/app_config.dart';
import 'package:meetit/core/constants/map_styles.dart';
import 'package:meetit/core/widgets/circular_avatar.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/friends/models/user_friend_model.dart';
import 'package:meetit/features/friends/providers/friends_provider.dart';
import 'package:meetit/features/match/models/place_result.dart';
import 'package:meetit/features/match/providers/match_provider.dart';
import 'package:meetit/features/match/providers/venue_search_provider.dart';
import 'package:meetit/features/personality/models/personality_model.dart';
import 'package:meetit/features/match/providers/saved_venues_provider.dart';
import 'package:meetit/features/match/attempt_meet_page.dart';
import 'package:url_launcher/url_launcher.dart';

class MatchPage extends ConsumerWidget {
  const MatchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final connections = ref.watch(connectionsProvider);
    final showVenues = ref.watch(showVenuesProvider);

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      body: SafeArea(
        child: showVenues
            ? _VenueResultsView(
                onBack: () {
                  ref.read(showVenuesProvider.notifier).state = false;
                },
              )
            : CustomScrollView(
                slivers: [
                  // Başlık
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'match.title'.tr(),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'match.subtitle'.tr(),
                            style: TextStyle(
                              fontSize: 13,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Kişilik profili banner
                  if (currentUser?.personalityProfile != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: _PersonalityBanner(
                          type: currentUser!.personalityProfile!.dominantType,
                        ),
                      ),
                    ),

                  // Konumun
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'match.your_location'.tr(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _LocationField(
                            defaultHint:
                                currentUser?.location ?? 'match.location_hint'.tr(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Arkadaş seçimi
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'match.friend_to_meet'.tr(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (connections.isEmpty)
                            const _EmptyFriendsCard()
                          else
                            SizedBox(
                              height: 112,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: connections.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, i) {
                                  final f = connections[i];
                                  return _FriendChip(friend: f);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Uyumluluk göstergesi
                  SliverToBoxAdapter(
                    child: Consumer(
                      builder: (context, ref, _) {
                        final selectedFriend = ref.watch(
                          selectedFriendProvider,
                        );
                        if (selectedFriend == null) {
                          return const SizedBox.shrink();
                        }
                        final score = ref.watch(compatibilityScoreProvider);
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: _CompatibilityCard(
                            friend: selectedFriend,
                            score: score,
                          ),
                        );
                      },
                    ),
                  ),

                  // Aktivite seçimi (çoklu)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'match.activity_types'.tr(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 8),
                          _ActivityGrid(),
                        ],
                      ),
                    ),
                  ),

                  // Fiyat filtresi
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'match.price_level'.tr(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 8),
                          _PriceFilter(),
                        ],
                      ),
                    ),
                  ),

                  // Mekan Bul butonu
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
                      child: Consumer(
                        builder: (context, ref, _) {
                          final selectedFriend = ref.watch(
                            selectedFriendProvider,
                          );
                          // "Haritada Göster" butonu için arama durumu —
                          // arama sürerken bu buton da spinner gösterir.
                          final isMapSearchLoading = ref.watch(
                            venueSearchProvider.select((s) => s.isLoading),
                          );
                          // Arkadaş seçilmese de tek başına mekan arama
                          // yapılabilsin — buton her zaman aktif.
                          const isEnabled = true;

                          return Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: isEnabled
                                      ? () {
                                          final currentUser = ref.read(
                                            currentUserProvider,
                                          );
                                          final activities = ref.read(
                                            selectedActivitiesProvider,
                                          );
                                          final userProfile =
                                              currentUser?.personalityProfile ??
                                              PersonalityProfile.mock(
                                                PersonalityType.sosyalKelebek,
                                              );
                                          // Arkadaş seçilmediyse kendi
                                          // profili kullanılır (tek başına
                                          // buluşma modu).
                                          final friendProfile =
                                              selectedFriend
                                                  ?.personalityProfile ??
                                              userProfile;
                                          final priceLevel = ref.read(
                                            selectedPriceLevelProvider,
                                          );
                                          final userLoc = ref.read(
                                            userLocationProvider,
                                          );
                                          ref
                                              .read(
                                                venueSearchProvider.notifier,
                                              )
                                              .searchVenues(
                                                userProfile: userProfile,
                                                friendProfile: friendProfile,
                                                selectedActivities: activities
                                                    .toList(),
                                                friendUid: selectedFriend?.uid,
                                                priceLevel: priceLevel,
                                                userLat: userLoc?.lat,
                                                userLng: userLoc?.lng,
                                              );
                                          ref
                                                  .read(
                                                    showVenuesProvider.notifier,
                                                  )
                                                  .state =
                                              true;
                                        }
                                      : null,
                                  icon: const Icon(
                                    Icons.search,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    'match.see_venues'.tr(),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: context.colors.primary,
                                    disabledBackgroundColor: context
                                        .colors
                                        .primary
                                        .withOpacity(0.35),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                              if (selectedFriend == null)
                                Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                    'match.solo_hint'.tr(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.colors.hint,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),

                              // ── Haritada Göster butonu ───────────────────
                              //
                              // Mevcut liste tabanlı "Mekan Önerilerini Gör"
                              // akışına dokunmadan, aynı arama mantığını
                              // çalıştırıp sonucu harita üzerinde pinlerle
                              // gösteren AYRI bir görünüme (AttemptMeetPage)
                              // geçiş yapar. Eski akış bozulmasın diye bu
                              // bilerek tamamen ek/yeni bir buton.
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: isMapSearchLoading
                                      ? null
                                      : () async {
                                          final currentUser = ref.read(
                                            currentUserProvider,
                                          );
                                          final activities = ref.read(
                                            selectedActivitiesProvider,
                                          );
                                          final userProfile =
                                              currentUser?.personalityProfile ??
                                              PersonalityProfile.mock(
                                                PersonalityType.sosyalKelebek,
                                              );
                                          final friendProfile =
                                              selectedFriend
                                                  ?.personalityProfile ??
                                              userProfile;
                                          final priceLevel = ref.read(
                                            selectedPriceLevelProvider,
                                          );
                                          final userLoc = ref.read(
                                            userLocationProvider,
                                          );

                                          await ref
                                              .read(
                                                venueSearchProvider.notifier,
                                              )
                                              .searchVenues(
                                                userProfile: userProfile,
                                                friendProfile: friendProfile,
                                                selectedActivities: activities
                                                    .toList(),
                                                friendUid: selectedFriend?.uid,
                                                priceLevel: priceLevel,
                                                userLat: userLoc?.lat,
                                                userLng: userLoc?.lng,
                                              );

                                          if (!context.mounted) return;

                                          final result = ref.read(
                                            venueSearchProvider,
                                          );
                                          if (!result.hasResults) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  result.errorMessage ??
                                                      'match.no_venues_found'
                                                          .tr(),
                                                ),
                                              ),
                                            );
                                            return;
                                          }

                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const AttemptMeetPage(),
                                            ),
                                          );
                                        },
                                  icon: isMapSearchLoading
                                      ? SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: context.colors.primary,
                                          ),
                                        )
                                      : Icon(
                                          Icons.map_outlined,
                                          color: context.colors.primary,
                                        ),
                                  label: Text(
                                    'match.see_on_map'.tr(),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: context.colors.primary,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: context.colors.primary
                                          .withOpacity(0.5),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
      ),
    );
  }
}

// ── Kişilik Banner ────────────────────────────────────────────────────────────

class _PersonalityBanner extends StatelessWidget {
  final PersonalityType type;

  const _PersonalityBanner({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.primary.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Text(type.emoji, style: const TextStyle(fontSize: 20)),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'match.personality_type_label'.tr(namedArgs: {'name': type.displayName}),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.colors.primary,
                  ),
                ),
                Text(
                  'match.personality_customized'.tr(),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textSecondary,
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

// ── Uyumluluk Kartı ───────────────────────────────────────────────────────────

class _CompatibilityCard extends StatelessWidget {
  final UserFriendModel friend;
  final int score;

  const _CompatibilityCard({required this.friend, required this.score});

  Color _scoreColor(BuildContext context) {
    if (score >= 85) return context.colors.success;
    if (score >= 70) return context.colors.primary;
    return context.colors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          CircularAvatar(
            name: friend.name,
            photoUrl: friend.photoUrl,
            radius: 22,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.name.split(' ').first,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                if (friend.personalityProfile != null)
                  Text(
                    '${friend.personalityProfile!.dominantType.emoji} ${friend.personalityProfile!.dominantType.displayName}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '%$score',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _scoreColor(context),
                ),
              ),
              Text(
                'match.compatibility'.tr(),
                style: TextStyle(
                  fontSize: 11,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Konum Alanı ───────────────────────────────────────────────────────────────

class _LocationField extends ConsumerWidget {
  final String defaultHint;

  const _LocationField({required this.defaultHint});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userLoc = ref.watch(userLocationProvider);
    final currentUser = ref.watch(currentUserProvider);
    final displayText = userLoc?.text ?? defaultHint;
    final hasCoords = userLoc?.hasCoords ?? false;

    // Konum DB'den (UserModel.lat/lng) geldiği için kullanıcı her seferinde
    // yeniden konum girmek zorunda değil — burada zaten kayıtlı konumu
    // gösteriyoruz. İsterse alttaki "Yeni Konum Seç" ile değiştirebilir.
    Future<void> pickLocation() async {
      final result = await Navigator.of(context).push<UserLocation>(
        MaterialPageRoute(
          builder: (_) => MapLocationPickerPage(
            initial: userLoc?.hasCoords == true
                ? LatLng(userLoc!.lat!, userLoc.lng!)
                : null,
          ),
        ),
      );
      if (result == null) return;

      // Anında UI geri bildirimi
      ref.read(userLocationProvider.notifier).state = result;

      // DB'ye kaydet — bir dahaki sefere konum servisine veya yeniden
      // girişe gerek kalmasın, arkadaşlarımız da benim konumumu DB'den
      // güvenilir şekilde okuyabilsin.
      if (result.hasCoords) {
        await ref.read(authProvider.notifier).updateLocation(
              result.lat!,
              result.lng!,
              address: result.text,
            );
      }
    }

    return GestureDetector(
      onTap: pickLocation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasCoords
                ? context.colors.primary.withOpacity(0.5)
                : context.colors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (hasCoords)
                  CircularAvatar(
                    name: currentUser?.name,
                    photoUrl: currentUser?.photoUrl,
                    radius: 12,
                  )
                else
                  Icon(
                    Icons.my_location,
                    color: context.colors.primary,
                    size: 20,
                  ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayText,
                    style: TextStyle(
                      fontSize: 14,
                      color: hasCoords
                          ? context.colors.textPrimary
                          : context.colors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!hasCoords)
                  Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: context.colors.hint,
                  ),
              ],
            ),
            if (hasCoords) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: pickLocation,
                child: Text(
                  'match.change_location'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.colors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Harita ile Konum Seçme Sayfası ───────────────────────────────────────────

class MapLocationPickerPage extends StatefulWidget {
  final LatLng? initial;

  const MapLocationPickerPage({super.key, this.initial});

  @override
  State<MapLocationPickerPage> createState() => _MapLocationPickerPageState();
}

class _MapLocationPickerPageState extends State<MapLocationPickerPage> {
  GoogleMapController? _mapController;
  LatLng _center = const LatLng(41.0082, 28.9784); // İstanbul varsayılan
  String? _address;

  /// Sadece ilçe/il (örn. "Kadıköy, İstanbul") — açık adres yerine bu
  /// kaydedilir/gösterilir. Profilde tam açık konum göstermek gereksiz ve
  /// gizlilik açısından da fazla detaylı; ilçe/il bilgisi yeterli.
  String? _shortAddress;
  bool _isLoading = false;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _center = widget.initial!;
    } else {
      _getInitialGps();
    }
  }

  Future<void> _getInitialGps() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever)
        return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() => _center = latLng);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      _fetchAddress(latLng);
    } catch (_) {}
  }

  Future<void> _fetchAddress(LatLng pos) async {
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=${pos.latitude},${pos.longitude}'
        '&language=tr'
        '&key=${AppConfig.googleMapsApiKey}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if ((body['status'] as String?) == 'OK') {
        final results = body['results'] as List;
        if (results.isNotEmpty) {
          final first = results.first as Map<String, dynamic>;
          final components = (first['address_components'] as List?) ?? [];
          setState(() {
            _address = first['formatted_address'] as String?;
            _shortAddress = _extractDistrictProvince(components);
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  /// Google Geocoding `address_components`'tan "İlçe, İl" formatında
  /// kısa bir konum metni çıkarır (örn. "Kadıköy, İstanbul"). Açık adres
  /// (sokak/numara) bilgisini bilerek dışarıda bırakır.
  String? _extractDistrictProvince(List components) {
    String? district;
    String? province;

    for (final c in components) {
      final map = c as Map<String, dynamic>;
      final types = (map['types'] as List?)?.cast<String>() ?? [];
      final name = map['long_name'] as String?;
      if (name == null) continue;

      if (types.contains('administrative_area_level_2')) {
        district ??= name;
      } else if (types.contains('locality') && district == null) {
        // Bazı bölgelerde ilçe 'administrative_area_level_2' değil
        // 'locality' olarak geliyor — yedek olarak kullan.
        district = name;
      }
      if (types.contains('administrative_area_level_1')) {
        province = name;
      }
    }

    if (district != null && province != null) {
      // Aynı isim tekrar etmesin (örn. büyükşehir merkez ilçesi == il adı).
      if (district == province) return province;
      return '$district, $province';
    }
    return province ?? district;
  }

  void _onCameraMove(CameraPosition pos) {
    _center = pos.target;
  }

  void _onCameraIdle() {
    _fetchAddress(_center);
  }

  Future<void> _confirm() async {
    setState(() => _isConfirming = true);
    // Profilde/diğer kullanıcılarda açık adres yerine sadece ilçe/il
    // gösteriliyor — gizlilik açısından daha uygun ve gösterim için
    // zaten yeterli bilgi.
    final address =
        _shortAddress ??
        _address ??
        '${_center.latitude.toStringAsFixed(4)}, ${_center.longitude.toStringAsFixed(4)}';
    Navigator.of(context).pop(
      UserLocation(
        text: address,
        lat: _center.latitude,
        lng: _center.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Harita ───────────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _center, zoom: 14),
            // Uygulama teması koyu ise haritayı da koyu stille aç.
            style: Theme.of(context).brightness == Brightness.dark
                ? darkMapStyle
                : null,
            onMapCreated: (ctrl) {
              _mapController = ctrl;
              ctrl.setMapStyle(
                Theme.of(context).brightness == Brightness.dark
                    ? darkMapStyle
                    : null,
              );
              _fetchAddress(_center);
            },
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // ── Ortadaki pin ─────────────────────────────────────────────────
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_pin, size: 48, color: Color(0xFFE53935)),
                SizedBox(height: 24), // pin'in alt ucu tam ortada dursun
              ],
            ),
          ),

          // ── Üst: geri + başlık ───────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: context.colors.card,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.card,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: _isLoading
                          ? Row(
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: context.colors.primary,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'map_picker.searching'.tr(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              _address ?? 'map_picker.drag_hint'.tr(),
                              style: TextStyle(
                                fontSize: 13,
                                color: context.colors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Sağ: GPS butonu ───────────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: 120,
            child: GestureDetector(
              onTap: _getInitialGps,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.colors.card,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.my_location,
                  size: 22,
                  color: context.colors.primary,
                ),
              ),
            ),
          ),

          // ── Alt: Onayla butonu ────────────────────────────────────────────
          Positioned(
            left: 20,
            right: 20,
            bottom: 40,
            child: ElevatedButton(
              onPressed: _isConfirming ? null : _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: _isConfirming
                  ? SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.colors.card,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'map_picker.confirm'.tr(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Arkadaş Chip ─────────────────────────────────────────────────────────────

class _FriendChip extends ConsumerWidget {
  final UserFriendModel friend;

  const _FriendChip({required this.friend});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedUid = ref.watch(selectedFriendUidProvider);
    final isSelected = selectedUid == friend.uid;

    return GestureDetector(
      onTap: () {
        if (isSelected) {
          ref.read(selectedFriendUidProvider.notifier).state = null;
        } else {
          ref.read(selectedFriendUidProvider.notifier).state = friend.uid;
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: context.colors.primary, width: 2.5)
                  : null,
            ),
            child: CircularAvatar(
              name: friend.name,
              photoUrl: friend.photoUrl,
              radius: 28,
            ),
          ),
          SizedBox(height: 4),
          Text(
            friend.name.split(' ').first,
            style: TextStyle(
              fontSize: 11,
              color: isSelected
                  ? context.colors.primary
                  : context.colors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          if (friend.personalityProfile != null)
            Text(
              friend.personalityProfile!.dominantType.emoji,
              style: const TextStyle(fontSize: 12),
            ),
        ],
      ),
    );
  }
}

// ── Boş Arkadaş Kartı ────────────────────────────────────────────────────────

class _EmptyFriendsCard extends StatelessWidget {
  const _EmptyFriendsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.people_outline, color: context.colors.hint),
          SizedBox(width: 12),
          Text(
            'match.add_friend_hint'.tr(),
            style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Aktivite Grid (Çoklu Seçim) ───────────────────────────────────────────────

class _ActivityGrid extends ConsumerWidget {
  const _ActivityGrid();

  // (key used in provider, translation key, icon)
  static const _activities = [
    ('Kafe', 'match.activity_cafe', Icons.local_cafe_outlined),
    ('Restoran', 'match.activity_restaurant', Icons.restaurant_outlined),
    ('Park', 'match.activity_park', Icons.park_outlined),
    ('Sinema', 'match.activity_cinema', Icons.movie_outlined),
    ('Alışveriş', 'match.activity_shopping', Icons.shopping_bag_outlined),
    ('Spor', 'match.activity_sports', Icons.fitness_center_outlined),
    ('Kültür/Müze', 'match.activity_culture', Icons.museum_outlined),
    ('Bar', 'match.activity_bar', Icons.local_bar_outlined),
    ('Eğlence', 'match.activity_entertainment', Icons.celebration_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedActivitiesProvider);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _activities.map((a) {
        final isSelected = selected.contains(a.$1);
        return GestureDetector(
          onTap: () {
            final current = Set<String>.from(selected);
            if (isSelected) {
              current.remove(a.$1);
            } else {
              current.add(a.$1);
            }
            ref.read(selectedActivitiesProvider.notifier).state = current;
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? context.colors.primary : context.colors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? context.colors.primary
                    : context.colors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  a.$3,
                  size: 16,
                  color: isSelected
                      ? Colors.white
                      : context.colors.textSecondary,
                ),
                SizedBox(width: 6),
                Text(
                  a.$2.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : context.colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Fiyat Filtresi ────────────────────────────────────────────────────────────

class _PriceFilter extends ConsumerWidget {
  const _PriceFilter();

  // (price level int?, translation key, ₺ symbol)
  static const _options = [
    (null, 'match.price_all', ''),
    (1, 'match.price_cheap', '₺'),
    (2, 'match.price_mid', '₺₺'),
    (3, 'match.price_expensive', '₺₺₺'),
    (4, 'match.price_luxury', '₺₺₺₺'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedPriceLevelProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _options.map((opt) {
          final isSelected = selected == opt.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () =>
                  ref.read(selectedPriceLevelProvider.notifier).state = opt.$1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? context.colors.primary
                      : context.colors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? context.colors.primary
                        : context.colors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (opt.$3.isNotEmpty) ...[
                      Text(
                        opt.$3,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF4CAF50),
                        ),
                      ),
                      SizedBox(width: 4),
                    ],
                    Text(
                      opt.$2.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : context.colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Mekan Önerileri Ekranı ────────────────────────────────────────────────────

class _VenueResultsView extends ConsumerWidget {
  final VoidCallback onBack;

  const _VenueResultsView({required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(venueSearchProvider);
    final currentUser = ref.watch(currentUserProvider);
    final selectedFriend = ref.watch(selectedFriendProvider);
    final score = ref.watch(compatibilityScoreProvider);

    return CustomScrollView(
      slivers: [
        // Başlık
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onBack,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: context.colors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new,
                      size: 16,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'match.results_title'.tr(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      Text(
                        'match.personality_selected'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Kişilik uyumu özeti
        if (selectedFriend != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.colors.primary.withOpacity(0.08),
                      context.colors.primary.withOpacity(0.03),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: context.colors.primary.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _PersonalityPill(
                      name: currentUser?.name.split(' ').first ?? 'match.you'.tr(),
                      type: currentUser?.personalityProfile?.dominantType,
                    ),
                    Column(
                      children: [
                        Text(
                          '%$score',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: context.colors.primary,
                          ),
                        ),
                        Text(
                          'match.compatibility'.tr(),
                          style: TextStyle(
                            fontSize: 11,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    _PersonalityPill(
                      name: selectedFriend.name.split(' ').first,
                      type: selectedFriend.personalityProfile?.dominantType,
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Yükleme / Hata / Sonuç ───────────────────────────────────────────
        if (searchState.isLoading)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: context.colors.primary),
                  SizedBox(height: 16),
                  Text(
                    'match.loading_venues'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (searchState.errorMessage != null)
          SliverFillRemaining(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_off_outlined,
                      size: 56,
                      color: context.colors.hint,
                    ),
                    SizedBox(height: 16),
                    Text(
                      searchState.errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.colors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: onBack,
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      label: Text(
                        'common.back'.tr(),
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else ...[
          // ── Mesafe uyarısı (orta nokta hesaplanamadıysa) ──────────────────
          if (searchState.distanceWarning != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFA000).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFFA000).withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: Color(0xFFFFA000),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          searchState.distanceWarning!,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: context.colors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Orta nokta mekanları (üstte, özel bölüm) ──────────────────────
          if (searchState.hasMidpoint && searchState.midpointVenues.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.my_location,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'match.midpoint_badge'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    ...searchState.midpointVenues.asMap().entries.map(
                      (e) => _VenueCard(
                        place: e.value,
                        rank: e.key + 1,
                        context: context,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'match.other_venues'.tr(),
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Başlık satırı: mekan sayısı + sayfa bilgisi
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'match.venue_count'.tr(namedArgs: {
                        'count': '${searchState.venues.length}',
                        'page': '${searchState.currentPage + 1}',
                        'total': '${searchState.totalPages}',
                      }),
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (searchState.hasNextPage)
                    GestureDetector(
                      onTap: () =>
                          ref.read(venueSearchProvider.notifier).nextPage(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: context.colors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              size: 14,
                              color: context.colors.primary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'venue.change_venue'.tr(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Mekan kartları
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _VenueCard(
                  place: searchState.venues[i],
                  rank: searchState.currentPage * 5 + i + 1,
                  context: context,
                ),
                childCount: searchState.venues.length,
              ),
            ),
          ),

          // Alt navigasyon
          if (searchState.totalPages > 1)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Önceki
                    if (searchState.hasPrevPage)
                      TextButton.icon(
                        onPressed: () =>
                            ref.read(venueSearchProvider.notifier).prevPage(),
                        icon: Icon(
                          Icons.arrow_back_ios_new,
                          size: 13,
                          color: context.colors.primary,
                        ),
                        label: Text(
                          'match.prev_page'.tr(),
                          style: TextStyle(
                            color: context.colors.primary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const Spacer(),
                    // Sayfa dots
                    Row(
                      children: List.generate(
                        searchState.totalPages,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == searchState.currentPage ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == searchState.currentPage
                                ? context.colors.primary
                                : context.colors.border,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Sonraki
                    if (searchState.hasNextPage)
                      TextButton.icon(
                        onPressed: () =>
                            ref.read(venueSearchProvider.notifier).nextPage(),
                        icon: Icon(
                          Icons.arrow_forward_ios,
                          size: 13,
                          color: context.colors.primary,
                        ),
                        label: Text(
                          'match.next_page'.tr(),
                          style: TextStyle(
                            color: context.colors.primary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ],
    );
  }
}

class _PersonalityPill extends StatelessWidget {
  final String name;
  final PersonalityType? type;

  const _PersonalityPill({required this.name, this.type});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(type?.emoji ?? '❓', style: TextStyle(fontSize: 24)),
        SizedBox(height: 4),
        Text(
          name,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.textPrimary,
          ),
        ),
        if (type != null)
          Text(
            type!.displayName,
            style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
          ),
      ],
    );
  }
}

// ── Mekan Kartı (Places API) ──────────────────────────────────────────────────

class _VenueCard extends ConsumerWidget {
  final PlaceResult place;
  final int rank;
  // ignore: avoid_field_initializers_in_const_classes
  final BuildContext context;
  const _VenueCard({
    required this.place,
    required this.rank,
    required this.context,
  });

  Color _rankColor(BuildContext ctx) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return ctx.colors.border;
  }

  Future<void> _openInMaps(WidgetRef ref) async {
    // Tarifi alınan mekanlara ekle
    await ref.read(navigatedVenuesProvider.notifier).add(place);
    final uri = Uri.parse(place.googleMapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rank <= 3
              ? _rankColor(context).withOpacity(0.5)
              : context.colors.border,
        ),
        boxShadow: rank == 1
            ? [
                BoxShadow(
                  color: context.colors.primary.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Fotoğraf ────────────────────────────────────────────────────────
          if (place.photoUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
              child: CachedNetworkImage(
                imageUrl: place.photoUrl!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  height: 160,
                  color: context.colors.primary.withOpacity(0.06),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: context.colors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (_, _, _) => Container(
                  height: 100,
                  color: context.colors.primary.withOpacity(0.06),
                  child: Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: context.colors.hint,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),

          // ── İçerik ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Üst satır: rozet + isim
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sıralama rozeti
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: rank <= 3
                            ? _rankColor(context).withOpacity(0.15)
                            : Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '$rank',
                          style: TextStyle(
                            fontSize: rank <= 3 ? 14 : 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          if (place.vicinity != null)
                            Text(
                              place.vicinity!,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 10),

                // Alt satır: tip etiketi + puan + durum + harita butonu
                Row(
                  children: [
                    // Tip etiketi
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        place.primaryTypeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Rating
                    if (place.rating != null) ...[
                      const Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: Color(0xFFFFB800),
                      ),
                      SizedBox(width: 2),
                      Text(
                        place.ratingText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      if (place.userRatingsTotal != null)
                        Text(
                          ' (${place.userRatingsTotal})',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.colors.textSecondary,
                          ),
                        ),
                    ],

                    // Fiyat etiketi
                    if (place.priceLabelText != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          place.priceLabelText!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                      ),
                    ],

                    const Spacer(),

                    // Haritada Gör (küçük link)
                    GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse(place.googleMapsUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_new, size: 13, color: context.colors.hint),
                          SizedBox(width: 3),
                          Text(
                            'match.open_maps'.tr(),
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colors.hint,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ── Kaydet + Gitmeye Başla ───────────────────────────────────
                const SizedBox(height: 10),
                Consumer(
                  builder: (ctx, ref, _) {
                    final isSaved = ref.watch(savedVenuesProvider
                        .select((list) => list.any((p) => p.placeId == place.placeId)));
                    return Row(
                      children: [
                        // Kaydet butonu
                        Expanded(
                          child: GestureDetector(
                            onTap: () => ref
                                .read(savedVenuesProvider.notifier)
                                .toggle(place),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: isSaved
                                    ? context.colors.primary.withOpacity(0.12)
                                    : context.colors.card,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSaved
                                      ? context.colors.primary
                                      : context.colors.border,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isSaved
                                        ? Icons.bookmark
                                        : Icons.bookmark_border_outlined,
                                    size: 15,
                                    color: isSaved
                                        ? context.colors.primary
                                        : context.colors.textSecondary,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    isSaved
                                        ? 'match.saved'.tr()
                                        : 'match.save'.tr(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isSaved
                                          ? context.colors.primary
                                          : context.colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Gitmeye Başla butonu
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _openInMaps(ref),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: context.colors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.navigation_outlined,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'match.navigate'.tr(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // Açık mı?
                if (place.isOpenNow) ...[
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF3FB950),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'match.now_open'.tr(),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
                                                             