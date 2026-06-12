import 'package:flutter/material.dart';

class CircularAvatar extends StatelessWidget {
  final String? name;
  final String? photoUrl;   // network URL — öncelikli
  final ImageProvider? image;
  final double radius;

  const CircularAvatar({
    super.key,
    this.name,
    this.photoUrl,
    this.image,
    this.radius = 22,
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

  @override
  Widget build(BuildContext context) {
    // 1) URL varsa network image göster
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(photoUrl!),
        backgroundColor: Colors.grey[200],
      );
    }

    // 2) ImageProvider verilmişse kullan
    if (image != null) {
      return CircleAvatar(radius: radius, backgroundImage: image);
    }

    // 3) Harf avatar
    final text = name?.isNotEmpty == true ? _initials(name!) : '?';
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
}
