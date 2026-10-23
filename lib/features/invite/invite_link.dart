/// Davet linki: kişilik kartıyla birlikte paylaşılan, açan kişiyi davet
/// edenle otomatik arkadaş yapan ve uyumlarını gösteren link.
///
/// Biçim: https://salihkocaturk.github.io/meet-it/davet/?u={uid}&n={isim}
///
/// • Uygulama yüklüyse: Android App Links / iOS Universal Links linki
///   doğrudan uygulamada açar (doğrulama dosyaları
///   salihkocaturk.github.io/.well-known/ altında — bkz. link-verification/).
///   go_router bu yolu yakalar (bkz. app_router.dart).
/// • Yüklü değilse: davet sayfası açılır (davet/index.html). Mağaza butonuna
///   basınca kod panoya `MEETIT-DAVET:{uid}` olarak kopyalanır; uygulama ilk
///   açılışta panoyu bir kez okuyup daveti tamamlar (bkz. invite_host.dart).
abstract final class InviteLink {
  static const host = 'salihkocaturk.github.io';
  static const path = '/meet-it/davet/';
  static const clipboardPrefix = 'MEETIT-DAVET:';

  static final _uidPattern = RegExp(r'^[A-Za-z0-9]{10,64}$');

  /// Paylaşılacak davet linki.
  static Uri build({required String uid, String? firstName}) => Uri.https(
        host,
        path,
        {
          'u': uid,
          if (firstName != null && firstName.trim().isNotEmpty)
            'n': firstName.trim(),
        },
      );

  /// Gelen link yolu bir davet mi? (Universal/App Link: /meet-it/davet)
  static bool isInvitePath(String path) =>
      path == '/meet-it/davet' ||
      path.startsWith('/meet-it/davet/') ||
      path == '/davet';

  /// Linkteki davet edenin uid'i (geçersizse null).
  static String? uidFromUri(Uri uri) {
    final u = uri.queryParameters['u']?.trim();
    return (u != null && _uidPattern.hasMatch(u)) ? u : null;
  }

  /// Davet sayfasının panoya kopyaladığı metinden uid çıkarır.
  static String? uidFromClipboard(String? text) {
    if (text == null) return null;
    final t = text.trim();
    if (!t.startsWith(clipboardPrefix)) return null;
    final uid = t.substring(clipboardPrefix.length).trim();
    return _uidPattern.hasMatch(uid) ? uid : null;
  }
}
