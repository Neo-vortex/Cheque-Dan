import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/cheque_model.dart';
import '../../../../core/models/cheque_book_model.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/bank_picker.dart';
import '../../../../shared/widgets/persian_date_picker.dart';
import '../blocs/cheque_bloc.dart';
import '../../../../shared/widgets/cheque_image_picker.dart';
import '../../../../shared/widgets/qr_scanner_button.dart';
import '../../../../features/cheque_books/data/cheque_book_repository.dart';

class ChequeFormScreen extends StatefulWidget {
  final Cheque? cheque;
  /// When provided (from راس‌گیری), the form opens in CREATE mode but
  /// pre-fills amount, dueDate, counterpartyName, and direction. All fields
  /// remain fully editable.
  final Cheque? prefillFromRasGiri;

  const ChequeFormScreen({super.key, this.cheque, this.prefillFromRasGiri});

  @override
  State<ChequeFormScreen> createState() => _ChequeFormScreenState();
}

class _ChequeFormScreenState extends State<ChequeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sayyadiCtrl = TextEditingController();
  final _chequeNumCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _counterpartyCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();

  String? _bankId;
  String? _bankName;
  DateTime? _issueDate = DateTime.now();
  DateTime? _dueDate;
  ChequeDirection _direction = ChequeDirection.issued;
  ChequeStatus _status = ChequeStatus.active;
  List<String> _tags = [];
  List<String> _imagePaths = [];

  List<ChequeBook> _chequeBooks = [];
  ChequeBook? _selectedBook;

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.cheque != null;
    if (_isEditing) {
      final c = widget.cheque!;
      _sayyadiCtrl.text = c.sayyadiId;
      _chequeNumCtrl.text = c.chequeNumber;
      _amountCtrl.text = CurrencyFormatter.formatNumber(c.amount);
      _counterpartyCtrl.text = c.counterpartyName;
      _phoneCtrl.text = c.counterpartyPhone ?? '';
      _noteCtrl.text = c.note ?? '';
      _bankId = c.bankId;
      _bankName = c.bankName;
      _issueDate = c.issueDate;
      _dueDate = c.dueDate;
      _direction = c.direction;
      _status = c.status;
      _tags = List.from(c.tags);
      _imagePaths = List.from(c.imagePaths);
    }
    // راس‌گیری prefill: applied only in create mode (no cheque being edited)
    if (!_isEditing && widget.prefillFromRasGiri != null) {
      final p = widget.prefillFromRasGiri!;
      _amountCtrl.text = CurrencyFormatter.formatNumber(p.amount);
      _counterpartyCtrl.text = p.counterpartyName;
      _dueDate = p.dueDate;
      _direction = p.direction;
    }
    _loadChequeBooks();
  }

  Future<void> _loadChequeBooks() async {
    final repo = ChequeBookRepository();
    final books = await repo.getAllChequeBooks();
    if (mounted) {
      setState(() {
        _chequeBooks = books.where((b) => b.isActive).toList();
        if (_isEditing && widget.cheque?.chequeBookId != null) {
          _selectedBook = _chequeBooks.firstWhere(
                (b) => b.id == widget.cheque!.chequeBookId,
            orElse: () => _chequeBooks.first,
          );
        }
      });
    }
  }

  Future<void> _onBookSelected(ChequeBook? book) async {
    if (book == null) {
      setState(() {
        _selectedBook = null;
        _bankId = null;
        _bankName = null;
        _chequeNumCtrl.text = '';
      });
      return;
    }
    final repo = ChequeBookRepository();
    final nextPage = await repo.getNextAvailablePage(book);
    setState(() {
      _selectedBook = book;
      _bankId = book.bankId;
      _bankName = book.bankName;
      _chequeNumCtrl.text = nextPage?.toString() ?? '';
    });
  }

  Future<void> _pickContact() async {
    if (!await FlutterContacts.requestPermission(readonly: true)) return;
    final contact = await FlutterContacts.openExternalPick();
    if (contact == null) return;
    final full = await FlutterContacts.getContact(contact.id);
    if (!mounted) return;
    setState(() {
      _counterpartyCtrl.text = full?.displayName ?? contact.displayName;
      _phoneCtrl.text =
      full?.phones.isNotEmpty == true ? full!.phones.first.number : '';
    });
  }

  @override
  void dispose() {
    _sayyadiCtrl.dispose();
    _chequeNumCtrl.dispose();
    _amountCtrl.dispose();
    _counterpartyCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_bankId == null) {
      _showError('لطفاً بانک را انتخاب کنید');
      return;
    }
    if (_issueDate == null) {
      _showError('لطفاً تاریخ صدور را وارد کنید');
      return;
    }
    if (_dueDate == null) {
      _showError('لطفاً تاریخ سررسید را وارد کنید');
      return;
    }
    if (_issueDate!.isAfter(_dueDate!)) {
      _showError(AppStrings.issueDateAfterDueDate);
      return;
    }

    final amount = CurrencyFormatter.parse(_amountCtrl.text) ?? 0;
    if (amount <= 0) {
      _showError(AppStrings.invalidAmount);
      return;
    }

    final phone = _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim();

    if (_isEditing) {
      final updated = widget.cheque!.copyWith(
        sayyadiId: _sayyadiCtrl.text.trim(),
        chequeNumber: _chequeNumCtrl.text.trim(),
        bankId: _bankId,
        bankName: _bankName,
        amount: amount,
        issueDate: _issueDate,
        dueDate: _dueDate,
        direction: _direction,
        counterpartyName: _counterpartyCtrl.text.trim(),
        counterpartyPhone: phone,
        status: _status,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        tags: _tags,
        imagePaths: _imagePaths,
        chequeBookId: _selectedBook?.id,
      );
      context.read<ChequeBloc>().add(UpdateChequeEvent(updated));
    } else {
      context.read<ChequeBloc>().add(CreateChequeEvent(
        sayyadiId: _sayyadiCtrl.text.trim(),
        chequeNumber: _chequeNumCtrl.text.trim(),
        bankId: _bankId!,
        bankName: _bankName!,
        amount: amount,
        issueDate: _issueDate!,
        dueDate: _dueDate!,
        direction: _direction,
        counterpartyName: _counterpartyCtrl.text.trim(),
        counterpartyPhone: phone,
        status: _status,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        tags: _tags,
        imagePaths: _imagePaths,
        chequeBookId: _selectedBook?.id,
      ));
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.returned),
    );
  }

  void _addTag(String tag) {
    final t = tag.trim();
    if (t.isEmpty || _tags.contains(t)) return;
    setState(() {
      _tags.add(t);
      _tagCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChequeBloc, ChequeState>(
      listener: (context, state) {
        if (state is ChequeOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
          Navigator.of(context).pop();
        } else if (state is ChequeOperationFailure) {
          _showError(state.error);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'ویرایش چک' : 'ثبت چک جدید'),
          actions: [
            TextButton(
              onPressed: _submit,
              child: const Text(
                'ذخیره',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionHeader(title: 'جهت چک'),
              const SizedBox(height: 8),
              _DirectionToggle(
                direction: _direction,
                onChanged: (d) => setState(() {
                  _direction = d;
                  if (d == ChequeDirection.received) {
                    _selectedBook = null;
                    _chequeNumCtrl.text = '';
                  }
                }),
              ),
              const SizedBox(height: 16),
              _SectionHeader(title: 'اطلاعات چک'),
              const SizedBox(height: 8),
              if (_chequeBooks.isNotEmpty && _direction == ChequeDirection.issued) ...[
                _ChequeBookPickerField(
                  books: _chequeBooks,
                  selected: _selectedBook,
                  onSelected: _onBookSelected,
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sayyadiCtrl,
                      decoration: const InputDecoration(
                        labelText: AppStrings.sayyadiId,
                        prefixIcon: Icon(Icons.fingerprint, color: AppColors.textSecondary),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? AppStrings.fieldRequired
                          : null,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  QrScannerButton(
                    onScanned: (val) => setState(() => _sayyadiCtrl.text = val),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _chequeNumCtrl,
                readOnly: _selectedBook != null,
                decoration: InputDecoration(
                  labelText: AppStrings.chequeNumber,
                  prefixIcon: const Icon(Icons.numbers, color: AppColors.textSecondary),
                  filled: _selectedBook != null,
                  fillColor: _selectedBook != null ? AppColors.surfaceVariant : null,
                  helperText: _selectedBook != null ? 'از دسته چک انتخاب شده' : null,
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? AppStrings.fieldRequired
                    : null,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              _selectedBook != null
                  ? _ReadOnlyBankField(bankName: _bankName ?? '', bankId: _bankId ?? '')
                  : BankPickerField(
                selectedBankId: _bankId,
                selectedBankName: _bankName,
                onSelected: (id, name) => setState(() {
                  _bankId = id;
                  _bankName = name;
                }),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountCtrl,
                decoration: const InputDecoration(
                  labelText: 'مبلغ (تومان)',
                  prefixIcon: Icon(Icons.payments_outlined, color: AppColors.textSecondary),
                  suffixText: 'تومان',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return AppStrings.fieldRequired;
                  final amt = CurrencyFormatter.parse(v);
                  if (amt == null || amt <= 0) return AppStrings.invalidAmount;
                  return null;
                },
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  // Bug 10 fix: normalize all digits to ASCII first,
                  // then reformat with Persian digits uniformly.
                  const farsi = '۰۱۲۳۴۵۶۷۸۹';
                  final normalized = v.split('').map((c) {
                    final idx = farsi.indexOf(c);
                    return idx >= 0 ? idx.toString() : c;
                  }).join();
                  final clean = normalized.replaceAll(',', '').replaceAll(' ', '');
                  final num = double.tryParse(clean);
                  if (num != null) {
                    final formatted = CurrencyFormatter.formatNumber(num);
                    if (formatted != v) {
                      _amountCtrl.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: formatted.length),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
              _SectionHeader(title: 'تاریخ‌ها'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: PersianDatePickerField(
                      selectedDate: _issueDate,
                      label: AppStrings.issueDate,
                      onDateSelected: (d) => setState(() => _issueDate = d),
                      lastDate: _dueDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PersianDatePickerField(
                      selectedDate: _dueDate,
                      label: AppStrings.dueDate,
                      onDateSelected: (d) => setState(() => _dueDate = d),
                      firstDate: _issueDate,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionHeader(title: 'طرف حساب'),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _counterpartyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'نام طرف حساب',
                        prefixIcon: Icon(Icons.person_outline, color: AppColors.textSecondary),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? AppStrings.fieldRequired
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'انتخاب از مخاطبین',
                    child: IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.contacts_outlined, color: AppColors.primary),
                      onPressed: _pickContact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'شماره موبایل طرف حساب (اختیاری)',
                  prefixIcon: Icon(Icons.phone_outlined, color: AppColors.textSecondary),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _SectionHeader(title: 'وضعیت'),
              const SizedBox(height: 8),
              _StatusDropdown(
                status: _status,
                onChanged: (s) => setState(() => _status = s),
              ),
              const SizedBox(height: 16),
              _SectionHeader(title: 'برچسب‌ها (اختیاری)'),
              const SizedBox(height: 8),
              _TagsSection(
                tags: _tags,
                controller: _tagCtrl,
                onAdd: _addTag,
                onRemove: (t) => setState(() => _tags.remove(t)),
              ),
              const SizedBox(height: 16),
              _SectionHeader(title: 'تصاویر چک (اختیاری)'),
              const SizedBox(height: 8),
              ChequeImagePicker(
                imagePaths: _imagePaths,
                onChanged: (paths) => setState(() => _imagePaths = paths),
              ),
              const SizedBox(height: 16),
              _SectionHeader(title: 'یادداشت (اختیاری)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  hintText: 'یادداشت یا توضیحات...',
                  prefixIcon: Icon(Icons.note_outlined, color: AppColors.textSecondary),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _submit,
                child: Text(_isEditing ? 'ذخیره تغییرات' : 'ثبت چک'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextSecondary : AppColors.textSecondary,
      ),
    );
  }
}

class _DirectionToggle extends StatelessWidget {
  final ChequeDirection direction;
  final Function(ChequeDirection) onChanged;

  const _DirectionToggle({required this.direction, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ToggleOption(
            label: AppStrings.issued,
            icon: Icons.arrow_upward,
            color: AppColors.issued,
            selected: direction == ChequeDirection.issued,
            onTap: () => onChanged(ChequeDirection.issued),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ToggleOption(
            label: AppStrings.received,
            icon: Icons.arrow_downward,
            color: AppColors.received,
            selected: direction == ChequeDirection.received,
            onTap: () => onChanged(ChequeDirection.received),
          ),
        ),
      ],
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : (Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : (Theme.of(context).brightness == Brightness.dark ? AppColors.darkBorder : AppColors.border),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? color : AppColors.textSecondary, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  final ChequeStatus status;
  final Function(ChequeStatus) onChanged;

  const _StatusDropdown({required this.status, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<ChequeStatus>(
      value: status,
      onChanged: (v) => v != null ? onChanged(v) : null,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.info_outline, color: AppColors.textSecondary),
      ),
      items: ChequeStatus.values.map((s) {
        return DropdownMenuItem(value: s, child: Text(_statusLabel(s)));
      }).toList(),
    );
  }

  String _statusLabel(ChequeStatus s) {
    switch (s) {
      case ChequeStatus.draft: return AppStrings.draft;
      case ChequeStatus.active: return AppStrings.active;
      case ChequeStatus.pendingReview: return AppStrings.pendingReview;
      case ChequeStatus.cleared: return AppStrings.cleared;
      case ChequeStatus.returned: return AppStrings.returned;
      case ChequeStatus.cancelled: return AppStrings.cancelled;
    }
  }
}

class _TagsSection extends StatelessWidget {
  final List<String> tags;
  final TextEditingController controller;
  final Function(String) onAdd;
  final Function(String) onRemove;

  const _TagsSection({
    required this.tags,
    required this.controller,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ...tags.map((t) => Chip(
              label: Text(t, style: const TextStyle(fontSize: 12)),
              onDeleted: () => onRemove(t),
              deleteIcon: const Icon(Icons.close, size: 14),
              backgroundColor: AppColors.primary.withOpacity(0.1),
              side: const BorderSide(color: Colors.transparent),
            )),
            ...AppStrings.commonTags
                .where((t) => !tags.contains(t))
                .map((t) => GestureDetector(
              onTap: () => onAdd(t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '+ $t',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            )),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'برچسب دلخواه...',
                  isDense: true,
                ),
                onSubmitted: onAdd,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => onAdd(controller.text),
              icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChequeBookPickerField extends StatelessWidget {
  final List<ChequeBook> books;
  final ChequeBook? selected;
  final ValueChanged<ChequeBook?> onSelected;

  const _ChequeBookPickerField({
    required this.books,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showPicker(context),
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'دسته چک',
          prefixIcon: const Icon(Icons.book_outlined, color: AppColors.textSecondary),
          suffixIcon: selected != null
              ? IconButton(
            icon: const Icon(Icons.clear, size: 18),
            onPressed: () => onSelected(null),
          )
              : const Icon(Icons.arrow_drop_down),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          helperText: selected == null ? 'اختیاری – انتخاب از دسته چک' : null,
        ),
        child: Text(
          selected == null
              ? 'انتخاب دسته چک...'
              : '${selected!.title} • ${selected!.bankName}',
          style: TextStyle(
            fontSize: 14,
            color: selected == null ? AppColors.textHint : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('انتخاب دسته چک',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('فقط دسته چک‌های فعال نمایش داده می‌شوند',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ...books.map((b) => ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.book_outlined, color: AppColors.primary, size: 20),
              ),
              title: Text(b.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${b.bankName} • شعبه ${b.branch}',
                  style: const TextStyle(fontSize: 12)),
              trailing: selected?.id == b.id
                  ? const Icon(Icons.check_circle, color: AppColors.primary)
                  : null,
              onTap: () {
                onSelected(b);
                Navigator.pop(context);
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyBankField extends StatelessWidget {
  final String bankName;
  final String bankId;

  const _ReadOnlyBankField({required this.bankName, required this.bankId});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'بانک',
        prefixIcon: const Icon(Icons.account_balance_outlined, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surfaceVariant,
        helperText: 'از دسته چک انتخاب شده',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      child: Text(
        bankName,
        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
      ),
    );
  }
}
