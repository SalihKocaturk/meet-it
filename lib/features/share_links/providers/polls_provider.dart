import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/share_links/poll.dart';

/// Giriş yapan kullanıcının oluşturduğu oylamalar (canlı Firestore akışı).
///
/// Kurallar gereği yalnızca sahibi listeleyebilir; oturum yoksa boş döner.
final myPollsProvider = StreamProvider.autoDispose<List<Poll>>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null || uid.isEmpty) return Stream.value(const <Poll>[]);
  return PollService.watchMine(uid);
});

/// Tek bir oylamanın canlı akışı (yönetim detay ekranı).
final pollProvider = StreamProvider.autoDispose.family<Poll?, String>(
  (ref, id) => PollService.watch(id),
);

/// Arkadaşlar sekmesindeki "Oylamalarım" rozeti: hâlâ canlı olan oylama sayısı.
final livePollCountProvider = Provider.autoDispose<int>((ref) {
  final polls = ref.watch(myPollsProvider).valueOrNull;
  if (polls == null) return 0;
  return polls.where((p) => p.isActive).length;
});
