import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:meetit/features/match/models/place_result.dart';

// ── Harita Pin Üretimi ─────────────────────────────────────────────────────────
//
// `AttemptMeetPage`'in (harita görünümü) mekan/kişi pinlerini oluşturan
// yardımcı fonksiyonlar — sayfa view dosyasının kendisi yerine ayrı bir
// utility dosyasına taşındı (bkz. attempt_meet_page.dart).
class MapMarkerBuilder {
  MapMarkerBuilder._();

  /// Mekan pini — Google'ın standart pin şekli, sıralamaya göre renklendirilir
  /// (1. sıra altın, 2. sıra gümüş tonu, 3. sıra bronz tonu, diğerleri kırmızı).
  /// Kasıtlı olarak kişi pinlerinden (avatar) tamamen farklı/standart bırakıldı.
  static Marker buildVenueMarker({
    required PlaceResult place,
    required int rankIndex,
    required VoidCallback onTap,
  }) {
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
      onTap: onTap,
    );
  }

  /// Kişi pini (kendi konumum / arkadaşım) — dairesel, ortasında profil
  /// fotoğrafı (varsa) ya da baş harfli avatar (yoksa). Mekan pinlerinden
  /// bilerek daha büyük ve tamamen farklı bir görünümde.
  static Future<Marker> buildPersonMarker({
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
  static Future<BitmapDescriptor> _renderAvatarBitmap({
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

  static Color _pickColorFor(String seed) =>
      _avatarColors[seed.hashCode.abs() % _avatarColors.length];

  static String _initialsOf(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}
