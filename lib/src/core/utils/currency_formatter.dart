class CurrencyFormatter {
  CurrencyFormatter._();

  static String _toPersianDigits(String s) {
    const digits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    return s.split('').map((c) {
      final i = int.tryParse(c);
      return i != null ? digits[i] : c;
    }).join();
  }

  static String _formatWithCommas(int amount) {
    final s = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(s[i]);
    }
    return _toPersianDigits(buffer.toString());
  }

  static String format(double amount) {
    return '${_formatWithCommas(amount.round())} تومان';
  }

  static String formatCompact(double amount) {
    if (amount >= 1000000000) {
      final v = (amount / 1000000000);
      final s = v == v.roundToDouble()
          ? v.toStringAsFixed(0)
          : v.toStringAsFixed(1);
      return '${_toPersianDigits(s)} میلیارد تومان';
    } else if (amount >= 1000000) {
      final v = (amount / 1000000);
      final s = v == v.roundToDouble()
          ? v.toStringAsFixed(0)
          : v.toStringAsFixed(1);
      return '${_toPersianDigits(s)} میلیون تومان';
    } else if (amount >= 1000) {
      return '${_toPersianDigits((amount / 1000).toStringAsFixed(0))} هزار تومان';
    }
    return format(amount);
  }

  static String formatNumber(double amount) {
    return _formatWithCommas(amount.round());
  }

  static double? parse(String text) {
    // Convert Persian digits to ASCII before parsing
    const farsi = '۰۱۲۳۴۵۶۷۸۹';
    final converted = text.split('').map((c) {
      final idx = farsi.indexOf(c);
      return idx >= 0 ? idx.toString() : c;
    }).join();
    final cleaned = converted.replaceAll(',', '').trim();
    return double.tryParse(cleaned);
  }
}
