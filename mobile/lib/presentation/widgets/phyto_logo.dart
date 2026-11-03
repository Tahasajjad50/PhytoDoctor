import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Official Phyto Doctor brand logo display component
/// Loads the actual official asset inspected from https://phytodoctor.pk/
class PhytoDoctorLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final bool compactIconOnly;
  final bool showTagline;

  const PhytoDoctorLogo({
    Key? key,
    this.width,
    this.height,
    this.compactIconOnly = false,
    this.showTagline = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (compactIconOnly) {
      return Image.asset(
        'assets/images/phytodoctor_icon.png',
        width: width ?? 54,
        height: height ?? 54,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _fallbackIcon(width ?? 54),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Official Phyto Doctor brand banner
        Container(
          constraints: BoxConstraints(
            maxWidth: width ?? 280,
            maxHeight: height ?? 72,
          ),
          child: Image.asset(
            'assets/images/phytodoctor_logo.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _fallbackBrandHeader(),
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.sageLight,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.sageBorder, width: 1.0),
            ),
            child: const Text(
              'AGRI-BIOTECH & CROP PROTECTION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppTheme.botanicalDark,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _fallbackIcon(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.botanicalPrimary,
        borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
      ),
      child: const Center(
        child: Icon(Icons.eco, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _fallbackBrandHeader() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _fallbackIcon(42),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'PHYTO DOCTOR',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppTheme.botanicalDark,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'Agri-Biotech Company of Pakistan',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
