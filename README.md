# OmniStore
### The Intelligent App Store and Repository Manager for the Decentralized iOS Ecosystem

**OmniStore** is a production-grade, repository-driven application manager for **iOS and Android**. It unifies fragmented independent distribution (GitHub Releases, Forgejo, AltStore, Feather, OmniSource, generic JSON) into a single offline-first experience with trust scoring, health analysis, update intelligence and real installer handoffs. It is **not** a signer, certificate platform or piracy tool — it brokers discovery and verification, then delegates installation to the user’s chosen on-device installer.

---

## Why OmniStore Exists

iOS sideloading and Android independent distribution are fragmented: each developer hosts releases differently, feeds use incompatible schemas, update discovery is manual, and users cannot tell whether a source is maintained, secure or even alive. OmniStore solves this by:

* normalising **8 repository formats** behind one catalog,
* scoring **trust** (transport, checksums, metadata) and **health** (release cadence, broken links) on-device,
* ranking and searching **offline** via an inverted index,
* explaining **why an update matters** (security, breaking changes, OS requirements),
* handing **install / update / reinstall / open** to real adapters (AltStore, SideStore, Feather, ESign, LiveContainer) — unsupported installers never appear in the UI.

---

## Supported Repository Sources (8) — Real Providers

| Type | Host Examples | What Is Parsed | Pagination | Failure & Cache Behavior |
|------|---------------|----------------|------------|--------------------------|
| **GitHub Releases** | `github.com` | tags, assets, changelogs, sizes, draft/prerelease flags | cursor `per_page` + multi-page | conditional ETag, 3-page prefetch, exponential backoff |
| **GitLab Releases** | `gitlab.com`, self-hosted | releases, assets/links, sources fallback | `per_page` + grouped subgroups | same |
| **Codeberg Releases** | `codeberg.org` | Gitea v1 repos, assets, sha256 | `limit/page` | same |
| **Forgejo Releases** | any self-hosted Forgejo/Gitea | generic Gitea v1 | `limit/page` | same |
| **AltStore Sources** | `*.json` with `sourceInfo` | apps, versions, icons, screenshots | single JSON + conditional | validation of feed structure |
| **OmniSource** | `.../feed` | feedInfo + apps, incremental `since` | ETag + `since` | delta sync |
| **Feather Sources** | `*feather*` | feather/altstore-compatible, bundleId variants | single JSON | tolerant key aliasing |
| **Generic JSON** | any HTTPS JSON | auto-detected `apps`/`applications`/`packages`/`items` | single JSON | tolerant, lenient version inference |

All providers: **parse metadata, assets, versions, changelogs, handle pagination, handle failures, cache responses (TTL 30 min + ETag 304), validate content.**

---

## Supported Installers (5) — Real Integrations

| Installer | Platform | File Types | Capabilities | URL Scheme |
|-----------|----------|------------|--------------|------------|
| **AltStore** | iOS | `ipa` | install, update, reinstall, open (fallback) | `altstore://` |
| **SideStore** | iOS | `ipa` | install, update, reinstall, open | `sidestore://` |
| **Feather** | iOS | `ipa`, `tipa`, `zip` | install, update, reinstall, open | `feather://` |
| **ESign** | iOS | `ipa` | install, update, reinstall, open | `esign://` |
| **LiveContainer** | iOS | `ipa`, `tipa` | install, update, reinstall, uninstall, open (also launches contained apps) | `livecontainer://` |

Unsupported installers **do not appear** in the UI (`isSupportedOnCurrentPlatform` filtered, then `isAvailable()` probed via `canLaunchUrl`).

---

## Key Features

* **Repository Validation Engine** — URL format, feed structure, metadata completeness, icon availability, HTTPS download checks, version sanity, checksum presence; produces `ValidationReport` with score 0–100 and remediation.
* **App Health System** — derived purely from release timestamps: recency, yearly cadence, consistency → score 0–100 and status **Healthy / Warning / Critical** (`HealthEngine`).
* **Trust Engine** — HTTPS usage, repo age, maintainer activity, release consistency, signed releases, community adoption, metadata quality → score 0–100 and category **Verified / Trusted / Community / Unknown / Risky** (`TrustEngine` + `TrustAnalyzer`).
* **Smart Discovery & Recommendations** — related/popular/trending/verified suggestions via Jaccard on categories/tags + health/popularity boost; `RecommendationEngine` builds `Trending / New & Noteworthy / Hidden Gems / Developer Tools …` collections.
* **Search Engine** — in-memory `SearchIndex` (inverted index, IDF, field weights, prefix expansion, bounded Damerau–Levenshtein, freshness boost) + category/source filters + popularity ranking + offline cache + spelling correction (`searchIndex`, `DiscoveryService`).
* **Update Intelligence** — `SemanticVersion` + changelog keyword analysis → bump classification (`major/minor/patch/prerelease/build`) and urgency **Critical / High / Medium / Low** with human summary and signals (`breaking_change`, `security_fix` …).
* **Compatibility Engine** — checks `minOSVersion` and architecture, explains `Compatible / Check required / Incompatible`.
* **Offline-First Database** — Isar with migration chain, transaction safety, deduplication, orphan cleanup, integrity checks, chunked indexing.
* **Sync Engine v2** — `SyncScheduler` (priority, adaptive intervals, exponential backoff with jitter, bounded `maxTasksPerRound`) + `SyncEngine` (offline queue, retry, partial sync, incremental `If-None-Match`, rate-limit 429 backoff, conflict resolution last-write-wins).
* **Security Hardening** — HTTPS-only, private-host blocking, credential stripping, SHA-256 hex validation, metadata injection filtering, URL sanitisation.
* **Monitoring** — in-memory `MonitoringService` (sync/validation/health/error logs) surfaced in Settings → Diagnostics.

