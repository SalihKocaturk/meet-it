import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/constants/map_styles.dart';
import 'package:meetit/core/providers/theme_provider.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/match/models/place_result.dart';
import 'package:meetit/features/match/providers/match_provider.dart';
import 'package:meetit/features/match/providers/saved_venues_provider.dart';
import 'package:meetit/features/match/providers/venue_search_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Mekan önerilerini harita üzerinde pinlerle gösteren alternatif görünüm.
///
/// ÖNEMLİ: Bu sayfa mevcut liste tabanlı `_VenueResultsView` akışına HİÇ
/// dokunmaz — `match_page.dart`'taki "Mekan Önerilerini Gör" butonu ve
/// onun mantığı tamamen olduğu gibi kalıyor. Bu, "Haritada Göster" adında
/// AYRI bir butonla açılan, ek bir görünüm. Bir sorun çıkarsa eski akış
/// sapasağlam çalışmaya devam eder.
///
/// Kurgu:
///   - Mekan arama sonucundaki TÜM mekanlar (sayfalama olmadan) haritada
///     pin olarak gösterilir. 1. sıradaki mekan ekrana ilk geldiğinde
///     kamera otomatik o pine odaklanır.
///   - Alt bilgi çubuğunda seçili mekanın kart bilgileri (foto, isim, tip,
///     puan, fiyat, kaydet/git butonları) gösterilir; ok tuşlarıyla diğer
///     mekanlara geçilebilir, pin'e dokununca da o mekan seçilir.
///   - Kendi konumum, mekan pinlerinden tamamen farklı/daha büyük, dairesel
///     bir pin ile gösterilir: fotoğrafım varsa yuvarlak halde o, yoksa
///     diğer yerlerde kullandığımız baş harfli avatar mantığıyla aynı.
///   - Eşleştiğim arkadaşımın konumu Firestore'da girilmişse, aynı mantıkla
///     onun da (kendi foto/avatarıyla) bir pin'i çıkar.
class AttemptMeetPage extends ConsumerStatefulWidget {
  const AttemptMeetPage({super.key});

  @override
  ConsumerState<AttemptMeetPage> createState() => _AttemptMeetPageState();
}

class _AttemptMeetPageState extends ConsumerState<AttemptMeetPage> {
  GoogleMapController? _mapController;
  int _selectedIndex = 0;
  bool _markersReady = false;

  List<PlaceResult> _venues = [];
  final Map<String, Marker> _venueMarkers = {};
  Marker? _meMarker;
  Marker? _friendMarker;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final state = ref.read(venueSearchProvider);
    // Sıralama: önce orta noktaya yakın mekanlar, sonra diğerleri — liste
    // görünümündeki ile aynı genel sıra mantığı.
    final venues = [...state.midpointVenues, ...state.allVenues];

    final currentUser = ref.read(currentUserProvider);
    final selectedFriend = ref.read(selectedFriendProvider);
    final userLoc = ref.read(userLocationProvider);

    // ── Kendi konumum ───────────────────────────────────────────────────
    //
    // ÖNEMLİ: `state.searchLat`/`searchLng` orta nokta hesaplandığında
    // (hasMidpoint == true) kendi gerçek konumum DEĞİL, ikimizin arasındaki
    // orta noktadır — bu yüzden kendi pinim için asla onu kullanmıyoruz.
    // Notifier, arama sırasında gerçekten kullanılan ham konumu
    // `state.myLat`/`myLng` içinde sakladığı için önce onu deniyoruz;
    // sonra manuel girilmiş konumu (`userLocationProvider`).
    double? myLat = state.myLat ?? userLoc?.lat;
    double? myLng = state.myLng ?? userLoc?.lng;
    if ((myLat == null || myLng == null) && !state.hasMidpoint) {
      // Orta nokta hesaplanmadıysa (tek başına arama) searchLat/Lng zaten
      // kendi konumumdur.
      myLat = state.searchLat;
      myLng = state.searchLng;
    }

