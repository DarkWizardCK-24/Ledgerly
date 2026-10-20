/// Money is always stored as integer minor units (paise/cents) — never as double.
const currencies = ['INR', 'USD', 'EUR', 'GBP'];
const _symbols = {'INR': '₹', 'USD': r'$', 'EUR': '€', 'GBP': '£'};

String currencySymbol(String code) => _symbols[code] ?? code;

String _western(String whole) =>
    whole.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

String _indian(String whole) {
  if (whole.length <= 3) return whole;
  final head = whole.substring(0, whole.length - 3);
  final tail = whole.substring(whole.length - 3);
  return '${head.replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (_) => ',')},$tail';
}

String formatMoney(int minor, String currency, {bool signed = false, bool compact = false}) {
  final neg = minor < 0;
  final a = minor.abs();
  final whole = (a ~/ 100).toString();
  final frac = (a % 100).toString().padLeft(2, '0');
  final grouped = currency == 'INR' ? _indian(whole) : _western(whole);
  final body = compact && a % 100 == 0 ? grouped : '$grouped.$frac';
  final s = '${currencySymbol(currency)}$body';
  if (neg) return '-$s';
  return signed ? '+$s' : s;
}

/// Parses user input like "1,250.5" into minor units. Returns null when invalid.
int? parseMinor(String input) {
  final cleaned = input.replaceAll(',', '').trim();
  final m = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(cleaned);
  if (m == null) return null;
  final whole = int.parse(m.group(1)!);
  final frac = int.parse((m.group(2) ?? '0').padRight(2, '0'));
  return whole * 100 + frac;
}
