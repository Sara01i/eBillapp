import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/app_scaffold.dart';
import 'login_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});
  final String email;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final AuthService _auth = AuthService();
  final TextEditingController _code = TextEditingController();

  bool _isVerifying = false;
  bool _isResending = false;

  Timer? _cooldownTimer;
  int _cooldown = 0;

  @override
  void initState() {
    super.initState();
    // Optional: Resend automatically if opening for the first time
    // _resend();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown -= 1);
      }
    });
  }

  void _show(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _verify() async {
    if (_isVerifying) return;

    final code = _code.text.trim();
    if (code.length < 4) {
      _show('أدخل رمز صحيح.');
      return;
    }

    setState(() => _isVerifying = true);
    try {
      // 1) Verify the OTP via API
      await _auth.verifyEmailOtp(code);

      // 2) ✅ Clear the login pending flag in Firestore
      await _auth.markLoginOtpPending(false);

      if (!mounted) return;
      _show('تم التحقق بنجاح!');

      // AuthGate will naturally pick up the Firestore change and navigate to Home.
      // But we can also force a reload if needed.
      await FirebaseAuth.instance.currentUser?.reload();

    } catch (e) {
      if (mounted) _show(_auth.toUserMessage(e));
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    if (_isResending || _cooldown > 0) return;

    setState(() => _isResending = true);
    try {
      await _auth.sendEmailOtpForEmail(widget.email);
      if (mounted) {
        _show('تم إرسال رمز جديد إلى بريدك.');
        _startCooldown(60);
      }
    } catch (e) {
      if (mounted) _show(_auth.toUserMessage(e));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBarTitle: 'تحقق من البريد الإلكتروني',
      title: 'أدخل رمز التحقق',
      subtitle: widget.email,
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
              'أدخل رمز التحقق المكوّن من 6 أرقام الذي وصلك على البريد.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: '123456',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 18),
          AppButton(
            label: 'تحقق الآن',
            icon: Icons.verified_rounded,
            isLoading: _isVerifying,
            onPressed: _isVerifying ? null : _verify,
          ),
          const SizedBox(height: 10),
          AppButton(
            label: _cooldown > 0 ? 'إعادة إرسال الرمز ($_cooldown)' : 'إعادة إرسال الرمز',
            icon: Icons.mark_email_unread_outlined,
            variant: AppButtonVariant.secondary,
            isLoading: _isResending,
            onPressed: (_isResending || _cooldown > 0) ? null : _resend,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => _auth.signOut(),
            child: const Text(
              'تسجيل الخروج',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
