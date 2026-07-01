import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/features/match/notifiers/venue_search_notifier.dart';

/// Gerçek Places API araması için provider.
/// autoDispose kaldırıldı — UI geçişinde state korunur.
final venueSearchProvider =
    NotifierProvider<VenueSearchNotifier, VenueSearchState>(
  VenueSearchNotifier.new,
);
