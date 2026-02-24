import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../widgets/app_button.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_text_field.dart';

class VerifyPhoneScreen extends StatefulWidget {
  const VerifyPhoneScreen({super.key, required this.phoneNumber});

  final String phoneNumber;

  @override
  State<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends State<VerifyPhoneScreen> {
  final TextEditingController _otpController = TextEditingController();
  final AuthService _auth = AuthService();

  String? _verificationId;
  bool _isSendingCode = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _startVerification();
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _startVerification() async {
    setState(() => _isSendingCode = true);
    await _auth.verifyPhone(
      phoneNumber: widget.phoneNumber,
      onCodeSent: (verificationId) {
        if (!mounted) {
          return;
        }
        setState(() {
          _verificationId = verificationId;
          _isSendingCode = false;
        });
        _showMessage('تم إرسال رمز التحقق إلى ${widget.phoneNumber}.');
      },
      onVerificationFailed: (message) {
        if (!mounted) {
          return;
        }
        setState(() => _isSendingCode = false);
        _showMessage(message);
      },
    );
  }

  Future<void> _verifyOtp() async {
    final String smsCode = _otpController.text.trim();
    if (smsCode.isEmpty) {
      _showMessage('أدخل رمز OTP أولاً.');
      return;
    }
    if (_verificationId == null) {
      _showMessage('لم يتم استلام معرف التحقق بعد. أعد إرسال الرمز.');
      return;
    }

    setState(() => _isVerifying = true);
    try {
      await _auth.linkPhone(_verificationId!, smsCode);
      if (mounted) {
        _showMessage('تم تفعيل رقم الجوال بنجاح.');
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        _showMessage(_auth.toUserMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
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
      appBarTitle: 'تفعيل رقم الجوال',
      title: 'التحقق عبر OTP',
      subtitle: 'أدخل الرمز الذي وصلك إلى ${widget.phoneNumber}',
      showWalletMark: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _otpController,
            label: 'رمز التحقق',
            hint: '123456',
            icon: Icons.sms_rounded,
            keyboardType: TextInputType.number,
            forceLtr: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _verifyOtp(),
            enabled: !_isSendingCode,
          ),
          const SizedBox(height: 18),
          AppButton(
            label: 'تأكيد الرمز',
            icon: Icons.verified_user_rounded,
            isLoading: _isVerifying,
            onPressed:
                (_isSendingCode || _isVerifying) ? null : _verifyOtp,
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'إعادة إرسال الرمز',
            icon: Icons.refresh_rounded,
            variant: AppButtonVariant.secondary,
            isLoading: _isSendingCode,
            onPressed: _isSendingCode ? null : _startVerification,
          ),
        ],
      ),
    );
  }
}
