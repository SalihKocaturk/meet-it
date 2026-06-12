import 'package:flutter/material.dart';

class RandomColor {
  static final _colors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.indigo,
    Colors.brown,
  ];

  static Color pick(String seed) {
    final hash = seed.hashCode;
    return _colors[hash.abs() % _colors.length];
  }
}
