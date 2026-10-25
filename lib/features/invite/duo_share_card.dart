import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/constants/emerald_palette.dart';
import 'package:meetit/core/services/analytics_service.dart';
import 'package:meetit/core/utils/text_utils.dart';
import 'package:meetit/core/widgets/circular_avatar.dart';
import 'package:meetit/features/auth/models/user_model.dart';
import 'package:meetit/features/personality/models/personality_model.dart';
import 'package:meetit/features/share_links/web_links.dart';
import 'package:share_plus/share_plus.dart';

/// "%84 uyumluyuz" çift kartı — uyum ekranından paylaşılır. İki kişi de
/// paylaşmak ister; altındaki link uygulama indirme sayfasına gider.
Future<void> showDuoShareSheet(
  BuildContext context, {
  required UserModel me,
  required UserModel friend,
  required int compat,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.scaffold,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _DuoSheet(me: me, friend: friend, compat: compat),
  );
}

class _DuoSheet extends StatefulWidget {
  final UserModel me;
  final UserModel friend;
  final int compat;

  const _DuoSheet({required this.me, required this.friend, required this.compat});

  @override
  State<_DuoSheet> createState() => _DuoSheetState();
}

class _DuoSheetState extends State<_DuoSheet> {
  final _key = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      AnalyticsService.shareDuoCard().ignore();
      final boundary =
          _key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      Uint8List? png;
      if (boundary != null) {
        final img = await boundary.toImage(pixelRatio: 1080 / DuoShareCard.width);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        png = bytes?.buffer.asUint8List();
      }
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(ShareParams(
        text: 'duo.share_text'.tr(namedArgs: {
          'value': '${widget.compat}',
          'link': WebLinks.download().toString(),
        }),
        files: [
          if (png != null)
            XFile.fromData(png, mimeType: 'image/png', name: 'meetit-uyum.png'),
        ],
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ));
    } catch (e) {
      debugPrint('[DuoCard] paylaşım hatası: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.58;
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
            SizedBox(
              height: h,
              child: FittedBox(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: RepaintBoundary(
                    key: _key,
                    child: DuoShareCard(
                      me: widget.me,
                      friend: widget.friend,
                      compat: widget.compat,
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
                icon: const Icon(Icons.ios_share_rounded, color: Colors.white),
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
          ],
        ),
      ),
    );
  }
}

class DuoShareCard extends StatelessWidget {
  static const double width = 360;
  static const double height = 640;

  final UserModel me;
  final UserModel friend;
  final int compat;

  const DuoShareCard({
    super.key,
    required this.me,
    required this.friend,
    required this.compat,
  });

  @override
  Widget build(BuildContext context) {
    final tr = context.locale.languageCode == 'tr';
    String first(String n) => titleCaseName(n.split(' ').first, turkish: tr);
    final myType = me.personalityProfile?.dominantType;
    final theirType = friend.personalityProfile?.dominantType;

    Widget person(UserModel u, PersonalityType? t) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Emerald.base,
              ),
              child: CircularAvatar(
                name: u.name,
                photoUrl: u.photoUrl,
                radius: 48,
                outline: false,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              first(u.name),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            if (t != null) ...[
              const SizedBox(height: 4),
              Text(
                '${t.emoji} ${t.displayName}',
                style: const TextStyle(fontSize: 12.5, color: Colors.white70),
              ),
            ],
          ],
        );

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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 28, 26, 26),
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
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(child: person(me, myType)),
                  const Text('🤝', style: TextStyle(fontSize: 30)),
                  Expanded(child: person(friend, theirType)),
                ],
              ),
              const SizedBox(height: 34),
              Text(
                '%$compat',
                style: const TextStyle(
                  fontSize: 84,
                  fontWeight: FontWeight.w900,
                  color: Emerald.light,
                  letterSpacing: -3,
                  height: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'duo.card_caption'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: Emerald.base.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Emerald.base.withOpacity(0.45)),
                ),
                child: Text(
                  'duo.card_cta'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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
