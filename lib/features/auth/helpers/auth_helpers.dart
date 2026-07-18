import 'package:easy_localization/easy_localization.dart';

/// Auth feature için paylaşılan sabit ve yardımcı fonksiyonlar.
/// Hem SignUpPage hem CompleteProfilePage tarafından kullanılır.

const List<String> kGenderCodes = ['male', 'female', 'other'];

String genderLabel(String code) {
  switch (code) {
    case 'male':
      return 'auth.gender_male'.tr();
    case 'female':
      return 'auth.gender_female'.tr();
    case 'other':
      return 'auth.gender_other'.tr();
    default:
      return code;
  }
}
