import 'package:flutter/services.dart';

/// Formateador que permite ingresar fechas en formato DD/MM/AAAA mediante teclado,
/// agregando automáticamente las barras separadoras a medida que se escriben los dígitos.
class DateTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    // Si el usuario está borrando caracteres, permitirlo libremente
    if (oldValue.text.length > text.length) {
      return newValue;
    }

    final digits = text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length > 8) {
      return oldValue;
    }

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) {
        buffer.write('/');
      }
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Parsea una cadena DD/MM/AAAA o DD-MM-AAAA a un DateTime válido no futuro.
  static DateTime? parse(String? text) {
    if (text == null) return null;
    final clean = text.replaceAll('-', '/').trim();
    final parts = clean.split('/');
    if (parts.length == 3) {
      final d = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      if (d != null && m != null && y != null &&
          y >= 1900 && y <= DateTime.now().year &&
          m >= 1 && m <= 12 &&
          d >= 1 && d <= 31) {
        try {
          final dt = DateTime(y, m, d);
          if (dt.day == d && dt.month == m && dt.year == y && !dt.isAfter(DateTime.now())) {
            return dt;
          }
        } catch (_) {}
      }
    }
    return null;
  }
}

