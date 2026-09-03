# OmniStore - Architecture Blueprint

## 1. Overview

OmniStore is a production-grade, repository-driven application manager for iOS and Android. Built with Flutter 3 and Dart 3, it implements Clean Architecture with feature-first organization.

**Mission:** Help users discover, track, download, and manage applications distributed through trusted repositories.

**Not:** An app signer, enterprise certificate platform, or piracy tool.

---

## 2. Technology Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.19+ / Dart 3.2+ |
| State Management | Riverpod 2.x |
| Navigation | GoRouter 13.x |
| Networking | Dio 5.x |
| Serialization | Freezed + JsonSerializable |
| Database | Isar 3.x |
| Theming | Material 3 + Dynamic Color |
| Notifications | flutter_local_notifications 17.x |
| Security | crypto + flutter_secure_storage |
| Background | workmanager |

---

## 3. Architecture Layers

```
┌─────────────────────────────────────────────┐
│              Presentation                    │
│  (Pages, Widgets, Providers, State)         │
├─────────────────────────────────────────────┤
│              Domain                          │
│  (Entities, Repository Interfaces,          │
│   Service Interfaces, Use Cases)            │
├─────────────────────────────────────────────┤
│              Data                            │
│  (Repository Implementations,               │
│   Remote Data Sources, Providers)           │
├─────────────────────────────────────────────┤
│              Infrastructure                  │
│  (Database, Notifications, Sync Engine,     │
│   Installer Manager, Storage)               │
├─────────────────────────────────────────────┤
│              Core                            │
│  (Constants, DI, Error, Extensions,         │
│   Logger, Network, Security, Theme,         │
│   Utils, Widgets, Plugin System)            │
└─────────────────────────────────────────────┘
```

---

## 4. Folder Structure

```
lib/
├── main.dart                          # App entry point
├── app/
│   └── app.dart                       # Root widget
├── core/
│   ├── constants/
│   │   └── app_constants.dart         # App-wide constants
│   ├── di/
│   │   ├── providers.dart             # DI container providers
│   │   └── router_provider.dart       # GoRouter configuration
│   ├── error/
│   │   ├── failures.dart              # Typed failure classes
│   │   └── exceptions.dart            # Custom exceptions
│   ├── extensions/
│   │   └── extensions.dart            # Dart extensions
│   ├── logger/
│   │   └── app_logger.dart            # Structured logging
│   ├── network/
│   │   └── http_client.dart           # Dio HTTP wrapper
│   ├── plugin/
│   │   └── plugin_system.dart         # Plugin architecture
│   ├── security/
│   │   └── security_service.dart      # SHA256, URL validation
│   ├── storage/
│   │   └── secure_storage.dart        # Secure key-value store
│   ├── theme/
│   │   └── app_theme.dart             # Material 3 theme
│   ├── utils/
│   │   └── app_utils.dart             # Utility functions
│   └── widgets/
│       └── common_widgets.dart        # Shared widgets
├── domain/
│   ├── models/
│   │   ├── app_entity.dart
│   │   ├── repository_entity.dart
│   │   ├── release_entity.dart
│   │   ├── download_entity.dart
│   │   ├── update_entity.dart
│   │   ├── collection_entity.dart
│   │   └── discover_entity.dart
│   ├── repositories/
│   │   ├── app_repository.dart        # Interface
│   │   ├── repository_manager.dart    # Interface
│   │   └── download_repository.dart   # Interface
│   └── services/
│       ├── repository_provider.dart   # Plugin interface
│       └── installer_adapter.dart     # Plugin interface
├── data/
│   ├── datasources/
│   │   ├── local/                     # Local data sources
│   │   └── remote/
│   │       ├── api_client.dart        # Centralized API client
│   │       └── providers/
│   │           ├── github_provider.dart
│   │           ├── altstore_provider.dart
│   │           └── omnisource_provider.dart
│   ├── models/                        # DTO models
│   ├── repositories/
│   │   ├── app_repository_impl.dart
│   │   ├── repository_manager_impl.dart
│   │   └── download_repository_impl.dart
│   └── services/
│       └── search_service.dart
├── infrastructure/
│   ├── database/
│   │   ├── database_provider.dart
│   │   ├── daos/
│   │   │   ├── app_dao.dart
│   │   │   ├── repository_dao.dart
│   │   │   ├── download_dao.dart
│   │   │   └── collection_dao.dart
│   │   └── tables/
│   │       ├── app_table.dart
│   │       ├── repository_table.dart
│   │       ├── download_table.dart
│   │       └── collection_table.dart
│   ├── installer/
│   │   ├── installer_manager.dart
│   │   └── adapters/
│   │       ├── altstore_adapter.dart
│   │       └── sidestore_adapter.dart
│   ├── notifications/
│   │   └── notification_service.dart
│   ├── storage/
│   └── sync/
│       └── sync_engine.dart
└── features/
    ├── home/
    │   └── presentation/
    │       ├── pages/home_page.dart
    │       └── providers/navigation_provider.dart
    ├── discover/
    │   └── presentation/
    │       ├── pages/discover_page.dart
    │       ├── widgets/
    │       └── providers/discover_provider.dart
    ├── search/
    │   └── presentation/
    │       ├── pages/search_page.dart
    │       ├── widgets/
    │       └── providers/search_provider.dart
    ├── updates/
    │   └── presentation/
    │       ├── pages/updates_page.dart
    │       ├── widgets/
    │       └── providers/
    ├── downloads/
    │   └── presentation/
    │       ├── pages/downloads_page.dart
    │       ├── widgets/
    │       └── providers/
    ├── repositories/
    │   └── presentation/
    │       ├── pages/repositories_page.dart
    │       ├── widgets/
    │       └── providers/
    ├── app_details/
    │   └── presentation/
    │       ├── pages/app_details_page.dart
    │       ├── widgets/
    │       └── providers/
    ├── favorites/
    │   └── presentation/
    ├── settings/
    │   └── presentation/
    │       └── pages/settings_page.dart
    └── collections/
        └── presentation/
```

