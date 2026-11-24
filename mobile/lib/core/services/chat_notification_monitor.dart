import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
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
  bool _isChecking = false;

  void start(UserModel user) {
    _currentUser = user;
    _chatService = ChatService(token: user.accessToken);
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
    } catch (_) {
      // Quiet background polling failure
    } finally {
      _isChecking = false;
    }
  }

  /// Mark a message fingerprint as seen so sending or active viewing doesn't duplicate
  void markSeen(String key) {
    _seenMessageKeys.add(key);
  }
}
