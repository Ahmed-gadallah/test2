import 'package:intl/intl.dart';

/// Locale-aware formatting (spec §4.3).
/// Assumption (documented in README): Western digits (0-9) are used in both
/// languages, matching Saudi retail receipts. Change [_latin] to switch.
class Fmt {
  final String lang;
  const Fmt(this.lang);
  bool get ar => lang == 'ar';

  static String _latin(String s) => s.replaceAllMapped(RegExp('[٠-٩]'), (m) => '${m[0]!.codeUnitAt(0) - 0x0660}');

  String number(num n) => NumberFormat.decimalPattern('en').format(n);
  String signed(int n) => n > 0 ? '+${number(n)}' : number(n);

  String sar(num amount) {
    final v = NumberFormat.currency(locale: 'en', symbol: '', decimalDigits: amount % 1 == 0 ? 0 : 2).format(amount).trim();
    return ar ? '$v ر.س' : 'SAR $v';
  }

  String date(DateTime d) => _latin(DateFormat('d MMM yyyy', lang).format(d));
  String dateTime(DateTime d) => _latin(DateFormat('d MMM yyyy · h:mm a', lang).format(d));
  String time(DateTime d) => _latin(DateFormat('h:mm a', lang).format(d));

  /// Displays a mobile number in local form: +966500000001 → 050 000 0001
  String mobile(String e164) {
    final n = e164.startsWith('+966') ? '0${e164.substring(4)}' : e164;
    return n.length == 10 ? '${n.substring(0, 3)} ${n.substring(3, 6)} ${n.substring(6)}' : n;
  }

  String countdown(Duration d) {
    final s = d.isNegative ? 0 : d.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }
}