---

## 5. Domain Models

### AppEntity
- `id`: String (unique)
- `name`: String
- `bundleId`: String (package identifier)
- `developer`: String
- `description`: String
- `version`: String (semver)
- `buildNumber`: String
- `releaseDate`: DateTime
- `iconUrl`: String
- `screenshots`: List<String>
- `categories`: List<String>
- `tags`: List<String>
- `downloadSize`: int (bytes)
- `minOsVersion`: String
- `sourceUrl`: String
- `repositoryId`: String
- `changelog`: String?
- `sha256`: String?
- `downloadUrl`: String?
- `isInstalled`: bool
- `installedVersion`: String?
- `isFavorite`: bool

### RepositoryEntity
- `id`: String (UUID)
- `name`: String
- `url`: String
- `type`: RepositoryType enum
- `isEnabled`: bool
- `addedAt`: DateTime
- `description`: String?
- `iconUrl`: String?
- `maintainer`: String?
- `appCount`: int?
- `lastSynced`: DateTime?
- `lastError`: String?
- `isValid`: bool

### DownloadEntity
- `id`: String (UUID)
- `appId`: String
- `appName`: String
- `url`: String
- `fileName`: String
- `savePath`: String
- `totalSize`: int
- `downloadedSize`: int
- `status`: DownloadStatus enum
- `createdAt`: DateTime
- `version`: String?
- `sha256`: String?
- `progress`: int (0-100)

---

## 6. Database Schema (Isar)

### AppTable
- Primary key: auto-increment Id
- Unique index: appId
- Index: repositoryId, isInstalled, isFavorite

### RepositoryTable
- Primary key: auto-increment Id
- Unique index: repositoryId
- Index: url, isEnabled

### DownloadTable
- Primary key: auto-increment Id
- Unique index: downloadId
- Index: appId, status

### CollectionTable
- Primary key: auto-increment Id
- Unique index: collectionId

---

## 7. Repository Provider Architecture

```
┌──────────────────────────────────────────────────┐
│           RepositoryProviderRegistry              │
│  ┌────────────────────────────────────────────┐  │
│  │ GitHubProvider  │ canHandle(github.com)     │  │
│  ├────────────────────────────────────────────┤  │
│  │ GitLabProvider  │ canHandle(gitlab.com)     │  │
│  ├────────────────────────────────────────────┤  │
│  │ CodebergProvider│ canHandle(codeberg.org)   │  │
│  ├────────────────────────────────────────────┤  │
│  │ ForgejoProvider │ canHandle(forgejo)        │  │
│  ├────────────────────────────────────────────┤  │
│  │ AltStoreProvider│ canHandle(altstore)       │  │
│  ├────────────────────────────────────────────┤  │
│  │ FeatherProvider │ canHandle(feather)        │  │
│  ├────────────────────────────────────────────┤  │
│  │ OmniSourceProv  │ canHandle(omnisource)     │  │
│  ├────────────────────────────────────────────┤  │
│  │ GenericProvider │ fallback                  │  │
│  └────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
```

Each provider implements:
- `validate(url)` → RepositoryValidationData
- `fetchApps(url)` → List<AppEntity>
- `fetchUpdates(url, since)` → List<AppEntity>
- `canHandle(url)` → bool

---

## 8. Installer Adapter Architecture

```
┌──────────────────────────────────────────────────┐
│              InstallerAdapterRegistry              │
│  ┌────────────────────────────────────────────┐  │
│  │ AltStoreAdapter  │ .ipa files               │  │
│  ├────────────────────────────────────────────┤  │
│  │ SideStoreAdapter │ .ipa files               │  │
│  ├────────────────────────────────────────────┤  │
│  │ FeatherAdapter   │ .ipa files               │  │
│  ├────────────────────────────────────────────┤  │
│  │ AndroidAdapter   │ .apk files (future)      │  │
│  └────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
```

