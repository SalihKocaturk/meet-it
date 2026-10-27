import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/constants/emerald_palette.dart';
import 'package:meetit/features/match/models/place_result.dart';
import 'package:meetit/features/match/providers/match_provider.dart';
import 'package:meetit/features/match/providers/saved_venues_provider.dart';
import 'package:meetit/features/match/services/places_service.dart';
import 'package:meetit/features/share_links/poll.dart';

// ── Oylama hazırlama ekranı ──────────────────────────────────────────────────
//
// "Gruba sor"a basınca doğrudan paylaşmak yerine bu ekran açılır:
//  • üstte oylamadaki seçenekler (bulunan ilk 3 hazır gelir, × ile çıkar)
//  • arama kutusu: Google'da mekan arar; bulunamazsa yazılan metin
//    serbest seçenek olarak eklenebilir ("Bende film gecesi")
//  • sekmeler: Bulunanlar / Kaydedilenler / Gittiklerin — dokununca ekle/çıkar
//  • altta "Oylamayı paylaş" (2-6 seçenek)

class PollComposerPage extends ConsumerStatefulWidget {
  /// Mekan aramasında bulunan mekanlar (ilk 3'ü hazır seçili gelir).
  final List<PlaceResult> foundVenues;

  const PollComposerPage({super.key, this.foundVenues = const []});

  @override
  ConsumerState<PollComposerPage> createState() => _PollComposerPageState();
}

class _PollComposerPageState extends ConsumerState<PollComposerPage> {
  late final List<PollOption> _selected = [
    for (final v in widget.foundVenues.take(3)) PollOption.fromPlace(v),
  ];
  final _query = TextEditingController();
  Timer? _debounce;
  List<PlaceResult> _results = const [];
  bool _searching = false;
  int _tab = 0;
  bool _sharing = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  bool _isSelected(String key) => _selected.any((o) => o.key == key);

  void _toggle(PollOption option) {
    setState(() {
      final i = _selected.indexWhere((o) => o.key == option.key);
      if (i >= 0) {
        _selected.removeAt(i);
      } else if (_selected.length >= kPollMaxOptions) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('poll.max_reached'.tr())));
      } else {
        _selected.add(option);
      }
    });
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    setState(() {
      if (q.length < 3) {
        _results = const [];
        _searching = false;
      } else {
        _searching = true;
      }
    });
    if (q.length < 3) return;
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final loc = ref.read(userLocationProvider);
      final anchor = widget.foundVenues.isNotEmpty
          ? widget.foundVenues.first
          : null;
      final results = await PlacesService.searchText(
        q,
        lat: loc?.lat ?? anchor?.lat,
        lng: loc?.lng ?? anchor?.lng,
        languageCode: context.locale.languageCode,
      );
      if (!mounted || _query.text.trim() != q) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    });
  }

  void _addCustom() {
    final text = _query.text.trim();
    if (text.isEmpty) return;
    final option = PollOption.text(text);
    if (!_isSelected(option.key)) _toggle(option);
    _query.clear();
    _onQueryChanged('');
    FocusScope.of(context).unfocus();
  }

  Future<void> _share(BuildContext btnContext) async {
    if (_sharing || _selected.length < kPollMinOptions) return;
    setState(() => _sharing = true);
    final ok = await createAndSharePoll(btnContext, ref, List.of(_selected));
    if (!mounted) return;
    setState(() => _sharing = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(savedVenuesProvider);
    final visited = ref.watch(navigatedVenuesProvider);
    final hasQuery = _query.text.trim().isNotEmpty;
    final canShare = _selected.length >= kPollMinOptions;

    final source = switch (_tab) {
      0 => widget.foundVenues,
      1 => saved,
      _ => visited,
    };
    final emptyKey = switch (_tab) {
      0 => 'poll.empty_found',
      1 => 'poll.empty_saved',
      _ => 'poll.empty_visited',
    };

    return Scaffold(
      backgroundColor: context.colors.scaffold,
      appBar: AppBar(
        backgroundColor: context.colors.scaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'poll.compose_title'.tr(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        iconTheme: IconThemeData(color: context.colors.textPrimary),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Text(
                  'poll.compose_desc'.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),

                // ── Seçili seçenekler ────────────────────────────────────
                _SectionTitle(
                  'poll.selected_title'.tr(namedArgs: {
                    'count': '${_selected.length}',
                    'max': '$kPollMaxOptions',
                  }),
                ),
                if (_selected.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'poll.empty_selected'.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < _selected.length; i++)
                    _SelectedTile(
                      index: i + 1,
                      option: _selected[i],
                      onRemove: () => _toggle(_selected[i]),
                    ),
                const SizedBox(height: 20),

                // ── Arama / serbest seçenek ──────────────────────────────
                TextField(
                  controller: _query,
                  onChanged: _onQueryChanged,
                  onSubmitted: (_) => _addCustom(),
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: 'poll.search_hint'.tr(),
                    hintStyle:
                        TextStyle(color: context.colors.hint, fontSize: 14),
                    prefixIcon: Icon(
                      Iconsax.search_normal_1,
                      color: context.colors.hint,
                      size: 20,
                    ),
                    suffixIcon: hasQuery
                        ? IconButton(
                            icon: Icon(
                              Iconsax.close_circle,
                              color: context.colors.hint,
                              size: 20,
                            ),
                            onPressed: () {
                              _query.clear();
                              _onQueryChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: context.colors.card,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: Emerald.base, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                if (hasQuery) ...[
                  _CustomOptionTile(
                    text: _query.text.trim(),
                    selected:
                        _isSelected(PollOption.text(_query.text).key),
                    onTap: _addCustom,
                  ),
                  if (_searching)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.accentStrong,
                          ),
                        ),
                      ),
                    )
                  else if (_query.text.trim().length >= 3 && _results.isEmpty)
                    _EmptyHint('poll.no_results'.tr())
                  else
                    for (final p in _results)
                      _PlaceTile(
                        place: p,
                        selected: _isSelected(PollOption.fromPlace(p).key),
                        onTap: () => _toggle(PollOption.fromPlace(p)),
                      ),
                ] else ...[
                  _SourceTabs(
                    index: _tab,
                    labels: [
                      'poll.tab_found'.tr(),
                      'poll.tab_saved'.tr(),
                      'poll.tab_visited'.tr(),
                    ],
                    onChanged: (i) => setState(() => _tab = i),
                  ),
                  const SizedBox(height: 10),
                  if (source.isEmpty)
                    _EmptyHint(emptyKey.tr())
                  else
                    for (final p in source)
                      _PlaceTile(
                        place: p,
                        selected: _isSelected(PollOption.fromPlace(p).key),
                        onTap: () => _toggle(PollOption.fromPlace(p)),
                      ),
                ],
              ],
            ),
          ),

          // ── Paylaş ─────────────────────────────────────────────────────
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Builder(
                builder: (btnContext) => SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: canShare && !_sharing
                        ? () => _share(btnContext)
                        : null,
                    icon: _sharing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Iconsax.send_2, color: Colors.white),
                    label: Text(
                      canShare
                          ? 'poll.share_btn'.tr()
                          : 'poll.need_more'.tr(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Emerald.base,
                      disabledBackgroundColor:
                          Emerald.base.withValues(alpha: 0.35),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Parçalar ────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
      );
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
          ),
        ),
      );
}

