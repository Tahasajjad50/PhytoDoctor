import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:phyto_doctor/core/models/user_model.dart';
import 'package:phyto_doctor/core/services/auth_service.dart';

class MockHttpClient extends http.BaseClient {
  final int statusCode;
  final String body;
  MockHttpClient({required this.statusCode, required this.body});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  group('UserModel Role Validation Tests', () {
    test('Correctly identifies employee role and privileges', () {
      final user = UserModel(
        id: '1',
        email: 'employee@phytodoctor.com',
        username: 'emp.john',
        fullName: 'John Doe',
        role: 'EMPLOYEE',
        isActive: true,
      );

      expect(user.isEmployee, isTrue);
      expect(user.isAdmin, isFalse);
      expect(user.isManager, isFalse);
      expect(user.isOwner, isFalse);
    });

    test('Correctly identifies admin/manager role and privileges', () {
      final manager = UserModel(
        id: '2',
        email: 'manager@phytodoctor.com',
        username: 'manager.punjab',
        fullName: 'Farhan Qureshi',
        role: 'MANAGER',
        isActive: true,
      );

      expect(manager.isEmployee, isFalse);
      expect(manager.isAdmin, isTrue);
      expect(manager.isManager, isTrue);

      final owner = UserModel(
        id: '3',
        email: 'owner@phytodoctor.com',
        username: 'owner',
        fullName: 'Dr. Tariq Malik',
        role: 'OWNER',
        isActive: true,
      );

      expect(owner.isEmployee, isFalse);
      expect(owner.isAdmin, isTrue);
      expect(owner.isOwner, isTrue);
    });
  });

  group('AuthService Security & Role Access Enforcement', () {
    test('Throws AuthException when employee attempts admin login', () async {
      // Mock client returning 403 Forbidden
      final mockClient = MockHttpClient(
        statusCode: 403,
        body: jsonEncode({'detail': 'Access denied: Employee accounts cannot access Administrator dashboard.'}),
      );
      final authService = AuthService(baseUrl: 'http://mock-server', client: mockClient);
      
      expect(
        () async => await authService.login(
          usernameOrEmail: 'emp.john',
          password: 'emp123',
          portal: 'admin',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('Throws AuthException on invalid credentials (401)', () async {
      final mockClient = MockHttpClient(
        statusCode: 401,
        body: jsonEncode({'detail': 'Incorrect username/email or password.'}),
      );
      final authService = AuthService(baseUrl: 'http://mock-server', client: mockClient);
      expect(
        () async => await authService.login(
          usernameOrEmail: 'emp.john',
          password: 'wrong_password',
          portal: 'employee',
        ),
        throwsA(isA<AuthException>()),
      );
    });
  });
}
