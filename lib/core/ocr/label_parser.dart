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
  final lines = rawText
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .toList();

  for (var i = 0; i < lines.length; i += 1) {
    final trimmed = lines[i];
    final match = _productNamePattern.firstMatch(trimmed);
    if (match == null) {
      continue;
    }

    final sameLineName = _cleanProductName(match.group(1) ?? '');
    if (sameLineName != null) {
      return sameLineName;
    }

    if (i + 1 < lines.length) {
      final nextLineName = _cleanProductName(lines[i + 1]);
      if (nextLineName != null) {
        return nextLineName;
      }
    }
  }

  for (final trimmed in lines) {
    if (trimmed.isNotEmpty && trimmed.length < 30) {
      return trimmed;
    }
  }
  return null;
}

final RegExp _productNamePattern = RegExp(r'^品\s*名\s*[:：]?\s*(.*)$');

final RegExp _nextFieldPattern = RegExp(
  r'\s+(?:原\s*料|內\s*容\s*量|有效日期|保存期限|保存期間|保存條件)\s*[:：]',
);

String? _cleanProductName(String value) {
  final fieldStart = _nextFieldPattern.firstMatch(value);
  final name =
      (fieldStart == null ? value : value.substring(0, fieldStart.start))
          .trim();
  if (name.isEmpty) {
    return null;
  }
  return name;
}

String _normalizeUnit(String unit) {
  return unit.toLowerCase() == 'l' ? 'L' : unit;
}
