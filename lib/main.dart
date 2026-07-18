import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:meetit/core/constants/app_theme.dart';
import 'package:meetit/core/providers/theme_provider.dart';
import 'package:meetit/core/router/app_router.dart';
import 'package:meetit/core/services/firestore_seed_service.dart';
import 'package:meetit/core/services/ad_service.dart';
import 'package:meetit/core/services/network_service.dart';
import 'package:meetit/core/services/notification_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Google Maps renderer'i acikca baslat
  if (!kIsWeb) {
    final mapsImpl = GoogleMapsFlutterPlatform.instance;
    if (mapsImpl is GoogleMapsFlutterAndroid) {
      try {
        await mapsImpl.initializeWithRenderer(AndroidMapRenderer.latest);
      } catch (_) {}
    }
  }

  await EasyLocalization.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // App Check: debug modda debug provider, release'de Play Integrity
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode
        ? AndroidProvider.debug
        : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode
        ? AppleProvider.debug
        : AppleProvider.deviceCheck,
  );

  // AdMob SDK'yı başlat (Firebase'den sonra çağrılmalı)
  await AdService.initialize();

  // Push bildirim servisini baslat
  await NotificationService.initialize();

  // 3-katmanli ag izleyiciyi baslat
  NetworkService.instance.init();

  // Firestore bossa mock kullanicilari ekle
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
      themeMode: themeMode,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}
