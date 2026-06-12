import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/features/feed/notifiers/feed_notifier.dart';

final feedProvider = NotifierProvider<FeedNotifier, FeedState>(
  FeedNotifier.new,
);