Each adapter implements:
- `isAvailable()` → bool
- `install(filePath, bundleId)` → InstallResult
- `uninstall(bundleId)` → bool
- `isInstalled(bundleId)` → bool
- `getInstalledVersion(bundleId)` → String?
- `supportsFileType(extension)` → bool

---

## 9. State Management Design

Riverpod is used throughout with the following patterns:

- **StateProvider**: Simple state (theme mode, navigation index)
- **StateNotifierProvider**: Complex state (search, discover, downloads)
- **FutureProvider**: Async data (database initialization)
- **Provider**: Services and repositories (singleton instances)

State classes are immutable with `copyWith` pattern.

---

## 10. Synchronization Engine

```
┌──────────────────────────────────────────────────┐
│                 SyncEngine                        │
│                                                   │
│  ┌─────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │ Timer   │→ │ syncAll()   │→ │ Notifications│  │
│  │ (6hr)   │  │ syncRepo()  │  │ (updates)   │  │
│  └─────────┘  └──────┬──────┘  └─────────────┘  │
│                      │                            │
│              ┌───────▼───────┐                    │
│              │RepositoryMgr  │                    │
│              │(per provider) │                    │
│              └───────┬───────┘                    │
│                      │                            │
│              ┌───────▼───────┐                    │
│              │ AppRepository │                    │
│              │ (save to DB)  │                    │
│              └───────────────┘                    │
└──────────────────────────────────────────────────┘
```

---

## 11. Security Review

| Concern | Implementation |
|---------|---------------|
| HTTPS enforcement | `SecurityService.validateUrl()` rejects non-HTTPS |
| Download integrity | SHA256 hash verification before/after download |
| Metadata validation | Required fields, version format checking |
| Secure storage | `flutter_secure_storage` for tokens/keys |
| URL validation | Prevents SSRF via host/scheme validation |
| Duplicate prevention | Pre-download existence check |
| Duplicate download prevention | App+version uniqueness check |
| SQL injection | Isar's type-safe queries (no raw SQL) |

---

## 12. Scalability Review

| Concern | Strategy |
|---------|----------|
| 10,000+ apps | Isar indexed queries, pagination |
| 100,000+ releases | Cursor-based pagination, lazy loading |
| Hundreds of repos | Concurrent sync with rate limiting |
| Search performance | In-memory index + debounce + cache |
| Memory usage | Lazy image loading, stream-based data |
| Database performance | Write transactions, batch operations |
| Background sync | Configurable intervals, Wi-Fi only option |

---

## 13. Implementation Roadmap

### Phase 1: Foundation ✅
- [x] Project structure
- [x] Core infrastructure (DI, routing, theme, error handling)
- [x] Domain models
- [x] Database schema
- [x] Repository interfaces
- [x] Security service
- [x] HTTP client

### Phase 2: Core Features ✅
- [x] Home page with navigation
- [x] Discover page with categories
- [x] Search with debounce and caching
- [x] App details page
- [x] Repository management
- [x] Download manager
- [x] Updates page
- [x] Settings page

### Phase 3: Data Providers ✅
- [x] GitHub provider
- [x] AltStore provider
- [x] OmniSource provider
- [x] Repository validation
- [x] Sync engine

### Phase 4: Installer Integration ✅
- [x] Installer adapter abstraction
- [x] AltStore adapter
- [x] SideStore adapter
- [x] Installer manager

### Phase 5: Polish & Testing ✅
- [x] Unit tests (security, utils, failures, plugin system)
- [x] Error boundaries
- [x] Shimmer loading states
- [x] Empty states
- [x] Adaptive layouts

### Phase 6: Future (Planned)
- [ ] GitLab provider
- [ ] Codeberg provider
- [ ] Forgejo provider
- [ ] Feather provider
- [ ] Generic feed provider
- [ ] Background sync with workmanager
- [ ] Widget tests
- [ ] Integration tests
- [ ] Analytics abstraction
- [ ] Crash reporting integration
- [ ] Plugin marketplace
- [ ] macOS/Windows/Linux desktop support

---

## 14. Testing Strategy

### Unit Tests
- Security service (URL validation, SHA256, metadata)
- Utility functions (version comparison, byte formatting)
- Failure classes (equality, factory methods)
- Plugin system (registration, lifecycle)

### Widget Tests (Planned)
- App card widget
- Repository card widget
- Download progress widget
- Empty state widget
- Settings tile widgets

### Integration Tests (Planned)
- Repository add/remove flow
- Download start/pause/resume flow
- Sync engine end-to-end
- Search flow
