import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../widgets/app_primary_button.dart';
import '../widgets/app_text_field.dart';
import '../widgets/auth_scaffold.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final AuthService _auth = AuthService();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final String phone = _phoneController.text.trim();
    final String password = _passwordController.text.trim();
    final String confirmPassword = _confirmPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showMessage('يرجى تعبئة الاسم والبريد الإلكتروني وكلمة المرور.');
      return;
    }

    if (password != confirmPassword) {
      _showMessage('كلمتا المرور غير متطابقين.');
      return;
    }

    if (password.length < 6) {
      _showMessage('كلمة المرور يجب أن تكون 6 أحرف على الأقل.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _auth.register(
        email: email,
        password: password,
        name: name,
        phoneNumber: phone.isEmpty ? null : phone,
      );

      if (!mounted) return;

      _showMessage('تم إنشاء الحساب بنجاح.');

      // Navigate will be handled by AuthGate automatically
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
      title: 'إنشاء حساب',
      subtitle: 'ابدأ إدارة فواتيرك بسهولة',
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _nameController,
            label: 'الاسم',
            hint: 'الاسم الكامل',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 12),
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
            controller: _phoneController,
            label: 'رقم الجوال',
            hint: '+9665xxxxxxxx',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
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
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _confirmPasswordController,
            label: 'تأكيد كلمة المرور',
            hint: '********',
            icon: Icons.lock_reset_rounded,
            obscureText: true,
            forceLtr: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _register(),
          ),
          const SizedBox(height: 16),
          AppPrimaryButton(
            label: 'إنشاء حساب',
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _register,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('تسجيل الدخول'),
              ),
              const Text(
                ' | ',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const Text('لديك حساب؟'),
            ],
          ),
        ],
      ),
    );
  }
}