---

## Screens (Production UI, No Placeholders)

* **Home** — featured banner, quick actions, recently updated strip, discover preview, background sync affordances.
* **Discover** — featured/trending/new & updated/hidden gems, pull-to-refresh, offline banner, collections.
* **Sources** — list with health/trust badges, add dialog with live validation, sync/enable/remove, detail sheet with last error.
* **Search** — debounced live search, suggestions, recent searches, category/source filters, spelling correction, loading/empty/error states, accessibility labels.
* **Updates** — grouped by urgency (Critical/High/Medium/Low), breakage warnings, batch-update affordance, launches intelligence summaries.
* **Downloads** — active (progress, pause/resume), failed (retry), history, swipe-to-delete.
* **Health** — in App Details: health score + reasons, trust score + findings.
* **Settings** — theme, dynamic color, sync controls, security attestations, diagnostics, analytics opt-in.

**App Details** shows: screenshots carousel, changelog, compatibility, health score, trust score, source info, **Install / Update / Reinstall / Download / Open** (adapts via `resolveInstallAffordance`).

**Source Details** shows: metadata, health status, trust score, app count, last sync, maintainer, last error.

---

## Screenshots

> Screenshots are rendered live from the running app; the preview host embeds the Flutter canvas. Placeholders below are replaced by CI-captured images on release.

```
assets/screenshots/home.png
assets/screenshots/discover.png
assets/screenshots/search.png
assets/screenshots/app_details.png
assets/screenshots/updates.png
assets/screenshots/sources.png
```

---

## Installation

### Prerequisites
* Flutter SDK `>=3.19.0` / Dart `>=3.2.0`
* Xcode 15+ (iOS) or Android Studio Hedgehog+ (Android)
* `path_provider`, `url_launcher` configured per platform (already in `Info.plist`/`AndroidManifest.xml`)

### Clone & Run
```bash
git clone https://github.com/iamsmmh/OmniStore.git
cd OmniStore
flutter pub get

# Code generation (Freezed, Isar, JsonSerializable)
dart run build_runner build --delete-conflicting-outputs

flutter run
```

### Generate Code in Watch Mode
```bash
dart run build_runner watch
```

### Tests & Coverage
```bash
flutter test                         # all
flutter test test/unit/              # unit only
flutter test --coverage && genhtml coverage/lcov.info -o coverage/html
```

Target: **80%+** coverage on `domain/` engines (versioning, search, health, trust, recommendations, validation).

---

## Architecture

Clean Architecture + feature-first layout; `domain` is pure Dart, `data` implements providers, `infrastructure` owns DB/sync/installers, `features` own presentation. See [ARCHITECTURE.md](ARCHITECTURE.md).

```
lib/
  core/           constants, DI, error, logger, network, security, theme, search, monitoring, platform
  domain/         models, health, security/trust, discovery, updates, validation, compatibility
  data/           providers (8), repositories, services (search, discovery)
  infrastructure/ database (Isar + DAOs + migrations), sync (scheduler+engine), installer (5 adapters), notifications
  features/       home, discover, search, updates, downloads, repositories, app_details, settings
```

---

## Security

* Private/local-host and credential-bearing URLs rejected.
* `SHA-256` validated in `validateSha256Bytes` (binary) — metadata `validateSha256` delegates to it.
* Lenient semver parser accepts `v1.0`, `1.0`, `2024.05.01` but flags inconsistent schemes for trust.
* `enforceHttps` is enforced in `SecurityService.validateUrl` **and** `ApiClient._getJsonFeed`.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). All new engines must be codegen-free, pure-Dart and fully tested; new providers must implement `RepositoryProvider` and register in `RepositoryManagerImpl`.

---

## License

MIT — see `LICENSE`.

## Production Readiness

* Builds without TODO/placeholder code (`grep TODO` returns only historical tracking comments in docs).
* Works offline via `offline_cache_policy` + `SearchIndex`.
* Sync is bounded, retried and rate-limit aware.
* Every score ships an explanation for accessibility.
* Installer UI is platform-gated — web shows browse-only.

```
