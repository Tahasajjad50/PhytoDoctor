import 'package:flutter/material.dart';
import '../../core/models/user_model.dart';
import 'owner_admin_dashboard_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  final UserModel user;

  const AdminDashboardScreen({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OwnerAdminDashboardScreen(user: user);
  }
}

