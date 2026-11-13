import 'package:flutter/material.dart';

class RoleGuard extends StatelessWidget {
  final String? role;
  final Set<String> allowedRoles;
  final Widget child;

  const RoleGuard({
    super.key,
    required this.role,
    required this.allowedRoles,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (role != null && allowedRoles.contains(role)) return child;

    return const Scaffold(
      body: Center(child: Text('Bạn không có quyền truy cập.')),
    );
  }
}

class AdminUserManagementPage extends StatelessWidget {
  const AdminUserManagementPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quản lý người dùng')),
    body: const Center(
      child: Text(
        'Màn hình quản lý người dùng sẽ được hoàn thiện ở bước tiếp theo.',
      ),
    ),
  );
}
