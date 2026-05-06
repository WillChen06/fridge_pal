import 'package:intl/intl.dart';

final DateFormat _shoppingDateFormat = DateFormat('yyyy-MM-dd');
final NumberFormat _shoppingCostFormat = NumberFormat.currency(
  locale: 'zh_TW',
  symbol: r'$',
);

String formatShoppingDate(DateTime date) => _shoppingDateFormat.format(date);

String formatShoppingCost(double cost) => _shoppingCostFormat.format(cost);

String formatShoppingQuantity(double quantity, String unit) {
  final rounded = quantity.roundToDouble();
  final value = quantity == rounded
      ? rounded.toInt().toString()
      : quantity.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  return '$value $unit';
}
