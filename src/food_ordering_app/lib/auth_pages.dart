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
import 'package:trek_bikes_app/admin_orders_page.dart';
import 'package:trek_bikes_app/admin_users_page.dart';
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
      title: 'Chào mừng bạn trở lại',
      subtitle: 'Đăng nhập để đặt món và theo dõi đơn hàng của bạn.',
      icon: Icons.restaurant_menu_rounded,
      children: [
        _emailField(_email),
        const SizedBox(height: 16),
        _passwordField(_password, 'Mật khẩu'),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
            ),
            child: const Text('Quên mật khẩu?'),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: Text(_loading ? 'Đang đăng nhập...' : 'Đăng nhập'),
        ),
        const SizedBox(height: 16),
        const Divider(),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegisterPage()),
          ),
          child: const Text('Chưa có tài khoản? Đăng ký'),
        ),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const VerifyEmailPage()),
          ),
          child: const Text('Xác thực email'),
        ),
      ],
    ),
  );
  void _message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final email = TextEditingController();
  final token = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  @override
  void dispose() {
    email.dispose();
    token.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() operation, String message) async {
    setState(() => loading = true);
    try {
      await operation();
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
    } on ApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể kết nối máy chủ.')),
        );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quên mật khẩu')),
    body: _AuthLayout(
      title: 'Khôi phục mật khẩu',
      subtitle: 'Nhập email để nhận liên kết hoặc mã đặt lại mật khẩu.',
      icon: Icons.lock_reset_rounded,
      children: [
        const _SectionLabel(number: '1', label: 'Nhận mã qua email'),
        const SizedBox(height: 12),
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        FilledButton(
          onPressed: loading
              ? null
              : () => run(
                  () => AuthApi.forgotPassword(email.text),
                  'Nếu tài khoản tồn tại, mã đã được gửi qua email.',
                ),
          child: const Text('Gửi mã'),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        const _SectionLabel(number: '2', label: 'Nhập mã và mật khẩu mới'),
        const SizedBox(height: 12),
        TextField(
          controller: token,
          decoration: const InputDecoration(labelText: 'Mã từ email'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: password,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Mật khẩu mới',
            helperText: 'Ít nhất 8 ký tự, gồm chữ hoa, chữ thường và số.',
            helperMaxLines: 2,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: loading
              ? null
              : () => run(
                  () => AuthApi.resetPassword(token.text, password.text),
                  'Đổi mật khẩu thành công. Hãy đăng nhập.',
                ),
          child: const Text('Đặt lại mật khẩu'),
        ),
      ],
    ),
  );
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});
  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final token = TextEditingController();
  bool loading = false;
  @override
  void dispose() {
    token.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (token.text.trim().isEmpty) return;
    setState(() => loading = true);
    try {
      await AuthApi.verifyEmail(token.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xác thực email thành công.')),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Mã không hợp lệ, hết hạn hoặc không kết nối được máy chủ.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Xác thực email')),
    body: _AuthLayout(
      title: 'Xác thực email',
      subtitle: 'Bấm liên kết trong email hoặc nhập mã xác thực bên dưới.',
      icon: Icons.mark_email_read_outlined,
      children: [
        TextField(
          controller: token,
          decoration: const InputDecoration(
            labelText: 'Mã xác thực trong email',
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: loading ? null : submit,
          child: const Text('Xác thực'),
        ),
      ],
    ),
  );
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
      title: 'Tạo tài khoản',
      subtitle: 'Điền thông tin để bắt đầu đặt món.',
      icon: Icons.person_add_alt_1_rounded,
      children: [
        TextFormField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Họ và tên'),
          validator: _required,
        ),
        const SizedBox(height: 16),
        _emailField(_email),
        const SizedBox(height: 16),
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
      title: const Text('Thực đơn'),
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
    drawer: Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Đặt món ăn',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(_role == null ? 'Tài khoản' : 'Tài khoản · $_role'),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Đơn hàng của tôi'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OrdersPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Đổi mật khẩu'),
              onTap: () {
                Navigator.pop(context);
                _changePassword();
              },
            ),
            if (_role == 'Admin' || _role == 'Staff') const Divider(),
            if (_role == 'Staff' || _role == 'Admin')
              ListTile(
                leading: const Icon(Icons.add_shopping_cart),
                title: const Text('Tạo đơn tại quán'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StaffOrderPage()),
                  );
                },
              ),
            if (_role == 'Staff' || _role == 'Admin')
              ListTile(
                leading: const Icon(Icons.point_of_sale),
                title: const Text('Xử lý đơn tại quán'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StaffOrdersPage()),
                  );
                },
              ),
            if (_role == 'Admin')
              ListTile(
                leading: const Icon(Icons.restaurant),
                title: const Text('Quản lý món ăn'),
                onTap: () {
                  Navigator.pop(context);
                  _openAdminFoodItems();
                },
              ),
            if (_role == 'Admin')
              ListTile(
                leading: const Icon(Icons.category_outlined),
                title: const Text('Quản lý danh mục'),
                onTap: () {
                  Navigator.pop(context);
                  _openAdminCategories();
                },
              ),
            if (_role == 'Admin')
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('Quản lý người dùng'),
                onTap: () {
                  Navigator.pop(context);
                  _openAdminUsers();
                },
              ),
            if (_role == 'Admin')
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Quản lý đơn hàng'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RoleGuard(
                        role: _role,
                        allowedRoles: const {'Admin'},
                        child: const AdminOrdersPage(),
                      ),
                    ),
                  );
                },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(_loading ? 'Đang thoát...' : 'Đăng xuất'),
              enabled: !_loading,
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Danh mục',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        SizedBox(
          height: 52,
          child: HomeCategories(
            selectedId: _selectedCategory?.categoryId,
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
      title: 'Bảo mật tài khoản',
      subtitle: 'Nhập mật khẩu hiện tại và chọn mật khẩu mới.',
      icon: Icons.lock_outline_rounded,
      children: [
        _passwordField(_current, 'Mật khẩu hiện tại'),
        const SizedBox(height: 16),
        _passwordField(_next, 'Mật khẩu mới'),
        const SizedBox(height: 8),
        const Text(
          'Mật khẩu mới cần ít nhất 8 ký tự, gồm chữ hoa, chữ thường và số.',
        ),
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
  final String title;
  final String subtitle;
  final IconData icon;
  const _FormLayout({
    required this.formKey,
    required this.children,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) => _AuthLayout(
    title: title,
    subtitle: subtitle,
    icon: icon,
    children: [
      Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ],
  );
}

class _AuthLayout extends StatelessWidget {
  const _AuthLayout({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              ...children,
            ],
          ),
        ),
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.number, required this.label});
  final String number;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(radius: 14, child: Text(number)),
      const SizedBox(width: 10),
      Expanded(
        child: Text(label, style: Theme.of(context).textTheme.titleSmall),
      ),
    ],
  );
}

TextFormField _emailField(TextEditingController controller) => TextFormField(
  controller: controller,
  keyboardType: TextInputType.emailAddress,
  decoration: const InputDecoration(
    labelText: 'Email',
    prefixIcon: Icon(Icons.mail_outline),
  ),
  validator: (value) =>
      value != null && value.contains('@') ? null : 'Email không hợp lệ.',
);
TextFormField _passwordField(TextEditingController controller, String label) =>
    TextFormField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
      ),
      validator: (value) => value != null && value.length >= 8
          ? null
          : 'Mật khẩu tối thiểu 8 ký tự.',
    );
String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Trường này là bắt buộc.' : null;
