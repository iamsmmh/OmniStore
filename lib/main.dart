import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'app/app.dart';
import 'core/di/providers.dart';
import 'core/logger/app_logger.dart';
import 'infrastructure/database/database_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppLogger.init();
  final logger = Logger('OmniStore');
  logger.info('Starting OmniStore application...');

  final container = ProviderContainer();

  try {
    await container.read(databaseProvider.future);
    logger.info('Database initialized successfully');

    final notificationService = container.read(notificationServiceProvider);
    try {
      await notificationService.initialize();
      logger.info('Notification service initialized');
    } catch (e) {
      logger.warning('Notification service init failed: $e');
    }

    final syncEngine = container.read(syncEngineProvider);
    await syncEngine.initialize();
    logger.info('Sync engine initialized');

    // Warm up discovery index in background
    try {
      final discovery = container.read(discoveryServiceProvider);
      // Don't block startup on index build
      discovery.warmUp().then((_) => logger.info('Discovery index warmed'));
    } catch (e) {
      logger.warning('Discovery warmup failed: $e');
    }

    // Start periodic sync with 6-hour interval (respects offline handling)
    try {
      syncEngine.startPeriodicSync(const Duration(hours: 6));
    } catch (e) {
      logger.warning('Periodic sync start failed: $e');
    }

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const OmniStoreApp(),
      ),
    );
  } catch (e, stack) {
    logger.severe('Failed to initialize application', e, stack);
    // Show error UI instead of crashing
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Failed to start OmniStore', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(e.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                const Text('Try restarting the app. If the problem persists, clear app data.'),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
