import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/router/app_routes.dart';
import 'package:meetit/core/widgets/app_text_field.dart';
import 'package:meetit/features/auth/notifiers/auth_notifier.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/auth/providers/sign_in_form_provider.dart';
import 'package:quickalert/quickalert.dart';

class SignInPage extends ConsumerWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authLoadingProvider);
    final emailController = ref.watch(signInEmailControllerProvider);
    final passwordController = ref.watch(signInPasswordControllerProvider);

    // ── Durum Dinleyici ──────────────────────────────────────────────────────
    // Auth state değişikliklerini izle: hata → QuickAlert, başarı → navigate
    ref.listen<AuthState>(authProvider, (previous, next) {
      // Yeni bir hata mesajı geldi
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: 'Giriş Başarısız',
          text: next.errorMessage!,
          confirmBtnText: 'Tamam',
          confirmBtnColor: context.colors.primary,
          barrierDismissible: true,
          onConfirmBtnTap: () {
            Navigator.of(context).pop();
            ref.read(authProvider.notifier).clearError();
          },
        );
      }

      // Giriş başarılı → yönlendir
      if (!previous!.isAuthenticated && next.isAuthenticated) {
        context.go(next.hasPersonality ? AppRoutes.main : AppRoutes.quiz);
      }
    });

    // Klavye yüksekliği — logoyu küçültmek için
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = keyboardHeight > 50;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: context.colors.scaffold,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  keyboardHeight,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  SizedBox(height: isKeyboardOpen ? 16 : 32),

                  // Logo — klavye açıkken küçül
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: isKeyboardOpen ? 80 : 140,
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.fitHeight,
                    ),
                  ),

                  SizedBox(height: isKeyboardOpen ? 20 : 36),

                  // Email
                  AppTextField(
                    controller: emailController,
                    label: 'Email',
                    hint: 'ornek@email.com',
                    prefixIcon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Şifre
                  AppTextField(
                    controller: passwordController,
                    label: 'Şifre',
                    hint: 'Şifrenizi girin',
                    isPassword: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) =>
                        _submit(ref, emailController, passwordController),
                  ),

                  SizedBox(height: 4),

                  // Şifremi Unuttum
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push(AppRoutes.forgotPassword),
                      child: Text(
                        'Şifremi Unuttum',
                        style: TextStyle(
                          color: context.colors.primary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 8),

                  // Giriş Yap Butonu
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () => _submit(
                              ref,
                              emailController,
                              passwordController,
                            ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: context.colors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.colors.card,
                              ),
                            )
                          : const Text(
                              'Giriş Yap',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),

                  SizedBox(height: 16),

                  // ── VEYA ayırıcı ──────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(child: Divider(color: context.colors.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'veya',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: context.colors.border)),
                    ],
                  ),

                  SizedBox(height: 16),

                  // ── Google ile Giriş ──────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: isLoading
                          ? null
                          : () => ref
                                .read(authProvider.notifier)
                                .signInWithGoogle(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(color: context.colors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: context.colors.card,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Google "G" logosu
                          Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: CustomPaint(painter: _GoogleLogoPainter()),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Google ile Giriş Yap',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  // Kayıt Ol
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Hesabın yok mu?',
                        style: TextStyle(color: context.colors.textSecondary),
                      ),
                      TextButton(
                        onPressed: () => context.push(AppRoutes.signUp),
                        child: Text(
                          'Kayıt Ol',
                          style: TextStyle(
                            color: context.colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Dil seçici
                  if (!isKeyboardOpen) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundImage: const AssetImage(
                            'assets/images/flags/tr.png',
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Türkçe',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ] else
                    const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Butona basınca veya klavyeden done'a basınca çağrılır.
  /// Tüm validasyon AuthNotifier.signIn() içinde yapılır.
  void _submit(
    WidgetRef ref,
    TextEditingController email,
    TextEditingController password,
  ) {
    ref
        .read(authProvider.notifier)
        .signIn(email: email.text.trim(), password: password.text.trim());
  }
}

// ── Google "G" Logo Painter ───────────────────────────────────────────────────

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Renkler
    const blue = Color(0xFF4285F4);
    const red = Color(0xFFEA4335);
    const yellow = Color(0xFFFBBC05);
    const green = Color(0xFF34A853);

    final paint = Paint()..style = PaintingStyle.fill;

    // Mavi dilim (sağ)
    paint.color = blue;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -0.35,
      2.07,
      true,
      paint,
    );

    // Kırmızı dilim (sol üst)
    paint.color = red;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      math.pi + 0.35,
      1.22,
      true,
      paint,
    );

    // Sarı dilim (sol alt)
    paint.color = yellow;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      math.pi * 1.5 - 0.12,
      0.85,
      true,
      paint,
    );

    // Yeşil dilim (sağ alt)
    paint.color = green;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      math.pi * 1.83,
      0.88,
      true,
      paint,
    );

    // Orta beyaz daire
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r * 0.6, paint);

    // Mavi yatay çizgi (G harfinin kolu)
    paint.color = blue;
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - r * 0.13, r * 0.95, r * 0.27),
      paint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
