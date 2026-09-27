import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/constants/app_config.dart';
import 'package:meetit/core/constants/map_styles.dart';
import 'package:meetit/core/constants/supported_cities.dart';
import 'package:meetit/features/match/providers/match_provider.dart';

// ── Harita ile Konum Seçme Sayfası ───────────────────────────────────────────

class MapLocationPickerPage extends StatefulWidget {
  final LatLng? initial;

  const MapLocationPickerPage({super.key, this.initial});

  @override
  State<MapLocationPickerPage> createState() => _MapLocationPickerPageState();
}

/// 🗺️ KAPSAM (2026-09-27): Uygulama Türkiye'nin en büyük 10 ilinde açık —
/// liste ve il kutuları `core/constants/supported_cities.dart`'ta (önceden
/// burada sadece İstanbul kutusu vardı). Harita Türkiye geneline
/// kaydırılabiliyor; seçilen noktanın desteklenen bir ilde olup olmadığı
/// kamera durduğunda ve onay anında kontrol ediliyor.
bool _isSupported(LatLng pos) =>
    SupportedCities.contains(pos.latitude, pos.longitude);

final LatLngBounds _turkeyBox = LatLngBounds(
  southwest: const LatLng(
    SupportedCities.turkeyMinLat,
    SupportedCities.turkeyMinLng,
  ),
  northeast: const LatLng(
    SupportedCities.turkeyMaxLat,
    SupportedCities.turkeyMaxLng,
  ),
);

String _outOfScopeText() => 'map_picker.out_of_scope_warning'.tr(
  namedArgs: {'cities': SupportedCities.namesText},
);

class _MapLocationPickerPageState extends State<MapLocationPickerPage> {
  GoogleMapController? _mapController;
  LatLng _center = LatLng(
    SupportedCities.fallback.centerLat,
    SupportedCities.fallback.centerLng,
  ); // varsayılan: listedeki ilk şehir (İstanbul)
  String? _address;
  String? _outOfScopeWarning;

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
      // Daha önce kaydedilmiş bir konum desteklenen şehirlerin dışındaysa
      // (örn. eski bir kayıt veya GPS hatası), kullanıcıyı doğrudan o
      // noktada bırakmak yerine varsayılan şehre çekiyoruz.
      _center = _isSupported(widget.initial!)
          ? widget.initial!
          : _center;
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
      if (!_isSupported(latLng)) {
        // Kullanıcının GERÇEK GPS konumu desteklenen şehirlerin dışında —
        // haritayı varsayılan şehirde bırakıp kullanıcıyı bilgilendiriyoruz.
        setState(() {
          _outOfScopeWarning = _outOfScopeText();
        });
        return;
      }
      setState(() {
        _center = latLng;
        _outOfScopeWarning = null;
      });
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
    // Kapsam kontrolü (desteklenen şehir mi) kamera durunca
    // (onCameraIdle) yapılıyor — setState'i her kamera karesinde
    // tetiklememek için burada çağırmıyoruz.
  }

  void _onCameraIdle() {
    final outOfScope = !_isSupported(_center);
    setState(() {
      _outOfScopeWarning = outOfScope ? _outOfScopeText() : null;
    });
    if (!outOfScope) {
      _fetchAddress(_center);
    }
  }

  Future<void> _confirm() async {
    if (!_isSupported(_center)) {
      // Desteklenen şehirlerin dışında bir nokta onaylanamaz.
      setState(() {
        _outOfScopeWarning = _outOfScopeText();
      });
      return;
    }
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

  /// Üstteki şehir butonlarından birine dokununca haritayı o şehrin
  /// merkezine götürür (kamera durunca adres + kapsam kontrolü kendiliğinden
  /// çalışır).
  void _jumpToCity(SupportedCity city) {
    final target = LatLng(city.centerLat, city.centerLng);
    _center = target;
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 12));
  }

  @override
  Widget build(BuildContext context) {
    final currentCity =
        SupportedCities.cityAt(_center.latitude, _center.longitude);
    return Scaffold(
      body: Stack(
        children: [
          // ── Harita ───────────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _center, zoom: 14),
            // Harita Türkiye geneline kaydırılabiliyor; desteklenen şehir
            // kontrolü onCameraIdle / onay anında yapılıyor.
            cameraTargetBounds: CameraTargetBounds(_turkeyBox),
            minMaxZoomPreference: const MinMaxZoomPreference(5, 20),
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
                Icon(Iconsax.location, size: 48, color: Color(0xFFE53935)),
                SizedBox(height: 24), // pin'in alt ucu tam ortada dursun
              ],
            ),
          ),

          // ── Üst: geri + başlık + şehir butonları ─────────────────────────
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
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
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Icon(
                            Iconsax.arrow_left_2,
                            size: 16,
                            color: Theme.of(context).brightness != Brightness.dark
                                ? Colors.black87
                                : Colors.white70,
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
                                color: Colors.black.withValues(alpha: 0.1),
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
                // Desteklenen şehirler — dokununca harita o şehre gider.
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: SupportedCities.all.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final city = SupportedCities.all[i];
                      final selected = currentCity?.name == city.name;
                      return GestureDetector(
                        onTap: () => _jumpToCity(city),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? context.colors.primary
                                : context.colors.card,
                            borderRadius: BorderRadius.circular(17),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Text(
                            city.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : context.colors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
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
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  Iconsax.gps,
                  size: 22,
                  color: context.colors.primary,
                ),
              ),
            ),
          ),

          // ── Kapsam dışı uyarısı (desteklenen şehirler dışı) ─────────────────────────────
          if (_outOfScopeWarning != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 110,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Iconsax.info_circle,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _outOfScopeWarning!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Alt: Onayla butonu ────────────────────────────────────────────
          Positioned(
            left: 20,
            right: 20,
            bottom: 40,
            child: ElevatedButton(
              onPressed: (_isConfirming || _outOfScopeWarning != null)
                  ? null
                  : _confirm,
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
                          Iconsax.check,
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
