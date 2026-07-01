import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:meetit/features/match/notifiers/map_controller_notifier.dart';

/// `AttemptMeetPage`'in (harita görünümü) `GoogleMapController`'ı için
/// provider. autoDispose YOK — sayfa rebuild olduğunda controller kaybolmasın.
final mapControllerProvider =
    NotifierProvider<MapControllerNotifier, GoogleMapController?>(
  MapControllerNotifier.new,
);
