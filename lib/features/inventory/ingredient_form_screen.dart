import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import 'inventory_providers.dart';
import 'widgets/ingredient_formatters.dart';

class IngredientFormScreen extends ConsumerWidget {
  const IngredientFormScreen({this.ingredientId, super.key});

  final int? ingredientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ingredientId;
    if (id == null) {
      return const _IngredientFormScaffold();
    }

    final ingredient = ref.watch(ingredientByIdProvider(id));
    return ingredient.when(
      data: (item) {
        if (item == null) {
          return const Scaffold(
            appBar: _IngredientFormAppBar(title: '編輯食材'),
            body: Center(child: Text('找不到這筆食材')),
          );
        }
        return _IngredientFormScaffold(ingredient: item);
      },
      error: (error, stackTrace) => Scaffold(
        appBar: const _IngredientFormAppBar(title: '編輯食材'),
        body: Center(child: Text('食材讀取失敗：$error')),
      ),
      loading: () => const Scaffold(
        appBar: _IngredientFormAppBar(title: '編輯食材'),
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _IngredientFormScaffold extends ConsumerStatefulWidget {
  const _IngredientFormScaffold({this.ingredient});

  final Ingredient? ingredient;

  @override
  ConsumerState<_IngredientFormScaffold> createState() =>
      _IngredientFormScaffoldState();
}

class _IngredientFormScaffoldState
    extends ConsumerState<_IngredientFormScaffold> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _quantityController;
  late final TextEditingController _unitController;
  late final TextEditingController _locationController;
  late final TextEditingController _lowStockThresholdController;
  DateTime? _expiryDate;
  bool _isSaving = false;

  bool get _isEditing => widget.ingredient != null;

  @override
  void initState() {
    super.initState();
    final ingredient = widget.ingredient;
    _nameController = TextEditingController(text: ingredient?.name);
    _categoryController = TextEditingController(
      text: ingredient?.category ?? '未分類',
    );
    _quantityController = TextEditingController(
      text: ingredient == null ? '' : ingredient.quantity.toString(),
    );
    _unitController = TextEditingController(text: ingredient?.unit ?? '個');
    _locationController = TextEditingController(text: ingredient?.location);
    _lowStockThresholdController = TextEditingController(
      text: ingredient?.lowStockThreshold?.toString() ?? '',
    );
    _expiryDate = ingredient?.expiryDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _locationController.dispose();
    _lowStockThresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _IngredientFormAppBar(title: _isEditing ? '編輯食材' : '新增食材'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '名稱',
                prefixIcon: Icon(Icons.local_dining_outlined),
              ),
              textInputAction: TextInputAction.next,
              validator: _requiredValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: '分類',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              textInputAction: TextInputAction.next,
              validator: _requiredValidator,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _quantityController,
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
                    controller: _unitController,
                    decoration: const InputDecoration(labelText: '單位'),
                    textInputAction: TextInputAction.next,
                    validator: _requiredValidator,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: '位置',
                prefixIcon: Icon(Icons.place_outlined),
                hintText: '冷藏 / 冷凍 / 常溫',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lowStockThresholdController,
              decoration: const InputDecoration(
                labelText: '低庫存門檻',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [_DecimalTextInputFormatter()],
              textInputAction: TextInputAction.done,
              validator: _optionalPositiveNumberValidator,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('到期日'),
              subtitle: Text(
                _expiryDate == null
                    ? '未設定'
                    : formatIngredientDate(_expiryDate!),
              ),
              trailing: Wrap(
                spacing: 8,
                children: [
                  if (_expiryDate != null)
                    IconButton(
                      tooltip: '清除到期日',
                      onPressed: () => setState(() => _expiryDate = null),
                      icon: const Icon(Icons.clear),
                    ),
                  IconButton(
                    tooltip: '選擇到期日',
                    onPressed: _pickExpiryDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                  ),
                ],
              ),
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
            label: Text(_isEditing ? '儲存變更' : '新增食材'),
          ),
        ),
      ),
    );
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null && mounted) {
      setState(() => _expiryDate = picked);
    }
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    final input = IngredientInput(
      name: _nameController.text,
      category: _categoryController.text,
      quantity: double.parse(_quantityController.text),
      unit: _unitController.text,
      expiryDate: _expiryDate,
      lowStockThreshold: _parseOptionalDouble(
        _lowStockThresholdController.text,
      ),
      location: _locationController.text,
    );

    try {
      final repository = ref.read(ingredientRepositoryProvider);
      final ingredient = widget.ingredient;
      if (ingredient == null) {
        await repository.create(input);
      } else {
        await repository.updateExisting(ingredient, input);
      }

      if (mounted) {
        context.pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('食材儲存失敗：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '必填';
    }
    return null;
  }

  String? _positiveNumberValidator(String? value) {
    final parsed = double.tryParse(value ?? '');
    if (parsed == null || parsed <= 0) {
      return '請輸入大於 0 的數字';
    }
    return null;
  }

  String? _optionalPositiveNumberValidator(String? value) {
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

  double? _parseOptionalDouble(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return double.parse(trimmed);
  }
}

class _IngredientFormAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _IngredientFormAppBar({required this.title});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(title: Text(title));
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
