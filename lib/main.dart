import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'app/app.dart';
import 'core/di/providers.dart';
import 'core/logger/app_logger.dart';
import 'infrastructure/database/database_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize structured logging
  AppLogger.init();

  final logger = Logger('OmniStore');
  logger.info('Starting OmniStore application...');

  // Create the provider container for pre-app initialization
  final container = ProviderContainer();

  try {
    // Initialize the database
    await container.read(databaseProvider.future);

    logger.info('Database initialized successfully');

    // Initialize notification service
    final notificationService = container.read(notificationServiceProvider);
    await notificationService.initialize();

    logger.info('Notification service initialized');

    // Initialize sync engine
    final syncEngine = container.read(syncEngineProvider);
    await syncEngine.initialize();

    logger.info('Sync engine initialized');

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const OmniStoreApp(),
      ),
    );
  } catch (e, stack) {
    logger.severe('Failed to initialize application', e, stack);
    rethrow;
  }
}
