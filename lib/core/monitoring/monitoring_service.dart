import 'dart:collection';
import '../logger/app_logger.dart';

enum LogCategory { sync, validation, health, trust, download, error, security }

class DiagnosticEntry {
  final DateTime timestamp;
  final LogCategory category;
  final String message;
  final String? details;
  final String? repositoryId;
  final String? appId;

  DiagnosticEntry({
    required this.timestamp,
    required this.category,
    required this.message,
    this.details,
    this.repositoryId,
    this.appId,
  });
}

/// Central monitoring and diagnostics service.
/// Keeps recent logs in memory for display in Settings Diagnostics screen.
class MonitoringService {
  final _logger = AppLogger.getLogger('MonitoringService');
  final ListQueue<DiagnosticEntry> _entries = ListQueue();
  final int maxEntries;

  MonitoringService({this.maxEntries = 500});

  void log({
    required LogCategory category,
    required String message,
    String? details,
    String? repositoryId,
    String? appId,
  }) {
    final entry = DiagnosticEntry(
      timestamp: DateTime.now(),
      category: category,
      message: message,
      details: details,
      repositoryId: repositoryId,
      appId: appId,
    );
    _entries.addLast(entry);
    if (_entries.length > maxEntries) _entries.removeFirst();
    _logger.info('[${category.name}] $message');
  }

  void logError(Object error, StackTrace? stack, {String? context, LogCategory category = LogCategory.error}) {
    log(category: category, message: context ?? error.toString(), details: stack?.toString());
    _logger.severe(context ?? 'Error', error, stack);
  }

  List<DiagnosticEntry> getEntries({LogCategory? category, int limit = 100}) {
    var list = _entries.toList();
    if (category != null) {
      list = list.where((e) => e.category == category).toList();
    }
    if (list.length > limit) list = list.sublist(list.length - limit);
    return List.unmodifiable(list.reversed);
  }

  List<DiagnosticEntry> get syncLogs => getEntries(category: LogCategory.sync);
  List<DiagnosticEntry> get validationLogs => getEntries(category: LogCategory.validation);
  List<DiagnosticEntry> get healthReports => getEntries(category: LogCategory.health);
  List<DiagnosticEntry> get errorLogs => getEntries(category: LogCategory.error);

  Map<String, int> get countsByCategory {
    final map = <String, int>{};
    for (final e in _entries) {
      map[e.category.name] = (map[e.category.name] ?? 0) + 1;
    }
    return map;
  }

  void clear() => _entries.clear();
}
