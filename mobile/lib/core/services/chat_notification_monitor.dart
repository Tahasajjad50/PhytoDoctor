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
  bool _visitsSeeded = false;
  bool _isChecking = false;
  int _pollCounter = 0;
  String? _notifiedUpdateVersion;

  void start(UserModel user) {
    _currentUser = user;
    _chatService = ChatService(token: user.accessToken);
    _seenVisitIds.clear();
    _visitsSeeded = false;
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
    _visitsSeeded = false;
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

      // Check for newly submitted field visits for CEO and assigned Admins
      await _checkForNewFieldVisits();

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
            body: '$officerName shared a field visit for verification.',
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

  /// Mark a message fingerprint as seen so sending or active viewing doesn't duplicate
  void markSeen(String key) {
    _seenMessageKeys.add(key);
  }
}
