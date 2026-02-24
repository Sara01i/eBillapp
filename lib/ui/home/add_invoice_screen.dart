import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/invoice_repository.dart';
import '../../theme/app_colors.dart';
import '../widgets/app_primary_button.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_text_field.dart';

class AddInvoiceScreen extends StatefulWidget {
  const AddInvoiceScreen({super.key});

  @override
  State<AddInvoiceScreen> createState() => _AddInvoiceScreenState();
}

class _AddInvoiceScreenState extends State<AddInvoiceScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _vendorController = TextEditingController();
  final InvoiceRepository _invoiceRepository = InvoiceRepository();

  DateTime _issuedAt = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _vendorController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _issuedAt,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 5),
    );

    if (selected != null) {
      setState(() => _issuedAt = selected);
    }
  }

  Future<void> _saveInvoice() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('لا توجد جلسة مستخدم نشطة.');
      return;
    }

    final String title = _titleController.text.trim();
    final String vendor = _vendorController.text.trim();
    final String amountText = _amountController.text.trim();
    final double? amount = double.tryParse(amountText);

    if (title.isEmpty) {
      _showMessage('أدخل عنوان الفاتورة.');
      return;
    }
    if (vendor.isEmpty) {
      _showMessage('أدخل اسم الجهة / المورد.');
      return;
    }
    if (amount == null || amount <= 0) {
      _showMessage('أدخل مبلغًا صحيحًا أكبر من صفر.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _invoiceRepository.addInvoice(
        ownerId: user.uid,
        title: title,
        amount: amount,
        vendor: vendor,
        issuedAt: _issuedAt,
      );

      if (!mounted) {
        return;
      }

      _showMessage('تمت إضافة الفاتورة بنجاح.');
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        _showMessage('تعذر حفظ الفاتورة الآن. حاول مرة أخرى.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatDate(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBarTitle: 'إضافة فاتورة',
      title: 'فاتورة جديدة',
      subtitle: 'أدخل تفاصيل الفاتورة ثم احفظها',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _titleController,
            label: 'عنوان الفاتورة',
            hint: 'مثال: فاتورة كهرباء',
            icon: Icons.receipt_long_rounded,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _amountController,
            label: 'المبلغ',
            hint: '0.00',
            icon: Icons.payments_outlined,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            forceLtr: true,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _vendorController,
            label: 'المورد / الجهة',
            hint: 'اسم المتجر أو الشركة',
            icon: Icons.storefront_outlined,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month_rounded),
            label: Align(
              alignment: Alignment.centerRight,
              child: Text('تاريخ الإصدار: ${_formatDate(_issuedAt)}'),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
          const SizedBox(height: 16),
          AppPrimaryButton(
            label: 'حفظ الفاتورة',
            isLoading: _isSaving,
            onPressed: _isSaving ? null : _saveInvoice,
          ),
        ],
      ),
    );
  }
}
