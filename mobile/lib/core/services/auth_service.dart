import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/user_model.dart';

class AuthException implements Exception {
  final String message;
  final int? statusCode;

  AuthException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class AuthService extends ChangeNotifier {
  // Dynamic base URL defaulting to AppConfig.apiBaseUrl (e.g. Render cloud URL in release)
  // with fallback candidate probes for local dev / emulator
  static String defaultBaseUrl = AppConfig.apiBaseUrl;
  String baseUrl;
  final http.Client? client;

  UserModel? _currentUser;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  AuthService({
    String? baseUrl,
    this.client,
  }) : baseUrl = baseUrl ?? defaultBaseUrl;

  /// Authenticate user via FastAPI backend with strict role and portal verification
  Future<UserModel> login({
    required String usernameOrEmail,
    required String password,
    required String portal, // 'employee' or 'admin'
  }) async {
    _isLoading = true;
    notifyListeners();

    final httpClient = client ?? http.Client();

    // Probe candidate endpoints in order: configured URL, Wi-Fi LAN IP, Emulator host, localhost
    final candidateHosts = [
      baseUrl,
      AppConfig.apiBaseUrl,
      'http://192.168.1.15:8000',
      'http://10.0.2.2:8000',
      'http://127.0.0.1:8000',
    ].where((h) => h.isNotEmpty).toSet().toList();

    http.Response? response;
    Exception? lastException;

    for (final host in candidateHosts) {
      try {
        final probeUrl = Uri.parse('$host/api/v1/auth/login');
        final res = await httpClient.post(
          probeUrl,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'username_or_email': usernameOrEmail.trim(),
            'password': password,
            'portal': portal,
          }),
        ).timeout(const Duration(seconds: 4));

        response = res;
        baseUrl = host;
        defaultBaseUrl = host;
        break;
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
      }
    }

    try {
      if (response == null) {
        throw SocketException(lastException?.toString() ?? 'Failed to reach backend on any candidate endpoint.');
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final token = responseData['access_token'] as String;
        final userData = responseData['user'] as Map<String, dynamic>;
        final user = UserModel.fromJson(userData, token: token);

        // Security check: Verify returned role matches expected portal
        if (portal == 'admin' && !user.isAdmin) {
          throw AuthException(
            'Access denied: Administrator privileges required for Admin Portal.',
            statusCode: 403,
          );
        }

        _currentUser = user;
        _isLoading = false;
        notifyListeners();
        return user;
      } else if (response.statusCode == 401) {
        throw AuthException(
          responseData['detail'] as String? ?? 'Invalid credentials. Please verify your details.',
          statusCode: 401,
        );
      } else if (response.statusCode == 403) {
        throw AuthException(
          responseData['detail'] as String? ?? 'Access denied. You do not have permission for this portal.',
          statusCode: 403,
        );
      } else {
        throw AuthException(
          'Server error (${response.statusCode}): ${responseData['detail'] ?? 'Please try again later.'}',
          statusCode: response.statusCode,
        );
      }
    } on SocketException {
      throw AuthException(
        'Unable to connect to Phyto Doctor server. Please check your internet connection or server status.',
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('An unexpected error occurred: ${e.toString()}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch created accounts (CEO gets full visibility, Admin gets only their created/assigned employees)
  Future<List<CreatedAccountModel>> getCreatedAccounts() async {
    final token = _currentUser?.accessToken;
    final url = Uri.parse('$baseUrl/api/v1/users/created-accounts');
    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((item) => CreatedAccountModel.fromJson(item as Map<String, dynamic>)).toList();
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'Failed to load accounts (${response.statusCode})');
    }
  }

  /// Update account credentials (CEO can update any account, Admin can only update employees they created)
  Future<CreatedAccountModel> updateAccountCredentials(
    String userId, {
    String? username,
    String? email,
    String? password,
    String? fullName,
    String? phone,
    String? designation,
    bool? isActive,
  }) async {
    final token = _currentUser?.accessToken;
    final url = Uri.parse('$baseUrl/api/v1/users/$userId/credentials');
    final Map<String, dynamic> body = {};
    if (username != null && username.isNotEmpty) body['username'] = username;
    if (email != null && email.isNotEmpty) body['email'] = email;
    if (password != null && password.isNotEmpty) body['password'] = password;
    if (fullName != null && fullName.isNotEmpty) body['full_name'] = fullName;
    if (phone != null) body['phone'] = phone;
    if (designation != null) body['designation'] = designation;
    if (isActive != null) body['is_active'] = isActive;

    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return CreatedAccountModel.fromJson(jsonDecode(response.body));
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'Failed to update credentials (${response.statusCode})');
    }
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}