String _subtitle(double? rating, int? count, String? address) {
  final r = rating == null
      ? ''
      : '★ ${rating.toStringAsFixed(1)}${count != null ? ' ($count)' : ''}';
  return [r, address ?? ''].where((s) => s.isNotEmpty).join(' · ');
}

/// Oylamadaki bir seçenek: sıra numarası, ad, alt bilgi ve çıkar butonu.
class _SelectedTile extends StatelessWidget {
  final int index;
  final PollOption option;
  final VoidCallback onRemove;

  const _SelectedTile({
    required this.index,
    required this.option,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final sub = option.isCustom
        ? 'poll.custom_label'.tr()
        : _subtitle(option.rating, option.ratingCount, option.address);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Emerald.base.withValues(
                alpha: context.isDarkTheme ? 0.20 : 0.16,
              ),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.accentStrong,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                if (sub.isNotEmpty)
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox.square(
            dimension: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: 'poll.remove'.tr(),
              onPressed: onRemove,
              icon: Icon(
                Iconsax.close_circle,
                size: 20,
                color: context.colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Eklenebilir mekan satırı (sekmeler ve arama sonuçları).
class _PlaceTile extends StatelessWidget {
  final PlaceResult place;
  final bool selected;
  final VoidCallback onTap;

  const _PlaceTile({
    required this.place,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sub = _subtitle(place.rating, place.userRatingsTotal, place.vicinity);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(Iconsax.location, size: 20, color: context.accentStrong),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  if (sub.isNotEmpty)
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? Iconsax.tick_circle : Iconsax.add_circle,
              size: 22,
              color: selected
                  ? context.accentStrong
                  : context.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Yazılan metni serbest seçenek olarak ekleme satırı.
class _CustomOptionTile extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _CustomOptionTile({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: selected ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(Iconsax.edit_2, size: 20, color: context.accentStrong),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'poll.add_custom'.tr(namedArgs: {'text': text}),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? Iconsax.tick_circle : Iconsax.add_circle,
              size: 22,
              color: selected
                  ? context.accentStrong
                  : context.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Arkadaşlar ekranındaki sekmelerle aynı segmented control.
class _SourceTabs extends StatelessWidget {
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  const _SourceTabs({
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? Emerald.base : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: i == index
                            ? Colors.white
                            : context.colors.textPrimary
                                .withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
