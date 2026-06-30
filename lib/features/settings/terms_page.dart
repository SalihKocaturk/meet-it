import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:meetit/core/constants/app_colors.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: context.colors.scaffold,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: context.colors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'legal.terms_title'.tr(),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: context.colors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(context, 'legal.terms_s1_title'.tr(), 'legal.terms_s1_body'.tr()),
            _buildSection(context, 'legal.terms_s2_title'.tr(), 'legal.terms_s2_body'.tr()),
            _buildSection(context, 'legal.terms_s3_title'.tr(), 'legal.terms_s3_body'.tr()),
            _buildSection(context, 'legal.terms_s4_title'.tr(), 'legal.terms_s4_body'.tr()),
            _buildSection(context, 'legal.terms_s5_title'.tr(), 'legal.terms_s5_body'.tr()),
            _buildSection(context, 'legal.terms_s6_title'.tr(), 'legal.terms_s6_body'.tr()),
            const SizedBox(height: 32),
            Text(
              'legal.terms_last_updated'.tr(),
              style: TextStyle(fontSize: 12, color: context.colors.hint),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              fontSize: 14,
              color: context.colors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
