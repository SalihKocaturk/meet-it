import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/features/match/notifiers/attempt_meet_notifier.dart';

/// `AttemptMeetPage` (harita görünümü) durumu için provider.
///
/// `AsyncNotifierProvider` — autoDispose YOK (liste/harita geçişinde
/// state korunsun diye). `AttemptMeetNotifier.build()` izlediği
/// `venueSearchProvider`/`selectedFriendProvider` değiştiğinde KENDİSİ
/// otomatik yeniden çalışır; bu yüzden burada elle bir `reset()` çağırmaya
/// gerek YOK (bkz. notifiers/attempt_meet_notifier.dart dosya başı yorumu).
final attemptMeetProvider =
    AsyncNotifierProvider<AttemptMeetNotifier, AttemptMeetState>(
  AttemptMeetNotifier.new,
);
