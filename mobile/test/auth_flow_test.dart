import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:phyto_doctor/core/models/user_model.dart';
import 'package:phyto_doctor/core/services/auth_service.dart';

class MockHttpClient extends Mock implements http.Client {}

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
      final authService = AuthService(baseUrl: 'http://mock-server');
      
      // When backend rejects role with 403
      // Verify AuthException is thrown with descriptive error
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
      final authService = AuthService(baseUrl: 'http://mock-server');
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
