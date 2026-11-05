import 'package:flutter_test/flutter_test.dart';
import 'package:meetit/features/share_links/poll.dart';

void main() {
  PollOption option(String name) => PollOption(name: name);

  group('Poll', () {
    test('oy sayıları, lider ve katılımcı adları doğru hesaplanır', () {
      final poll = Poll(
        id: 'p1',
        ownerUid: 'owner',
        ownerName: 'Ece',
        options: [option('Kafe'), option('Park')],
        votes: const {'a': 0, 'b': 0, 'c': 1},
        voterNames: const {'a': 'Ali', 'c': 'Zeynep'},
        expireAt: DateTime.now().add(const Duration(days: 1)),
      );

      expect(poll.totalVotes, 3);
      expect(poll.counts, [2, 1]);
      expect(poll.leadingIndex, 0);
      expect(poll.leadingOption?.name, 'Kafe');
      expect(poll.status, PollStatus.live);
      expect(poll.title, 'Kafe · Park');
      expect(
        poll.votersFor(0, anonymousLabel: 'Biri'),
        containsAll(<String>['Ali', 'Biri']),
      );
    });

    test('kapatılmış oylama süresi dolmamış olsa da kapalı sayılır', () {
      final poll = Poll(
        id: 'p2',
        ownerUid: 'owner',
        ownerName: '',
        options: [option('A'), option('B')],
        votes: const {},
        voterNames: const {},
        closed: true,
        expireAt: DateTime.now().add(const Duration(days: 5)),
      );

      expect(poll.status, PollStatus.closed);
      expect(poll.isActive, isFalse);
      expect(poll.leadingIndex, isNull);
    });

    test('süresi geçen oylama expired olur', () {
      final poll = Poll(
        id: 'p3',
        ownerUid: 'owner',
        ownerName: '',
        options: [option('A'), option('B')],
        votes: const {'a': 1},
        voterNames: const {'a': 'Ali'},
        expireAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      expect(poll.status, PollStatus.expired);
      expect(poll.isActive, isFalse);
    });

    test('sahip kontrolü', () {
      final poll = Poll(
        id: 'p4',
        ownerUid: 'owner',
        ownerName: '',
        options: [option('A'), option('B')],
        votes: const {},
        voterNames: const {},
      );

      expect(poll.isOwner('owner'), isTrue);
      expect(poll.isOwner('other'), isFalse);
      expect(poll.isOwner(null), isFalse);
    });
  });

  group('PollOption', () {
    test('harita bilgileri toMap/fromMap turunda korunur', () {
      const original = PollOption(
        placeId: 'place-1',
        name: 'Kafe X',
        address: 'İzmit',
        rating: 4.5,
        ratingCount: 120,
        mapsUrl: 'https://maps.example/place-1',
        lat: 40.76,
        lng: 29.92,
        photoUrl: 'https://cdn.example/photo.jpg',
      );

      final restored = PollOption.fromMap(original.toMap());

      expect(restored.placeId, 'place-1');
      expect(restored.name, 'Kafe X');
      expect(restored.address, 'İzmit');
      expect(restored.rating, 4.5);
      expect(restored.ratingCount, 120);
      expect(restored.mapsUrl, 'https://maps.example/place-1');
      expect(restored.lat, 40.76);
      expect(restored.lng, 29.92);
      expect(restored.photoUrl, 'https://cdn.example/photo.jpg');
      expect(restored.isCustom, isFalse);
      expect(restored.hasCoords, isTrue);
    });

    test('serbest metin seçeneği koordinatsız ve custom sayılır', () {
      final restored = PollOption.fromMap(<String, dynamic>{
        'name': 'Film gecesi',
      });

      expect(restored.isCustom, isTrue);
      expect(restored.hasCoords, isFalse);
      expect(restored.key, 'text:film gecesi');
    });
  });
}
