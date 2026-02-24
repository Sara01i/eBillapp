import 'dart:async';
import 'package:flutter/material.dart';
import '../../main.dart'; // To access rootNavKey
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../widgets/app_primary_button.dart';
import '../widgets/app_text_field.dart';
import '../widgets/auth_scaffold.dart';

class VerifyEmailOtpScreen extends StatefulWidget {
  const VerifyEmailOtpScreen({
    super.key,
    required this.email,
  });

  final String email;

  @override
  State<VerifyEmailOtpScreen> createState() => _VerifyEmailOtpScreenState();
}

class _VerifyEmailOtpScreenState extends State<VerifyEmailOtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  final AuthService _auth = AuthService();

  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  bool _isSending = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[OTP_UI] Screen initialized for: ${widget.email}');
    // Delay slightly to allow the screen to settle
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _sendOtp();
    });
  }

  @override
  void dispose() {
    debugPrint('[OTP_UI] Screen disposed.');
    _countdownTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_isSending || _remainingSeconds > 0) return;

    setState(() => _isSending = true);
    debugPrint('[OTP_UI] Resend OTP triggered.');

    try {
      await _auth.sendEmailOtp();
      _startCountdown(60);
      _showMessage('تم إرسال رمز التحقق بنجاح.');
      debugPrint('[OTP_UI] OTP Sent successfully.');
    } catch (error) {
      debugPrint('[OTP_UI] Send OTP Error: $error');
      if (mounted) _showMessage(_auth.toUserMessage(error));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _startCountdown(int seconds) {
    _countdownTimer?.cancel();
    setState(() => _remainingSeconds = seconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
      } else {
        setState(() => _remainingSeconds -= 1);
      }
    });
  }

  Future<void> _verifyOtp() async {
    final String code = _otpController.text.trim();
    if (code.length != 6) {
      _showMessage('أدخل 6 أرقام للتحقق.');
      return;
    }

    setState(() => _isVerifying = true);
    debugPrint('[OTP_UI] Verifying code: $code');

    try {
      await _auth.verifyEmailOtp(code);
      debugPrint('[OTP_UI] Verify API success (200 OK)');

      _showMessage('تم التحقق بنجاح! جاري الدخول...');

      // FORCE NAVIGATION using rootNavKey to bypass context issues
      debugPrint('[OTP_UI] NAVIGATING TO HOME via rootNavKey');
      rootNavKey.currentState?.pushNamedAndRemoveUntil('/home', (route) => false);

    } catch (error) {
      debugPrint('[OTP_UI] Verify Error: $error');
      if (mounted) _showMessage(_auth.toUserMessage(error));
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _handleLogout() async {
    debugPrint('[OTP_UI] Logout button clicked.');
    try {
      _countdownTimer?.cancel();
      await _auth.signOut();
      debugPrint('[OTP_UI] Sign out successful.');

      // FORCE NAVIGATION to login
      debugPrint('[OTP_UI] NAVIGATING TO LOGIN via rootNavKey');
      rootNavKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      debugPrint('[OTP_UI] Logout error: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'تحقق من البريد الإلكتروني',
      subtitle: widget.email,
      showBack: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'أدخل رمز التحقق المكون من 6 أرقام الذي أرسلناه إلى بريدك الإلكتروني.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),
          AppTextField(
            controller: _otpController,
            label: 'رمز التحقق',
            hint: '123456',
            icon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            forceLtr: true,
            onSubmitted: (_) => _verifyOtp(),
          ),
          const SizedBox(height: 24),
          AppPrimaryButton(
            label: 'تحقق الآن',
            isLoading: _isVerifying,
            onPressed: _isVerifying ? null : _verifyOtp,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: (_remainingSeconds == 0 && !_isSending) ? _sendOtp : null,
            child: Text(
              _remainingSeconds > 0
                  ? 'إعادة الإرسال خلال $_remainingSeconds ثانية'
                  : 'إعادة إرسال الرمز',
              style: TextStyle(
                color: _remainingSeconds > 0 ? AppColors.textSecondary : AppColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _handleLogout,
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
