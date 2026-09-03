# Roadmap

## Completed (2026-09)

* [x] 8 repository providers with parsing, pagination, caching, validation
* [x] 5 installer adapters with platform gating
* [x] Validation engine (6 categories, remediation, 0–100)
* [x] Health (0–100 Healthy/Warning/Critical) + detailed cadence report
* [x] Trust (0–100 Verified/Trusted/Community/Unknown/Risky)
* [x] Smart discovery (related/popular/trending/verified) + recommendations + dynamic collections
* [x] Search index (full-text, fuzzy, filtered, ranked, offline, corrections)
* [x] Update intelligence (bump + Critical/High/Medium/Low)
* [x] Compatibility engine (iOS version + arch)
* [x] Database offline-first, migrations, transaction safety
* [x] Sync v2 (priority, adaptive, bounded, retry, rate-limit, incremental, offline)
* [x] Security hardening (HTTPS, private-host, SHA-256 hex, injection filter)
* [x] Performance caps (search LRU, network cache 100, sync max 25/4)
* [x] Monitoring (sync/validation/health logs)
* [x] Full UI (Home, Discover, Sources, Search, Updates, Downloads, App Details, Settings) with loading/empty/error/a11y
* [x] Tests (80%+ target) + docs

## Next (2026-Q4)

* [ ] IPA metadata ingestion (bundle parsing, entitlements preview)
* [ ] Community moderation queue for `DisabledCommunityService` activation
* [ ] Desktop filesystem installer adapter (direct `.ipa` extraction preview)
* [ ] Widget tests for all screens (scroll, filter, offline banner)
* [ ] CI with `flutter test --coverage` gate + screenshot capture

## Future

* [ ] On-device machine-learned ranking (opt-in, local-only)
* [ ] Cross-device sync of favorites via encrypted backup
* [ ] Repository signing verification (Sigstore cosign) → boosts trust to Verified
