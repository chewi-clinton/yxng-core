import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const LifeosApp());
}

class LifeosApp extends StatelessWidget {
  const LifeosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthService(),
      child: MaterialApp(
        title: 'Yxng Core',
        theme: AppTheme.dark,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _secureStorage = const FlutterSecureStorage();
  bool? _onboardingComplete;

  @override
  void initState() {
    super.initState();
    context.read<AuthService>().checkAuth();
    _secureStorage.read(key: 'onboarding_complete').then((value) {
      if (mounted) setState(() => _onboardingComplete = value == 'true');
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (_onboardingComplete == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    if (!_onboardingComplete!) {
      return const OnboardingScreen();
    }
    return auth.isAuthenticated
        ? const HomeShell()
        : const LoginScreen();
  }
}
