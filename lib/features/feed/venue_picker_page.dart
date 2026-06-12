import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/constants/app_config.dart';
import 'package:meetit/features/match/match_page.dart';
import 'package:meetit/features/match/providers/match_provider.dart';

/// Kullanıcının seçtiği mekanın özeti
class PickedVenue {
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String? photoUrl;

  const PickedVenue({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.photoUrl,
  });
}

/// Konum al → yakındaki mekanları listele → arama yap → seç
class VenuePickerPage extends StatefulWidget {
  const VenuePickerPage({super.key});

  @override
  State<VenuePickerPage> createState() => _VenuePickerPageState();
}

class _VenuePickerPageState extends State<VenuePickerPage> {
  final _searchCtrl = TextEditingController();

  double? _lat;
  double? _lng;
  String? _locationLabel;

  List<_NearbyPlace> _allPlaces = [];
  List<_NearbyPlace> _filtered = [];

  bool _isLoadingLocation = false;
  bool _isLoadingPlaces = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _getGpsAndLoad();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── GPS + Places yükleme ─────────────────────────────────────────────────

  Future<void> _getGpsAndLoad() async {
    setState(() {
      _isLoadingLocation = true;
      _errorText = null;
    });

    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() {
          _isLoadingLocation = false;
          _errorText = 'Konum izni gerekli. Haritadan manuel seçebilirsin.';
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _lat = pos.latitude;
      _lng = pos.longitude;
      _locationLabel = await _reverseGeocode(_lat!, _lng!);

      setState(() => _isLoadingLocation = false);
      await _loadNearbyPlaces();
    } catch (_) {
      setState(() {
        _isLoadingLocation = false;
        _errorText = 'Konum alınamadı. Haritadan seçebilirsin.';
      });
    }
  }

