import 'dart:ui';

// ignore_for_file: deprecated_member_use
extension ColorHexHtml on Color {
  String toHex({bool withAlpha = true, bool leadingHashSign = true}) {
    final String r = red.toRadixString(16).padLeft(2, '0');
    final String g = green.toRadixString(16).padLeft(2, '0');
    final String b = blue.toRadixString(16).padLeft(2, '0');
    if (!withAlpha) {
      return '${leadingHashSign ? '#' : ''}$r$g$b';
    }
    final String a = alpha.toRadixString(16).padLeft(2, '0');
    return '${leadingHashSign ? '#' : ''}$r$g$b$a';
  }
}
