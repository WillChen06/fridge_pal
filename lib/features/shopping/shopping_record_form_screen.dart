import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../inventory/inventory_providers.dart';
import 'shopping_providers.dart';
import 'widgets/shopping_formatters.dart';

class ShoppingRecordFormScreen extends ConsumerStatefulWidget {
  const ShoppingRecordFormScreen({super.key});

  @override
  ConsumerState<ShoppingRecordFormScreen> createState() =>
      _ShoppingRecordFormScreenState();
}

class _ShoppingRecordFormScreenState
    extends ConsumerState<ShoppingRecordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  final _itemScrollController = ScrollController();
  final _items = <_ShoppingItemDraft>[];
  DateTime _date = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _addItem();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _itemScrollController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ingredients = ref.watch(ingredientListProvider);
    final inventory = ingredients.valueOrNull ?? const <Ingredient>[];

    return Scaffold(
      appBar: AppBar(title: const Text('新增買菜紀錄')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('日期'),
              subtitle: Text(formatShoppingDate(_date)),
              trailing: IconButton(
                tooltip: '選擇日期',
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '備註',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text('品項', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addItemAndScroll,
                  icon: const Icon(Icons.add),
                  label: const Text('加品項'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth
                    .clamp(280.0, 340.0)
                    .toDouble();

                return SingleChildScrollView(
                  controller: _itemScrollController,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < _items.length; i++) ...[
                        SizedBox(
                          width: cardWidth,
                          child: _ShoppingItemFields(
                            key: ValueKey(_items[i]),
                            index: i,
                            item: _items[i],
                            canRemove: _items.length > 1,
                            inventory: inventory,
                            onChanged: () =>
                                _applyIngredientMatch(i, inventory),
                            onRemove: () => _removeItem(i),
                          ),
                        ),
                        if (i != _items.length - 1) const SizedBox(width: 12),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('儲存紀錄'),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 5),
      lastDate: DateTime(_date.year + 1),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  void _addItem() {
    _items.add(_ShoppingItemDraft());
  }

  void _addItemAndScroll() {
    setState(_addItem);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_itemScrollController.hasClients) {
        return;
      }
      _itemScrollController.animateTo(
        _itemScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index).dispose();
    });
  }

  void _applyIngredientMatch(int index, List<Ingredient> inventory) {
    final item = _items[index];
    final match = _findIngredient(item.nameController.text, inventory);
    if (match?.id == item.matchedIngredientId) {
      return;
    }
    setState(() {
      item.matchedIngredientId = match?.id;
      item.matchedIngredientName = match?.name;
      if (match != null) {
        item.unitController.text = match.unit;
      }
    });
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    final input = ShoppingRecordInput(
      date: _date,
      note: _noteController.text,
      items: [
        for (final item in _items)
          ShoppingItemInput(
            name: item.nameController.text,
            quantity: double.parse(item.quantityController.text),
            unit: item.unitController.text,
            cost: _parseOptionalDouble(item.costController.text),
          ),
      ],
    );

    try {
      await ref.read(shoppingRepositoryProvider).createRecord(input);
      if (mounted) {
        context.pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('買菜紀錄儲存失敗：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Ingredient? _findIngredient(String name, List<Ingredient> inventory) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    for (final ingredient in inventory) {
      if (ingredient.name.trim().toLowerCase() == normalized) {
        return ingredient;
      }
    }
    return null;
  }

  double? _parseOptionalDouble(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return double.parse(trimmed);
  }
}

class _ShoppingItemFields extends StatelessWidget {
  const _ShoppingItemFields({
    required this.index,
    required this.item,
    required this.canRemove,
    required this.inventory,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final int index;
  final _ShoppingItemDraft item;
  final bool canRemove;
  final List<Ingredient> inventory;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('品項 ${index + 1}'),
                const Spacer(),
                Visibility(
                  visible: canRemove,
                  maintainAnimation: true,
                  maintainSize: true,
                  maintainState: true,
                  child: IconButton(
                    tooltip: '移除品項',
                    onPressed: onRemove,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ),
              ],
            ),
            TextFormField(
              key: ValueKey('shopping-item-name-$index'),
              controller: item.nameController,
              decoration: const InputDecoration(
                labelText: '名稱',
                prefixIcon: Icon(Icons.local_dining_outlined),
              ),
              textInputAction: TextInputAction.next,
              onChanged: (_) => onChanged(),
              validator: _requiredValidator,
            ),
            if (item.matchedIngredientName != null) ...[
              const SizedBox(height: 8),
              InputChip(
                avatar: const Icon(Icons.link, size: 18),
                label: Text('已連結 ${item.matchedIngredientName}'),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: ValueKey('shopping-item-quantity-$index'),
                    controller: item.quantityController,
                    decoration: const InputDecoration(
                      labelText: '數量',
                      prefixIcon: Icon(Icons.scale_outlined),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: const [_DecimalTextInputFormatter()],
                    textInputAction: TextInputAction.next,
                    validator: _positiveNumberValidator,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('shopping-item-unit-$index'),
                    controller: item.unitController,
                    decoration: const InputDecoration(labelText: '單位'),
                    textInputAction: TextInputAction.next,
                    validator: _requiredValidator,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey('shopping-item-cost-$index'),
              controller: item.costController,
              decoration: const InputDecoration(
                labelText: '金額',
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [_DecimalTextInputFormatter()],
              textInputAction: TextInputAction.done,
              validator: _optionalPositiveNumberValidator,
            ),
          ],
        ),
      ),
    );
  }

  static String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '必填';
    }
    return null;
  }

  static String? _positiveNumberValidator(String? value) {
    final parsed = double.tryParse(value ?? '');
    if (parsed == null || parsed <= 0) {
      return '請輸入大於 0 的數字';
    }
    return null;
  }

  static String? _optionalPositiveNumberValidator(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null || parsed <= 0) {
      return '請輸入大於 0 的數字';
    }
    return null;
  }
}

class _ShoppingItemDraft {
  final nameController = TextEditingController();
  final quantityController = TextEditingController();
  final unitController = TextEditingController(text: '個');
  final costController = TextEditingController();
  int? matchedIngredientId;
  String? matchedIngredientName;

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    unitController.dispose();
    costController.dispose();
  }
}

class _DecimalTextInputFormatter extends TextInputFormatter {
  const _DecimalTextInputFormatter();

  static final RegExp _validPattern = RegExp(r'^\d*\.?\d*$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (_validPattern.hasMatch(newValue.text)) {
      return newValue;
    }
    return oldValue;
  }
}
