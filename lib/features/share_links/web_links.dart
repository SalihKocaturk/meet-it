/// GitHub Pages üzerindeki web sayfalarının linkleri. Bu sayfalar
/// uygulaması OLMAYAN kişiler içindir (Firebase JS + anonim oturum ile
/// Firestore'a yazar/okur — bkz. konum/ ve oylama/ klasörleri).
abstract final class WebLinks {
  static const host = 'salihkocaturk.github.io';
  static const base = '/meet-it';

  /// Uygulamayı indirme sayfası.
  static Uri download() => Uri.https(host, '$base/indir/');

  /// Arkadaştan konum isteme sayfası.
  static Uri locationRequest(String requestId, {String? ownerFirstName}) =>
      Uri.https(host, '$base/konum/', {
        'r': requestId,
        if (ownerFirstName != null && ownerFirstName.isNotEmpty)
          'n': ownerFirstName,
      });

  /// Grup oylama sayfası.
  static Uri poll(String pollId) => Uri.https(host, '$base/oylama/', {'p': pollId});
}
