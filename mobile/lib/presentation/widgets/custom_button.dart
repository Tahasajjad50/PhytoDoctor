import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum ButtonVariant { primary, outlined, admin, danger }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final double height;
  final double? width;

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.height = AppTheme.standardButtonHeight,
    this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color fgColor;
    BorderSide? borderSide;

    switch (variant) {
      case ButtonVariant.primary:
        bgColor = AppTheme.botanicalPrimary;
        fgColor = Colors.white;
        borderSide = BorderSide.none;
        break;
      case ButtonVariant.outlined:
        bgColor = AppTheme.surfaceCard;
        fgColor = AppTheme.botanicalPrimary;
        borderSide = const BorderSide(color: AppTheme.botanicalPrimary, width: 1.5);
        break;
      case ButtonVariant.admin:
        bgColor = AppTheme.adminSlate;
        fgColor = Colors.white;
        borderSide = BorderSide.none;
        break;
      case ButtonVariant.danger:
        bgColor = AppTheme.alertCrimson;
        fgColor = Colors.white;
        borderSide = BorderSide.none;
        break;
    }

    final child = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: fgColor),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: fgColor,
                ),
              ),
            ],
          );

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          disabledBackgroundColor: bgColor.withOpacity(0.6),
          side: borderSide,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
          ),
        ),
        child: child,
      ),
    );
  }
}
