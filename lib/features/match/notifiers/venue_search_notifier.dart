import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:meetit/features/match/models/place_result.dart';
import 'package:meetit/features/match/services/places_service.dart';
import 'package:meetit/features/personality/models/personality_model.dart';

const _pageSize = 5;

// ── State ─────────────────────────────────────────────────────────────────────

class VenueSearchState {
  /// Orta noktaya yakın mekanlar (en üstte gösterilir)
  final List<PlaceResult> midpointVenues;

  /// Diğer mekanlar (kişiliğe göre sıralı)
  final List<PlaceResult> allVenues;

  final int currentPage;
  final bool isLoading;
  final String? errorMessage;
  final double? searchLat;
  final double? searchLng;
  final bool hasMidpoint; // iki kullanıcının konumu kullanıldı mı?

  /// Mesafe çok uzak olduğu için orta nokta hesaplanamadığında
  /// kullanıcıya gösterilecek uyarı (sonuçları engellemez).
  final String? distanceWarning;

  const VenueSearchState({
    this.midpointVenues = const [],
    this.allVenues = const [],
    this.currentPage = 0,
    this.isLoading = false,
    this.errorMessage,
    this.searchLat,
    this.searchLng,
    this.hasMidpoint = false,
    this.distanceWarning,
  });

  List<PlaceResult> get venues {
    final start = currentPage * _pageSize;
    if (start >= allVenues.length) return [];
    final end = (start + _pageSize).clamp(0, allVenues.length);
    return allVenues.sublist(start, end);
  }

  bool get hasResults => allVenues.isNotEmpty || midpointVenues.isNotEmpty;
  bool get hasNextPage => (currentPage + 1) * _pageSize < allVenues.length;
  bool get hasPrevPage => currentPage > 0;
  int get totalPages => (allVenues.length / _pageSize).ceil();

  VenueSearchState copyWith({
    List<PlaceResult>? midpointVenues,
    List<PlaceResult>? allVenues,
    int? currentPage,
    bool? isLoading,
    String? errorMessage,
    double? searchLat,
    double? searchLng,
    bool? hasMidpoint,
    String? distanceWarning,
    bool clearError = false,
    bool clearAll = false,
    bool clearDistanceWarning = false,
  }) {
    return VenueSearchState(
      midpointVenues:
          clearAll ? [] : (midpointVenues ?? this.midpointVenues),
      allVenues: clearAll ? [] : (allVenues ?? this.allVenues),
      currentPage: clearAll ? 0 : (currentPage ?? this.currentPage),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      searchLat: searchLat ?? this.searchLat,
      searchLng: searchLng ?? this.searchLng,
      hasMidpoint: hasMidpoint ?? this.hasMidpoint,
      distanceWarning: clearDistanceWarning
          ? null
          : (distanceWarning ?? this.distanceWarning),
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class VenueSearchNotifier extends Notifier<VenueSearchState> {
  @override
  VenueSearchState build() => const VenueSearchState();

  Future<void> searchVenues({
    required PersonalityProfile userProfile,
    required PersonalityProfile friendProfile,
    required List<String> selectedActivities,
    required String? friendUid, // Firestore'dan konumu çekmek için
    int? priceLevel,
    double? userLat,
    double? userLng,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearAll: true,
      clearDistanceWarning: true,
    );

    // ── Kullanıcı konumu ───────────────────────────────────────────────────
    double myLat;
    double myLng;

    if (userLat != null && userLng != null) {
      myLat = userLat;
      myLng = userLng;
    } else {
      final position = await _getLocation();
      if (position == null) return;
      myLat = position.latitude;
      myLng = position.longitude;
    }

    // ── Arkadaşın konumunu Firestore'dan çek ──────────────────────────────
    double? friendLat;
    double? friendLng;
    if (friendUid != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(friendUid)
            .get();
        if (doc.exists) {
          friendLat = (doc.data()?['lat'] as num?)?.toDouble();
          friendLng = (doc.data()?['lng'] as num?)?.toDouble();
        }
      } catch (_) {}
    }

    // ── Orta nokta hesapla ────────────────────────────────────────────────
    bool usingMidpoint = false;
    double searchLat = myLat;
    double searchLng = myLng;
    String? distanceWarning;

    const maxDistanceKm = 200.0;

    if (friendUid != null) {
      if (friendLat != null && friendLng != null) {
        final dist = _haversineKm(myLat, myLng, friendLat, friendLng);
        if (dist < maxDistanceKm) {
          searchLat = (myLat + friendLat) / 2;
          searchLng = (myLng + friendLng) / 2;
          usingMidpoint = true;
        } else {
          // İki kişi arasındaki mesafe çok uzun — ortak bir mekan
          // bulmak gerçekçi değil. Kullanıcıyı uyar, kendi konumuna
          // göre aramaya devam et.
          distanceWarning =
              'İkiniz arasındaki mesafe çok uzun (${dist.round()} km). '
              'Ortak bir mekan önerilemiyor, bunun yerine kendi '
              'konumuna yakın mekanlar gösteriliyor.';
        }
      } else {
        // Arkadaşın konum bilgisi yok — orta nokta hesaplanamıyor.
        distanceWarning =
            'Arkadaşının konum bilgisi bulunamadığı için ortak bir '
            'buluşma noktası hesaplanamadı. Kendi konumuna yakın '
            'mekanlar gösteriliyor.';
      }
    }

    state = state.copyWith(
      searchLat: searchLat,
      searchLng: searchLng,
      hasMidpoint: usingMidpoint,
      distanceWarning: distanceWarning,
    );

    // ── Places API ────────────────────────────────────────────────────────
    try {
      final results = await PlacesService.searchVenues(
        lat: searchLat,
        lng: searchLng,
        userProfile: userProfile,
        friendProfile: friendProfile,
        selectedActivities: selectedActivities,
        priceLevel: priceLevel,
      );

      if (results.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'Yakında uygun mekan bulunamadı. Farklı aktivite veya fiyat seç.',
        );
        return;
      }

      if (usingMidpoint) {
        // Orta noktaya en yakın 3 mekan ayrı gösterilir
        final sorted = List<PlaceResult>.from(results)
          ..sort((a, b) {
            final dA = _haversineKm(searchLat, searchLng, a.lat, a.lng);
            final dB = _haversineKm(searchLat, searchLng, b.lat, b.lng);
            return dA.compareTo(dB);
          });
        final midpoint = sorted.take(3).toList();
        final others = sorted.skip(3).toList();

        state = state.copyWith(
          midpointVenues: midpoint,
          allVenues: others,
          currentPage: 0,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          allVenues: results,
          currentPage: 0,
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Mekan arama sırasında bir hata oluştu.',
      );
    }
  }

  void nextPage() {
    if (state.hasNextPage) {
      state = state.copyWith(currentPage: state.currentPage + 1);
    }
  }

  void prevPage() {
    if (state.hasPrevPage) {
      state = state.copyWith(currentPage: state.currentPage - 1);
    }
  }

  void reset() => state = const VenueSearchState();

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _deg2rad(double deg) => deg * pi / 180;

  Future<Position?> _getLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      state = state.copyWith(
          isLoading: false,
          errorMessage: 'Konum servisi kapalı. Lütfen açın.');
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        state = state.copyWith(
            isLoading: false, errorMessage: 'Konum izni verilmedi.');
        return null;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(
          isLoading: false,
          errorMessage: 'Konum izni kalıcı reddedildi.');
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return await Geolocator.getLastKnownPosition();
    }
  }
}
