String formatIngredientAmount(double quantity, String unit) {
  final rounded = quantity.roundToDouble();
  final value = quantity == rounded
      ? rounded.toInt().toString()
      : quantity.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  return '$value $unit';
}

String formatIngredientDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
