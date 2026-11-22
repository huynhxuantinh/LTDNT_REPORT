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
