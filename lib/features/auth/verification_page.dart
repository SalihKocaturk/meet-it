import 'package:flutter/material.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/features/auth/sign_in_page.dart';

class VerificationPage extends StatelessWidget {
  final String email;

  const VerificationPage({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: context.colors.scaffold,
        elevation: 0,
        leading: BackButton(color: context.colors.textPrimary),
        title: Text(
          'Email Doğrulama',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.email_outlined,
                size: 80,
                color: context.colors.primary,
              ),
              SizedBox(height: 24),
              Text(
                'Email Adresinizi Doğrulayın',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
              SizedBox(height: 12),
              Text(
                '$email adresine bir doğrulama linki gönderdik. Lütfen emailinizi kontrol edin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 40),

              // Doğrulandı butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: FirebaseAuth ile doğrulama kontrolü yapılacak
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const SignInPage()),
                      (_) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: context.colors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Doğruladım, Giriş Yap',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 16),

              // Tekrar gönder
              TextButton(
                onPressed: () {
                  // TODO: FirebaseAuth.instance.currentUser?.sendEmailVerification()
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Doğrulama emaili tekrar gönderildi.'),
                      backgroundColor: context.colors.success,
                    ),
                  );
                },
                child: Text(
                  'Tekrar Gönder',
                  style: TextStyle(color: context.colors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
