import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:fridge_pal/app.dart';
import 'package:fridge_pal/core/db/database.dart';
import 'package:fridge_pal/core/db/database_provider.dart';
import 'package:fridge_pal/core/ocr/ocr_service.dart';
import 'package:fridge_pal/features/scan/scan_screen.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  testWidgets('scan page shows camera and gallery actions', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const FridgePalApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('掃描'));
    await tester.pumpAndSettle();

    expect(find.text('📷 拍照'), findsOneWidget);
    expect(find.text('🖼️ 從相簿選'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('scan result routes parsed label into ingredient form', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    final imagePicker = _FakeImagePicker();
    const ocrService = _FakeOcrService(
      rawText: '愛文芒果\n保存期限 2026/05/30\n600 公克',
    );
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          imagePickerProvider.overrideWithValue(imagePicker),
          ocrServiceProvider.overrideWithValue(ocrService),
        ],
        child: const FridgePalApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('掃描'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🖼️ 從相簿選'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(imagePicker.lastSource, ImageSource.gallery);
    expect(find.text('愛文芒果'), findsOneWidget);
    expect(find.text('2026-05-30'), findsOneWidget);
    expect(find.text('600 公克'), findsOneWidget);

    await tester.tap(find.text('使用此資訊建立食材'));
    await tester.pumpAndSettle();

    expect(find.text('新增食材'), findsWidgets);
    expect(find.text('愛文芒果'), findsOneWidget);
    expect(find.text('600'), findsOneWidget);
    expect(find.text('公克'), findsOneWidget);
    expect(find.text('2026-05-30'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });
}

class _FakeImagePicker extends ImagePicker {
  ImageSource? lastSource;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    lastSource = source;
    return XFile('/tmp/fridge_pal_ocr_test.jpg');
  }
}

class _FakeOcrService implements OcrService {
  const _FakeOcrService({required this.rawText});

  final String rawText;

  @override
  Future<void> dispose() async {}

  @override
  Future<String> recognize(File imageFile) async => rawText;
}