    // ── Arkadaşımın konumu ──────────────────────────────────────────────
    // Notifier arama sırasında arkadaşın konumunu zaten Firestore'dan
    // çekip `state.friendLat`/`friendLng` içinde saklıyor — önce onu
    // kullanıyoruz, sadece eksikse aşağıda tekrar Firestore'a soruyoruz.
    double? friendLat = state.friendLat ?? selectedFriend?.lat;
    double? friendLng = state.friendLng ?? selectedFriend?.lng;
    if ((friendLat == null || friendLng == null) && selectedFriend != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(selectedFriend.uid)
            .get();
        if (doc.exists) {
          friendLat = (doc.data()?['lat'] as num?)?.toDouble() ?? friendLat;
          friendLng = (doc.data()?['lng'] as num?)?.toDouble() ?? friendLng;
        }
      } catch (_) {
        // Firestore'dan çekilemezse elimizdeki (varsa) eski değerle devam.
      }
    }

    // ── Mekan pinleri ────────────────────────────────────────────────────
    final venueMarkers = <String, Marker>{};
    for (var i = 0; i < venues.length; i++) {
      final place = venues[i];
      venueMarkers[place.placeId] = _buildVenueMarker(place, i);
    }

    // ── Kişi pinleri (foto/avatar render'ı asenkron) ─────────────────────
    Marker? meMarker;
    if (myLat != null && myLng != null) {
      meMarker = await _buildPersonMarker(
        id: 'me',
        lat: myLat,
        lng: myLng,
        name: currentUser?.name ?? 'match.map_you'.tr(),
        photoUrl: currentUser?.photoUrl,
        borderColor: const Color(0xFF6C5CE7),
        size: 54,
      );
    }

    Marker? friendMarker;
    if (friendLat != null && friendLng != null) {
      friendMarker = await _buildPersonMarker(
        id: 'friend',
        lat: friendLat,
        lng: friendLng,
        name: selectedFriend?.name ?? 'match.map_friend'.tr(),
        photoUrl: selectedFriend?.photoUrl,
        borderColor: const Color(0xFFE17055),
        size: 48,
      );
    }

    if (!mounted) return;

    setState(() {
      _venues = venues;
      _venueMarkers
        ..clear()
        ..addAll(venueMarkers);
      _meMarker = meMarker;
      _friendMarker = friendMarker;
      _markersReady = true;
    });

    // İlk sıradaki mekana odaklan.
    if (venues.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 350), () {
        _focusOn(venues.first);
      });
    }
  }

  void _focusOn(PlaceResult place) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(place.lat, place.lng), 15.5),
    );
  }

  void _selectVenue(int index) {
    if (index < 0 || index >= _venues.length) return;
    setState(() => _selectedIndex = index);
    _focusOn(_venues[index]);
  }

  // ── Marker oluşturma yardımcıları ────────────────────────────────────────

  /// Mekan pini — Google'ın standart pin şekli, sıralamaya göre renklendirilir
  /// (1. sıra altın, 2. sıra gümüş tonu, 3. sıra bronz tonu, diğerleri kırmızı).
  /// Kasıtlı olarak kişi pinlerinden (avatar) tamamen farklı/standart bırakıldı.
  Marker _buildVenueMarker(PlaceResult place, int rankIndex) {
    double hue;
    if (rankIndex == 0) {
      hue = 45; // altın/sarı
    } else if (rankIndex == 1) {
      hue = 200; // gümüşe yakın açık mavi
    } else if (rankIndex == 2) {
      hue = 25; // bronza yakın turuncu-kahve
    } else {
      hue = 0; // standart kırmızı
    }
    return Marker(
      markerId: MarkerId(place.placeId),
      position: LatLng(place.lat, place.lng),
      icon: BitmapDescriptor.defaultMarkerWithHue(hue),
      anchor: const Offset(0.5, 1.0),
      onTap: () {
        final idx = _venues.indexWhere((p) => p.placeId == place.placeId);
        if (idx != -1) _selectVenue(idx);
      },
    );
  }

  /// Kişi pini (kendi konumum / arkadaşım) — dairesel, ortasında profil
  /// fotoğrafı (varsa) ya da baş harfli avatar (yoksa). Mekan pinlerinden
  /// bilerek daha büyük ve tamamen farklı bir görünümde.
  Future<Marker> _buildPersonMarker({
    required String id,
    required double lat,
    required double lng,
    required String name,
    required String? photoUrl,
    required Color borderColor,
    required double size,
  }) async {
    final icon = await _renderAvatarBitmap(
      photoUrl: photoUrl,
      name: name,
      size: size,
      borderColor: borderColor,
    );
    return Marker(
      markerId: MarkerId(id),
      position: LatLng(lat, lng),
      icon: icon,
      anchor: const Offset(0.5, 0.5),
      zIndex: 10,
      consumeTapEvents: true,
    );
  }

  /// `dart:ui` Canvas ile dairesel, renkli kenarlıklı bir avatar pin'i
  /// rasterize eder. Fotoğraf varsa indirip daire içine kırpar, yoksa
  /// `CircularAvatar` widget'ındaki ile aynı mantıkla baş harfli, renkli
  /// bir daire çizer.
  ///
  /// ÖNEMLİ: `BitmapDescriptor.bytes(...)` cihazın piksel oranını
  /// (devicePixelRatio) otomatik dikkate almaz — bu yüzden `imagePixelRatio`
  /// belirtilmezse pin, özellikle yüksek çözünürlüklü (Retina/yüksek DPI)
  /// ekranlarda gerçek boyutunun kat kat büyüğü görünür. Burada bitmap'i
  /// `size * devicePixelRatio` piksel olarak (keskin görünüm için) çiziyoruz
  /// ama `imagePixelRatio` parametresiyle haritaya "bu görsel `size` mantıksal
  /// piksel genişliğinde gösterilsin" bilgisini veriyoruz; böylece pin ekranda
  /// her cihazda aynı, doğru fiziksel boyutta görünür.
  Future<BitmapDescriptor> _renderAvatarBitmap({
    required String? photoUrl,
    required String name,
    required double size,
    required Color borderColor,
  }) async {
    try {
      final dpr = ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
      final renderSize = size * dpr;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, renderSize, renderSize),
      );
      final radius = renderSize / 2;
      final borderWidth = 5.0 * dpr;

      // Dış renkli halka + beyaz ayraç
      canvas.drawCircle(
        Offset(radius, radius),
        radius,
        Paint()..color = borderColor,
      );
      canvas.drawCircle(
        Offset(radius, radius),
        radius - borderWidth,
        Paint()..color = Colors.white,
      );

      final innerRadius = radius - borderWidth - (3 * dpr);
      ui.Image? avatarImage;

      if (photoUrl != null && photoUrl.isNotEmpty) {
        try {
          final response = await http
              .get(Uri.parse(photoUrl))
              .timeout(const Duration(seconds: 6));
          if (response.statusCode == 200) {
            final codec = await ui.instantiateImageCodec(
              response.bodyBytes,
              targetWidth: (innerRadius * 2).round(),
              targetHeight: (innerRadius * 2).round(),
            );
            final frame = await codec.getNextFrame();
            avatarImage = frame.image;
          }
        } catch (_) {
          // Fotoğraf indirilemezse aşağıda baş harfli avatara düşülür.
        }
      }

      if (avatarImage != null) {
        canvas.save();
        final clipPath = Path()
          ..addOval(
            Rect.fromCircle(
              center: Offset(radius, radius),
              radius: innerRadius,
            ),
          );
        canvas.clipPath(clipPath);
        canvas.drawImage(
          avatarImage,
          Offset(radius - innerRadius, radius - innerRadius),
          Paint(),
        );
        canvas.restore();
      } else {
        canvas.drawCircle(
          Offset(radius, radius),
          innerRadius,
          Paint()..color = _pickColorFor(name),
        );
        final initials = _initialsOf(name);
        final textPainter = TextPainter(
          text: TextSpan(
            text: initials,
            style: TextStyle(
              color: Colors.white,
              fontSize: innerRadius * 0.85,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(
            radius - textPainter.width / 2,
            radius - textPainter.height / 2,
          ),
        );
      }

      final picture = recorder.endRecording();
      final img = await picture.toImage(
        renderSize.round(),
        renderSize.round(),
      );
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      return BitmapDescriptor.bytes(
        bytes!.buffer.asUint8List(),
        imagePixelRatio: dpr,
      );
    } catch (_) {
      return BitmapDescriptor.defaultMarker;
    }
  }

  static const _avatarColors = [
    Color(0xFF0984E3),
    Color(0xFF00B894),
    Color(0xFFE17055),
    Color(0xFF6C5CE7),
    Color(0xFF00CEC9),
    Color(0xFFD63031),
  ];

  Color _pickColorFor(String seed) =>
      _avatarColors[seed.hashCode.abs() % _avatarColors.length];

  String _initialsOf(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Future<void> _openInMaps(PlaceResult place) async {
    await ref.read(navigatedVenuesProvider.notifier).add(place);
    final uri = Uri.parse(place.googleMapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialTarget = _venues.isNotEmpty
        ? LatLng(_venues.first.lat, _venues.first.lng)
        : const LatLng(41.0082, 28.9784); // İstanbul varsayılan
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialTarget,
              zoom: 14,
            ),
            // Uygulama teması koyu ise haritayı da koyu stille aç.
            style: isDark ? darkMapStyle : null,
            onMapCreated: (ctrl) {
              _mapController = ctrl;
              // `style` parametresi ilk render'da uygulanır; ama tema
              // çalışma zamanında değişirse (didUpdateWidget yok) burada
              // da set ediyoruz ki tutarlı kalsın.
              ctrl.setMapStyle(isDark ? darkMapStyle : null);
              if (_venues.isNotEmpty) {
                Future.delayed(const Duration(milliseconds: 200), () {
                  _focusOn(_venues.first);
                });
              }
            },
            // SADECE şu an alt çubukta gösterilen (seçili) mekanın pini
            // çıkar — tüm mekanları aynı anda göstermek kalabalık ve
            // kafa karıştırıcı oluyordu. Sırada ilerlerken (ok tuşları)
            // her adımda haritada da tek bir pin görünür.
            markers: {
              if (_venues.isNotEmpty &&
                  _venueMarkers[_venues[_selectedIndex].placeId] != null)
                _venueMarkers[_venues[_selectedIndex].placeId]!,
              if (_meMarker != null) _meMarker!,
              if (_friendMarker != null) _friendMarker!,
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          if (!_markersReady)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.only(top: 64, left: 12, right: 12),
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text('match.map_loading_venues'.tr()),
                    ],
                  ),
                ),
              ),
            ),

          // ── Üst: geri butonu ─────────────────────────────────────────────
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
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Alt: seçili mekan kartı + gezinme ──────────────────────────────
          if (_venues.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Kullanıcı haritayı yakınlaştırıp/uzaklaştırıp pini
                    // gözden kaybetmiş olsa bile, bu butonla seçili
                    // mekanın pinine her zaman geri dönülebilir.
                    Padding(
                      padding: const EdgeInsets.only(right: 12, bottom: 10),
                      child: GestureDetector(
                        onTap: () => _focusOn(_venues[_selectedIndex]),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: context.colors.card,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.center_focus_strong),
                        ),
                      ),
                    ),
                    _VenueBottomBar(
                      place: _venues[_selectedIndex],
                      index: _selectedIndex,
                      total: _venues.length,
                      onPrev: _selectedIndex > 0
                          ? () => _selectVenue(_selectedIndex - 1)
                          : null,
                      onNext: _selectedIndex < _venues.length - 1
                          ? () => _selectVenue(_selectedIndex + 1)
                          : null,
                      onOpenMaps: () => _openInMaps(_venues[_selectedIndex]),
                    ),
                  ],
                ),
              ),
            )
          else if (_markersReady)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: SafeArea(
                top: false,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.colors.card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'match.no_venues_found'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.colors.textSecondary),
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

