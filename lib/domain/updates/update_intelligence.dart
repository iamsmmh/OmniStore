/// Update intelligence: explains *why* an update matters.
///
/// A version number alone gives users no basis for deciding whether to
/// install now, defer, or read the changelog first. This module derives a
/// structured, explainable verdict from data OmniStore already syncs
/// (versions, changelogs, asset metadata, dates) with no extra network cost.
library;

import '../../core/versioning/semantic_version.dart';

/// How urgently an update should be surfaced to the user.
enum UpdateUrgency {
  /// Security fix or critical crash fix — surface prominently.
  critical,

  /// Major release, or contains breaking changes the user should read about.
  important,

  /// Ordinary feature/bugfix release.
  routine,

  /// Pre-release, build-metadata-only, or cosmetic change.
  optional,
}

/// A single machine-derived reason contributing to the verdict.
class UpdateSignal {
  final String code;
  final String label;

  /// Human-readable justification shown in the UI.
  final String detail;
  final UpdateUrgency weight;

  const UpdateSignal({
    required this.code,
    required this.label,
    required this.detail,
    required this.weight,
  });

  @override
  String toString() => '$code(${weight.name})';
}

/// The full explanation for one pending update.
class UpdateVerdict {
  final String appId;
  final String fromVersion;
  final String toVersion;
  final VersionBumpType bumpType;
  final UpdateUrgency urgency;
  final List<UpdateSignal> signals;

  /// One-line summary suitable for a list row.
  final String summary;

  /// `true` when the release may require user action after installing.
  final bool hasBreakingChanges;
  final bool isSecurityUpdate;
  final bool isPreRelease;

  const UpdateVerdict({
    required this.appId,
    required this.fromVersion,
    required this.toVersion,
    required this.bumpType,
    required this.urgency,
    required this.signals,
    required this.summary,
    required this.hasBreakingChanges,
    required this.isSecurityUpdate,
    required this.isPreRelease,
  });
}

/// Input describing a candidate release. Deliberately primitive-typed so the
/// analyzer stays independent of persistence and Freezed models.
class ReleaseCandidate {
  final String appId;
  final String installedVersion;
  final String latestVersion;
  final String? changelog;
  final DateTime? releaseDate;
  final int? downloadSize;
  final int? previousDownloadSize;
  final String? sha256;
  final bool isPrerelease;

  /// Minimum OS version required by the new release, if declared.
  final String? minOsVersion;

  /// Minimum OS version required by the currently installed release.
  final String? installedMinOsVersion;

  const ReleaseCandidate({
    required this.appId,
    required this.installedVersion,
    required this.latestVersion,
    this.changelog,
    this.releaseDate,
    this.downloadSize,
    this.previousDownloadSize,
    this.sha256,
    this.isPrerelease = false,
    this.minOsVersion,
    this.installedMinOsVersion,
  });
}

/// Derives [UpdateVerdict]s from [ReleaseCandidate]s.
class UpdateIntelligence {
  const UpdateIntelligence();

  // Matched against a normalised (lowercased) changelog.
  static const List<String> _securityKeywords = [
    'security',
    'vulnerabilit',
    'cve-',
    'exploit',
    'rce ',
    'remote code execution',
    'privilege escalation',
    'xss',
    'sql injection',
    'sanitiz',
    'patched a flaw',
    'security advisory',
  ];

  static const List<String> _breakingKeywords = [
    'breaking change',
    'breaking:',
    'no longer supported',
    'removed support',
    'dropped support',
    'incompatible',
    'migration required',
    'you must re-',
    'requires reconfigur',
    'data will be reset',
    'not backwards compatible',
    'backwards incompatible',
  ];

  static const List<String> _criticalFixKeywords = [
    'crash on launch',
    'data loss',
    'corrupt',
    'fixes a critical',
    'critical bug',
    'hotfix',
  ];

