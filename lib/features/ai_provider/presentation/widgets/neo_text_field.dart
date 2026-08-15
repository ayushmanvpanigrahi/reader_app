import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Flat Material text field with label and optional inline error,
/// replacing the debossed neomorphic field used by the old provider screens.
class NeoTextField extends StatefulWidget {
  final String label;
  final String hint;
  final String initialValue;
  final TextEditingController? controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final String? errorText;
  final String? helperText;

  const NeoTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.initialValue,
    this.controller,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    required this.onChanged,
    this.onSubmitted,
    this.suffix,
    this.errorText,
    this.helperText,
  });

  @override
  State<NeoTextField> createState() => _NeoTextFieldState();
}

class _NeoTextFieldState extends State<NeoTextField> {
  late final TextEditingController _controller;
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController(text: widget.initialValue);
    _obscured = widget.obscure;
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _controller,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autocorrect: false,
          enableSuggestions: false,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.darkInk : AppColors.lightInk,
          ),
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.darkMuted.withValues(alpha: 0.7)
                  : AppColors.lightMuted.withValues(alpha: 0.7),
            ),
            errorText: widget.errorText,
            errorMaxLines: 3,
            helperText: widget.helperText,
            suffixIcon: widget.obscure
                ? IconButton(
                    icon: Icon(
                      _obscured ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      size: 19,
                      color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : widget.suffix,
          ),
        ),
      ],
    );
  }
}
