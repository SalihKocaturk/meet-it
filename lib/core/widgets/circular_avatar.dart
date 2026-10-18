import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class CircularAvatar extends StatelessWidget {
  final String? name;
  final String? photoUrl;   // network URL — öncelikli
  final ImageProvider? image;
  final double radius;

  /// Koyu fotoğraflar koyu arka planda kaybolmasın diye 1 px ince çerçeve.
  final bool outline;

  const CircularAvatar({
    super.key,
    this.name,
    this.photoUrl,
    this.image,
    this.radius = 22,
    this.outline = true,
  });

  static const _colors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.indigo,
  ];

  Color _pickColor(String seed) =>
      _colors[seed.hashCode.abs() % _colors.length];

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Widget _letterAvatar(String seed) {
    final text = seed.isNotEmpty ? _initials(seed) : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: _pickColor(text),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: radius * 0.8,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _buildAvatar();
    if (!outline) return avatar;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.15)
              : Colors.black.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: avatar,
    );
  }

  Widget _buildAvatar() {
    // 1) URL varsa CachedNetworkImage göster — hata durumunda harfli avatara düş
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: photoUrl!,
        imageBuilder: (_, provider) => CircleAvatar(
          radius: radius,
          backgroundImage: provider,
          backgroundColor: Colors.grey[200],
        ),
        placeholder: (_, __) => CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey[200],
        ),
        errorWidget: (_, __, ___) => _letterAvatar(name ?? ''),
      );
    }

    // 2) ImageProvider verilmişse kullan
    if (image != null) {
      return CircleAvatar(radius: radius, backgroundImage: image);
    }

    // 3) Harf avatar
    return _letterAvatar(name ?? '');
  }
}
