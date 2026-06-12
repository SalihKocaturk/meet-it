import 'package:flutter/material.dart';

class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 16,
      child: GestureDetector(
        onTap: () {
          // Implement language switch logic here
        },
        child: CircleAvatar(
          radius: 18,
          backgroundImage: AssetImage('assets/images/flags/tr.png'),
        ),
      ),
    );
  }
}
