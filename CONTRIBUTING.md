# Contributing to OmniStore

## Ground Rules

* **No mocks as deliverables.** Every provider, DAO, adapter and engine must do real work.
* **No TODOs in `lib/`.** If an abstraction exists without implementation, implement it or delete it.
* **No placeholder screens.** Each route must handle loading, empty, error and ready states with accessibility labels.
* **Codegen-free domain.** `lib/domain` and new `lib/core` engines must compile without `build_runner` (pure Dart, no `part` files). Data models may use Freezed/Isar but provide hand-written `g.dart` stubs or migration path.
* **Tests before merge.** New engines require unit tests (`flutter test`). Target 80%+ on `domain`.

## Setup

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter analyze
```

## Adding a Repository Provider

1. Implement `RepositoryProvider` in `lib/data/datasources/remote/providers/your_provider.dart`:
   * `canHandle(String url)` — host/path heuristic (must not steal generic URLs).
   * `validate(String url)` — fetch with `ApiClient`, return `RepositoryValidationData`.
   * `fetchApps(String url)` — parse metadata, assets, versions, changelogs; handle pagination; tolerate key aliases; validate HTTPS; cache via `ApiClient._getWithCache`.
   * `fetchUpdates(String url, DateTime since)` — filter by `releaseDate`.
2. Register in `RepositoryManagerImpl._registerProviders()`.
3. Add `canHandle` unit test in `test/unit/providers_test.dart`.
4. Document host examples in `README.md`.

## Adding an Installer Adapter

1. Implement `InstallerAdapter` in `lib/infrastructure/installer/adapters/`.
2. `isSupportedOnCurrentPlatform` must gate on `Platform.isIOS`/`isAndroid`.
3. `isAvailable()` must probe `canLaunchUrl(Uri.parse('scheme://'))`.
4. Implement `install`, `update`, `reinstall`, `openApp` — each must validate `filePath.existsSync()` and `supportsFileType`, then `launchUrl` with encoded file URI.
5. Register in `InstallerManager._registerDefaultAdapters()`.
6. Add file-type test in `test/unit/installer_test.dart`.
7. The UI automatically hides unsupported adapters via `getAvailableAdapters()`.

## Engine Guidelines

* Keep engines pure (no `BuildContext`, no I/O, clock injectable).
* Every score returns a justification string for UI and a11y.
* Use `boundedEditDistance` for fuzzy matching, not full Levenshtein.
* Respect offline: never return empty when cached data exists (`offline_cache_policy`).

## Commit & PR

* Branch from `main`, PR into `arena/*` for this sandbox session.
* Use conventional commits (`feat:`, `fix:`, `docs:`).
* Run `dart format .` and `flutter analyze` (0 errors).
* Attach `flutter test --coverage` output.

## Code of Conduct

Be respectful. Do not submit feeds that distribute malware or violate upstream terms. Security issues: open an issue with `security` label; do not include exploit payloads.
