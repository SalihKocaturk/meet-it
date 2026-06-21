import 'package:flutter/material.dart';
import 'package:meetit/core/constants/app_colors.dart';

/// QuickAlert paketinin yerini alan, uygulamanın kendi renk paletine ve
/// dark/light temaya uyumlu basit alert dialog'u.
///
/// QuickAlert ile birebir aynı parametre adlarını kullanır (context, type,
/// title, text, confirmBtnText, cancelBtnText, confirmBtnColor,
/// headerBackgroundColor, onConfirmBtnTap, onCancelBtnTap) — böylece eski
/// çağrı yerleri sadece `QuickAlert.show` → `showAppAlert` ve
/// `QuickAlertType.x` → `AppAlertType.x` değişikliğiyle taşındı, davranış
/// (callback verilmişse manuel pop, verilmemişse otomatik pop) aynı kaldı.
enum AppAlertType { success, error, warning, info, confirm }

Future<T?> showAppAlert<T>({
  required BuildContext context,
  required AppAlertType type,
  required String title,
  String? text,
  String? confirmBtnText,
  String? cancelBtnText,
  Color? confirmBtnColor,
  Color? headerBackgroundColor,
  VoidCallback? onConfirmBtnTap,
  VoidCallback? onCancelBtnTap,
  bool barrierDismissible = true,
}) {
  final colors = context.colors;

  final IconData icon;
  final Color iconColor;
  switch (type) {
    case AppAlertType.success:
      icon = Icons.check_rounded;
      iconColor = colors.success;
      break;
    case AppAlertType.error:
      icon = Icons.close_rounded;
      iconColor = colors.error;
      break;
    case AppAlertType.warning:
      icon = Icons.priority_high_rounded;
      iconColor = const Color(0xFFF59E0B);
      break;
    case AppAlertType.info:
      icon = Icons.info_outline_rounded;
      iconColor = colors.primary;
      break;
    case AppAlertType.confirm:
      icon = Icons.help_outline_rounded;
      iconColor = colors.primary;
      break;
  }

  final accentColor = confirmBtnColor ?? colors.primary;
  final showCancel = type == AppAlertType.confirm || cancelBtnText != null;

  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: (headerBackgroundColor ?? iconColor).withOpacity(
                    headerBackgroundColor != null ? 1 : 0.12,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              if (text != null) ...[
                const SizedBox(height: 8),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  if (showCancel) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          if (onCancelBtnTap != null) {
                            onCancelBtnTap();
                          } else {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: BorderSide(color: colors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          cancelBtnText ?? 'Cancel',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (onConfirmBtnTap != null) {
                          onConfirmBtnTap();
                        } else {
                          Navigator.of(dialogContext).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        confirmBtnText ?? 'OK',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
