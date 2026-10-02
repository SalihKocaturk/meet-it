import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Ağ bağlantı durumu.
enum NetworkStatus {
  /// 🟢 İnternet + sunucu erişilebilir.
  connected,

  /// 🟠 İnternet var ama sunucu bakımda.
  maintenance,

  /// 🟡 Ağ arayüzü bağlı (WiFi/data) ama internet yok.
  noInternet,

  /// 🔴 Hiçbir ağ arayüzü yok (uçak modu, WiFi+data kapalı).
  noConnection,
}

/// Üç katmanlı ağ izleyici — singleton.
///
/// Katman 1 — Ağ arayüzü : [connectivity_plus] ile WiFi/mobil veri var mı?
/// Katman 2 — Gerçek internet : HEAD isteği ile paket ulaşabiliyor mu?
/// Katman 3 — Sunucu durumu : Firestore [appConfig/maintenance] belgesi aktif mi?
///
/// Kullanım:
///   `main()` içinde `NetworkService.instance.init()` çağır.
///   [networkStatusProvider] aracılığıyla dinle.
///
/// 📍 ARKA PLAN DÜZELTMESİ (2026-10-02): Uygulama arka plana alınıp geri
/// gelince banner ~10 sn boyunca yanlışlıkla "bağlantı yok" gösteriyordu
/// (ve MainPage bu sürede tüm dokunuşları AbsorbPointer ile kilitliyordu).
/// Sebep: arka planda işletim sistemi ağ soketlerini donduruyor — o sırada
/// başlamış/periyodik bir kontrol zaman aşımına düşüp "internet yok"
/// sonucu üretiyor, ya da dönüşteki ilk kontrol ağ henüz uyanmadan
/// yapılıyor. Çözüm:
///   • Uygulama yaşam döngüsü dinleniyor: arka plandayken kontrol
///     yapılmıyor, o sırada yarım kalan kontrollerin sonucu ÇÖPE atılıyor.
///   • Dönüşte kısa bir gecikmeyle taze kontrol yapılıyor.
///   • "Bağlantı koptu" gibi KÖTÜ bir sonuç, kısa aralıklarla tekrar
///     doğrulanmadan yayınlanmıyor (geçici hatalar yanlış alarm vermesin);
///     İYİ sonuçlar (bağlantı geldi) ise anında yayınlanıyor.
class NetworkService with WidgetsBindingObserver {
  NetworkService._();
  static final NetworkService instance = NetworkService._();

  final _connectivity = Connectivity();
  final _controller = StreamController<NetworkStatus>.broadcast();

  NetworkStatus _current = NetworkStatus.connected;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _pollTimer;
  Timer? _debounce;

  /// Uygulama arka plandayken true — kontrol yapılmaz.
  bool _paused = false;

  /// Arka plana geçiş/dönüşte artar; eski (yarım kalmış) kontrollerin
  /// sonucunu ayırt edip yok saymak için.
  int _generation = 0;

  /// Aynı anda tek kontrol çalışsın; arada gelen istekler sıraya alınır.
  bool _checking = false;
  bool _pendingCheck = false;

  /// Kötü sonucu yayınlamadan önce yapılacak ek doğrulama sayısı ve aralığı.
  static const int _confirmRetries = 2;
  static const Duration _confirmDelay = Duration(milliseconds: 1500);

  /// Mevcut durum — provider'ın başlangıç değeri için kullanılır.
  NetworkStatus get current => _current;

  /// Durum değişikliklerini yayınlayan stream.
  Stream<NetworkStatus> get stream => _controller.stream;

