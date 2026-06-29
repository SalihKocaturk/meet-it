/// Form alanları için ortak validasyon yardımcıları.
///
/// Şu ana kadar email adresi sadece "boş mu?" diye kontrol ediliyordu —
/// format hatalı bir email (örn. "asd@asd", "asd.com", boşluklu adresler)
/// doğrudan Firebase'e gönderiliyor, hesap oluşturulamayınca/doğrulama
/// maili atılamayınca kullanıcı anlaşılmaz bir hata mesajıyla baş başa
/// kalıyordu. Bu dosya, mail göndermeden ÖNCE istemci tarafında format
/// kontrolü yapmak için kullanılır.
class Validators {
  Validators._();

  // RFC 5322'nin tam karşılığı değil (o regex pratikte gereğinden karmaşık
  // ve bakımı zor) — ama "kullanıcı@alan-adı.uzantı" şeklini, en az bir nokta
  // içeren bir alan adı ve uzantı ile zorunlu kılan, pratikte kullanılan
  // standart bir email regex'i.
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*\.[a-zA-Z]{2,}$',
  );

  /// Email formatı geçerli mi? Boş string her zaman false döner — boşluk
  /// kontrolü çağıran tarafta (zorunlu alan uyarısı) zaten ayrı yapılıyor,
  /// burada sadece format kontrolü yapılır.
  static bool isValidEmail(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return false;
    return _emailRegex.hasMatch(trimmed);
  }
}
