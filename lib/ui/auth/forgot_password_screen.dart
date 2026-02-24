import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../widgets/app_button.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final AuthService _auth = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final String email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('يرجى إدخال البريد الإلكتروني.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _auth.sendPasswordReset(email);
      if (mounted) {
        _showMessage('تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك.');
        Navigator.pop(context);
      }
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
    return AppScaffold(
      appBarTitle: 'استعادة كلمة المرور',
      title: 'استرجاع الوصول',
      subtitle: 'أدخل بريدك الإلكتروني وسنرسل لك رابط إعادة التعيين',
      showWalletMark: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _emailController,
            label: 'البريد الإلكتروني',
            hint: 'name@example.com',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            forceLtr: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _resetPassword(),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'إرسال رابط الاستعادة',
            icon: Icons.send_rounded,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _resetPassword,
          ),
        ],
      ),
    );
  }
}
