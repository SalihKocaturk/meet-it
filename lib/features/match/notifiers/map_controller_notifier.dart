import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ── Harita Kontrolcüsü ───────────────────────────────────────────────────────
//
// `GoogleMapController`, `AttemptMeetState`'in (mekan/marker verisi) bir
// PARÇASI DEĞİL — kamera animasyonu için kullanılan, render'a özgü bir
// UI nesnesi. Yine de "initState kullanma, state'i sayfadan çıkar" isteği
// gereği bunu widget'ın kendi `State` sınıfında DEĞİL, ayrı, basit bir
// Notifier'da tutuyoruz; böylece `AttemptMeetPage` tamamen `ConsumerWidget`
// (StatefulWidget değil) olabiliyor.
///
/// Sadece tek bir referans tutar; "veri" değildir, bu yüzden `copyWith` vb.
/// yok — `set()` ile atanır, `onMapCreated`'da bir kez çağrılır.
class MapControllerNotifier extends Notifier<GoogleMapController?> {
  @override
  GoogleMapController? build() => null;

  void set(GoogleMapController controller) {
    state = controller;
  }
}
