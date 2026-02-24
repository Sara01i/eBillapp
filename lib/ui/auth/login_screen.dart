import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../widgets/app_primary_button.dart';
import '../widgets/app_text_field.dart';
import '../widgets/auth_scaffold.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _auth = AuthService();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage('يرجى إدخال البريد الإلكتروني وكلمة المرور.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _auth.login(email, password);
      // Success: AuthGate will automatically redirect to HomeScreen
    } catch (error) {
      if (mounted) {
        _showMessage(_auth.toUserMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'تسجيل الدخول',
      subtitle: 'أهلًا بك مجددًا',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _emailController,
            label: 'البريد الإلكتروني',
            hint: 'name@example.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            forceLtr: true,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _passwordController,
            label: 'كلمة المرور',
            hint: '********',
            icon: Icons.lock_outline_rounded,
            obscureText: true,
            forceLtr: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _login(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ForgotPasswordScreen(),
                  ),
                );
              },
              child: const Text('نسيت كلمة المرور؟'),
            ),
          ),
          const SizedBox(height: 6),
          AppPrimaryButton(
            label: 'تسجيل الدخول',
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _login,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
                child: const Text('إنشاء حساب جديد'),
              ),
              const Text(
                ' | ',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const Text('ليس لديك حساب؟'),
            ],
          ),
        ],
      ),
    );
  }
}
