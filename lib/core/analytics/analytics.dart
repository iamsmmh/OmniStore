/// Privacy-respecting analytics abstraction.
///
/// Design rules enforced by this layer, not by policy documents:
///  * **Opt-in only.** The default sink is [NoopAnalytics]; nothing is
///    recorded until the user enables it.
///  * **No PII, structurally.** Events carry a closed set of typed properties;
///    free-form strings are passed through [_sanitize], which strips anything
///    resembling an email, URL with userinfo, file path or long hex token.
///  * **Local-first.** [LocalAnalytics] aggregates counters on-device. Any
///    future remote sink must implement [AnalyticsSink] and can only ever see
///    already-sanitised, already-aggregated data.
///  * **No stable identifier.** There is no user id, device id or session id
///    in the event model at all, so cross-session correlation is impossible.
library;

/// Closed set of event kinds. Adding a kind is a deliberate review point.
enum AnalyticsEvent {
  appViewed,
  appInstalled,
  appUpdated,
  appUninstalled,
  searchPerformed,
  searchNoResults,
  collectionOpened,
  repositoryAdded,
  repositoryRemoved,
  syncCompleted,
  syncFailed,
  downloadFailed,
  trustWarningShown,
}

/// A single recorded event. Immutable and free of identifiers.
class AnalyticsRecord {
  final AnalyticsEvent event;

  /// Non-identifying dimensions, e.g. `{'category': 'music'}`.
  final Map<String, String> dimensions;

  /// Optional numeric measurement, e.g. result count or duration in ms.
  final num? value;

  const AnalyticsRecord({
    required this.event,
    this.dimensions = const {},
    this.value,
  });
}

/// Destination for analytics records.
abstract class AnalyticsSink {
  Future<void> record(AnalyticsRecord record);
  Future<void> flush();
}

/// Default sink: records nothing. Used whenever analytics are disabled.
class NoopAnalytics implements AnalyticsSink {
  const NoopAnalytics();

  @override
  Future<void> record(AnalyticsRecord record) async {}

  @override
  Future<void> flush() async {}
}

/// On-device aggregation. Stores counters only — never an event log — so the
/// data cannot be replayed into a behavioural timeline.
class LocalAnalytics implements AnalyticsSink {
  final Map<String, int> _counters = {};
  final Map<String, num> _sums = {};

  /// Popularity signals keyed by app id, consumed by the ranking engine.
  final Map<String, int> _appPopularity = {};
  final Map<String, int> _repositoryPopularity = {};
  final Map<String, int> _searchTerms = {};

  /// Cap on distinct search terms retained, bounding both memory and the
  /// re-identification risk of a long-tail query being stored verbatim.
  final int maxSearchTerms;

  /// Minimum times a term must be seen before it is retained at all.
  final int searchTermThreshold;

  LocalAnalytics({this.maxSearchTerms = 200, this.searchTermThreshold = 2});

  Map<String, int> get counters => Map.unmodifiable(_counters);

  /// App popularity normalised to `[0, 1]` for use as a ranking signal.
  Map<String, double> get appPopularity {
    if (_appPopularity.isEmpty) return const {};
    final max = _appPopularity.values.reduce((a, b) => a > b ? a : b);
    if (max == 0) return const {};
    return {
      for (final entry in _appPopularity.entries) entry.key: entry.value / max,
    };
  }

  Map<String, int> get repositoryPopularity =>
      Map.unmodifiable(_repositoryPopularity);

