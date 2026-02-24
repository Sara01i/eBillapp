import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../main.dart'; // Access rootNavKey
import '../../services/auth_service.dart';
import '../../services/profile_repository.dart';
import '../../theme/app_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/app_primary_button.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_text_field.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  final AuthService _authService = AuthService();
  final ProfileRepository _profileRepository = ProfileRepository();

  bool _isSaving = false;
  bool _initializedForm = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile(UserProfileData profile) async {
    final String name = _nameController.text.trim();
    final String phone = _phoneController.text.trim();

    if (name.isEmpty) {
      _showMessage('الاسم مطلوب.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _profileRepository.updateProfile(
        uid: profile.uid,
        name: name,
        phoneNumber: phone,
      );
      if (mounted) {
        _showMessage('تم تحديث الملف الشخصي.');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('تعذر تحديث الملف الشخصي الآن.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _sendResetPasswordEmail(String email) async {
    if (email.isEmpty) {
      _showMessage('البريد الإلكتروني غير متوفر.');
      return;
    }
    try {
      await _authService.sendPasswordReset(email);
      if (mounted) {
        _showMessage('تم إرسال رابط إعادة تعيين كلمة المرور.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(_authService.toUserMessage(error));
      }
    }
  }

  Future<void> _logout() async {
    debugPrint('[Profile] Logging out...');
    try {
      await _authService.signOut();
      debugPrint('[Profile] Sign out successful.');

      // Navigate to initial route (AuthGate) to reset app state completely
      rootNavKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      debugPrint('[Profile] Logout error: $e');
    }
  }

  Future<void> _deleteAccount() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تأكيد حذف الحساب'),
          content: const Text(
            'سيتم حذف حسابك وجميع فواتيرك نهائيًا. لا يمكن التراجع عن هذا الإجراء.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'حذف نهائي',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _authService.deleteCurrentUserAccount();
      debugPrint('[Profile] Account deleted.');
      rootNavKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
    } catch (error) {
      if (mounted) {
        _showMessage(_authService.toUserMessage(error));
      }
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
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const AppScaffold(
        appBarTitle: 'الملف الشخصي',
        title: 'لا توجد جلسة',
        subtitle: 'سجّل الدخول للوصول إلى بيانات الحساب.',
        child: SizedBox.shrink(),
      );
    }

    return StreamBuilder<UserProfileData>(
      stream: _profileRepository.watchProfile(
        uid: user.uid,
        fallbackEmail: user.email ?? '',
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const AppScaffold(
            appBarTitle: 'الملف الشخصي',
            title: 'جاري التحميل',
            subtitle: 'يتم جلب بيانات الحساب...',
            child: Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          );
        }

        final UserProfileData profile = snapshot.data ??
            UserProfileData(
              uid: user.uid,
              name: '',
              email: user.email ?? '',
              phoneNumber: '',
              emailOtpVerified: false,
              phoneVerified: false,
            );

        if (!_initializedForm) {
          _nameController.text = profile.name;
          _phoneController.text = profile.phoneNumber;
          _initializedForm = true;
        }

        return AppScaffold(
          appBarTitle: 'الملف الشخصي',
          title: 'حسابي',
          subtitle: 'إدارة البيانات والإعدادات',
          actions: [
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
              tooltip: 'تسجيل الخروج',
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionCard(
                title: 'المعلومات الشخصية',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InfoLine(label: 'الاسم', value: profile.name.isEmpty ? '-' : profile.name),
                    _InfoLine(label: 'البريد', value: profile.email.isEmpty ? '-' : profile.email),
                    _InfoLine(
                      label: 'الجوال',
                      value: profile.phoneNumber.isEmpty ? 'غير مضاف' : profile.phoneNumber,
                    ),
                    _InfoLine(
                      label: 'تحقق البريد OTP',
                      value: profile.emailOtpVerified ? 'مفعّل' : 'غير مفعّل',
                    ),
                    _InfoLine(
                      label: 'تحقق الجوال',
                      value: profile.phoneVerified ? 'مفعّل' : 'غير مفعّل',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'تعديل البيانات',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      controller: _nameController,
                      label: 'الاسم',
                      hint: 'الاسم الكامل',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 10),
                    AppTextField(
                      controller: _phoneController,
                      label: 'رقم الجوال (اختياري)',
                      hint: '+9665xxxxxxxx',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      forceLtr: true,
                    ),
                    const SizedBox(height: 14),
                    AppPrimaryButton(
                      label: 'حفظ التغييرات',
                      isLoading: _isSaving,
                      onPressed: _isSaving ? null : () => _saveProfile(profile),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'الإعدادات',
                child: Column(
                  children: [
                    AppButton(
                      label: 'تغيير كلمة المرور',
                      icon: Icons.password_rounded,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => _sendResetPasswordEmail(profile.email),
                    ),
                    const SizedBox(height: 10),
                    const _PlaceholderTile(
                      icon: Icons.dark_mode_outlined,
                      title: 'تبديل الثيم',
                      subtitle: 'قريبًا',
                    ),
                    const SizedBox(height: 8),
                    const _PlaceholderTile(
                      icon: Icons.language_rounded,
                      title: 'اللغة',
                      subtitle: 'قريبًا',
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'تسجيل الخروج',
                      icon: Icons.logout_rounded,
                      variant: AppButtonVariant.secondary,
                      onPressed: _logout,
                    ),
                    const SizedBox(height: 10),
                    AppButton(
                      label: 'حذف الحساب نهائيًا',
                      icon: Icons.delete_forever_rounded,
                      variant: AppButtonVariant.secondary,
                      onPressed: _deleteAccount,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderTile extends StatelessWidget {
  const _PlaceholderTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}