  /// Servisi başlatır. Genellikle [main()] içinde Firebase init'ten sonra çağrılır.
  void init() {
    // Arka plana alma / geri dönme olaylarını dinle.
    WidgetsBinding.instance.addObserver(this);

    // Bağlantı değişikliklerini dinle (WiFi kesildi, data açıldı vb.)
    _connSub = _connectivity.onConnectivityChanged.listen((_) {
      if (!_paused) _scheduleCheck();
    });

    // Her 30 saniyede bir periyodik kontrol (maintenance flag güncellendi mi?)
    _startPolling();

    // İlk kontrol
    _check();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _paused = false;
        _generation++;
        _startPolling();
        // Ağ arayüzü dönüşte birkaç yüz ms içinde uyanıyor — hemen değil,
        // kısa bir gecikmeyle kontrol et.
        _scheduleCheck(delay: const Duration(milliseconds: 800));
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _paused = true;
        _generation++; // yarım kalan kontrollerin sonucu yok sayılır
        _pollTimer?.cancel();
        _debounce?.cancel();
      case AppLifecycleState.inactive:
        // Kısa kesintiler (bildirim paneli, uygulama değiştirici) —
        // durumu değiştirmeye gerek yok.
        break;
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
  }

  /// Rapid-fire connectivity olaylarını 600 ms debounce ile sınırlar.
  void _scheduleCheck({Duration delay = const Duration(milliseconds: 600)}) {
    _debounce?.cancel();
    _debounce = Timer(delay, _check);
  }

  static bool _isOffline(NetworkStatus s) =>
      s == NetworkStatus.noConnection || s == NetworkStatus.noInternet;

  Future<void> _check() async {
    if (_paused) return;
    if (_checking) {
      _pendingCheck = true;
      return;
    }
    _checking = true;
    final gen = _generation;
    try {
      var status = await _compute();

      // Bağlantıdan → bağlantısıza geçiş: hemen yayınlama, kısa aralıklarla
      // doğrula. Gerçekten kopmuşsa birkaç saniye içinde yine yayınlanır.
      if (_isOffline(status) && !_isOffline(_current)) {
        for (var i = 0; i < _confirmRetries && _isOffline(status); i++) {
          await Future<void>.delayed(_confirmDelay);
          if (gen != _generation || _paused) return;
          status = await _compute();
        }
      }

      // Bu sırada uygulama arka plana gittiyse/döndüyse sonuç bayat.
      if (gen != _generation || _paused) return;

      if (status != _current) {
        _current = status;
        if (!_controller.isClosed) _controller.add(status);
      }
    } finally {
      _checking = false;
      if (_pendingCheck && !_paused) {
        _pendingCheck = false;
        _scheduleCheck();
      }
    }
  }

  Future<NetworkStatus> _compute() async {
    // ── Katman 1: Ağ arayüzü ──────────────────────────────────────────────
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.every((r) => r == ConnectivityResult.none)) {
        return NetworkStatus.noConnection;
      }
    } catch (_) {
      return NetworkStatus.noConnection;
    }

    // ── Katman 2: Gerçek internet erişimi (web'de atla) ───────────────────
    if (!kIsWeb) {
      try {
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 5);
        final req = await client
            .headUrl(
              Uri.parse('https://connectivitycheck.gstatic.com/generate_204'),
            )
            .timeout(const Duration(seconds: 5));
        final res = await req.close().timeout(const Duration(seconds: 5));
        client.close(force: false);
        if (res.statusCode >= 400) return NetworkStatus.noInternet;
      } catch (_) {
        return NetworkStatus.noInternet;
      }
    }

    // ── Katman 3: Sunucu / bakım durumu (Firestore) ───────────────────────
    try {
      final snap = await FirebaseFirestore.instance
          .collection('appConfig')
          .doc('maintenance')
          .get()
          .timeout(const Duration(seconds: 5));
      if (snap.exists && snap.data()?['active'] == true) {
        return NetworkStatus.maintenance;
      }
    } catch (e) {
      // Firestore hatası → internet var ama loglayıp geç
      debugPrint('[NetworkService] Bakım kontrolü atlandı: $e');
    }

    return NetworkStatus.connected;
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connSub?.cancel();
    _pollTimer?.cancel();
    _debounce?.cancel();
    _controller.close();
  }
}
