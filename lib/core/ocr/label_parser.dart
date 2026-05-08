class ParsedLabel {
  const ParsedLabel({
    required this.rawText,
    this.productName,
    this.expiryDate,
    this.quantity,
    this.unit,
  });

  final String? productName;
  final DateTime? expiryDate;
  final double? quantity;
  final String? unit;
  final String rawText;
}

ParsedLabel parseLabel(String rawText) {
  final expiryDate = _parseExpiryDate(rawText);
  final quantityMatch = _quantityPattern.firstMatch(rawText);
  final quantity = quantityMatch == null
      ? null
      : double.tryParse(quantityMatch.group(1)!);
  final unit = quantityMatch == null
      ? null
      : _normalizeUnit(quantityMatch.group(2)!);

  return ParsedLabel(
    productName: _parseProductName(rawText),
    expiryDate: expiryDate,
    quantity: quantity,
    unit: unit,
    rawText: rawText,
  );
}

final RegExp _datePattern = RegExp(
  r'(?:保存期限|有效日期|賞味期限|Best\s*before)?\s*'
  r'(\d{4})\s*(?:[./-]|年)\s*(\d{1,2})\s*(?:[./-]|月)\s*(\d{1,2})\s*(?:日)?',
  caseSensitive: false,
);

final RegExp _quantityPattern = RegExp(
  r'(\d+(?:\.\d+)?)\s*(kg|g|ml|L|公克|毫升|公斤|公升|包|個|入)',
  caseSensitive: false,
);

DateTime? _parseExpiryDate(String rawText) {
  final match = _datePattern.firstMatch(rawText);
  if (match == null) {
    return null;
  }

  final year = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final day = int.tryParse(match.group(3)!);
  if (year == null || month == null || day == null) {
    return null;
  }

  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}

String? _parseProductName(String rawText) {
  for (final line in rawText.split(RegExp(r'\r?\n'))) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty && trimmed.length < 30) {
      return trimmed;
    }
  }
  return null;
}

String _normalizeUnit(String unit) {
  return unit.toLowerCase() == 'l' ? 'L' : unit;
}
