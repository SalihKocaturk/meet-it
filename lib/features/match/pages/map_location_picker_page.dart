import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/constants/app_config.dart';
import 'package:meetit/core/constants/map_styles.dart';
import 'package:meetit/features/match/providers/match_provider.dart';

// ── Harita ile Konum Seçme Sayfası ───────────────────────────────────────────

class MapLocationPickerPage extends StatefulWidget {
  final LatLng? initial;

  const MapLocationPickerPage({super.key, this.initial});

  @override
  State<MapLocationPickerPage> createState() => _MapLocationPickerPageState();
}

/// 🗺️ KAPSAM SINIRLAMASI (2026-06-28): Uygulama şimdilik SADECE İstanbul
/// içinde kullanılabiliyor (eşleşme/mekan önerisi mantığı henüz başka
/// şehirler için test edilmedi). Bu kutu, İstanbul ilinin tüm ilçelerini
/// (Silivri'den Şile'ye) kapsayacak kadar geniş tutuldu. İleride başka
/// şehirler/bölgeler eklenmek istenirse bu tek nokta güncellenmeli — ya da
/// dinamik bir "desteklenen bölgeler" listesine dönüştürülmeli.
class _IstanbulBounds {
  // LatLngBounds'un constructor'ı const değil (runtime'da enlem/boylam
  // sınırlarını doğruluyor) — bu yüzden 'const' yerine 'final' kullanıyoruz.
  static final LatLngBounds box = LatLngBounds(
    southwest: const LatLng(40.80, 27.85),
    northeast: const LatLng(41.60, 29.95),
  );

  static bool contains(LatLng pos) {
    return pos.latitude >= box.southwest.latitude &&
        pos.latitude <= box.northeast.latitude &&
        pos.longitude >= box.southwest.longitude &&
        pos.longitude <= box.northeast.longitude;
  }
}

class _MapLocationPickerPageState extends State<MapLocationPickerPage> {
  GoogleMapController? _mapController;
  LatLng _center = const LatLng(41.0082, 28.9784); // İstanbul varsayılan
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
      // Daha önce kaydedilmiş bir konum İstanbul dışındaysa (örn. eski bir
      // kayıt veya GPS hatası), kullanıcıyı doğrudan o noktada bırakmak
      // yerine İstanbul varsayılanına çekiyoruz — harita zaten İstanbul
      // dışına çıkılamayacak şekilde sınırlı.
      _center = _IstanbulBounds.contains(widget.initial!)
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
      if (!_IstanbulBounds.contains(latLng)) {
        // Kullanıcının GERÇEK GPS konumu İstanbul dışında — uygulama
        // şimdilik sadece İstanbul kapsamında çalıştığından, haritayı
        // İstanbul varsayılanında bırakıp kullanıcıyı bilgilendiriyoruz.
        setState(() {
          _outOfScopeWarning = 'map_picker.out_of_scope_warning'.tr();
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
    // cameraTargetBounds zaten İstanbul dışına kaydırmayı engelliyor; bu
    // sadece ek bir güvenlik kontrolü (örn. zoom-out sınırında küçük taşmalar
    // için). Uyarı banner'ını anlık güncelliyoruz, setState'i build sırasında
    // tetiklememek için doğrudan burada çağırmıyoruz — onCameraIdle'da.
  }

  void _onCameraIdle() {
    final outOfScope = !_IstanbulBounds.contains(_center);
    setState(() {
      _outOfScopeWarning = outOfScope
          ? 'map_picker.out_of_scope_warning'.tr()
          : null;
    });
    if (!outOfScope) {
      _fetchAddress(_center);
    }
  }

  Future<void> _confirm() async {
    if (!_IstanbulBounds.contains(_center)) {
      // Güvenlik ağı: cameraTargetBounds normalde buraya gelmeyi
      // engelliyor ama yine de son bir kontrol yapıyoruz.
      setState(() {
        _outOfScopeWarning = 'map_picker.out_of_scope_warning'.tr();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Harita ───────────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _center, zoom: 14),
            // Uygulama şimdilik sadece İstanbul kapsamında çalıştığı için
            // harita kamerası İstanbul kutusunun dışına kaydırılamıyor.
            cameraTargetBounds: CameraTargetBounds(_IstanbulBounds.box),
            minMaxZoomPreference: const MinMaxZoomPreference(9, 20),
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
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new,
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
                  Icons.my_location,
                  size: 22,
                  color: context.colors.primary,
                ),
              ),
            ),
          ),

          // ── Kapsam dışı uyarısı (İstanbul dışı) ─────────────────────────────
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
                      Icons.info_outline,
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
