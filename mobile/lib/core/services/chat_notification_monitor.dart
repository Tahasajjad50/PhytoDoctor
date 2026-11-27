import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import 'app_update_service.dart';
import 'auth_service.dart';
import 'chat_service.dart';
import 'notification_service.dart';

class ChatNotificationMonitor {
  static final ChatNotificationMonitor _instance = ChatNotificationMonitor._internal();
  factory ChatNotificationMonitor() => _instance;
  ChatNotificationMonitor._internal();

  UserModel? _currentUser;
  ChatService? _chatService;
  Timer? _pollingTimer;
  final Set<String> _seenMessageKeys = {};
  final Set<String> _seenVisitIds = {};
  final Map<String, String> _knownEmployeeVisitStatuses = {};
  bool _visitsSeeded = false;
  bool _employeeVisitsSeeded = false;
  bool _isChecking = false;
  int _pollCounter = 0;
  String? _notifiedUpdateVersion;

  void start(UserModel user) {
    _currentUser = user;
    _chatService = ChatService(token: user.accessToken);
    _seenVisitIds.clear();
    _knownEmployeeVisitStatuses.clear();
    _visitsSeeded = false;
    _employeeVisitsSeeded = false;
    NotificationService().initialize();
    _pollingTimer?.cancel();
    _checkForNewMessages();
    _pollingTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      _checkForNewMessages();
    });
    debugPrint('[ChatNotificationMonitor] Started background monitoring for ${user.username}');
  }

  void stop() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _currentUser = null;
    _chatService = null;
    _seenVisitIds.clear();
    _knownEmployeeVisitStatuses.clear();
    _visitsSeeded = false;
    _employeeVisitsSeeded = false;
    debugPrint('[ChatNotificationMonitor] Stopped');
  }

  Future<void> _checkForNewMessages() async {
    if (_isChecking || _chatService == null || _currentUser == null) return;
    _isChecking = true;

    try {
      final rooms = await _chatService!.getRooms();
      for (final room in rooms) {
        final lastMsg = room.lastMessage;
        final sender = room.lastMessageSender;
        final lastMsgAt = room.lastMessageAt;
        if (lastMsg == null || lastMsg.trim().isEmpty) continue;

        final key = '${room.id}_${lastMsg.trim()}_${lastMsgAt?.millisecondsSinceEpoch}';

        if (!_seenMessageKeys.contains(key)) {
          _seenMessageKeys.add(key);

          // Only notify if message is recent (within 10 minutes)
          // and not authored by the current user
          final isRecent = lastMsgAt != null && DateTime.now().difference(lastMsgAt).inMinutes < 10;
          final isOwnMessage = sender != null && (
            sender.toLowerCase().trim() == _currentUser!.fullName.toLowerCase().trim() ||
            sender.toLowerCase().trim() == _currentUser!.username.toLowerCase().trim()
          );

          if (isRecent && !isOwnMessage) {
            final senderDisplay = (sender != null && sender.trim().isNotEmpty) ? sender.trim() : 'Phyto Doctor';
            NotificationService().showMessageNotification(
              title: '$senderDisplay • ${room.title}',
              body: lastMsg,
              payload: room.id,
              id: room.id.hashCode.abs() % 100000,
            );
          }
        }
      }

      // Check for newly submitted field visits for CEO/Admin, or visit status updates for Employees
      await _checkForNewFieldVisits();
      await _checkForEmployeeVisitUpdates();

      // Periodically check for pushed app updates (~every 28s)
      _pollCounter++;
      if (_pollCounter % 4 == 1) {
        final updateInfo = await AppUpdateService().checkVersion();
        if (updateInfo != null &&
            AppUpdateService.isUpdateRequired(updateInfo) &&
            _notifiedUpdateVersion != '${updateInfo.latestVersion}_${updateInfo.latestBuildNumber}') {
          _notifiedUpdateVersion = '${updateInfo.latestVersion}_${updateInfo.latestBuildNumber}';
          NotificationService().showMessageNotification(
            title: 'PhytoDoctor Update v${updateInfo.latestVersion}',
            body: 'A new update is available. Please update the app.',
            payload: 'app_update',
            id: 999999,
          );
        }
      }
    } catch (_) {
      // Quiet background polling failure
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _checkForNewFieldVisits() async {
    final user = _currentUser;
    if (user == null) return;
    final role = user.role.toUpperCase();
    if (!user.isOwner && role != 'MANAGER') return;
    final token = user.accessToken;
    if (token == null || token.isEmpty) return;

    try {
      final url = Uri.parse('${AuthService.defaultBaseUrl}/api/v1/visits?status=PENDING&limit=20');
      final res = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return;
      final decoded = jsonDecode(res.body);
      final List<dynamic> items = decoded is Map ? (decoded['items'] ?? []) : (decoded is List ? decoded : []);

      for (final raw in items) {
        if (raw is! Map) continue;
        final visitId = raw['id']?.toString() ?? '';
        if (visitId.isEmpty || _seenVisitIds.contains(visitId)) continue;
        _seenVisitIds.add(visitId);

        final receiptStr = (raw['server_receipt_time'] ?? raw['device_capture_time'])?.toString();
        bool isRecent = true;
        if (receiptStr != null && receiptStr.isNotEmpty) {
          final dt = DateTime.tryParse(receiptStr);
          if (dt != null) {
            isRecent = DateTime.now().toUtc().difference(dt.toUtc()).inMinutes < 10;
          }
        }

        // On initial poll, notify only if submitted within the last 2 minutes; afterwards notify all newly arriving visits
        bool shouldNotify = _visitsSeeded;
        if (!_visitsSeeded && receiptStr != null && receiptStr.isNotEmpty) {
          final dt = DateTime.tryParse(receiptStr);
          if (dt != null) {
            shouldNotify = DateTime.now().toUtc().difference(dt.toUtc()).inMinutes < 2;
          }
        }

        if (shouldNotify && isRecent) {
          final clientName = (raw['client_name']?.toString().trim().isNotEmpty == true)
              ? raw['client_name'].toString().trim()
              : 'Field Visit';
          final officerName = (raw['employee_name']?.toString().trim().isNotEmpty == true)
              ? raw['employee_name'].toString().trim()
              : ((raw['officer']?.toString().trim().isNotEmpty == true) ? raw['officer'].toString().trim() : 'Field Officer');

          NotificationService().showMessageNotification(
            title: 'New Visit: $clientName',
            body: '$officerName has uploaded a visit. Click to review.',
            payload: 'visit:$visitId',
            id: 200000 + (visitId.hashCode.abs() % 100000),
          );
        }
      }
      _visitsSeeded = true;
    } catch (_) {
      // Quietly ignore transient network hiccups
    }
  }

  Future<void> _checkForEmployeeVisitUpdates() async {
    final user = _currentUser;
    if (user == null || user.isAdmin) return;
    final token = user.accessToken;
    if (token == null || token.isEmpty) return;

    try {
      final url = Uri.parse('${AuthService.defaultBaseUrl}/api/v1/visits?limit=20');
      final res = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return;
      final decoded = jsonDecode(res.body);
      final List<dynamic> items = decoded is Map ? (decoded['items'] ?? []) : (decoded is List ? decoded : []);

      for (final raw in items) {
        if (raw is! Map) continue;
        final visitId = raw['id']?.toString() ?? '';
        final status = (raw['status']?.toString() ?? '').toUpperCase();
        if (visitId.isEmpty || status.isEmpty) continue;

        final prevStatus = _knownEmployeeVisitStatuses[visitId];
        _knownEmployeeVisitStatuses[visitId] = status;

        final isFinal = status == 'VERIFIED' || status == 'REJECTED';
        if (!isFinal) continue;

        bool shouldNotify = _employeeVisitsSeeded && prevStatus != status;
        if (!_employeeVisitsSeeded) {
          final verifiedAtStr = raw['verified_at']?.toString();
          if (verifiedAtStr != null && verifiedAtStr.isNotEmpty) {
            final dt = DateTime.tryParse(verifiedAtStr);
            if (dt != null) {
              shouldNotify = DateTime.now().toUtc().difference(dt.toUtc()).inMinutes < 2;
            }
          }
        }

        if (shouldNotify) {
          final clientName = (raw['client_name']?.toString().trim().isNotEmpty == true)
              ? raw['client_name'].toString().trim()
              : 'Your field visit';
          final actionWord = status == 'VERIFIED' ? 'approved' : 'rejected';

          NotificationService().showMessageNotification(
            title: status == 'VERIFIED' ? 'Visit Approved' : 'Visit Rejected',
            body: '$clientName has been $actionWord.',
            payload: 'visit_status:$visitId',
            id: 300000 + (visitId.hashCode.abs() % 100000),
          );
        }
      }
      _employeeVisitsSeeded = true;
    } catch (_) {
      // Quietly ignore transient network hiccups
    }
  }

  /// Mark a message fingerprint as seen so sending or active viewing doesn't duplicate
  void markSeen(String key) {
    _seenMessageKeys.add(key);
  }
}