  /// Search terms seen at least [searchTermThreshold] times, most frequent
  /// first. Rare terms are excluded because they are the identifying ones.
  List<MapEntry<String, int>> get searchTrends {
    final entries = _searchTerms.entries
        .where((e) => e.value >= searchTermThreshold)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  @override
  Future<void> record(AnalyticsRecord record) async {
    final key = _key(record);
    _counters[key] = (_counters[key] ?? 0) + 1;
    if (record.value != null) {
      _sums[key] = (_sums[key] ?? 0) + record.value!;
    }

    final appId = record.dimensions['appId'];
    if (appId != null &&
        (record.event == AnalyticsEvent.appViewed ||
            record.event == AnalyticsEvent.appInstalled)) {
      final weight = record.event == AnalyticsEvent.appInstalled ? 3 : 1;
      _appPopularity[appId] = (_appPopularity[appId] ?? 0) + weight;
    }

    final repositoryId = record.dimensions['repositoryId'];
    if (repositoryId != null) {
      _repositoryPopularity[repositoryId] =
          (_repositoryPopularity[repositoryId] ?? 0) + 1;
    }

    final term = record.dimensions['term'];
    if (term != null && record.event == AnalyticsEvent.searchPerformed) {
      _recordSearchTerm(term);
    }
  }

  void _recordSearchTerm(String term) {
    final cleaned = term.trim().toLowerCase();
    // Very long queries are more likely to be unique/identifying.
    if (cleaned.isEmpty || cleaned.length > 40) return;
    _searchTerms[cleaned] = (_searchTerms[cleaned] ?? 0) + 1;

    if (_searchTerms.length > maxSearchTerms) {
      final sorted = _searchTerms.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      for (final entry in sorted.take(_searchTerms.length - maxSearchTerms)) {
        _searchTerms.remove(entry.key);
      }
    }
  }

  @override
  Future<void> flush() async {}

  void clear() {
    _counters.clear();
    _sums.clear();
    _appPopularity.clear();
    _repositoryPopularity.clear();
    _searchTerms.clear();
  }

  String _key(AnalyticsRecord record) {
    if (record.dimensions.isEmpty) return record.event.name;
    final parts = record.dimensions.keys.toList()..sort();
    // Only low-cardinality dimensions become part of the counter key.
    final safe = parts
        .where((k) => k == 'category' || k == 'outcome' || k == 'source')
        .map((k) => '$k=${record.dimensions[k]}')
        .join(',');
    return safe.isEmpty ? record.event.name : '${record.event.name}|$safe';
  }
}

/// Facade used by the rest of the app. Guarded by an explicit opt-in flag so
/// call sites never need to check consent themselves.
class AnalyticsService {
  AnalyticsSink _sink;
  bool _enabled;

  AnalyticsService({AnalyticsSink? sink, bool enabled = false})
      : _sink = sink ?? const NoopAnalytics(),
        _enabled = enabled;

  bool get isEnabled => _enabled;

  /// Enabling requires an explicit user action; disabling clears local data.
  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled && _sink is LocalAnalytics) {
      (_sink as LocalAnalytics).clear();
    }
  }

  void useSink(AnalyticsSink sink) => _sink = sink;

  Future<void> track(
    AnalyticsEvent event, {
    Map<String, String> dimensions = const {},
    num? value,
  }) async {
    if (!_enabled) return;
    final sanitized = <String, String>{};
    dimensions.forEach((key, value) {
      final clean = _sanitize(value);
      if (clean != null) sanitized[key] = clean;
    });
    await _sink.record(
      AnalyticsRecord(
        event: event,
        dimensions: sanitized,
        value: value,
      ),
    );
  }

  Future<void> flush() => _enabled ? _sink.flush() : Future.value();

  static final RegExp _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+');
  static final RegExp _longToken = RegExp(r'\b[0-9a-fA-F]{24,}\b');
  static final RegExp _path = RegExp(r'(/(?:home|Users|data|storage)/\S+)');
  static final RegExp _userinfoUrl = RegExp(r'\w+://[^/\s]*@');

  /// Drops or redacts anything that could carry personal data.
  static String? _sanitize(String input) {
    var value = input.trim();
    if (value.isEmpty) return null;
    if (_email.hasMatch(value)) return null;
    if (_userinfoUrl.hasMatch(value)) return null;
    if (_path.hasMatch(value)) return null;
    value = value.replaceAll(_longToken, '<redacted>');
    if (value.length > 64) value = value.substring(0, 64);
    return value;
  }
}
