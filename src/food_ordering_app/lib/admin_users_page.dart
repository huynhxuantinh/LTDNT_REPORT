import 'package:flutter/material.dart';
import 'package:food_ordering_app/admin_users_api.dart';
import 'package:food_ordering_app/app_states.dart';
import 'package:food_ordering_app/auth_api.dart';
import 'package:food_ordering_app/vietnamese_labels.dart';

class AdminUserManagementPage extends StatefulWidget {
  const AdminUserManagementPage({super.key});
  @override
  State<AdminUserManagementPage> createState() =>
      _AdminUserManagementPageState();
}

class _AdminUserManagementPageState extends State<AdminUserManagementPage> {
  late final AdminUsersApi api;
  final search = TextEditingController();
  late Future<AdminUsersPageData> users;
  int page = 1;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    api = AdminUsersApi();
    reload();
  }

  @override
  void dispose() {
    search.dispose();
    api.dispose();
    super.dispose();
  }

  void reload() {
    users = api.getUsers(page: page, search: search.text);
  }

  void searchUsers() => setState(() {
    page = 1;
    reload();
  });
  Future<void> perform(Future<void> Function() operation) async {
    setState(() => busy = true);
    try {
      await operation();
      if (mounted) {
        setState(reload);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cập nhật thành công.')));
      }
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể kết nối máy chủ.')),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> changeRole(AdminUser user) async {
    final role = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Đổi vai trò: ${user.name}'),
        children: ['Member', 'Staff', 'Admin']
            .map(
              (value) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, value),
                child: Row(
                  children: [
                    Expanded(child: Text(roleLabel(value))),
                    if (value == user.role) const Icon(Icons.check),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
    if (role == null || role == user.role || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận đổi vai trò'),
        content: Text(
          'Đổi ${user.name} từ ${roleLabel(user.role)} sang ${roleLabel(role)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted)
      await perform(() => api.setRole(user.id, role));
  }

  Future<void> toggleActive(AdminUser user) async {
    final label = user.active ? 'Khóa' : 'Mở khóa';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$label tài khoản'),
        content: Text('$label tài khoản ${user.email}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted)
      await perform(() => api.setActive(user.id, !user.active));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quản lý người dùng')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => searchUsers(),
            decoration: InputDecoration(
              labelText: 'Tìm theo tên hoặc email',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              suffixIcon: IconButton(
                tooltip: 'Tìm kiếm',
                onPressed: searchUsers,
                icon: const Icon(Icons.arrow_forward),
              ),
            ),
          ),
        ),
        if (busy) const LinearProgressIndicator(),
        Expanded(
          child: FutureBuilder<AdminUsersPageData>(
            future: users,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return const AppLoadingState();
              if (snapshot.hasError)
                return AppErrorState(onRetry: () => setState(reload));
              final result = snapshot.data!;
              if (result.users.isEmpty)
                return const AppEmptyState(
                  message: 'Không tìm thấy người dùng.',
                );
              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: result.users.length,
                      itemBuilder: (context, index) {
                        final user = result.users[index];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      child: Icon(
                                        user.active
                                            ? Icons.person_outline
                                            : Icons.person_off_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                          Text(user.email),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${roleLabel(user.role)} · ${user.active ? 'Đang hoạt động' : 'Đã khóa'} · ${user.verified ? 'Email đã xác thực' : 'Email chưa xác thực'}',
                                ),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    OutlinedButton(
                                      onPressed: busy
                                          ? null
                                          : () => changeRole(user),
                                      child: const Text('Đổi vai trò'),
                                    ),
                                    TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => toggleActive(user),
                                      child: Text(
                                        user.active ? 'Khóa' : 'Mở khóa',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Trang trước',
                          onPressed: page > 1 && !busy
                              ? () => setState(() {
                                  page--;
                                  reload();
                                })
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text(
                          'Trang ${result.page}/${result.totalPages} · ${result.totalItems} người',
                        ),
                        IconButton(
                          tooltip: 'Trang sau',
                          onPressed: page < result.totalPages && !busy
                              ? () => setState(() {
                                  page++;
                                  reload();
                                })
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}
