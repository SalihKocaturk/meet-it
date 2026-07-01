import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_theme.dart';
import 'package:meetit/core/providers/theme_provider.dart';
import 'package:meetit/core/router/app_router.dart';
import 'package:meetit/core/services/firestore_seed_service.dart';
import 'package:meetit/core/services/network_service.dart';
import 'package:meetit/core/services/notification_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Push bildirim servisini başlat (FCM token + izin + ön plan handler)
  await NotificationService.initialize();

  // 3-katmanlı ağ izleyiciyi başlat (connectivity_plus + HEAD check + Firestore)
  NetworkService.instance.init();

  // Firestore boşsa mock kullanıcılar ekle
  await FirestoreSeedService.seedIfEmpty();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      startLocale: const Locale('tr'),
      child: const ProviderScope(
        child: MyApp(),
      ),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'MeetIt',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
     