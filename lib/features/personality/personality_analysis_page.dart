import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/router/app_routes.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/personality/models/personality_model.dart';
import 'package:meetit/features/personality/providers/personality_provider.dart';
import 'package:meetit/features/personality/character_preview_page.dart';
import 'package:meetit/features/personality/widgets/personality_breakdown.dart';
import 'package:meetit/features/personality/widgets/personality_history_chart.dart';

/// Kullanıcının KAYITLI (quiz + sonradan ziyaret edilen mekanlarla evrilmiş)
/// kişilik profilini gösteren sayfa.
///
/// quiz_page.dart'taki sonuç ekranından farkı: burada quiz'in o anki
/// `result`'u değil, `authProvider`'daki güncel `personalityProfile`
/// gösterilir — yani ReviewNotifier.addReview() içindeki
/// `PersonalityProfile.evolvedWith()` çağrılarıyla zamanla "kaymış" olan
/// gerçek profil burada görünür.
class PersonalityAnalysisPage extends ConsumerWidget {
  const PersonalityAnalysisPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final profile = currentUser?.personalityProfile;
    // `personalityHistory` boş olabilir (örn. quiz feature'ı eklenmeden önce
    // hesap oluşturulmuş eski kullanıcılar) — bu durumda en azından şu anki
    // profili tek noktalı bir geçmiş olarak kullan, grafiği tamamen
    // gizlemek yerine "henüz tek kayıt var" boş durumunu göster.
    final List<PersonalityProfile> history =
        (currentUser?.personalityHistory.isNotEmpty ?? false)
            ? currentUser!.personalityHistory
            : (profile != null ? [profile] : const []);

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: context.colors.scaffold,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left_2, color: context.colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'personality_analysis.title'.tr(),
          style: TextStyle(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Iconsax.eye, color: context.colors.textSecondary),
            tooltip: 'Kişilik Tiplerini Keşfet',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CharacterPreviewPage()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: profile == null
            ? _EmptyState(
                onTakeQuiz: () {
                  ref.read(quizProvider.notifier).reset();
                  context.push(AppRoutes.quiz);
                },
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Dinamik evrim bilgi notu ─────────────────────────
                    //
                    // Kullanıcılar mekan önerisi almakla profillerinin
                    // değiştiğini düşünebiliyor — bu net değil. Asıl
                    // tetikleyici, gidilen bir mekana YORUM yazmak
                    // (ReviewNotifier.addReview → evolvedWith). Bu kutu
                    // bunu açıkça belirtiyor.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.primary.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Iconsax.chart,
                            color: context.colors.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'personality_analysis.evolves_hint'.tr(),
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'personality_analysis.last_updated'.tr(
                          namedArgs: {'time': _timeAgo(profile.lastUpdated)},
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    PersonalityBreakdown(
                      profile: profile,
                      gender: currentUser?.gender,
                    ),

                    const SizedBox(height: 16),

                    // ── Zaman içinde değişim grafiği ─────────────────────
                    //
                    // Sol: her tipin skorunun gerçek tarihlere göre çizgi
                    // grafiği. Sağ: tip + rengi + ilk kayıttan bu yana
                    // artış/azalış göstergesi.
                    PersonalityHistoryChart(history: history),

                    const SizedBox(height: 16),

                    // ── Kişilik Tipleri keşif kartı ───────────────────────
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CharacterPreviewPage(),
                        ),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.colors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: context.colors.primary.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Iconsax.people,
                                color: context.colors.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Kişilik Tiplerini Keşfet',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: context.colors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Tüm karakterlerin animasyonlarını gör',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Iconsax.arrow_right_3,
                              size: 16,
                              color: context.colors.textSecon