  /// Analyses a single candidate.
  UpdateVerdict analyze(ReleaseCandidate candidate) {
    final signals = <UpdateSignal>[];
    final bump = SemanticVersion.classify(
      candidate.installedVersion,
      candidate.latestVersion,
    );
    final changelog = (candidate.changelog ?? '').toLowerCase();

    final isSecurity = _containsAny(changelog, _securityKeywords);
    if (isSecurity) {
      signals.add(const UpdateSignal(
        code: 'security_fix',
        label: 'Security fix',
        detail: 'The changelog references a security fix or advisory.',
        weight: UpdateUrgency.critical,
      ));
    }

    if (_containsAny(changelog, _criticalFixKeywords)) {
      signals.add(const UpdateSignal(
        code: 'critical_fix',
        label: 'Critical fix',
        detail: 'Fixes a crash, data-loss or corruption issue.',
        weight: UpdateUrgency.critical,
      ));
    }

    final hasBreakingText = _containsAny(changelog, _breakingKeywords);
    if (hasBreakingText) {
      signals.add(const UpdateSignal(
        code: 'breaking_change',
        label: 'Breaking change',
        detail: 'The changelog announces a breaking or incompatible change.',
        weight: UpdateUrgency.important,
      ));
    }

    if (bump == VersionBumpType.major) {
      signals.add(UpdateSignal(
        code: 'major_release',
        label: 'Major release',
        detail:
            'Version moves from ${candidate.installedVersion} to ${candidate.latestVersion}. '
            'Major releases often change behaviour or settings.',
        weight: UpdateUrgency.important,
      ));
    }

    // 0.x projects treat minor bumps as breaking per semver convention.
    final installed = SemanticVersion.tryParse(candidate.installedVersion);
    if (bump == VersionBumpType.minor &&
        installed != null &&
        installed.isUnstable) {
      signals.add(const UpdateSignal(
        code: 'unstable_minor',
        label: 'Pre-1.0 minor release',
        detail:
            'This project is below 1.0, where minor releases may include '
            'breaking changes.',
        weight: UpdateUrgency.important,
      ));
    }

    if (candidate.isPrerelease ||
        (SemanticVersion.tryParse(candidate.latestVersion)?.isPreRelease ??
            false)) {
      signals.add(const UpdateSignal(
        code: 'prerelease',
        label: 'Pre-release',
        detail: 'This is a beta or release-candidate build.',
        weight: UpdateUrgency.optional,
      ));
    }

    final osChange = _osRequirementRaised(candidate);
    if (osChange != null) {
      signals.add(UpdateSignal(
        code: 'os_requirement_raised',
        label: 'Higher OS requirement',
        detail: osChange,
        weight: UpdateUrgency.important,
      ));
    }

    final sizeSignal = _sizeSignal(candidate);
    if (sizeSignal != null) signals.add(sizeSignal);

    if (candidate.sha256 == null || candidate.sha256!.length != 64) {
      signals.add(const UpdateSignal(
        code: 'missing_checksum',
        label: 'No checksum published',
        detail:
            'The publisher did not provide a SHA-256 checksum, so download '
            'integrity cannot be verified automatically.',
        weight: UpdateUrgency.important,
      ));
    }

    if ((candidate.changelog ?? '').trim().isEmpty) {
      signals.add(const UpdateSignal(
        code: 'no_changelog',
        label: 'No changelog',
        detail: 'The publisher did not describe what changed in this release.',
        weight: UpdateUrgency.routine,
      ));
    }

    final urgency = _resolveUrgency(bump, signals);

    return UpdateVerdict(
      appId: candidate.appId,
      fromVersion: candidate.installedVersion,
      toVersion: candidate.latestVersion,
      bumpType: bump,
      urgency: urgency,
      signals: List.unmodifiable(signals),
      summary: _summarize(bump, urgency, signals),
      hasBreakingChanges: hasBreakingText ||
          bump == VersionBumpType.major ||
          signals.any((s) => s.code == 'unstable_minor'),
      isSecurityUpdate: isSecurity,
      isPreRelease: signals.any((s) => s.code == 'prerelease'),
    );
  }

  /// Analyses a batch and returns it ordered by urgency, then recency.
  List<UpdateVerdict> analyzeAll(Iterable<ReleaseCandidate> candidates) {
    // Materialise once: the input may be a single-subscription iterable.
    final items = candidates.toList(growable: false);
    final dates = <String, DateTime?>{
      for (final c in items) c.appId: c.releaseDate,
    };
    final verdicts = items.map(analyze).toList()
      ..sort((a, b) {
        final byUrgency = a.urgency.index.compareTo(b.urgency.index);
        if (byUrgency != 0) return byUrgency;
        final dateA = dates[a.appId];
        final dateB = dates[b.appId];
        if (dateA != null && dateB != null) return dateB.compareTo(dateA);
        return a.appId.compareTo(b.appId);
      });
    return verdicts;
  }

