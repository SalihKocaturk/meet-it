import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/widgets/circular_avatar.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/match/pages/map_location_picker_page.dart';
import 'package:meetit/features/match/providers/match_provider.dart';

// ── Konum Alanı ───────────────────────────────────────────────────────────────

class LocationField extends ConsumerWidget {
  final String defaultHint;

  const LocationField({super.key, required this.defaultHint});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userLoc = ref.watch(userLocationProvider);
    final currentUser = ref.watch(currentUserProvider);
    final displayText = userLoc?.text ?? defaultHint;
    final hasCoords = userLoc?.hasCoords ?? false;

    // Konum DB'den (UserModel.lat/lng) geldiği için kullanıcı her seferinde
    // yeniden konum girmek zorunda değil — burada zaten kayıtlı konumu
    // gösteriyoruz. İsterse alttaki "Yeni Konum Seç" ile değiştirebilir.
    Future<void> pickLocation() async {
      final result = await Navigator.of(context).push<UserLocation>(
        MaterialPageRoute(
          builder: (_) => MapLocationPickerPage(
            initial: userLoc?.hasCoords == true
                ? LatLng(userLoc!.lat!, userLoc.lng!)
                : null,
          ),
        ),
      );
      if (result == null) return;

      // Anında UI geri bildirimi
      ref.read(userLocationProvider.notifier).state = result;

      // DB'ye kaydet — bir dahaki sefere konum servisine veya yeniden
      // girişe gerek kalmasın, arkadaşlarımız da benim konumumu DB'den
      // güvenilir şekilde okuyabilsin.
      if (result.hasCoords) {
        await ref
            .read(authProvider.notifier)
            .updateLocation(result.lat!, result.lng!, address: result.text);
      }
    }

    return GestureDetector(
      onTap: pickLocation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasCoords
                ? context.colors.primary.withOpacity(0.5)
                : context.colors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (hasCoords)
                  CircularAvatar(
                    name: currentUser?.name,
                    photoUrl: currentUser?.photoUrl,
                    radius: 12,
                  )
                else
                  Icon(
                    Icons.my_location,
                    color: context.colors.primary,
                    size: 20,
                  ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayText,
                    style: TextStyle(
                      fontSize: 14,
                      color: hasCoords
                          ? context.colors.textPrimary
                          : context.colors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!hasCoords)
                  Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: context.colors.hint,
                  ),
              ],
            ),
            if (hasCoords) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: pickLocation,
                child: Text(
                  'match.change_location'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.colors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
