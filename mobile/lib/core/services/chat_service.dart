import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_model.dart';
import 'auth_service.dart';

class ChatService {
  final String? token;
  final String baseUrl;
  final http.Client _client;

  ChatService({this.token, String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? AuthService.defaultBaseUrl,
        _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  /// Fetch all chat rooms accessible to the authenticated user
  Future<List<ChatRoomModel>> getRooms() async {
    try {
      final url = Uri.parse('$baseUrl/api/v1/chat/rooms');
      final response = await _client.get(url, headers: _headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.map((json) => ChatRoomModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load chat rooms (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Network error while loading rooms: $e');
    }
  }

  /// Open or retrieve a 1-on-1 direct chat room with an admin/employee
  Future<ChatRoomModel> openDirectRoom(String targetUserId) async {
    try {
      final url = Uri.parse('$baseUrl/api/v1/chat/rooms');
      final response = await _client.post(
        url,
        headers: _headers,
        body: jsonEncode({'target_user_id': targetUserId}),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return ChatRoomModel.fromJson(data);
      } else {
        throw Exception('Failed to create direct chat room: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error starting conversation: $e');
    }
  }

  /// Fetch messages for a specific room.
  /// If [after] is provided, only retrieves messages created after that timestamp (lightweight polling).
  Future<List<ChatMessageModel>> getMessages(String roomId, {DateTime? after}) async {
    try {
      String query = '';
      if (after != null) {
        query = '?after=${Uri.encodeComponent(after.toIso8601String())}';
      }
      final url = Uri.parse('$baseUrl/api/v1/chat/rooms/$roomId/messages$query');
      final response = await _client.get(url, headers: _headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.map((json) => ChatMessageModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load messages (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Network error while fetching messages: $e');
    }
  }

  /// Send a message to a chatroom
  Future<ChatMessageModel> sendMessage(String roomId, String content) async {
    try {
      final url = Uri.parse('$baseUrl/api/v1/chat/rooms/$roomId/messages');
      final response = await _client.post(
        url,
        headers: _headers,
        body: jsonEncode({'content': content.trim()}),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ChatMessageModel.fromJson(data);
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['detail'] ?? 'Failed to send message');
      }
    } catch (e) {
      throw Exception('$e');
    }
  }

  /// Fetch administrators/leadership available to contact
  Future<List<AdminContactModel>> getAvailableAdmins() async {
    try {
      final url = Uri.parse('$baseUrl/api/v1/chat/admins');
      final response = await _client.get(url, headers: _headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.map((json) => AdminContactModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load admins list');
      }
    } catch (e) {
      throw Exception('Network error while fetching admin list: $e');
    }
  }

  /// Fetch permitted contacts for direct messaging
  Future<List<ChatContactModel>> getChatContacts({String? query}) async {
    try {
      String q = '';
      if (query != null && query.trim().isNotEmpty) {
        q = '?query=${Uri.encodeComponent(query.trim())}';
      }
      final url = Uri.parse('$baseUrl/api/v1/chat/contacts$q');
      final response = await _client.get(url, headers: _headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.map((json) => ChatContactModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load contacts');
      }
    } catch (e) {
      throw Exception('Network error while fetching contacts: $e');
    }
  }
}
