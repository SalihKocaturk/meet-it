import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/features/personality/models/personality_model.dart';

// ── Kişilik Banner ────────────────────────────────────────────────────────────

class PersonalityBanner extends StatelessWidget {
  final PersonalityType type;

  const PersonalityBanner({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.primary.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Text(type.emoji, style: const TextStyle(fontSize: 20)),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'match.personality_type_label'.tr(
                    namedArgs: {'name': type.displayName},
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.colors.primary,
                  ),
                ),
                Text(
                  'match.personality_customized'.tr(),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
