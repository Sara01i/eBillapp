import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/invoice_repository.dart';
import '../../theme/app_colors.dart';
import '../profile/profile_screen.dart';
import '../widgets/app_button.dart';
import 'add_invoice_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final InvoiceRepository _invoiceRepository = InvoiceRepository();

  @override
  void initState() {
    super.initState();
    _bootstrapUserDocument();
  }

  Future<void> _bootstrapUserDocument() async {
    try {
      await _authService.ensureCurrentUserDocument();
    } catch (_) {
      // Keep home usable even when self-heal fails temporarily.
    }
  }

  Future<void> _openAddInvoice() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddInvoiceScreen()),
    );
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('لا توجد جلسة مستخدم نشطة.'),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Image.asset(
                'assets/brand/wallet_logo.png',
                width: 30,
                height: 30,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 10),
              const Text('الرئيسية'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'الملف الشخصي',
              onPressed: _openProfile,
              icon: const Icon(Icons.person_outline_rounded),
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0A120F),
                AppColors.background,
                Color(0xFF050A08),
              ],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _AddInvoiceCta(onPressed: _openAddInvoice),
              const SizedBox(height: 16),
              Text(
                'فواتيري',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 10),
              StreamBuilder<List<InvoiceRecord>>(
                stream: _invoiceRepository.watchUserInvoices(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.accent),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return const _ErrorCard(
                      message: 'تعذر تحميل الفواتير الآن. حاول مرة أخرى.',
                    );
                  }

                  final List<InvoiceRecord> invoices =
                      List<InvoiceRecord>.from(snapshot.data ?? const []);
                  if (invoices.isEmpty) {
                    return _EmptyInvoicesState(onAddPressed: _openAddInvoice);
                  }

                  return Column(
                    children: invoices
                        .map((invoice) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _InvoiceCard(invoice: invoice),
                            ))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddInvoiceCta extends StatelessWidget {
  const _AddInvoiceCta({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF1F6A47),
            Color(0xFF174F37),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2D8B5F)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'إدارة فواتيرك أسرع',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'أضف فاتورة جديدة واحتفظ بسجل واضح لكل المصروفات.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'إضافة فاتورة',
            icon: Icons.add_rounded,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice});

  final InvoiceRecord invoice;

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '-';
    }
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.title.isEmpty ? 'فاتورة بدون عنوان' : invoice.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  invoice.vendor.isEmpty ? 'مورد غير محدد' : invoice.vendor,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'تاريخ الإصدار: ${_formatDate(invoice.issuedAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            invoice.amount.toStringAsFixed(2),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.accentSoft,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyInvoicesState extends StatelessWidget {
  const _EmptyInvoicesState({required this.onAddPressed});

  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_rounded,
            size: 42,
            color: AppColors.accentSoft,
          ),
          const SizedBox(height: 10),
          Text(
            'لا توجد فواتير حتى الآن',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          const Text(
            'ابدأ الآن بإضافة أول فاتورة لتحصل على سجل مرتب وواضح.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'إضافة أول فاتورة',
            icon: Icons.add_circle_outline_rounded,
            onPressed: onAddPressed,
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.danger),
      ),
    );
  }
}
