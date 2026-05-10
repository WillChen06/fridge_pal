import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_pal/core/ocr/label_parser.dart';

void main() {
  group('parseLabel', () {
    test('parses slash expiry date', () {
      final label = parseLabel('鮮乳\n保存期限 2026/05/30');

      expect(label.productName, '鮮乳');
      expect(label.expiryDate, DateTime(2026, 5, 30));
    });

    test('parses dashed expiry date', () {
      final label = parseLabel('優格\n有效日期：2026-06-01');

      expect(label.expiryDate, DateTime(2026, 6, 1));
    });

    test('parses Chinese expiry date', () {
      final label = parseLabel('豆腐\n賞味期限 2026年7月2日');

      expect(label.expiryDate, DateTime(2026, 7, 2));
    });

    test('prefers product name label over first OCR line fallback', () {
      final label = parseLabel(
        '營養標示\n'
        '品 名：統一陽光 陽光黃金豆無加糖豆漿\n'
        '原 料：水、非基因改造黃豆、食鹽\n'
        '內容量：1858毫升',
      );

      expect(label.productName, '統一陽光 陽光黃金豆無加糖豆漿');
    });

    test('parses product name when OCR splits name onto next line', () {
      final label = parseLabel(
        '品 名：\n'
        '統一陽光 陽光黃金豆無加糖豆漿\n'
        '保存期間：13天',
      );

      expect(label.productName, '統一陽光 陽光黃金豆無加糖豆漿');
    });

    test('parses weight quantity', () {
      final label = parseLabel('冷凍水餃\n900 g');

      expect(label.quantity, 900);
      expect(label.unit, 'g');
    });

    test('parses volume quantity', () {
      final label = parseLabel('燕麥奶\n1.5 L');

      expect(label.quantity, 1.5);
      expect(label.unit, 'L');
    });

    test('falls back to first short non-empty line as product name', () {
      final label = parseLabel('\n  黑芝麻醬  \n沒有日期也沒有容量');

      expect(label.productName, '黑芝麻醬');
      expect(label.expiryDate, isNull);
      expect(label.quantity, isNull);
      expect(label.unit, isNull);
    });

    test('returns empty parsed fields for empty or noisy text', () {
      final emptyLabel = parseLabel('');
      final noisyLabel = parseLabel('這是一段超過三十個字而且沒有明確商品名的辨識雜訊文字應該略過');

      expect(emptyLabel.productName, isNull);
      expect(emptyLabel.expiryDate, isNull);
      expect(emptyLabel.quantity, isNull);
      expect(emptyLabel.unit, isNull);
      expect(noisyLabel.productName, isNull);
      expect(noisyLabel.expiryDate, isNull);
      expect(noisyLabel.quantity, isNull);
      expect(noisyLabel.unit, isNull);
    });
  });
}
