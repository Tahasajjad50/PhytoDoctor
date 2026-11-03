import 'dart:convert';
import 'visit_state.dart';

class LocalVisitModel {
  final String id; // UUID generated locally before upload
  final String employeeId;
  final String clientName;
  final String? clientPhone;
  final String clientType;
  final String visitPurpose;
  final String? notes;

  // Geolocation & Quality Metrics
  final double latitude;
  final double longitude;
  final double gpsAccuracy;
  final bool isMockLocation;

  // Timestamps
  final DateTime deviceCaptureTime;
  final DateTime? serverReceiptTime;

  // Evidence references (Stored in app-private sandbox)
  final String localPhotoPath;
  final String photoAssetId;
  final String? photoUploadUrl;

  // Synchronization & Backoff Management
  final VisitSyncState syncState;
  final int syncAttempts;
  final DateTime? lastSyncAttempt;
  final String? syncError;

  // Fraud-aware audit review flags
  final bool isFlaggedForReview;
  final List<String> reviewSignals;

  final DateTime createdAt;
  final DateTime updatedAt;

  LocalVisitModel({
    required this.id,
    required this.employeeId,
    required this.clientName,
    this.clientPhone,
    required this.clientType,
    required this.visitPurpose,
    this.notes,
    required this.latitude,
    required this.longitude,
    required this.gpsAccuracy,
    required this.isMockLocation,
    required this.deviceCaptureTime,
    this.serverReceiptTime,
    required this.localPhotoPath,
    required this.photoAssetId,
    this.photoUploadUrl,
    required this.syncState,
    this.syncAttempts = 0,
    this.lastSyncAttempt,
    this.syncError,
    this.isFlaggedForReview = false,
    this.reviewSignals = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  LocalVisitModel copyWith({
    String? id,
    String? employeeId,
    String? clientName,
    String? clientPhone,
    String? clientType,
    String? visitPurpose,
    String? notes,
    double? latitude,
    double? longitude,
    double? gpsAccuracy,
    bool? isMockLocation,
    DateTime? deviceCaptureTime,
    DateTime? serverReceiptTime,
    String? localPhotoPath,
    String? photoAssetId,
    String? photoUploadUrl,
    VisitSyncState? syncState,
    int? syncAttempts,
    DateTime? lastSyncAttempt,
    String? syncError,
    bool? isFlaggedForReview,
    List<String>? reviewSignals,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LocalVisitModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      clientType: clientType ?? this.clientType,
      visitPurpose: visitPurpose ?? this.visitPurpose,
      notes: notes ?? this.notes,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      gpsAccuracy: gpsAccuracy ?? this.gpsAccuracy,
      isMockLocation: isMockLocation ?? this.isMockLocation,
      deviceCaptureTime: deviceCaptureTime ?? this.deviceCaptureTime,
      serverReceiptTime: serverReceiptTime ?? this.serverReceiptTime,
      localPhotoPath: localPhotoPath ?? this.localPhotoPath,
      photoAssetId: photoAssetId ?? this.photoAssetId,
      photoUploadUrl: photoUploadUrl ?? this.photoUploadUrl,
      syncState: syncState ?? this.syncState,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      lastSyncAttempt: lastSyncAttempt ?? this.lastSyncAttempt,
      syncError: syncError ?? this.syncError,
      isFlaggedForReview: isFlaggedForReview ?? this.isFlaggedForReview,
      reviewSignals: reviewSignals ?? this.reviewSignals,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Converts record to SQLite database row map
  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'client_name': clientName,
      'client_phone': clientPhone,
      'client_type': clientType,
      'visit_purpose': visitPurpose,
      'notes': notes,
      'latitude': latitude,
      'longitude': longitude,
      'gps_accuracy': gpsAccuracy,
      'is_mock_location': isMockLocation ? 1 : 0,
      'device_capture_time': deviceCaptureTime.toUtc().toIso8601String(),
      'server_receipt_time': serverReceiptTime?.toUtc().toIso8601String(),
      'local_photo_path': localPhotoPath,
      'photo_asset_id': photoAssetId,
      'photo_upload_url': photoUploadUrl,
      'sync_state': syncState.name,
      'sync_attempts': syncAttempts,
      'last_sync_attempt': lastSyncAttempt?.toUtc().toIso8601String(),
      'sync_error': syncError,
      'is_flagged_for_review': isFlaggedForReview ? 1 : 0,
      'review_signals': jsonEncode(reviewSignals),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  /// Instantiates model from SQLite database row map
  factory LocalVisitModel.fromSqliteMap(Map<String, dynamic> map) {
    List<String> signals = [];
    if (map['review_signals'] != null) {
      try {
        final decoded = jsonDecode(map['review_signals'] as String);
        if (decoded is List) {
          signals = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    VisitSyncState state = VisitSyncState.pendingSync;
    final stateStr = map['sync_state'] as String?;
    if (stateStr != null) {
      for (final s in VisitSyncState.values) {
        if (s.name == stateStr) {
          state = s;
          break;
        }
      }
    }

    return LocalVisitModel(
      id: map['id'] as String,
      employeeId: (map['employee_id'] as String?) ?? '',
      clientName: map['client_name'] as String,
      clientPhone: map['client_phone'] as String?,
      clientType: (map['client_type'] as String?) ?? 'DEALER',
      visitPurpose: (map['visit_purpose'] as String?) ?? 'PRODUCT_PITCH',
      notes: map['notes'] as String?,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      gpsAccuracy: (map['gps_accuracy'] as num).toDouble(),
      isMockLocation: map['is_mock_location'] == 1 || map['is_mock_location'] == true,
      deviceCaptureTime: DateTime.parse(map['device_capture_time'] as String),
      serverReceiptTime: map['server_receipt_time'] != null
          ? DateTime.parse(map['server_receipt_time'] as String)
          : null,
      localPhotoPath: map['local_photo_path'] as String,
      photoAssetId: map['photo_asset_id'] as String,
      photoUploadUrl: map['photo_upload_url'] as String?,
      syncState: state,
      syncAttempts: (map['sync_attempts'] as num?)?.toInt() ?? 0,
      lastSyncAttempt: map['last_sync_attempt'] != null
          ? DateTime.parse(map['last_sync_attempt'] as String)
          : null,
      syncError: map['sync_error'] as String?,
      isFlaggedForReview: map['is_flagged_for_review'] == 1 || map['is_flagged_for_review'] == true,
      reviewSignals: signals,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Builds the REST API payload matching FastAPI VisitCreate schema
  Map<String, dynamic> toApiPayload() {
    return {
      'id': id, // UUID idempotency key
      'client_name': clientName,
      'client_phone': clientPhone,
      'notes': notes != null && notes!.isNotEmpty
          ? '[$clientType - $visitPurpose] $notes'
          : '[$clientType - $visitPurpose]',
      'latitude': latitude,
      'longitude': longitude,
      'gps_accuracy': gpsAccuracy,
      'is_mock_location': isMockLocation,
      'device_capture_time': deviceCaptureTime.toUtc().toIso8601String(),
      'photo_asset_id': photoAssetId,
      'photo_url': photoUploadUrl,
    };
  }
}
