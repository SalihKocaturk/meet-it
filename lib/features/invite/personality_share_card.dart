import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/constants/emerald_palette.dart';
import 'package:meetit/core/utils/text_utils.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/invite/invite_link.dart';
import 'package:meetit/features/personality/models/personality_model.dart';
import 'package:meetit/features/personality/widgets/personality_character.dart';
import 'package:share_plus/share_plus.dart';

// ── Paylaşılabilir kişilik kartı ─────────────────────────────────────────────
//
// Story boyutunda (9:16) kart: karakter, tip adı, ilk 3 tipin yüzdesi ve
// "Benimle uyumunu test et" çağrısı. Kart görsel olarak, davet linki metin
// olarak paylaşılır — linke tıklayan arkadaş uygulamayı açınca otomatik
// arkadaş olunur ve testi bitirince uyum ekranı gelir (bkz. invite_host).

/// Kartı önizleyip paylaşma alt sayfasını açar. [profile] verilmezse
/// kullanıcının kayıtlı profili kullanılır.
Future<void> showPersonalityShareSheet(
  BuildContext context,
  WidgetRef ref, {
  PersonalityProfile? profile,
}) {
  final user = ref.read(currentUserProvider);
  final p = profile ?? user?.personalityProfile;
  if (user == null || p == null) return Future.value();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.scaffold,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ShareSheet(
      profile: p,
      uid: user.uid,
      name: user.name,
      gender: user.gender,
    ),
  );
}

class _ShareSheet extends StatefulWidget {
  final PersonalityProfile profile;
  final String uid;
  final String name;
  final String? gender;

  const _ShareSheet({
    required this.profile,
    required this.uid,
    required this.name,
    required this.gender,
  });

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _cardKey = GlobalKey();
  bool _busy = false;

  String get _firstName => titleCaseName(
        widget.name.split(' ').first,
        turkish: context.locale.languageCode == 'tr',
      );

  Uri get _link => InviteLink.build(uid: widget.uid, firstName: _firstName);

  String get _shareText => 'invite.share_text'.tr(namedArgs: {
        'type': widget.profile.dominantType.displayName,
        'link': _link.toString(),
      });

  Future<Uint8List?> _capture() async {
    final boundary = _cardKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    // Kart 360×640 mantıksal boyutta çizilir → 3x = 1080×1920 Story.
    final image = await boundary.toImage(
      pixelRatio: 1080 / PersonalityShareCard.width,
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final png = await _capture();
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(ShareParams(
        text: _shareText,
        files: [
          if (png != null)
            XFile.fromData(png, mimeType: 'image/png', name: 'meetit-kisilik.png'),
        ],
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ));
    } catch (e) {
      debugPrint('[ShareCard] paylaşım hatası: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _link.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('invite.link_copied'.tr())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxCardHeight = MediaQuery.sizeOf(context).height * 0.58;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'invite.sheet_title'.tr(),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'invite.sheet_desc'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
            ),
            const SizedBox(height: 14),
            // Önizleme: kart sabit 360×640'ta çizilir, ekrana sığacak kadar
            // küçültülür. Yakalama RepaintBoundary'den tam çözünürlükte.
            SizedBox(
              height: maxCardHeight,
              child: FittedBox(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: PersonalityShareCard(
                      profile: widget.profile,
                      firstName: _firstName,
                      friendCode: widget.uid.substring(0, 6).toUpperCase(),
                      gender: widget.gender,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _share,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.ios_share_rounded, color: Colors.white),
                label: Text(
                  'invite.share_button'.tr(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Emerald.base,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _copyLink,
              icon: Icon(Icons.link_rounded, size: 18, color: context.accentStrong),
              label: Text(
                'invite.copy_link'.tr(),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: context.accentStrong,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartın kendisi — sabit 360×640 mantıksal boyut (9:16).
class PersonalityShareCard extends StatelessWidget {
  static const double width = 360;
  static const double height = 640;

  final PersonalityProfile profile;
  final String firstName;
  final String friendCode;
  final String? gender;

  const PersonalityShareCard({
    super.key,
    required this.profile,
    required this.firstName,
    required this.friendCode,
    this.gender,
  });

  static Color _typeColor(PersonalityType t) {
    final hex = t.colorHex.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final dominant = profile.dominantType;
    final secondary = profile.secondaryType;
    final top = profile.rankedTypes.take(3).toList();
    final accent = _typeColor(dominant);

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F2A20), Color(0xFF0B1512)],
          ),
        ),
        child: Stack(
          children: [
            // Tipin renginde yumuşak hale
            Positioned(
              top: 70,
              left: 40,
              right: 40,
              height: 260,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [accent.withOpacity(0.28), accent.withOpacity(0)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 26, 26, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/logo_icon.png',
                          width: 28,
                          height: 28,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'MeetIt',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'invite.card_label'.tr(namedArgs: {'name': firstName}),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  PersonalityCharacterWidget(
                    type: dominant,
                    gender: gender,
                    size: 210,
                    showBackground: false,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${dominant.emoji} ${dominant.displayName}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (secondary != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'invite.card_secondary'.tr(namedArgs: {
                        'name': secondary.displayName,
                      }),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  for (final e in top) ...[
                    _Bar(
                      label: e.key.displayName,
                      value: e.value,
                      color: _typeColor(e.key),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Emerald.base.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Emerald.base.withOpacity(0.45)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'invite.card_cta'.tr(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'invite.card_code'.tr(namedArgs: {'code': friendCode}),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Emerald.pale,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _Bar({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).round();
    return Row(
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: Colors.white.withOpacity(0.10)),
                  FractionallySizedBox(
                    widthFactor: value.clamp(0.02, 1.0),
                    child: Container(color: color),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 38,
          child: Text(
            '%$pct',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
