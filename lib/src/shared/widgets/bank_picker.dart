import 'package:flutter/material.dart';
import '../../core/constants/banks_list.dart';
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _openPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.inputDecorationTheme.fillColor ?? colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: errorText != null
                ? colorScheme.error
                : (isDark
                ? theme.dividerColor
                : theme.dividerColor),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.account_balance_outlined,
                color: colorScheme.onSurface.withOpacity(0.55), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedBankName ?? AppStrings.bankName,
                style: TextStyle(
                  color: selectedBankName != null
                      ? colorScheme.onSurface
                      : colorScheme.onSurface.withOpacity(0.4),
                  fontSize: 14,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down,
                color: colorScheme.onSurface.withOpacity(0.55)),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxH = MediaQuery.of(context).size.height * 0.75;

    return Container(
      height: maxH,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'انتخاب بانک',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
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
                      color: colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.account_balance_outlined,
                      color: colorScheme.primary,
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
