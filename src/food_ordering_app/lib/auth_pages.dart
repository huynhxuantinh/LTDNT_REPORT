import 'package:flutter/material.dart';
import 'package:trek_bikes_app/admin_categories_page.dart';
import 'package:trek_bikes_app/admin_food_items_page.dart';
import 'package:trek_bikes_app/auth_api.dart';
import 'package:trek_bikes_app/home_categories.dart';
import 'package:trek_bikes_app/home_latest_foods.dart';
import 'package:trek_bikes_app/member_category_api.dart';
import 'package:trek_bikes_app/cart_api.dart';
import 'package:trek_bikes_app/cart_page.dart';
import 'package:trek_bikes_app/orders_page.dart';
import 'package:trek_bikes_app/staff_order_page.dart';
import 'package:trek_bikes_app/staff_orders_page.dart';
import 'package:trek_bikes_app/role_guard.dart';
import 'package:trek_bikes_app/session_helper.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onSessionChanged;
  const LoginPage({super.key, required this.onSessionChanged});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await SessionHelper.save(
        await AuthApi.login(
          email: _email.text.trim(),
          password: _password.text,
        ),
      );
      await CartApi.syncOfflineCart();
      if (mounted) widget.onSessionChanged();
    } on ApiException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('Không thể kết nối máy chủ. Kiểm tra mạng và thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đăng nhập')),
    body: _FormLayout(
      formKey: _formKey,
      children: [
        _emailField(_email),
        _passwordField(_password, 'Mật khẩu'),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: Text(_loading ? 'Đang đăng nhập...' : 'Đăng nhập'),
        ),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegisterPage()),
          ),
          child: const Text('Chưa có tài khoản? Đăng ký'),
        ),
      ],
    ),
  );
  void _message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthApi.register(
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng ký thành công. Hãy đăng nhập.')),
      );
      Navigator.pop(context);
    } on ApiException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('Không thể kết nối máy chủ. Kiểm tra mạng và thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đăng ký')),
    body: _FormLayout(
      formKey: _formKey,
      children: [
        TextFormField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Họ và tên'),
          validator: _required,
        ),
        _emailField(_email),
        _passwordField(_password, 'Mật khẩu'),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Mật khẩu có tối thiểu 8 ký tự, gồm chữ hoa, chữ thường và số.',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: Text(_loading ? 'Đang đăng ký...' : 'Đăng ký'),
        ),
      ],
    ),
  );
  void _message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class AccountHome extends StatefulWidget {
  final VoidCallback onSessionChanged;
  const AccountHome({super.key, required this.onSessionChanged});
  @override
  State<AccountHome> createState() => _AccountHomeState();
}

class _AccountHomeState extends State<AccountHome> {
  bool _loading = false;
  String? _role;
  MemberCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await SessionHelper.role;
    if (mounted) setState(() => _role = role);
  }

  void _openAdminUsers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoleGuard(
          role: _role,
          allowedRoles: const {'Admin'},
          child: const AdminUserManagementPage(),
        ),
      ),
    );
  }

  void _openAdminCategories() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoleGuard(
          role: _role,
          allowedRoles: const {'Admin'},
          child: const AdminCategoriesPage(),
        ),
      ),
    );
  }

  void _openAdminFoodItems() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoleGuard(
          role: _role,
          allowedRoles: const {'Admin'},
          child: const AdminFoodItemsPage(),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    setState(() => _loading = true);
    try {
      final accessToken = await SessionHelper.accessToken;
      final refreshToken = await SessionHelper.refreshToken;
      if (accessToken != null && refreshToken != null)
        await AuthApi.logout(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
    } on ApiException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('Không thể kết nối máy chủ. Đã đăng xuất trên thiết bị.');
    } finally {
      await SessionHelper.clear();
      if (mounted) {
        setState(() => _loading = false);
        widget.onSessionChanged();
      }
    }
  }

  Future<void> _changePassword() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
    );
    if (changed == true && mounted) widget.onSessionChanged();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Đặt món ăn'),
      actions: [
        ValueListenableBuilder<int>(
          valueListenable: cartCount,
          builder: (_, count, __) => Stack(
            children: [
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartPage()),
                ),
                icon: const Icon(Icons.shopping_cart),
              ),
              if (count > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: CircleAvatar(
                    radius: 9,
                    child: Text('$count', style: const TextStyle(fontSize: 11)),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
    body: Column(
      children: [
        SizedBox(
          height: 170,
          child: HomeCategories(
            onSelected: (category) =>
                setState(() => _selectedCategory = category),
          ),
        ),
        Expanded(
          child: HomeLatestFoods(
            categoryId: _selectedCategory?.categoryId,
            categoryName: _selectedCategory?.name,
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_role == 'Admin')
                  OutlinedButton(
                    onPressed: _openAdminFoodItems,
                    child: const Text('Quản lý món ăn'),
                  ),
                if (_role == 'Staff' || _role == 'Admin')
                  OutlinedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffOrderPage())),
                    child: const Text('Tạo đơn tại quán'),
                  ),
                if (_role == 'Staff' || _role == 'Admin')
                  OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffOrdersPage())), child: const Text('Xử lý đơn tại quán')),
                if (_role == 'Admin')
                  OutlinedButton(
                    onPressed: _openAdminCategories,
                    child: const Text('Quản lý danh mục'),
                  ),
                if (_role == 'Admin')
                  OutlinedButton(
                    onPressed: _openAdminUsers,
                    child: const Text('Quản lý người dùng'),
                  ),
                const Text('Bạn đã đăng nhập.'),
                OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersPage())), child: const Text('Đơn hàng của tôi')),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _changePassword,
                  child: const Text('Đổi mật khẩu'),
                ),
                FilledButton.tonal(
                  onPressed: _loading ? null : _logout,
                  child: Text(_loading ? 'Đang thoát...' : 'Đăng xuất'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
  void _message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});
  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _loading = false;
  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final token = await SessionHelper.accessToken;
      if (token == null)
        throw const ApiException('Phiên đăng nhập đã hết hạn.');
      await AuthApi.changePassword(
        accessToken: token,
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      await SessionHelper.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đổi mật khẩu thành công. Hãy đăng nhập lại.'),
        ),
      );
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('Không thể kết nối máy chủ. Kiểm tra mạng và thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đổi mật khẩu')),
    body: _FormLayout(
      formKey: _formKey,
      children: [
        _passwordField(_current, 'Mật khẩu hiện tại'),
        _passwordField(_next, 'Mật khẩu mới'),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: Text(_loading ? 'Đang cập nhật...' : 'Đổi mật khẩu'),
        ),
      ],
    ),
  );
  void _message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _FormLayout extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  const _FormLayout({required this.formKey, required this.children});
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    ),
  );
}

TextFormField _emailField(TextEditingController controller) => TextFormField(
  controller: controller,
  keyboardType: TextInputType.emailAddress,
  decoration: const InputDecoration(labelText: 'Email'),
  validator: (value) =>
      value != null && value.contains('@') ? null : 'Email không hợp lệ.',
);
TextFormField _passwordField(TextEditingController controller, String label) =>
    TextFormField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(labelText: label),
      validator: (value) => value != null && value.length >= 8
          ? null
          : 'Mật khẩu tối thiểu 8 ký tự.',
    );
String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Trường này là bắt buộc.' : null;
