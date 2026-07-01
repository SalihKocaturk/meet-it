import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/network_service.dart';

export '../services/network_service.dart' show NetworkStatus;

/// Uygulama genelinde anlık ağ durumunu sağlayan provider.
///
/// [NetworkService.stream]'i dinler ve her değişiklikte rebuild tetikler.
/// Başlangıç değeri olarak [NetworkService.current] kullanılır (optimistik: connected).
///
/// Örnek kullanım:
/// ```dart
/// final status = ref.watch(networkStatusProvider);
/// if (status == NetworkStatus.noConnection) { ... }
/// ```
final networkStatusProvider =
    StateNotifierProvider<_NetworkNotifier, NetworkStatus>(
  (_) => _NetworkNotifier(),
);

class _NetworkNotifier extends StateNotifier<NetworkStatus> {
  _NetworkNotifier() : super(NetworkService.instance.current) {
    _sub = NetworkService.instance.stream.listen((s) => state = s);
  }

  late final StreamSubscription<NetworkStatus> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
