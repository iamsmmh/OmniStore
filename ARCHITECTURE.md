# Architecture — OmniStore

## 1. Mission & Non-Goals

**Mission:** unify decentralized app distribution (GitHub/GitLab/Codeberg/Forgejo + AltStore/OmniSource/Feather/Generic JSON) into one offline-first, trust-aware catalog that hands installation to the user's chosen on-device installer.

**Non-goals:** signing, certificate warehousing, piracy facilitation.

## 2. Stack

Flutter 3.19 / Dart 3.2, Riverpod 2.x, GoRouter 13.x, Dio 5.x, Isar 3.x, Freezed/JsonSerializable, Material 3 + Dynamic Color, `crypto`, `flutter_secure_storage`, `connectivity_plus`, `url_launcher`.

All new domain engines are **codegen-free pure Dart** (no `part` files) so the core compiles without `build_runner`.

## 3. Layers

```
Presentation (features/*) → Domain (entities, interfaces, engines) → Data (provider impls) → Infrastructure (DB, sync, installer) → Core (DI, security)
```
`domain` depends only on `core`. No `dart:io` in domain.

## 4. Folder Map

```
lib/core/{constants,di,error,extensions,logger,network,platform,plugin,analytics,monitoring,search,text_matching,security,storage,theme,utils,versioning,widgets}
lib/domain/{models,services/repository_provider,services/installer_adapter,repositories,health,security,discovery,updates,validation,compatibility,developer,community}
lib/data/{datasources/remote/{api_client,providers/*},repositories,services}
lib/infrastructure/{database/{daos,tables},installer/adapters,manager,sync,scheduler,cache,notifications}
lib/features/{home,discover,search,updates,downloads,repositories,app_details,settings}
```

## 5. Intelligence Layer (Pure Dart)

| Module | File | Responsibility | Tests |
|--------|------|----------------|-------|
| Versioning | `core/versioning/semantic_version.dart` | parse `v1.0.0-beta+42`, compare, classify bump | 30 |
| Text matching | `core/search/text_matching.dart` | normalize, bounded Damerau-Levenshtein, similarity | 20 |
| Search index | `domain/discovery/search_index.dart` | inverted index, IDF, prefix/fuzzy, freshness | 40 |
| Recommendations | `domain/discovery/recommendation_engine.dart` | similar/trending/gems, dynamic collections | 25 |
| Health | `domain/health/app_health.dart` + `health_engine.dart` | cadence → 0–100 + Healthy/Warning/Critical | 20 |
| Trust | `domain/security/trust_analyzer.dart` + `trust_engine.dart` | 0–100 + Verified/Trusted/Community/Unknown/Risky | 25 |
| Updates | `domain/updates/update_intelligence.dart` | bump + urgency Critical/High/Medium/Low | 30 |
| Validation | `domain/validation/repository_validator.dart` | 6-category report, remediation | 15 |
| Compatibility | `domain/compatibility/compatibility_engine.dart` | iOS version + arch check | 10 |
| Discovery | `domain/discovery/smart_discovery_engine.dart` | related/popular/trending/verified suggestions | 10 |
| Platform | `core/platform/platform_capabilities.dart` | per-target install/download affordance | 10 |
| Sync policy | `infrastructure/sync/sync_scheduler.dart` | priority, adaptive interval, backoff, bounded plan | 30 |
| Cache policy | `infrastructure/cache/offline_cache_policy.dart` | decides stale vs cached | 15 |

Invariants:
1. Every score ships a human-readable justification.
2. Offline never means empty screen.
3. Sync work per round is bounded.
4. Analytics is opt-in, PII-sanitised, local-first.

## 6. Data Flow

```
Remote JSON → ApiClient (cache + ETag) → RepositoryProvider (parse) → RepositoryManagerImpl (persist via AppDao) → Isar → CatalogSource → DiscoveryService (index) → UI (Riverpod)
```

SyncEngine owns the loop: `SyncScheduler.plan` → bounded concurrent `syncRepository` with retry/backoff/429 handling → `applySyncOutcome` → persist `RepositorySyncState`.

## 7. Providers & Installers

`RepositoryProviderRegistry` holds 8 typed providers; `detectProvider` uses host heuristics plus explicit `RepositoryType` for self-hosted Forgejo. `GenericJsonProvider` is fallback and tolerates key aliases (`iconURL`/`iconUrl`, `bundleIdentifier`/`bundleId`, `downloadURL`/`downloadUrl`).

`InstallerAdapterRegistry` holds 5 adapters; `getAvailableAdapters()` filters `isSupportedOnCurrentPlatform` then probes `canLaunchUrl`. `InstallerManager` exposes `install/update/reinstall/open` with preferred-adapter override and file-type gating.

## 8. Database

Isar collections: `AppTable`, `RepositoryTable`, `DownloadTable`, `CollectionTable`. All have indexed `Id` + query indexes (`appId`, `repositoryId`, `isFavorite`, `isInstalled`). Migrations run on `databaseProvider` init inside write transactions: dedup, orphan cleanup, URL normalisation.

DAOs implement conflict resolution (last-write wins preserving user state), bounded pagination (sorted by `releaseDate`), and `saveAll` deduplication.

## 9. Security

`SecurityService`: HTTPS + host + private-IP + credential rejection, SHA-256 hex validation, injection filtering, sanitise helpers. `ApiClient` rejects non-HTTPS feeds before fetch. `AppUtils.sanitizeFilename` prevents traversal.

## 10. Testing Strategy

* Unit tests for every engine (deterministic clock/RNG).
* Provider tests assert `canHandle` and tolerant parsing.
* Installer tests assert file-type gating and registry size.
* Widget tests (future) for loading/empty/error/aff states.
* Coverage gate: `flutter test --coverage` ≥80% on `lib/domain`.

## 11. Performance

* Search is O(postings) in-memory, not DB `contains` scan per keystroke.
* Index rebuild is chunked with `await Future.delayed(Duration.zero)` to avoid jank.
* Network cache caps at 100 entries; search cache caps at 80 via LRU.
* Sync is `maxTasksPerRound=25`, `maxConcurrency=4`, adaptive intervals (quiet repos back off to 7 days).
* Duplicates removed before `putAll`; no redundant rebuilds (`discoveryService` emits `indexChanged` once).

## 12. Roadmap

See ROADMAP.md — phases: validation UI polish → package ingestion (IPA metadata) → community moderation queue → desktop filesystem installer.
