import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'custom_button.dart';

/// Reusable Loading State View
class LoadingView extends StatelessWidget {
  final String message;

  const LoadingView({Key? key, this.message = 'Loading data...'}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.8,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.botanicalPrimary),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable Empty State View
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionText;
  final VoidCallback? onAction;

  const EmptyStateView({
    Key? key,
    this.icon = Icons.assignment_outlined,
    required this.title,
    required this.description,
    this.actionText,
    this.onAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.sageLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.sageBorder),
              ),
              child: Icon(icon, size: 40, color: AppTheme.botanicalPrimary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textMuted,
                height: 1.4,
              ),
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 20),
              CustomButton(
                text: actionText!,
                onPressed: onAction,
                width: 200,
                height: 44,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Reusable Error State View
class ErrorStateView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorStateView({
    Key? key,
    required this.message,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
            border: Border.all(color: AppTheme.alertCrimson.withOpacity(0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 38, color: AppTheme.alertCrimson),
              const SizedBox(height: 12),
              const Text(
                'Operation Encountered an Error',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textMain,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 18),
                CustomButton(
                  text: 'Try Again',
                  onPressed: onRetry,
                  variant: ButtonVariant.outlined,
                  height: 42,
                  width: 150,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Offline Mode Status Banner
class OfflineBanner extends StatelessWidget {
  final int pendingCount;
  final VoidCallback? onSyncTap;

  const OfflineBanner({
    Key? key,
    this.pendingCount = 0,
    this.onSyncTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: AppTheme.earthAmberLight,
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 16, color: AppTheme.earthAmber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pendingCount > 0
                  ? 'Offline Mode: $pendingCount visit(s) queued for sync'
                  : 'Offline Mode: Device operating from local cache',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.earthAmber,
              ),
            ),
          ),
          if (onSyncTap != null)
            InkWell(
              onTap: onSyncTap,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  'SYNC',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.earthAmber,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
