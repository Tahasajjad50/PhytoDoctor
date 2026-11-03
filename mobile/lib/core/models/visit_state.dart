import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The operational offline synchronization state of a Field Visit
enum VisitSyncState {
  /// Visit is currently being authored; not yet submitted for sync
  draft,

  /// Stored securely in local SQLite; awaiting network transmission
  pendingSync,

  /// Transmission currently in-flight over HTTP/Cloudinary
  syncing,

  /// Successfully confirmed and verified by Phyto Doctor backend server
  synced,

  /// Flagged by backend review signals (e.g. mock GPS, clock drift, >50m accuracy)
  needsReview,

  /// Network or server error during last attempt; queued for backoff retry
  syncFailed,
}

extension VisitSyncStateX on VisitSyncState {
  String get label {
    switch (this) {
      case VisitSyncState.draft:
        return 'Draft';
      case VisitSyncState.pendingSync:
        return 'Pending Sync';
      case VisitSyncState.syncing:
        return 'Syncing...';
      case VisitSyncState.synced:
        return 'Synced';
      case VisitSyncState.needsReview:
        return 'Needs Review';
      case VisitSyncState.syncFailed:
        return 'Sync Failed';
    }
  }

  Color get badgeColor {
    switch (this) {
      case VisitSyncState.draft:
        return AppTheme.textMuted;
      case VisitSyncState.pendingSync:
        return AppTheme.earthAmber;
      case VisitSyncState.syncing:
        return AppTheme.botanicalPrimary;
      case VisitSyncState.synced:
        return AppTheme.cropGreen;
      case VisitSyncState.needsReview:
        return const Color(0xFFD97706); // Dark Amber / Ochre
      case VisitSyncState.syncFailed:
        return AppTheme.alertCrimson;
    }
  }

  IconData get icon {
    switch (this) {
      case VisitSyncState.draft:
        return Icons.edit_note;
      case VisitSyncState.pendingSync:
        return Icons.cloud_queue;
      case VisitSyncState.syncing:
        return Icons.sync;
      case VisitSyncState.synced:
        return Icons.check_circle;
      case VisitSyncState.needsReview:
        return Icons.policy_outlined;
      case VisitSyncState.syncFailed:
        return Icons.error_outline;
    }
  }

  bool get isPendingOrFailed =>
      this == VisitSyncState.pendingSync || this == VisitSyncState.syncFailed;

  bool get isTerminal => this == VisitSyncState.synced;
}
