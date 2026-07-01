import 'dart:ui' show Brightness;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

// NOT: Kullanıcı tercihi henüz kaydedilmemişse (ilk açılış) artık zorla
// koyu tema yerine `ThemeMode.system` kullanılıyor — yani uygulama
// telefonun o anki sistem temasına (açık/koyu) göre açılır. Kullanıcı
// Ayarlar'daki anahtara dokunduğu anda bu açık/koyu bir tercihe
// dönüşür ve SharedPreferences'a yazılır; `system` bir daha
// otomatik olarak geri gelmez (sadece "hiç seçim yapılmadı" durumunu
// temsil eder).
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  static const _key = 'theme_mode';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getString(_key);
      if (val == 'light') state = ThemeMode.light;
      else if (val == 'dark') state = ThemeMode.dark;
      else state = ThemeMode.system; // kayıtlı tercih yok -> sistem teması
    } catch (_) {}
  }

  Future<void> toggle() async {
    // `system` modundayken anahtara dokunulursa, telefonun O ANKİ asıl
    // görünen rengine göre "tersini" seçiyoruz (örn. sistem koyuysa
    // anahtar açığa geçirir) — kullanıcı için sezgisel olan budur.
    final currentlyDark = isEffectivelyDark(state);
    state = currentlyDark ? ThemeMode.light : ThemeMode.dark;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, state == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }

  bool get isDark => isEffectivelyDark(state);
}

// NOT: `ThemeMode.system` iken hangi rengin gerçekte gösterildiğini
// bulmak için platformun anlık parlaklık ayarına bakılır. Hem
// `ThemeModeNotifier.isDark` (context'siz) hem de context'i olan
// widget'lar (örn. Google Maps koyu stili, Ayarlar anahtarı metni) bu
// fonksiyonu kullanır.
bool isEffectivelyDark(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.dark:
      return true;
    case ThemeMode.light:
      return false;
    case ThemeMode.system:
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark;
  }
}
