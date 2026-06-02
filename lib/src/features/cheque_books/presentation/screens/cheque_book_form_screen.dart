import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/cheque_book_model.dart';
import '../../../../core/utils/currency_formatter.dart'; // adjust path as needed
import '../../../../shared/widgets/bank_picker.dart';
import '../blocs/cheque_book_bloc.dart';

// ── digit helpers (reuse CurrencyFormatter internals via thin wrappers) ──────

/// Persian/Arabic-Indic → ASCII. Reuses CurrencyFormatter.parse logic.
int? _parsepersian(String s) => CurrencyFormatter.parse(s)?.toInt();

/// ASCII → Persian digits (mirrors CurrencyFormatter._toPersianDigits).
String _toPersian(int n) {
  const d = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  return n.toString().split('').map((c) {
    final i = int.tryParse(c);
    return i != null ? d[i] : c;
  }).join();
}

// ── formatter applied to every numeric field ─────────────────────────────────

/// Accepts Persian, Arabic-Indic, or ASCII digits; strips everything else;
/// rewrites the field value in Persian digits on every keystroke.
class _PersianDigitFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    // Normalise → keep only digit characters (any script)
    final digitsOnly = newValue.text.split('').where((c) {
      return int.tryParse(c) != null || '۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩'.contains(c);
    }).join();

    // Re-express as Persian
    const farsi  = '۰۱۲۳۴۵۶۷۸۹';
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    final persian = digitsOnly.split('').map((c) {
      final fi = farsi.indexOf(c);
      if (fi >= 0) return c;               // already Persian
      final ai = arabic.indexOf(c);
      if (ai >= 0) return farsi[ai];       // Arabic-Indic → Persian
      final li = int.tryParse(c);
      return li != null ? farsi[li] : c;   // ASCII → Persian
    }).join();

    return newValue.copyWith(
      text: persian,
      selection: TextSelection.collapsed(offset: persian.length),
    );
  }
}

// ── screen ────────────────────────────────────────────────────────────────────

enum _PageField { total, start, end }

class ChequeBookFormScreen extends StatefulWidget {
  final ChequeBook? book;

  const ChequeBookFormScreen({super.key, this.book});

  @override
  State<ChequeBookFormScreen> createState() => _ChequeBookFormScreenState();
}

