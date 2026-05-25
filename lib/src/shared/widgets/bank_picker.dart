import 'package:flutter/material.dart';
import '../../core/constants/banks_list.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';

class BankPickerField extends StatelessWidget {
  final String? selectedBankId;
  final String? selectedBankName;
  final Function(String id, String name) onSelected;
  final String? errorText;

  const BankPickerField({
    super.key,
    this.selectedBankId,
    this.selectedBankName,
    required this.onSelected,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: errorText != null
                ? AppColors.returned
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.account_balance_outlined,
                color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedBankName ?? AppStrings.bankName,
                style: TextStyle(
                  color: selectedBankName != null
                      ? AppColors.textPrimary
                      : AppColors.textHint,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down,
                color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _BankPickerSheet(),
    );

    if (result != null) {
      onSelected(result['id']!, result['name']!);
    }
  }
}

class _BankPickerSheet extends StatefulWidget {
  const _BankPickerSheet();

  @override
  State<_BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends State<_BankPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<Map<String, String>> _filtered = BanksList.banks;

  void _onSearch(String q) {
    setState(() {
      _filtered = BanksList.search(q);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.75;

    return Container(
      height: maxH,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'انتخاب بانک',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearch,
                  decoration: const InputDecoration(
                    hintText: 'جستجوی بانک...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemBuilder: (ctx, i) {
                final bank = _filtered[i];
                return ListTile(
                  title: Text(bank['name']!),
                  subtitle: Text('کد: ${bank['code']}'),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () => Navigator.pop(ctx, bank),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
