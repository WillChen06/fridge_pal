import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/ocr/label_parser.dart';
import '../../core/ocr/ocr_service.dart';
import '../inventory/widgets/ingredient_formatters.dart';

final imagePickerProvider = Provider<ImagePicker>((ref) => ImagePicker());

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  ParsedLabel? _parsedLabel;
  String? _errorMessage;
  bool _isRecognizing = false;

  @override
  Widget build(BuildContext context) {
    final parsedLabel = _parsedLabel;
    return Scaffold(
      appBar: AppBar(title: const Text('掃描標籤')),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: parsedLabel == null
            ? _ScanActions(
                isRecognizing: _isRecognizing,
                errorMessage: _errorMessage,
                onPickCamera: () => _pickAndRecognize(ImageSource.camera),
                onPickGallery: () => _pickAndRecognize(ImageSource.gallery),
              )
            : _ScanResult(
                parsedLabel: parsedLabel,
                onRetake: () => setState(() {
                  _parsedLabel = null;
                  _errorMessage = null;
                }),
              ),
      ),
    );
  }

  Future<void> _pickAndRecognize(ImageSource source) async {
    try {
      final picker = ref.read(imagePickerProvider);
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile == null) {
        return;
      }
      if (!mounted) {
        return;
      }

      setState(() {
        _isRecognizing = true;
        _errorMessage = null;
      });

      final rawText = await ref
          .read(ocrServiceProvider)
          .recognize(File(pickedFile.path));
      final parsedLabel = parseLabel(rawText);
      if (!mounted) {
        return;
      }
      setState(() {
        _parsedLabel = parsedLabel;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '辨識失敗：$error';
      });
    } finally {
      if (mounted) {
        setState(() => _isRecognizing = false);
      }
    }
  }
}

class _ScanActions extends StatelessWidget {
  const _ScanActions({
    required this.isRecognizing,
    required this.onPickCamera,
    required this.onPickGallery,
    this.errorMessage,
  });

  final bool isRecognizing;
  final String? errorMessage;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ScanActionButton(
                label: '📷 拍照',
                icon: Icons.photo_camera_outlined,
                onPressed: isRecognizing ? null : onPickCamera,
              ),
              const SizedBox(height: 16),
              _ScanActionButton(
                label: '🖼️ 從相簿選',
                icon: Icons.photo_library_outlined,
                onPressed: isRecognizing ? null : onPickGallery,
              ),
              if (isRecognizing) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],
              if (errorMessage != null) ...[
                const SizedBox(height: 24),
                Text(
                  errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanActionButton extends StatelessWidget {
  const _ScanActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        textStyle: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class _ScanResult extends StatelessWidget {
  const _ScanResult({required this.parsedLabel, required this.onRetake});

  final ParsedLabel parsedLabel;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('scan-result'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _ResultTile(
          icon: Icons.local_dining_outlined,
          title: '商品名',
          value: parsedLabel.productName ?? '未辨識',
        ),
        _ResultTile(
          icon: Icons.event_outlined,
          title: '期限',
          value: parsedLabel.expiryDate == null
              ? '未辨識'
              : formatIngredientDate(parsedLabel.expiryDate!),
        ),
        _ResultTile(
          icon: Icons.scale_outlined,
          title: '容量',
          value: _formatQuantity(parsedLabel),
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 12),
          title: const Text('原始 OCR 文字'),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                parsedLabel.rawText.trim().isEmpty
                    ? '未辨識'
                    : parsedLabel.rawText.trim(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: onRetake,
          icon: const Icon(Icons.refresh),
          label: const Text('重拍'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => context.push('/inventory/new', extra: parsedLabel),
          icon: const Icon(Icons.check),
          label: const Text('使用此資訊建立食材'),
        ),
      ],
    );
  }

  String _formatQuantity(ParsedLabel label) {
    final quantity = label.quantity;
    final unit = label.unit;
    if (quantity == null || unit == null) {
      return '未辨識';
    }
    final quantityText = quantity == quantity.truncateToDouble()
        ? quantity.toInt().toString()
        : quantity.toString();
    return '$quantityText $unit';
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value),
    );
  }
}
