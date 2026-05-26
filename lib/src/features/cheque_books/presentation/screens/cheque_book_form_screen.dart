import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/cheque_book_model.dart';
import '../../../../shared/widgets/bank_picker.dart';
import '../blocs/cheque_book_bloc.dart';

class ChequeBookFormScreen extends StatefulWidget {
  final ChequeBook? book;

  const ChequeBookFormScreen({super.key, this.book});

  @override
  State<ChequeBookFormScreen> createState() => _ChequeBookFormScreenState();
}

class _ChequeBookFormScreenState extends State<ChequeBookFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _totalPagesCtrl = TextEditingController();
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();

  String? _bankId;
  String? _bankName;

  @override
  void initState() {
    super.initState();
    if (widget.book != null) {
      final b = widget.book!;
      _titleCtrl.text = b.title;
      _branchCtrl.text = b.branch;
      _totalPagesCtrl.text = b.totalPages.toString();
      _startCtrl.text = b.startNumber.toString();
      _endCtrl.text = b.endNumber.toString();
      _bankId = b.bankId;
      _bankName = b.bankName;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _branchCtrl.dispose();
    _totalPagesCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_bankId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً بانک را انتخاب کنید')),
      );
      return;
    }

    final totalPages = int.tryParse(_totalPagesCtrl.text.trim()) ?? 0;
    final start = int.tryParse(_startCtrl.text.trim()) ?? 0;
    final end = int.tryParse(_endCtrl.text.trim()) ?? 0;

    if (totalPages <= 0 || start <= 0 || end <= 0 || end < start) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اطلاعات شماره برگ‌ها نادرست است')),
      );
      return;
    }

    if (widget.book != null) {
      context.read<ChequeBookBloc>().add(UpdateChequeBookEvent(
            widget.book!.copyWith(
              title: _titleCtrl.text.trim(),
              bankId: _bankId,
              bankName: _bankName,
              branch: _branchCtrl.text.trim(),
              totalPages: totalPages,
              startNumber: start,
              endNumber: end,
            ),
          ));
    } else {
      context.read<ChequeBookBloc>().add(CreateChequeBookEvent(
            title: _titleCtrl.text.trim(),
            bankId: _bankId!,
            bankName: _bankName!,
            branch: _branchCtrl.text.trim(),
            totalPages: totalPages,
            startNumber: start,
            endNumber: end,
          ));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.book != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'ویرایش دسته چک' : 'دسته چک جدید'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSection('اطلاعات کلی', [
              _field(
                controller: _titleCtrl,
                label: 'عنوان دسته چک',
                hint: 'مثال: دسته چک ملت شخصی',
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'عنوان الزامی است' : null,
              ),
            ]),
            const SizedBox(height: 16),
            _buildSection('اطلاعات بانکی', [
              BankPickerField(
                selectedBankId: _bankId,
                selectedBankName: _bankName,
                onSelected: (id, name) => setState(() {
                  _bankId = id;
                  _bankName = name;
                }),
              ),
              const SizedBox(height: 12),
              _field(
                controller: _branchCtrl,
                label: 'شعبه',
                hint: 'نام شعبه',
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'شعبه الزامی است' : null,
              ),
            ]),
            const SizedBox(height: 16),
            _buildSection('اطلاعات برگ‌ها', [
              _field(
                controller: _totalPagesCtrl,
                label: 'تعداد برگ',
                hint: '۲۵',
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null || n <= 0) return 'عدد معتبر وارد کنید';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _startCtrl,
                      label: 'شروع شماره',
                      hint: '100001',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse(v?.trim() ?? '');
                        return (n == null || n <= 0) ? 'نادرست' : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      controller: _endCtrl,
                      label: 'پایان شماره',
                      hint: '100025',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse(v?.trim() ?? '');
                        return (n == null || n <= 0) ? 'نادرست' : null;
                      },
                    ),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(isEdit ? 'ذخیره تغییرات' : 'ثبت دسته چک',
                  style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkBorder : AppColors.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: validator,
    );
  }
}
