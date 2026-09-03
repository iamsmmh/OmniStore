import 'package:logging/logging.dart';

class AppLogger {
  AppLogger._();

  static void init() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      // In production, send to crash reporting service
      // ignore: avoid_print
      print(
        '${record.time} [${record.level.name}] ${record.loggerName}: '
        '${record.message}',
      );

      if (record.error != null) {
        // ignore: avoid_print
        print('Error: ${record.error}');
      }

      if (record.stackTrace != null) {
        // ignore: avoid_print
        print('Stack trace: ${record.stackTrace}');
      }
    });
  }

  static Logger getLogger(String name) => Logger(name);
}