// ── Alt Bilgi Çubuğu ─────────────────────────────────────────────────────────

class _VenueBottomBar extends ConsumerWidget {
  final PlaceResult place;
  final int index;
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onOpenMaps;

  const _VenueBottomBar({
    required this.place,
    required this.index,
    required this.total,
    required this.onPrev,
    required this.onNext,
    required this.onOpenMaps,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSaved = ref.watch(
      savedVenuesProvider.select(
        (list) => list.any((p) => p.placeId == place.placeId),
      ),
    );

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Gezinme + sayaç
          Row(
            children: [
              IconButton(
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left),
                color: onPrev == null
                    ? context.colors.hint
                    : context.colors.primary,
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  'match.map_venue_of'.tr(
                    namedArgs: {
                      'current': '${index + 1}',
                      'total': '$total',
                    },
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
                color: onNext == null
                    ? context.colors.hint
                    : context.colors.primary,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Foto
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: place.photoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: place.photoUrl!,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Container(
                          width: 72,
                          height: 72,
                          color: context.colors.primary.withOpacity(0.06),
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: context.colors.hint,
                          ),
                        ),
                      )
                    : Container(
                        width: 72,
                        height: 72,
                        color: context.colors.primary.withOpacity(0.06),
                        child: Icon(
                          Icons.place_outlined,
                          color: context.colors.hint,
                        ),
                      ),
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
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            place.primaryTypeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: context.colors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (place.rating != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 13,
                                color: Color(0xFFFFB800),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                place.ratingText,
                                style: TextStyle(
                                  fontSize: 11,
 