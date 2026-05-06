import 'package:intl/intl.dart';

final DateFormat _ingredientDateFormat = DateFormat('yyyy-MM-dd');

String formatIngredientAmount(double quantity, String unit) {
  final rounded = quantity.roundToDouble();
  final value = quantity == rounded
      ? rounded.toInt().toString()
      : quantity.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  return '$value $unit';
}

String formatIngredientDate(DateTime date) {
  return _ingredientDateFormat.format(date);
}
