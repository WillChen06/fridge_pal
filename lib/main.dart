import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  try {
    await container.read(notificationServiceProvider).init();
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'notifications',
        context: ErrorDescription('while initializing notifications'),
      ),
    );
  }
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const FridgePalApp(),
    ),
  );
}
