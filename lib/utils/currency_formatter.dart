import 'package:intl/intl.dart';
import '../models/currency_model.dart';

class CurrencyFormatter {
  static String format(num amount, [CurrencyModel? currency]) {
    final curr = currency ?? CurrencyModel.defaultCurrency;
    try {
      final formatter = NumberFormat.currency(
        locale: curr.locale.replaceAll('-', '_'),
        symbol: '${curr.symbol} ',
        decimalDigits: 0,
      );
      return formatter.format(amount);
    } catch (_) {
      final formatter = NumberFormat.currency(
        symbol: '${curr.symbol} ',
        decimalDigits: 0,
      );
      return formatter.format(amount);
    }
  }

  static String formatNumber(num amount) {
    final formatter = NumberFormat('#,###', 'id_ID');
    return formatter.format(amount);
  }

  static int unformat(String text) {
    if (text.isEmpty) return 0;
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }
}
