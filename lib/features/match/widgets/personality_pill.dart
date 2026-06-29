import 'package:flutter/material.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/features/personality/models/personality_model.dart';

class PersonalityPill extends StatelessWidget {
  final String name;
  final PersonalityType? type;

  const PersonalityPill({super.key, required this.name, this.type});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(type?.emoji ?? '❓', style: TextStyle(fontSize: 24)),
        SizedBox(height: 4),
        Text(
          name,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.textPrimary,
          ),
        ),
        if (type != null)
          Text(
            type!.displayName,
            style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
          ),
      ],
    );
  }
}
