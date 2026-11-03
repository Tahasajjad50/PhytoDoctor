class ChatRoomModel {
  final String id;
  final String title;
  final String roomType;
  final String? participant1Id;
  final String? participant2Id;
  final String? lastMessage;
  final String? lastMessageSender;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatRoomModel({
    required this.id,
    required this.title,
    required this.roomType,
    this.participant1Id,
    this.participant2Id,
    this.lastMessage,
    this.lastMessageSender,
    this.lastMessageAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAnnouncement => roomType == 'ANNOUNCEMENT';
  bool get isManagement => roomType == 'MANAGEMENT';
  bool get isDirect => roomType == 'DIRECT';

  factory ChatRoomModel.fromJson(Map<String, dynamic> json) {
    return ChatRoomModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Conversation',
      roomType: json['room_type'] as String? ?? 'DIRECT',
      participant1Id: json['participant_1_id'] as String?,
      participant2Id: json['participant_2_id'] as String?,
      lastMessage: json['last_message'] as String?,
      lastMessageSender: json['last_message_sender'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class ChatMessageModel {
  final String id;
  final String roomId;
  final String? senderId;
  final String senderName;
  final String senderRole;
  final String content;
  final bool isAnnouncement;
  final DateTime createdAt;

  ChatMessageModel({
    required this.id,
    required this.roomId,
    this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.content,
    this.isAnnouncement = false,
    required this.createdAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String? ?? '',
      roomId: json['room_id'] as String? ?? '',
      senderId: json['sender_id'] as String?,
      senderName: json['sender_name'] as String? ?? 'User',
      senderRole: json['sender_role'] as String? ?? 'EMPLOYEE',
      content: json['content'] as String? ?? '',
      isAnnouncement: json['is_announcement'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class AdminContactModel {
  final String id;
  final String fullName;
  final String username;
  final String email;
  final String role;
  final bool isAssigned;

  AdminContactModel({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    required this.role,
    this.isAssigned = false,
  });

  factory AdminContactModel.fromJson(Map<String, dynamic> json) {
    return AdminContactModel(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'MANAGER',
      isAssigned: json['is_assigned'] as bool? ?? false,
    );
  }
}

class ChatContactModel {
  final String id;
  final String fullName;
  final String username;
  final String email;
  final String role;
  final String? designation;
  final bool isAssigned;

  ChatContactModel({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    required this.role,
    this.designation,
    this.isAssigned = false,
  });

  bool get isOwner => role == 'OWNER';
  bool get isManager => role == 'MANAGER';
  bool get isEmployee => role == 'EMPLOYEE';

  factory ChatContactModel.fromJson(Map<String, dynamic> json) {
    return ChatContactModel(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'EMPLOYEE',
      designation: json['designation'] as String?,
      isAssigned: json['is_assigned'] as bool? ?? false,
    );
  }
}