  /// Haversine — iki nokta arası metre cinsinden gerçek mesafe
  double _distanceM(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final dPhi = (lat2 - lat1) * math.pi / 180;
    final dLam = (lon2 - lon1) * math.pi / 180;
    final a =
        math.sin(dPhi / 2) * math.sin(dPhi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(dLam / 2) *
            math.sin(dLam / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  Future<void> _loadNearbyPlaces({String? keyword}) async {
    if (_lat == null || _lng == null) return;
    setState(() {
      _isLoadingPlaces = true;
      _allPlaces = [];
      _filtered = [];
    });

    final places = <_NearbyPlace>[];

    if (keyword != null && keyword.isNotEmpty) {
      // Arama varsa keyword ile tek istek
      final batch = await _fetchNearby(keyword: keyword);
      places.addAll(batch);
    } else {
      // Arama yoksa birkaç type
      for (final type in [
        'restaurant',
        'cafe',
        'bar',
        'park',
        'museum',
        'shopping_mall',
        'gym',
        'movie_theater',
        'night_club',
        'bakery',
      ]) {
        if (places.length >= 50) break;
        final batch = await _fetchNearby(type: type);
        for (final p in batch) {
          if (!places.any((x) => x.placeId == p.placeId)) {
            places.add(p);
          }
        }
      }
    }

    // Her mekanın mesafesini hesapla ve kaydet
    for (final p in places) {
      p.distanceM = _distanceM(_lat!, _lng!, p.lat, p.lng);
    }
    // Her zaman en yakından en uzağa sırala
    places.sort((a, b) => a.distanceM.compareTo(b.distanceM));

    setState(() {
      _allPlaces = places;
      _filtered = places;
      _isLoadingPlaces = false;
    });
  }

  Future<List<_NearbyPlace>> _fetchNearby({
    String? type,
    String? keyword,
  }) async {
    try {
      final params = <String, String>{
        'location': '$_lat,$_lng',
        'radius': '5000', // 5 km
        'language': 'tr',
        'key': AppConfig.googleMapsApiKey,
      };
      if (type != null) params['type'] = type;
      if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;

      final uri = Uri.parse(
        AppConfig.placesNearbyUrl,
      ).replace(queryParameters: params);
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['status'] != 'OK') return [];
      final results = body['results'] as List? ?? [];
      return results.take(10).map((r) {
        final loc = r['geometry']['location'];
        final photos = r['photos'] as List?;
        String? photoUrl;
        if (photos != null && photos.isNotEmpty) {
          final ref = photos.first['photo_reference'] as String?;
          if (ref != null) {
            photoUrl =
                '${AppConfig.placesPhotoUrl}?maxwidth=400&photo_reference=$ref&key=${AppConfig.googleMapsApiKey}';
          }
        }
        return _NearbyPlace(
          placeId: r['place_id'] as String,
          name: r['name'] as String,
          address: r['vicinity'] as String? ?? '',
          lat: (loc['lat'] as num).toDouble(),
          lng: (loc['lng'] as num).toDouble(),
          rating: (r['rating'] as num?)?.toDouble(),
          photoUrl: photoUrl,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$lat,$lng&language=tr&result_type=locality|sublocality'
        '&key=${AppConfig.googleMapsApiKey}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['status'] == 'OK') {
        final results = body['results'] as List;
        if (results.isNotEmpty) {
          return results.first['formatted_address'] as String?;
        }
      }
    } catch (_) {}
    return null;
  }

  // ── Arama ────────────────────────────────────────────────────────────────

  void _onSearch(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) {
      // Boşsa local listeden göster
      setState(() => _filtered = _allPlaces);
      return;
    }

    // Önce mevcut listede filtrele (anlık)
    final localMatch = _allPlaces
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) ||
              p.address.toLowerCase().contains(q),
        )
        .toList();
    setState(() => _filtered = localMatch);

    // Eğer local sonuç azsa API'ye keyword ile sor
    if (localMatch.length < 3) {
      _loadNearbyPlaces(keyword: query);
    }
  }

  // ── Haritadan konum değiştir ──────────────────────────────────────────────

  Future<void> _changeLocationFromMap() async {
    final result = await Navigator.of(context).push<UserLocation>(
      MaterialPageRoute(
        builder: (_) => MapLocationPickerPage(
          initial: _lat != null && _lng != null ? LatLng(_lat!, _lng!) : null,
        ),
      ),
    );
    if (result != null && result.lat != null) {
      _lat = result.lat;
      _lng = result.lng;
      _locationLabel = result.text;
      await _loadNearbyPlaces();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: context.colors.scaffold,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: context.colors.textPrimary,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mekan Seç',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Konum kartı — tüm kart tıklanabilir ───────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(
              children: [
                // Aktif konum al
                Expanded(
                  child: GestureDetector(
                    onTap: _isLoadingLocation ? null : _getGpsAndLoad,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.primary.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: context.colors.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (_isLoadingLocation)
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.colors.primary,
                              ),
                            )
                          else
                            Icon(
                              Icons.my_location,
                              size: 15,
                              color: context.colors.primary,
                            ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _isLoadingLocation
                                  ? 'Konum alınıyor...'
                                  : _locationLabel ?? 'Konumumu Al',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                // Haritadan seç
                GestureDetector(
                  onTap: _changeLocationFromMap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.map_outlined,
                          size: 15,
                          color: context.colors.textPrimary,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Konum Seç',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 12),

          // ── Arama ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Mekan ara...',
                hintStyle: TextStyle(color: context.colors.hint, fontSize: 14),
                prefixIcon: Icon(
                  Icons.search,
                  color: context.colors.hint,
                  size: 20,
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close,
                          color: context.colors.hint,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: context.colors.card,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: context.colors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: 12),

          // ── Liste ─────────────────────────────────────────────────────
          Expanded(
            child: _isLoadingPlaces
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: context.colors.primary,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Yakındaki mekanlar yükleniyor...',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : _errorText != null && _allPlaces.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_off_outlined,
                            size: 48,
                            color: context.colors.hint,
                          ),
                          SizedBox(height: 12),
                          Text(
                            _errorText!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.colors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _changeLocationFromMap,
                            icon: Icon(
                              Icons.map_outlined,
                              color: Colors.white,
                              size: 16,
                            ),
                            label: Text(
                              'Haritadan Seç',
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
                  )
                : _filtered.isEmpty
                ? Center(
                    child: Text(
                      'Mekan bulunamadı.',
                      style: TextStyle(color: context.colors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = _filtered[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        leading: p.photoUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  p.photoUrl!,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => _PlaceIcon(),
                                ),
                              )
                            : _PlaceIcon(),
                        title: Text(
                          p.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.address,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                // Mesafe
                                Icon(
                                  Icons.near_me_outlined,
                                  size: 11,
                                  color: context.colors.hint,
                                ),
                                SizedBox(width: 2),
                                Text(
                                  _formatDistance(p.distanceM),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.colors.hint,
                                  ),
                                ),
                                if (p.rating != null) ...[
                                  SizedBox(width: 8),
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 11,
                                    color: Color(0xFFFFB800),
                                  ),
                                  SizedBox(width: 2),
                                  Text(
                                    p.rating!.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        onTap: () => Navigator.pop(
                          context,
                          PickedVenue(
                            name: p.name,
                            address: p.address,
                            lat: p.lat,
                            lng: p.lng,
                            photoUrl: p.photoUrl,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PlaceIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: context.colors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.place_outlined,
        color: context.colors.primary,
        size: 24,
      ),
    );
  }
}

// ── Model ────────────────────────────────────────────────────────────────────

class _NearbyPlace {
  final String placeId;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final double? rating;
  final String? photoUrl;
  double distanceM;

  _NearbyPlace({
    required this.placeId,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.rating,
    this.photoUrl,
    this.distanceM = 0,
  });
}
