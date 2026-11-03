import 'package:flutter/material.dart';
import '../../core/models/chat_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/chat_service.dart';
import '../../core/theme/app_theme.dart';
import 'chat_conversation_screen.dart';

class ChatListScreen extends StatefulWidget {
  final UserModel currentUser;

  const ChatListScreen({Key? key, required this.currentUser}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  late final ChatService _chatService;
  final List<ChatRoomModel> _rooms = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(token: widget.currentUser.accessToken);
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rooms = await _chatService.getRooms();
      if (mounted) {
        setState(() {
          _rooms.clear();
          _rooms.addAll(rooms);
          _isLoading = false;
        });
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

  void _openRoom(ChatRoomModel room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatConversationScreen(
          room: room,
          currentUser: widget.currentUser,
        ),
      ),
    ).then((_) => _loadRooms());
  }

  Future<void> _showDirectMessageSearchDialog([String initialQuery = '']) async {
    final searchCtrl = TextEditingController(text: initialQuery);
    List<ChatContactModel> contacts = [];
    bool isSearching = true;
    String? searchError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void performSearch(String query) async {
              setModalState(() {
                isSearching = true;
                searchError = null;
              });
              try {
                final results = await _chatService.getChatContacts(query: query);
                setModalState(() {
                  contacts = results;
                  isSearching = false;
                });
              } catch (e) {
                setModalState(() {
                  searchError = '$e';
                  isSearching = false;
                });
              }
            }

            if (isSearching && contacts.isEmpty && searchError == null) {
              performSearch(searchCtrl.text);
            }

            final isOwner = widget.currentUser.isOwner;
            final isManager = widget.currentUser.role == 'MANAGER';

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isOwner
                              ? 'Direct Message Anyone'
                              : isManager
                                  ? 'Message Assigned Employee / CEO'
                                  : 'Message Admin / CEO',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textMain,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    Text(
                      isOwner
                          ? 'CEO Executive Access: Search any employee or admin by name to start a direct message.'
                          : isManager
                              ? 'Admin Access: You can only message employees assigned to you or the CEO.'
                              : 'Employee Access: You can message your assigned admin or the CEO.',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchCtrl,
                      autofocus: isOwner,
                      decoration: InputDecoration(
                        hintText: isOwner ? 'Type employee or admin name...' : 'Search contacts...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onChanged: (val) {
                        performSearch(val);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (isSearching)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (searchError != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(searchError!, style: const TextStyle(color: AppTheme.alertCrimson)),
                        ),
                      )
                    else if (contacts.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No contacts found matching search.', style: TextStyle(color: AppTheme.textMuted)),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: contacts.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final c = contacts[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: c.isOwner
                                    ? AppTheme.botanicalPrimary
                                    : c.isManager
                                        ? AppTheme.adminSlateLight
                                        : AppTheme.cropGreenLight,
                                child: Icon(
                                  c.isOwner
                                      ? Icons.shield
                                      : c.isManager
                                          ? Icons.admin_panel_settings
                                          : Icons.person,
                                  color: c.isOwner
                                      ? Colors.white
                                      : c.isManager
                                          ? AppTheme.adminSlate
                                          : AppTheme.cropGreen,
                                  size: 20,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      c.fullName,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: c.isOwner
                                          ? AppTheme.mintBadge
                                          : c.isManager
                                              ? AppTheme.adminSlateLight
                                              : AppTheme.cropGreenLight,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      c.isOwner
                                          ? 'CEO'
                                          : c.isManager
                                              ? 'ADMIN'
                                              : 'EMPLOYEE',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: c.isOwner
                                            ? AppTheme.botanicalPrimary
                                            : c.isManager
                                                ? AppTheme.adminSlate
                                                : AppTheme.cropGreen,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                c.designation != null && c.designation!.isNotEmpty
                                    ? '${c.designation} (${c.username})'
                                    : c.username,
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: const Icon(Icons.chat_bubble_outline, size: 20, color: AppTheme.botanicalPrimary),
                              onTap: () {
                                Navigator.pop(ctx);
                                _startDirectChat(c.id);
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _startDirectChat(String targetUserId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final room = await _chatService.openDirectRoom(targetUserId);
      if (mounted) {
        Navigator.pop(context); // Pop loader
        _openRoom(room);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open chat: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = widget.currentUser.isOwner;
    final isEmployee = widget.currentUser.isEmployee;

    return Scaffold(
      backgroundColor: AppTheme.warmOffWhite,
      appBar: AppBar(
        title: const Text('Chatrooms & Announcements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_search),
            tooltip: 'Direct Message',
            onPressed: () => _showDirectMessageSearchDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadRooms,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDirectMessageSearchDialog(),
        backgroundColor: AppTheme.botanicalPrimary,
        icon: Icon(isOwner ? Icons.person_search : Icons.chat),
        label: Text(
          isOwner
              ? 'Direct Message'
              : isEmployee
                  ? 'Message Admin'
                  : 'Message Team / CEO',
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadRooms,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_off, size: 48, color: AppTheme.alertCrimson),
                            const SizedBox(height: 12),
                            Text(_errorMessage!, textAlign: TextAlign.center),
                            const SizedBox(height: 14),
                            ElevatedButton(
                              onPressed: _loadRooms,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [

                        // Section 1: Official Broadcasts
                        const Text(
                          'Company Broadcast Channels',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        ..._rooms
                            .where((r) => r.isAnnouncement || r.isManagement)
                            .map((r) => _buildRoomTile(r))
                            .toList(),

                        const SizedBox(height: 20),

                        // Section 2: Team & Direct Conversations
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isOwner
                                  ? 'All Employee & Admin Conversations'
                                  : 'Direct Staff & Admin Chats',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textMuted,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (!isEmployee)
                              Text(
                                '${_rooms.where((r) => r.isDirect).length} active',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (_rooms.where((r) => r.isDirect).isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceCard,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.sageBorder),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.question_answer_outlined, size: 36, color: AppTheme.adminSlate),
                                const SizedBox(height: 8),
                                const Text(
                                  'No direct conversations yet',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isEmployee
                                      ? 'Tap "Message Admin" below to start chatting with your supervisor or CEO.'
                                      : 'Direct 1-on-1 messages between employees and managers will appear here.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._rooms
                              .where((r) => r.isDirect)
                              .map((r) => _buildRoomTile(r))
                              .toList(),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildRoomTile(ChatRoomModel room) {
    IconData iconData = Icons.chat_bubble;
    Color iconColor = AppTheme.botanicalPrimary;
    Color iconBg = AppTheme.mintBadge;

    if (room.isAnnouncement) {
      iconData = Icons.campaign;
      iconColor = AppTheme.earthAmber;
      iconBg = AppTheme.earthAmberLight;
    } else if (room.isManagement) {
      iconData = Icons.groups;
      iconColor = AppTheme.adminSlate;
      iconBg = AppTheme.adminSlateLight;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.standardBorderRadius),
        border: Border.all(color: AppTheme.sageBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: iconBg,
          child: Icon(iconData, color: iconColor, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                room.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppTheme.textMain,
                ),
              ),
            ),
            if (room.isAnnouncement)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.earthAmberLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'BROADCAST',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.earthAmber,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            room.lastMessage != null
                ? '${room.lastMessageSender != null ? "${room.lastMessageSender}: " : ""}${room.lastMessage}'
                : (room.isAnnouncement ? 'Official company announcements channel' : 'No messages yet'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: room.lastMessage != null ? AppTheme.textMain : AppTheme.textMuted,
            ),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
        onTap: () => _openRoom(room),
      ),
    );
  }
}
