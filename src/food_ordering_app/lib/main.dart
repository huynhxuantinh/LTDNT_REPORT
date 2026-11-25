import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:trek_bikes_app/auth_pages.dart';
import 'package:trek_bikes_app/session_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const FoodOrderingApp());
}

class FoodOrderingApp extends StatelessWidget {
  const FoodOrderingApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Đặt món ăn',
    locale: const Locale('vi'),
    supportedLocales: const [Locale('vi')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
      useMaterial3: true,
    ),
    home: const AuthGate(),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<String?> _tokenFuture;
  @override
  void initState() {
    super.initState();
    SessionHelper.sessionExpired.addListener(_sessionExpired);
    _reload();
  }

  @override
  void dispose() {
    SessionHelper.sessionExpired.removeListener(_sessionExpired);
    super.dispose();
  }

  void _sessionExpired() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      setState(_reload);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'),
        ),
      );
    });
  }

  void _reload() {
    _tokenFuture = SessionHelper.accessToken;
  }

  void _changed() => setState(_reload);
  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: _tokenFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      return snapshot.data?.isNotEmpty == true
          ? AccountHome(onSessionChanged: _changed)
          : LoginPage(onSessionChanged: _changed);
    },
  );
}