class _ChequeBookFormScreenState extends State<ChequeBookFormScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _titleCtrl  = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _totalCtrl  = TextEditingController();
  final _startCtrl  = TextEditingController();
  final _endCtrl    = TextEditingController();

  String? _bankId;
  String? _bankName;

  _PageField? _focusedField;
  bool        _autoFilling = false;

  // ── parsed values (Persian-aware) ─────────────────────────────────────────
  int? get _total => _parsepersian(_totalCtrl.text.trim());
  int? get _start => _parsepersian(_startCtrl.text.trim());
  int? get _end   => _parsepersian(_endCtrl.text.trim());

  // ── hint texts ────────────────────────────────────────────────────────────
  String? _totalHint;
  String? _startHint;
  String? _endHint;

  @override
  void initState() {
    super.initState();
    if (widget.book != null) {
      final b = widget.book!;
      _titleCtrl.text  = b.title;
      _branchCtrl.text = b.branch;
      // Pre-populate in Persian so edit mode looks consistent
      _totalCtrl.text  = _toPersian(b.totalPages);
      _startCtrl.text  = _toPersian(b.startNumber);
      _endCtrl.text    = _toPersian(b.endNumber);
      _bankId   = b.bankId;
      _bankName = b.bankName;
    }

    _totalCtrl.addListener(_onPageFieldChanged);
    _startCtrl.addListener(_onPageFieldChanged);
    _endCtrl.addListener(_onPageFieldChanged);
  }

  @override
  void dispose() {
    _totalCtrl.removeListener(_onPageFieldChanged);
    _startCtrl.removeListener(_onPageFieldChanged);
    _endCtrl.removeListener(_onPageFieldChanged);
    _titleCtrl.dispose();
    _branchCtrl.dispose();
    _totalCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  // ── auto-fill ─────────────────────────────────────────────────────────────
  void _onPageFieldChanged() {
    if (_autoFilling) return;
    _autoFilling = true;
    try {
      _recalculate();
    } finally {
      _autoFilling = false;
    }
  }

  void _recalculate() {
    final total = _total;
    final start = _start;
    final end   = _end;

    String? totalHint;
    String? startHint;
    String? endHint;

    switch (_focusedField) {
      case _PageField.total:
        if (total != null && total > 0) {
          if (start != null && start > 0) {
            final c = start + total - 1;
            _setCtrl(_endCtrl, c);
            endHint = 'محاسبه شده: ${_toPersian(c)}';
          } else if (end != null && end > 0) {
            final c = end - total + 1;
            if (c > 0) {
              _setCtrl(_startCtrl, c);
              startHint = 'محاسبه شده: ${_toPersian(c)}';
            }
          } else {
            totalHint = 'شماره شروع یا پایان را وارد کنید';
          }
        }

      case _PageField.start:
        if (start != null && start > 0) {
          if (total != null && total > 0) {
            final c = start + total - 1;
            _setCtrl(_endCtrl, c);
            endHint = 'محاسبه شده: ${_toPersian(c)}';
          } else if (end != null && end > 0 && end >= start) {
            final c = end - start + 1;
            _setCtrl(_totalCtrl, c);
            totalHint = 'محاسبه شده: ${_toPersian(c)}';
          } else {
            startHint = 'تعداد برگ یا شماره پایان را وارد کنید';
          }
        }

      case _PageField.end:
        if (end != null && end > 0) {
          if (total != null && total > 0) {
            final c = end - total + 1;
            if (c > 0) {
              _setCtrl(_startCtrl, c);
              startHint = 'محاسبه شده: ${_toPersian(c)}';
            }
          } else if (start != null && start > 0 && end >= start) {
            final c = end - start + 1;
            _setCtrl(_totalCtrl, c);
            totalHint = 'محاسبه شده: ${_toPersian(c)}';
          } else {
            endHint = 'تعداد برگ یا شماره شروع را وارد کنید';
          }
        }

      case null:
      // Edit-mode pre-population: fill the missing field if exactly two are known
        if (total != null && start != null && _end == null) {
          _setCtrl(_endCtrl, start + total - 1);
        } else if (total != null && end != null && _start == null) {
          final s = end - total + 1;
          if (s > 0) _setCtrl(_startCtrl, s);
        } else if (start != null && end != null && _total == null) {
          final t = end - start + 1;
          if (t > 0) _setCtrl(_totalCtrl, t);
        }
    }

    setState(() {
      _totalHint = totalHint;
      _startHint = startHint;
      _endHint   = endHint;
    });
  }

  /// Writes [value] to [ctrl] as Persian digits; skips if already identical.
  void _setCtrl(TextEditingController ctrl, int value) {
    final persian = _toPersian(value);
    if (ctrl.text == persian) return;
    ctrl.text = persian;
    ctrl.selection = TextSelection.collapsed(offset: persian.length);
  }

  // ── submit ────────────────────────────────────────────────────────────────
  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_bankId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً بانک را انتخاب کنید')),
      );
      return;
    }

    // Parse Persian digits back to int for the model
    final totalPages = _total ?? 0;
    final start      = _start ?? 0;
    final end        = _end   ?? 0;

    if (totalPages <= 0 || start <= 0 || end <= 0 || end < start) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اطلاعات شماره برگ‌ها نادرست است')),
      );
      return;
    }

    if (widget.book != null) {
      context.read<ChequeBookBloc>().add(UpdateChequeBookEvent(
        widget.book!.copyWith(
          title:       _titleCtrl.text.trim(),
          bankId:      _bankId,
          bankName:    _bankName,
          branch:      _branchCtrl.text.trim(),
          totalPages:  totalPages,
          startNumber: start,
          endNumber:   end,
        ),
      ));
    } else {
      context.read<ChequeBookBloc>().add(CreateChequeBookEvent(
        title:       _titleCtrl.text.trim(),
        bankId:      _bankId!,
        bankName:    _bankName!,
        branch:      _branchCtrl.text.trim(),
        totalPages:  totalPages,
        startNumber: start,
        endNumber:   end,
      ));
    }
    Navigator.pop(context);
  }

  // ── build ─────────────────────────────────────────────────────────────────
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
                selectedBankId:   _bankId,
                selectedBankName: _bankName,
                onSelected: (id, name) => setState(() {
                  _bankId   = id;
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
              Focus(
                onFocusChange: (gained) {
                  if (gained) setState(() => _focusedField = _PageField.total);
                },
                child: _numericField(
                  controller: _totalCtrl,
                  label: 'تعداد برگ',
                  hint: '۲۵',
                  helperText: _totalHint,
                  validator: (v) {
                    final n = _parsepersian(v?.trim() ?? '');
                    if (n == null || n <= 0) return 'عدد معتبر وارد کنید';
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Focus(
                      onFocusChange: (gained) {
                        if (gained) setState(() => _focusedField = _PageField.start);
                      },
                      child: _numericField(
                        controller: _startCtrl,
                        label: 'شروع شماره',
                        hint: '۱۰۰۰۰۱',
                        helperText: _startHint,
                        validator: (v) {
                          final n = _parsepersian(v?.trim() ?? '');
                          return (n == null || n <= 0) ? 'نادرست' : null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Focus(
                      onFocusChange: (gained) {
                        if (gained) setState(() => _focusedField = _PageField.end);
                      },
                      child: _numericField(
                        controller: _endCtrl,
                        label: 'پایان شماره',
                        hint: '۱۰۰۰۲۵',
                        helperText: _endHint,
                        validator: (v) {
                          final n = _parsepersian(v?.trim() ?? '');
                          return (n == null || n <= 0) ? 'نادرست' : null;
                        },
                      ),
                    ),
                  ),
                ],
              ),
              _buildConsistencyWarning(),
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
              child: Text(
                isEdit ? 'ذخیره تغییرات' : 'ثبت دسته چک',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── consistency row ───────────────────────────────────────────────────────
  Widget _buildConsistencyWarning() {
    final total = _total;
    final start = _start;
    final end   = _end;

    if (total == null || start == null || end == null) return const SizedBox.shrink();
    if (end < start) {
      return _hintRow('شماره پایان باید بزرگ‌تر از شماره شروع باشد', isError: true);
    }
    if (end - start + 1 != total) {
      return _hintRow(
        'تعداد برگ (${_toPersian(end - start + 1)}) با مقادیر شروع و پایان تطابق ندارد',
        isError: true,
      );
    }
    return _hintRow('اطلاعات برگ‌ها صحیح است', isError: false);
  }

  Widget _hintRow(String text, {required bool isError}) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            size: 16,
            color: isError ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isError ? Colors.red : Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── field builders ────────────────────────────────────────────────────────
  Widget _buildSection(String title, List<Widget> children) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: dark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: dark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: dark ? AppColors.darkBorder : AppColors.border,
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  /// Plain text field (title, branch — no digit formatting).
  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: validator,
    );
  }

  /// Numeric field with Persian digit formatter + helper text.
  Widget _numericField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [_PersianDigitFormatter()],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        helperStyle: const TextStyle(fontSize: 11, color: Colors.blue),
        helperMaxLines: 2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: validator,
    );
  }
}