  UpdateUrgency _resolveUrgency(
    VersionBumpType bump,
    List<UpdateSignal> signals,
  ) {
    if (signals.any((s) => s.weight == UpdateUrgency.critical)) {
      return UpdateUrgency.critical;
    }
    final isPreRelease = signals.any((s) => s.code == 'prerelease');
    if (signals.any((s) => s.weight == UpdateUrgency.important)) {
      // A beta that also announces breaking changes stays "important" — users
      // opting into pre-releases still need the warning.
      return UpdateUrgency.important;
    }
    if (isPreRelease) return UpdateUrgency.optional;
    switch (bump) {
      case VersionBumpType.major:
        return UpdateUrgency.important;
      case VersionBumpType.minor:
      case VersionBumpType.patch:
        return UpdateUrgency.routine;
      case VersionBumpType.prerelease:
      case VersionBumpType.build:
      case VersionBumpType.none:
        return UpdateUrgency.optional;
      case VersionBumpType.unknown:
        return UpdateUrgency.routine;
    }
  }

  String _summarize(
    VersionBumpType bump,
    UpdateUrgency urgency,
    List<UpdateSignal> signals,
  ) {
    if (signals.any((s) => s.code == 'security_fix')) {
      return 'Security update — install soon';
    }
    if (signals.any((s) => s.code == 'critical_fix')) {
      return 'Critical fix — install soon';
    }
    if (signals.any((s) => s.code == 'breaking_change')) {
      return 'Contains breaking changes — review the changelog';
    }
    if (bump == VersionBumpType.major) return 'Major release';
    if (urgency == UpdateUrgency.optional) return 'Optional update';
    if (bump == VersionBumpType.minor) return 'New features and fixes';
    if (bump == VersionBumpType.patch) return 'Bug fixes';
    return 'Update available';
  }

  String? _osRequirementRaised(ReleaseCandidate candidate) {
    final next = SemanticVersion.tryParse(candidate.minOsVersion);
    final current = SemanticVersion.tryParse(candidate.installedMinOsVersion);
    if (next == null || current == null) return null;
    if (next <= current) return null;
    return 'Requires OS ${candidate.minOsVersion} or later '
        '(previously ${candidate.installedMinOsVersion}).';
  }

  UpdateSignal? _sizeSignal(ReleaseCandidate candidate) {
    final next = candidate.downloadSize;
    final previous = candidate.previousDownloadSize;
    if (next == null || previous == null || previous <= 0) return null;
    final ratio = next / previous;
    if (ratio >= 2.0) {
      return const UpdateSignal(
        code: 'size_increase',
        label: 'Much larger download',
        detail: 'The download is at least twice the size of the installed '
            'version — expect a longer download.',
        weight: UpdateUrgency.routine,
      );
    }
    if (ratio <= 0.4) {
      return const UpdateSignal(
        code: 'size_drop',
        label: 'Unusually small download',
        detail: 'The download is far smaller than the installed version, '
            'which can indicate an incomplete or mispublished asset.',
        weight: UpdateUrgency.important,
      );
    }
    return null;
  }

  static bool _containsAny(String haystack, List<String> needles) {
    for (final needle in needles) {
      if (haystack.contains(needle)) return true;
    }
    return false;
  }
}

/// Diff between two changelog texts, so the UI can show "what's new since the
/// version you have" rather than only the newest release notes.
class ChangelogDiff {
  final List<String> addedLines;
  final List<String> removedLines;

  const ChangelogDiff({required this.addedLines, required this.removedLines});

  bool get isEmpty => addedLines.isEmpty && removedLines.isEmpty;

  /// Line-level diff, normalising list bullets and whitespace so cosmetic
  /// reformatting between releases does not create phantom changes.
  static ChangelogDiff between(String? previous, String? next) {
    final before = _lines(previous);
    final after = _lines(next);
    final beforeSet = before.toSet();
    final afterSet = after.toSet();
    return ChangelogDiff(
      addedLines: after.where((l) => !beforeSet.contains(l)).toList(),
      removedLines: before.where((l) => !afterSet.contains(l)).toList(),
    );
  }

  static List<String> _lines(String? text) {
    if (text == null) return const [];
    return text
        .split('\n')
        .map((l) => l.trim().replaceFirst(RegExp(r'^[-*+•]\s*'), ''))
        .where((l) => l.isNotEmpty)
        .toList();
  }
}
