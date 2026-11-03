import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/chat_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/chat_service.dart';
import '../../core/theme/app_theme.dart';
import 'chat_list_screen.dart';

class ChatConversationScreen extends StatefulWidget {
  final ChatRoomModel room;
  final UserModel currentUser;

  const ChatConversationScreen({
    Key? key,
    required this.room,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  late final ChatService _chatService;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessageModel> _messages = [];

  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;
  Timer? _pollingTimer;

  bool get _canPost {
    if (widget.room.isAnnouncement) {
      return widget.currentUser.isAdmin; // Only CEO and Admins can broadcast
    }
    if (widget.room.isManagement) {
      return widget.currentUser.isAdmin;
    }
    return true; // Direct rooms
  }

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(token: widget.currentUser.accessToken);
    _loadInitialMessages();
    // Lightweight polling every 6 seconds while screen is open
    _pollingTimer = Timer.periodic(const Duration(seconds: 6), (_) => _pollNewMessages());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialMessages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final msgs = await _chatService.getMessages(widget.room.id);
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(msgs);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pollNewMessages() async {
    if (!mounted || _isLoading) return;
    try {
      DateTime? lastTime;
      if (_messages.isNotEmpty) {
        lastTime = _messages.last.createdAt;
      }
      final newMsgs = await _chatService.getMessages(widget.room.id, after: lastTime);
      if (mounted && newMsgs.isNotEmpty) {
        setState(() {
          // Add only unique IDs
          final existingIds = _messages.map((m) => m.id).toSet();
          for (final msg in newMsgs) {
            if (!existingIds.contains(msg.id)) {
              _messages.add(msg);
            }
          }
        });
        _scrollToBottom();
      }
    } catch (_) {
      // Quietly ignore background poll network hiccups to prevent UI disruption
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final newMsg = await _chatService.sendMessage(widget.room.id, text);
      if (mounted) {
        setState(() {
          _messages.add(newMsg);
          _isSending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppTheme.alertCrimson,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmOffWhite,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.room.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              widget.room.isAnnouncement
                  ? 'Company-Wide Broadcast Channel'
                  : widget.room.isManagement
                      ? 'Executive & Admin Channel'
                      : 'Direct Secure Communication',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (widget.room.isManagement && widget.currentUser.isOwner)
            IconButton(
              icon: const Icon(Icons.person_search),
              tooltip: 'Direct Message Anyone',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatListScreen(currentUser: widget.currentUser),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Messages',
            onPressed: _loadInitialMessages,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [

            // Message list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, size: 40, color: AppTheme.alertCrimson),
                                const SizedBox(height: 10),
                                Text(_errorMessage!, textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: _loadInitialMessages,
                                  child: const Text('Try Again'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _messages.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    widget.room.isAnnouncement
                                        ? Icons.campaign_outlined
                                        : Icons.chat_bubble_outline,
                                    size: 48,
                                    color: AppTheme.textMuted.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    widget.room.isAnnouncement
                                        ? 'No announcements posted yet.'
                                        : 'No messages yet. Send a message to start!',
                                    style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final msg = _messages[index];
                                final isMe = msg.senderId == widget.currentUser.id;
                                return _buildMessageBubble(msg, isMe);
                              },
                            ),
            ),

            // Composer bar
            if (_canPost)
              _buildMessageComposer()
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                color: Colors.grey.shade200,
                child: const Text(
                  'Only CEO and Administrators can post in this channel.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel msg, bool isMe) {
    final role = msg.senderRole.toUpperCase();
    Color roleBadgeColor = AppTheme.adminSlate;
    Color roleBadgeBg = AppTheme.adminSlateLight;
    if (role == 'OWNER') {
      roleBadgeColor = AppTheme.botanicalPrimary;
      roleBadgeBg = AppTheme.mintBadge;
    } else if (role == 'MANAGER') {
      roleBadgeColor = AppTheme.adminSlate;
      roleBadgeBg = AppTheme.adminSlateLight;
    }

    final formattedTime = '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.botanicalPrimary : AppTheme.surfaceCard,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMe ? 14 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 14),
          ),
          border: isMe ? null : Border.all(color: AppTheme.sageBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Sender info & role badge
            if (!isMe) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    msg.senderName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isMe ? Colors.white : AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: roleBadgeBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      role == 'OWNER' ? 'CEO' : (role == 'MANAGER' ? 'ADMIN' : 'FIELD'),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: roleBadgeColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],

            // Content
            Text(
              msg.content,
              style: TextStyle(
                fontSize: 14,
                color: isMe ? Colors.white : AppTheme.textMain,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 4),

            // Time
            Text(
              formattedTime,
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.white70 : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        border: const Border(top: BorderSide(color: AppTheme.sageBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: widget.room.isAnnouncement ? 'Broadcast company announcement...' : 'Type your message...',
                hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: AppTheme.warmOffWhite,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppTheme.sageBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppTheme.sageBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppTheme.botanicalPrimary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: AppTheme.botanicalPrimary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: _isSending ? null : _handleSend,
            ),
          ),
        ],
      ),
    );
  }
}
