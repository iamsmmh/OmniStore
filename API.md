# API Reference — OmniStore

## RepositoryProvider

```dart
abstract class RepositoryProvider {
  RepositoryType get type;
  Future<RepositoryValidationData> validate(String url);
  Future<List<AppEntity>> fetchApps(String url);
  Future<List<AppEntity>> fetchUpdates(String url, DateTime since);
  bool canHandle(String url);
}
```

`ApiClient` wraps Dio with TTL cache (30 min), ETag 304 handling, bounded size (100) and retry interceptor.

## InstallerAdapter

```dart
abstract class InstallerAdapter {
  String get id, name, version;
  Future<bool> isAvailable();
  bool get isSupportedOnCurrentPlatform;
  bool supportsFileType(String ext);
  Future<InstallResult> install({required String filePath, required String bundleId, Map? metadata});
  Future<InstallResult> update({required String filePath, required String bundleId, required String currentVersion});
  Future<InstallResult> reinstall({required String filePath, required String bundleId});
  Future<bool> openApp(String bundleId);
}
```

`InstallerManager` resolves best adapter for file extension, prefers `preferredAdapter`, and proxies `openApp`.

## Validation Engine

```dart
final validator = RepositoryValidator(securityService: SecurityService(), registry: registry);
ValidationReport report = await validator.validate('https://example.com/feed.json');
report.score // 0–100
report.isValid // false if any error
report.issues // ValidationIssue{ code, message, severity, remediation }
```

Checks: URL format, HTTPS, feed structure, metadata completeness, icon availability, download HTTPS, version sanity, checksum presence.

## Health & Trust

```dart
HealthScore h = HealthEngine().evaluate(appId: 'x', releaseDates: [...]);
h.score // 0–100
h.status // healthy/warning/critical + detailed HealthReport

TrustScore t = TrustEngine().evaluate(RepositoryTrustInput(repositoryId: 'r', url: 'https://...', checksumCoverage: 0.9, ...));
t.score // 0–100
t.category // verified/trusted/community/unknown/risky
```

## Search & Discovery

```dart
// Index
final index = SearchIndex();
index.rebuild(documents);
List<SearchHit> hits = index.search('vlc', filter: SearchFilter(category: 'music'), limit: 25);
List<String> sugg = index.suggest('phot');
String? corrected = index.correct('gogle');

// Facade
final discovery = DiscoveryService(source: catalogSource, analytics: analytics);
await discovery.warmUp();
List<SearchHit> hits = discovery.search('code');
List<Recommendation> recs = discovery.recommendationsFor(UserSignals(installedAppIds: {...}));
```

## Update Intelligence

```dart
const intel = UpdateIntelligence();
UpdateVerdict v = intel.analyze(ReleaseCandidate(installedVersion: '1.2.3', latestVersion: '1.3.0', changelog: '…'));
v.urgency // critical/important/routine/optional → map to Critical/High/Medium/Low in UI
v.bumpType // major/minor/patch/prerelease/build
v.summary // human readable
```

## Sync

```dart
final scheduler = SyncScheduler();
List<SyncTask> tasks = scheduler.plan(states, now: DateTime.now(), forced: {'repoId'});
Duration backoff = scheduler.backoffFor(3);
RepositorySyncState next = applySyncOutcome(state, SyncOutcome.updated, now: now, etag: '…');
```

`SyncEngine.syncAll()` does bounded concurrent execution with offline check, retry, 429 backoff, incremental via ETag.

## Compatibility

```dart
const compat = CompatibilityEngine();
CompatibilityReport r = compat.checkCompatibility(appId: 'x', appMinOsVersion: '17.0', deviceOsVersion: '16.4');
r.status // compatible/warning/incompatible/unknown
r.message
```

## Monitoring

```dart
final monitoring = MonitoringService();
monitoring.log(category: LogCategory.sync, message: '…');
List<DiagnosticEntry> logs = monitoring.getEntries(category: LogCategory.validation, limit: 50);
```
