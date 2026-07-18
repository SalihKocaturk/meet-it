import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/router/app_routes.dart';
import 'package:meetit/core/widgets/app_alert.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';

/// Hesap silme sayfası.
///
/// Deep link `meetit://delete-account` ile doğrudan açılabilir (Google Play
/// hesap silme URL'si gereksinimi için) veya SettingsPage'den de erişilebilir.
/// Kullanıcı giriş yapmamışsa otomatik olarak giriş ekranına yönlendirilir.
class DeleteAccountPage extends ConsumerStatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  ConsumerState<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends ConsumerState<DeleteAccountPage> {
  bool _isLoading = false;

  Future<void> _deleteAccount() async {
    final confirmed = await _showConfirmDialog();
    if (!confirmed || !mounted) return;

    setState(() => _isLoading = true);
    final error = await ref.read(authProvider.notifier).deleteAccount();
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      showAppAlert(
        context: context,
        type: AppAlertType.error,
        title: 'common.error'.tr(),
        text: error.tr(),
        confirmBtnText: 'common.ok'.tr(),
        confirmBtnColor: context.colors.primary,
      );
      return;
    }

    context.go(AppRoutes.signIn);
  }

  Future<bool> _showConfirmDialog() async {
    bool result = false;
    await showAppAlert(
      context: context,
      type: AppAlertType.confirm,
      title: 'settings.delete_account_title'.tr(),
      text: 'settings.delete_account_confirm'.tr(),
      confirmBtnText: 'settings.delete_account_yes'.tr(),
      cancelBtnText: 'common.cancel'.tr(),
      confirmBtnColor: context.colors.error,
      headerBackgroundColor: context.colors.error.withOpacity(0.1),
      onConfirmBtnTap: () {
        result = true;
        Navigator.pop(context);
      },
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    // Giriş yapılmamışsa sign-in'e yönlendir
    if (!isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.signIn);
      });
    }

    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        backgroundColor: colors.scaffold,
        elevation: 0,
        leading: BackButton(color: colors.textPrimary),
        title: Text(
          'settings.delete_account_title'.tr(),
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Uyarı ikonu
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colors.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Iconsax.warning_2,
                    color: colors.error,
                    size: 36,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'settings.delete_account_title'.tr(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'settings.delete_account_confirm'.tr(),
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textSecondary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              // Silinecekler listesi
              _InfoRow(
                icon: Iconsax.profile_delete,
                text: 'Profil bilgilerin ve fotoğrafın',
                colors: colors,
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Iconsax.star_slash,
                text: 'Mekan yorumların ve beğenilerin',
                colors: colors,
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Iconsax.clock_slash,
                text: 'Buluşma geçmişin',
                colors: colors,
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Iconsax.people,
                text: 'Arkadaşlık bağlantıların',
                colors: colors,
              ),

              const Spacer(),

              // Sil butonu
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading ? null : _deleteAccount,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.error,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'settings.delete_account_yes'.tr(),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // Vazgeç butonu
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'common.cancel'.tr(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final AppColors colors;

  const _InfoRow({
    required this.icon,
    required this.text,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: colors.error.withOpacity(0.7)),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(fontSize: 13, color: colors.textSecondary),
        ),
      ],
    );
  }
}
