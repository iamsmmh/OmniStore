/// Developer profiles, verification and trust badges.
///
/// Independent distribution has no app-store gatekeeper, so identity is the
/// user's main defence against impersonation. This module models *evidence
/// based* verification: a badge is only granted when a check that can be
/// re-run mechanically has passed, and every badge records how it was earned.
library;

/// A verifiable claim of ownership between a developer and a source.
enum VerificationMethod {
  /// A `.well-known/omnistore.json` file served from the developer's domain.
  wellKnownFile,

  /// A DNS TXT record containing the developer key.
  dnsTxtRecord,

  /// A signed commit or release tag matching a published public key.
  signedRelease,

  /// The repository host itself asserts the account (e.g. GitHub org owner).
  platformOwnership,

  /// Manually vouched by an OmniSource curator.
  curatorVouch,
}

enum VerificationStatus { unverified, pending, verified, revoked, failed }

/// The outcome of one verification attempt.
class VerificationRecord {
  final VerificationMethod method;
  final VerificationStatus status;
  final DateTime checkedAt;

  /// The evidence location (domain, repo URL, key fingerprint).
  final String subject;

  final String? failureReason;

  /// Verification must be re-checked periodically; a stale pass is not a pass.
  final DateTime? expiresAt;

  const VerificationRecord({
    required this.method,
    required this.status,
    required this.checkedAt,
    required this.subject,
    this.failureReason,
    this.expiresAt,
  });

  bool isActiveAt(DateTime now) =>
      status == VerificationStatus.verified &&
      (expiresAt == null || expiresAt!.isAfter(now));
}

/// Badge kinds shown next to a developer or app.
enum BadgeKind {
  verifiedPublisher,
  signedReleases,
  consistentMaintainer,
  openSource,
  checksumPublisher,
  longStanding,
}

class Badge {
  final BadgeKind kind;
  final String label;

  /// Why this badge was granted — always shown on tap, never a bare icon.
  final String justification;

  final DateTime grantedAt;

  const Badge({
    required this.kind,
    required this.label,
    required this.justification,
    required this.grantedAt,
  });
}

/// Aggregated public information about a developer.
class DeveloperProfile {
  /// Stable id: normalised developer name scoped by primary repository host.
  final String id;
  final String displayName;

  /// App ids published by this developer, across all repositories.
  final List<String> appIds;

  /// Canonical links (project homepage, source forge, sponsor page).
  final List<DeveloperLink> links;

  final List<VerificationRecord> verifications;
  final List<Badge> badges;

  /// Timestamps of all releases across the developer's apps, newest last.
  final List<DateTime> releaseHistory;

  final DateTime? firstSeenAt;

  const DeveloperProfile({
    required this.id,
    required this.displayName,
    this.appIds = const [],
    this.links = const [],
    this.verifications = const [],
    this.badges = const [],
    this.releaseHistory = const [],
    this.firstSeenAt,
  });

  bool isVerifiedAt(DateTime now) =>
      verifications.any((record) => record.isActiveAt(now));

  DateTime? get lastReleaseAt =>
      releaseHistory.isEmpty ? null : (releaseHistory.toList()..sort()).last;
}

class DeveloperLink {
  final String label;
  final String url;
  final bool isVerified;

  const DeveloperLink({
    required this.label,
    required this.url,
    this.isVerified = false,
  });
}

/// Inputs for badge evaluation, gathered from the local catalog.
class DeveloperMetrics {
  final int appCount;
  final int releaseCount;
  final double checksumCoverage;
  final double openSourceRatio;
  final bool hasSignedReleases;
  final DateTime? firstSeenAt;
  final DateTime? lastReleaseAt;

  const DeveloperMetrics({
    this.appCount = 0,
    this.releaseCount = 0,
    this.checksumCoverage = 0,
    this.openSourceRatio = 0,
    this.hasSignedReleases = false,
    this.firstSeenAt,
    this.lastReleaseAt,
  });
}

/// Derives badges deterministically from verification records and metrics.
class BadgeEvaluator {
  const BadgeEvaluator();

  List<Badge> evaluate({
    required List<VerificationRecord> verifications,
    required DeveloperMetrics metrics,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final badges = <Badge>[];

    final active =
        verifications.where((v) => v.isActiveAt(reference)).toList();
    if (active.isNotEmpty) {
      final method = active.first.method;
      badges.add(Badge(
        kind: BadgeKind.verifiedPublisher,
        label: 'Verified publisher',
        justification:
            'Ownership of ${active.first.subject} confirmed via ${_methodLabel(method)}.',
        grantedAt: active.first.checkedAt,
      ));
    }

    if (metrics.hasSignedReleases) {
      badges.add(Badge(
        kind: BadgeKind.signedReleases,
        label: 'Signed releases',
        justification: 'Releases are cryptographically signed.',
        grantedAt: reference,
      ));
    }

    if (metrics.checksumCoverage >= 0.95 && metrics.releaseCount >= 3) {
      badges.add(Badge(
        kind: BadgeKind.checksumPublisher,
        label: 'Publishes checksums',
        justification:
            'At least 95% of releases publish a SHA-256 checksum, so downloads '
            'can be verified.',
        grantedAt: reference,
      ));
    }

    if (metrics.openSourceRatio >= 0.9 && metrics.appCount >= 1) {
      badges.add(Badge(
        kind: BadgeKind.openSource,
        label: 'Open source',
        justification: 'All published apps declare an open source licence.',
        grantedAt: reference,
      ));
    }

    final last = metrics.lastReleaseAt;
    if (metrics.releaseCount >= 6 &&
        last != null &&
        reference.difference(last).inDays <= 120) {
      badges.add(Badge(
        kind: BadgeKind.consistentMaintainer,
        label: 'Consistent maintainer',
        justification:
            '${metrics.releaseCount} releases published, most recent within the '
            'last four months.',
        grantedAt: reference,
      ));
    }

    final first = metrics.firstSeenAt;
    if (first != null && reference.difference(first).inDays >= 365 * 2) {
      badges.add(Badge(
        kind: BadgeKind.longStanding,
        label: 'Long-standing publisher',
        justification: 'Publishing through OmniStore for over two years.',
        grantedAt: reference,
      ));
    }

    return badges;
  }

  static String _methodLabel(VerificationMethod method) => switch (method) {
        VerificationMethod.wellKnownFile => 'a .well-known file on the domain',
        VerificationMethod.dnsTxtRecord => 'a DNS TXT record',
        VerificationMethod.signedRelease => 'a signed release',
        VerificationMethod.platformOwnership => 'repository host ownership',
        VerificationMethod.curatorVouch => 'an OmniSource curator review',
      };
}

/// Contract for performing verification checks. Implementations live in the
/// data layer (HTTP/DNS); keeping the interface in domain lets the web build
/// substitute a proxy-backed implementation without touching callers.
abstract class VerificationService {
  /// Attempts to verify [developerId] owns [subject] using [method].
  Future<VerificationRecord> verify({
    required String developerId,
    required String subject,
    required VerificationMethod method,
  });

  /// Re-checks records nearing expiry.
  Future<List<VerificationRecord>> refresh(List<VerificationRecord> records);
}
