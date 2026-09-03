# OmniStore

A production-grade, repository-driven application manager for iOS and Android.

OmniStore helps users discover, track, download, and manage applications distributed through trusted repositories — including GitHub Releases, AltStore Sources, OmniSource Feeds, and more.

## What OmniStore Is

- **Application Discovery** — Browse featured, trending, and new releases across multiple repositories
- **Repository Management** — Add, sync, validate, and manage trusted sources
- **Release Monitoring** — Track versions, get update notifications, view changelogs
- **Download Management** — Pause, resume, queue, and verify downloads
- **Installer Integration** — Modular adapters for AltStore, SideStore, and more

## What OmniStore Is NOT

- ❌ Not an app signer
- ❌ Not an enterprise certificate platform
- ❌ Not a piracy tool

## Technology Stack

| Component | Technology |
|-----------|-----------|
| Framework | Flutter 3.19+ / Dart 3.2+ |
| Architecture | Clean Architecture |
| State Management | Riverpod 2.x |
| Navigation | GoRouter 13.x |
| Networking | Dio 5.x |
| Database | Isar 3.x |
| Serialization | Freezed + JsonSerializable |
| Theming | Material 3 + Dynamic Color |

## Supported Repository Types

| Type | Source |
|------|--------|
| GitHub | GitHub Releases |
| GitLab | GitLab Releases |
| Codeberg | Codeberg Releases |
| Forgejo | Forgejo Releases |
| AltStore | AltStore Sources |
| OmniSource | OmniSource Feeds |
| Feather | Feather Repositories |
| Generic | Custom JSON Feeds |

## Architecture

```
┌─────────────────────────────────────────────┐
│  Presentation (Pages, Widgets, Providers)   │
├─────────────────────────────────────────────┤
│  Domain (Entities, Repository Interfaces)   │
├─────────────────────────────────────────────┤
│  Data (Implementations, Remote Providers)   │
├─────────────────────────────────────────────┤
│  Infrastructure (DB, Sync, Installer, Notif)│
├─────────────────────────────────────────────┤
│  Core (DI, Error, Security, Theme, Plugin)  │
└─────────────────────────────────────────────┘
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for the complete blueprint.

## Features

- 🏠 **Home** — Featured apps, quick actions, recent updates
- 🔍 **Discover** — Categories, trending, new releases, infinite scrolling
- 🔎 **Search** — Debounced search, suggestions, recent history
- 📱 **App Details** — Screenshots, changelogs, version history, SHA256
- 🔄 **Updates** — Track installed versions, available updates, bulk update
- 📥 **Downloads** — Pause/resume, queue management, progress tracking
- 📦 **Repositories** — Add/remove/validate sources, auto-detect type
- ⭐ **Favorites** — Save and organize favorite apps
- 📁 **Collections** — Organize apps by category
- ⚙️ **Settings** — Appearance, sync, notifications, security, data

## Security

- 🔒 HTTPS enforcement for all connections
- 🔐 SHA256 hash validation for downloads
- 🛡️ Metadata validation before installation
- 🔑 Secure token storage
- 🚫 Duplicate download prevention

## Getting Started

### Prerequisites

- Flutter SDK >= 3.19.0
- Dart SDK >= 3.2.0
- Xcode (for iOS)
- Android Studio (for Android)

### Setup

```bash
# Clone the repository
git clone https://github.com/iamsmmh/OmniStore.git
cd OmniStore

# Install dependencies
flutter pub get

# Generate code for Freezed, JsonSerializable, Isar
dart run build_runner build

# Run the app
flutter run
```

### Code Generation

```bash
# Generate all code
dart run build_runner build --delete-conflicting-outputs

# Watch mode
dart run build_runner watch
```

## Project Structure

```
lib/
├── main.dart              # Entry point
├── app/                   # Root app widget
├── core/                  # Shared infrastructure
├── domain/                # Business logic contracts
├── data/                  # Data layer implementation
├── infrastructure/        # Database, sync, installer
└── features/              # Feature modules
    ├── home/
    ├── discover/
    ├── search/
    ├── updates/
    ├── downloads/
    ├── repositories/
    ├── app_details/
    ├── favorites/
    ├── settings/
    └── collections/
```

## Testing

```bash
# Run unit tests
flutter test test/unit/

# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

## Contributing

Contributions are welcome! Please ensure:

1. Code follows the existing architecture patterns
2. New features include tests
3. Security considerations are documented
4. The plugin system is respected for extensibility

## License

This project is open source. See LICENSE for details.
