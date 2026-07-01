import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/history/models/meeting_record.dart';
import 'package:meetit/features/history/services/meeting_history_service.dart';

/// Giriş yapan kullanıcının geçmiş buluşmalarını gerçek zamanlı olarak akıtır.
///
/// Hem kullanıcının başlattığı aramalar hem de arkadaşının başlattığı ve
/// kullanıcının `participantUids` listesinde yer aldığı aramalar döner.
final meetingHistoryProvider = StreamProvider<List<MeetingRecord>>((ref) {
  final uid = ref.watch(authProvider).user?.uid;
  if (uid == null) return const Stream.empty();
  return MeetingHistoryService.historyStream(uid);
});
