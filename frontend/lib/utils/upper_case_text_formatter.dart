import 'package:flutter/services.dart';

/// Formateador que convierte todo el texto ingresado a mayúsculas en tiempo real.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    return newValue.copyWith(
      text: upper,
      selection: TextSelection.collapsed(offset: upper.length),
    );
  }
}
