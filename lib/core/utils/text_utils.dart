/// "salih kocaturk" → "Salih Kocaturk". Yalnızca kelimelerin ilk harfi
/// büyütülür (geri kalanı olduğu gibi kalır); Türkçede i → İ, ı → I.
String titleCaseName(String input, {bool turkish = true}) {
  return input
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) {
        final f = w[0];
        final upper = turkish && f == 'i'
            ? 'İ'
            : turkish && f == 'ı'
                ? 'I'
                : f.toUpperCase();
        return upper + w.substring(1);
      })
      .join(' ');
}
