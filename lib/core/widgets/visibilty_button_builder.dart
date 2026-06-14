import 'package:flutter/material.dart';

class VisibilityButtonBuilder extends StatefulWidget {
  const VisibilityButtonBuilder({
    super.key,
    required this.builder,
    this.initialObscure = true,
    this.onChanged,
  });
  final Widget Function(BuildContext context, bool obscure, Widget iconButton)
  builder;
  final bool initialObscure;
  final ValueChanged<bool>? onChanged;
  @override
  State<VisibilityButtonBuilder> createState() =>
      _VisibilityButtonBuilderState();
}

class _VisibilityButtonBuilderState extends State<VisibilityButtonBuilder> {
  late bool _obscure = widget.initialObscure;
  void _toggle() {
    setState(() => _obscure = !_obscure);
    widget.onChanged?.call(_obscure);
  }

  @override
  Widget build(BuildContext context) {
    final icon = IconButton(
      icon: Icon(
        _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
        color: Color.fromRGBO(203, 213, 224, 1),
        size: 24,
      ),
      onPressed: _toggle,
    );
    return widget.builder(context, _obscure, icon);
  }
}
