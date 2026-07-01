import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

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
class NetworkService {
  NetworkService._();
  static final NetworkService instance = NetworkService._();

  final _connectivity = Connectivity();
  final _controller = StreamController<NetworkStatus>.broadcast();

  NetworkStatus _current = NetworkStatus.connected;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _pollTimer;
  Timer? _debounce;

  /// Mevcut durum — provider'ın başlangıç değeri için kullanılır.
  NetworkStatus get current => _current;

  /// Durum değişikliklerini yayınlayan stream.
  Stream<NetworkStatus> get stream => _controller.stream;

  /// Servisi başlatır. Genellikle [main()] içinde Firebase init'ten sonra çağrılır.
  void init() {
    // Bağlantı değişikliklerini dinle (WiFi kesildi, data açıldı vb.)
    _connSub = _connectivity.onConnectivityChanged.listen((_) {
      _scheduleCheck();
    });

    // Her 30 saniyede bir periyodik kontrol (maintenance flag güncellendi mi?)
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _check());

    // İlk kontrol
    _check();
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  /// Rapid-fire connectivity olaylarını 600 ms debounce ile sınırlar.
  void _scheduleCheck() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _check);
  }

  Future<void> _check() async {
    final status = await _compute();
    if (status != _current) {
      _current = status;
      if (!_controller.isClosed) _controller.add(status);
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
    _connSub?.cancel();
    _pollTimer?.cancel();
    _debounce?.cancel();
    _controller.close();
  }
}
