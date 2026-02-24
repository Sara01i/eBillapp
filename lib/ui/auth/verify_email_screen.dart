import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../widgets/app_button.dart';
import '../widgets/app_scaffold.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final AuthService _auth = AuthService();
  bool _isChecking = false;
  bool _isResending = false;

  Future<void> _resendEmail() async {
    setState(() => _isResending = true);
    try {
      await _auth.resendVerificationEmail();
      if (mounted) {
        _showMessage('تمت إعادة إرسال رسالة التحقق بنجاح.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(_auth.toUserMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _checkStatus() async {
    setState(() => _isChecking = true);
    try {
      await _auth.reloadUser();
      if (mounted) {
        _showMessage('تم تحديث الحالة. إذا تم التفعيل سيتم تحويلك تلقائياً.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(_auth.toUserMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
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
      appBarTitle: 'تفعيل البريد الإلكتروني',
      title: 'تحقق من بريدك',
      subtitle: 'أرسلنا رابط التفعيل، فعّل الحساب ثم اضغط تحديث الحالة',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.backgroundElevated.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'قد تصل رسالة التحقق إلى Spam/Promotions… يرجى فحص هذه المجلدات ثم العودة والضغط على تحديث الحالة.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
          ),
          const SizedBox(height: 18),
          AppButton(
            label: 'تحديث الحالة الآن',
            icon: Icons.refresh_rounded,
            isLoading: _isChecking,
            onPressed: _isChecking ? null : _checkStatus,
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'إعادة إرسال رابط التحقق',
            icon: Icons.mark_email_unread_outlined,
            variant: AppButtonVariant.secondary,
            isLoading: _isResending,
            onPressed: _isResending ? null : _resendEmail,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => _auth.signOut(),
            child: const Text(
              'العودة إلى تسجيل الدخول',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
