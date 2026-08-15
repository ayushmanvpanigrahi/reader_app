import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../theme/neumorphic_decorations.dart';

/// A tactile Neomorphic interactive button with dynamic press animations,
/// haptic feedback support, and toggle state handling.
class NeumorphicButton extends StatefulWidget {
  final Widget? child;
  final IconData? icon;
  final double? iconSize;
  final Color? iconColor;
  final String? text;
  final TextStyle? textStyle;
  final VoidCallback? onPressed;
  final double borderRadius;
  final double depth;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool isCircle;
  final bool isSelected;
  final bool isAccent;
  final Color? customColor;
  final String? tooltip;

  const NeumorphicButton({
    super.key,
    this.child,
    this.icon,
    this.iconSize,
    this.iconColor,
    this.text,
    this.textStyle,
    this.onPressed,
    this.borderRadius = 14.0,
    this.depth = 3.5,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.isCircle = false,
    this.isSelected = false,
    this.isAccent = false,
    this.customColor,
    this.tooltip,
  });

  /// Factory constructor for a quick circular icon button (e.g., Back, Settings, Close)
  factory NeumorphicButton.icon({
    Key? key,
    required IconData icon,
    required VoidCallback? onPressed,
    double size = 46.0,
    double iconSize = 20.0,
    Color? iconColor,
    bool isSelected = false,
    bool isAccent = false,
    Color? customColor,
    String? tooltip,
    EdgeInsetsGeometry? margin,
  }) {
    return NeumorphicButton(
      key: key,
      icon: icon,
      iconSize: iconSize,
      iconColor: iconColor,
      onPressed: onPressed,
      width: size,
      height: size,
      isCircle: true,
      isSelected: isSelected,
      isAccent: isAccent,
      customColor: customColor,
      tooltip: tooltip,
      margin: margin,
      padding: EdgeInsets.zero,
    );
  }

  @override
  State<NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<NeumorphicButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = true);
    HapticFeedback.selectionClick();
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = widget.onPressed != null;

    final shape = widget.isSelected || _isPressed
        ? NeumorphicShape.debossed
        : (widget.isAccent ? NeumorphicShape.accent : NeumorphicShape.embossed);

    final defaultPadding = widget.isCircle
        ? EdgeInsets.zero
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    final defaultIconColor = widget.iconColor ??
        (widget.isAccent
            ? (isDark ? AppColors.darkPrimaryForeground : Colors.white)
            : (widget.isSelected
                ? (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                : (isDark ? AppColors.darkInk : AppColors.lightInk)));

    Widget content;
    if (widget.child != null) {
      content = widget.child!;
    } else if (widget.icon != null && widget.text != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(widget.icon, size: widget.iconSize ?? 18, color: defaultIconColor),
          const SizedBox(width: 8),
          Text(
            widget.text!,
            style: widget.textStyle ??
                TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: defaultIconColor,
                ),
          ),
        ],
      );
    } else if (widget.icon != null) {
      content = Icon(widget.icon, size: widget.iconSize ?? 20, color: defaultIconColor);
    } else if (widget.text != null) {
      content = Text(
        widget.text!,
        style: widget.textStyle ??
            TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: defaultIconColor,
            ),
      );
    } else {
      content = const SizedBox.shrink();
    }

    Widget button = AnimatedScale(
      scale: _isPressed ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeInOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        width: widget.width,
        height: widget.height,
        margin: widget.margin,
        padding: widget.padding ?? defaultPadding,
        decoration: NeumorphicDecorations.boxDecoration(
          context: context,
          shape: shape,
          borderRadius: widget.borderRadius,
          depth: _isPressed ? 1.5 : widget.depth,
          isCircle: widget.isCircle,
          color: widget.customColor,
        ),
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.45,
          child: (widget.width != null || widget.height != null)
              ? Center(child: content)
              : content,
        ),
      ),
    );


    if (widget.tooltip != null) {
      button = Tooltip(
        message: widget.tooltip!,
        child: button,
      );
    }

    return GestureDetector(
      onTapDown: isEnabled ? _handleTapDown : null,
      onTapUp: isEnabled ? _handleTapUp : null,
      onTapCancel: isEnabled ? _handleTapCancel : null,
      onTap: widget.onPressed,
      behavior: HitTestBehavior.opaque,
      child: button,
    );
  }
}
