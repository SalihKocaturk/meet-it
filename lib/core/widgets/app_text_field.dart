import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meetit/core/constants/app_colors.dart';

/// Uygulamanın ana text field widget'i.
///
/// Scaffold arka planı ile uyumlu, label üstte ayrı bir Text olarak gösterilir.
///
/// Kullanım:
/// ```dart
/// AppTextField(
///   controller: _emailCtrl,
///   label: 'Email',
///   hint: 'ornek@email.com',
///   prefixIcon: Icons.mail_outline,
/// )
/// ```
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.isPassword = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.readOnly = false,
    this.enabled = true,
    this.errorText,
    this.maxLines = 1,
    this.focusNode,
    this.inputFormatters,
    this.autofocus = false,
  });

  final TextEditingController? controller;

  /// Label field'ın üstünde gösterilir.
  final String? label;

  /// Placeholder metni.
  final String? hint;

  /// true ise şifre göster/gizle butonu eklenir.
  final bool isPassword;

  /// Sol ikon (örn. Icons.mail_outline).
  final IconData? prefixIcon;

  /// Sağ taraftaki custom widget (isPassword=true ise göz ikonu bunu ezer).
  final Widget? suffixIcon;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool readOnly;
  final bool enabled;

  /// Kırmızı hata metni — null ise gösterilmez.
  final String? errorText;

  final int maxLines;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscure = true;
  bool _hasFocus = false;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() => _hasFocus = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.removeListener(_onFocusChange);
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    // Aktif border rengi: hata varsa kırmızı, focus'ta yeşil, yoksa border
    final activeBorderColor = hasError
        ? colors.error
        : _hasFocus
            ? colors.primary
            : colors.border;

    final borderRadius = BorderRadius.circular(14);

    final border = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: activeBorderColor, width: 1.4),
    );

    final suffixWidget = widget.isPassword
        ? _PasswordToggle(
            obscure: _obscure,
            onTap: () => setState(() => _obscure = !_obscure),
            hintColor: colors.hint,
          )
        : widget.suffixIcon;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Label ──────────────────────────────────────────────────────────
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: hasError
                  ? colors.error
                  : _hasFocus
                      ? colors.primary
                      : colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
        ],

        // ── TextField ──────────────────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            // Focus'ta hafif glow
            boxShadow: _hasFocus && !hasError
                ? [
                    BoxShadow(
                      color: colors.primary.withOpacity(0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : hasError
                    ? [
                        BoxShadow(
                          color: colors.error.withOpacity(0.10),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: widget.isPassword ? _obscure : false,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            readOnly: widget.readOnly,
            enabled: widget.enabled,
            maxLines: widget.isPassword ? 1 : widget.maxLines,
            inputFormatters: widget.inputFormatters,
            autofocus: widget.autofocus,
            style: TextStyle(
              fontSize: 15,
              color: colors.textPrimary,
              fontWeight: FontWeight.w400,
            ),
            cursorColor: colors.primary,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                color: colors.hint,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),

              filled: true,
              fillColor: colors.card,

              contentPadding: EdgeInsets.symmetric(
                horizontal: widget.prefixIcon != null ? 4 : 16,
                vertical: 14,
              ),

              // Prefix ikon
              prefixIcon: widget.prefixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 12, right: 8),
                      child: Icon(
                        widget.prefixIcon,
                        size: 20,
                        color: _hasFocus
                            ? colors.primary
                            : colors.hint,
                      ),
                    )
                  : null,
              prefixIconConstraints: const BoxConstraints(
                minWidth: 44,
                minHeight: 44,
              ),

              // Suffix ikon / görünürlük butonu
              suffixIcon: suffixWidget != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: suffixWidget,
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 44,
                minHeight: 44,
              ),

              border: border,
              enabledBorder: OutlineInputBorder(
                borderRadius: borderRadius,
                borderSide: BorderSide(
                  color: hasError ? colors.error : colors.border,
                  width: 1.2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: borderRadius,
                borderSide: BorderSide(
                  color: hasError ? colors.error : colors.primary,
                  width: 1.6,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: borderRadius,
                borderSide: BorderSide(
                  color: colors.border.withOpacity(0.5),
                  width: 1.0,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: borderRadius,
                borderSide: BorderSide(
                  color: colors.error,
                  width: 1.4,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: borderRadius,
                borderSide: BorderSide(
                  color: colors.error,
                  width: 1.6,
                ),
              ),

              errorText: null,
              isDense: false,
            ),
          ),
        ),

        // ── Hata metni ──────────────────────────────────────────────────────
        if (hasError) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(Icons.error_outline,
                  size: 13, color: colors.error),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.errorText!,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Şifre görünürlük butonu ────────────────────────────────────────────────────
class _PasswordToggle extends StatelessWidget {
  const _PasswordToggle({required this.obscure, required this.onTap, required this.hintColor});

  final bool obscure;
  final VoidCallback onTap;
  final Color hintColor;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          key: ValueKey(obscure),
          size: 20,
          color: hintColor,
        ),
      ),
      splashRadius: 18,
    );
  }
}
