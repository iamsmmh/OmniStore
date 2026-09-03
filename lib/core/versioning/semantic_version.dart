/// Semantic version parsing and comparison.
///
/// Replaces the naive dotted-integer comparison previously used across
/// OmniStore, which mis-ordered pre-releases (`1.0.0-beta` was treated as
/// equal to `1.0.0`) and ignored common real-world tag shapes such as
/// `v1.2.3`, `1.2.3+45` or `2024.05.01`.
///
/// Pure Dart: no code generation, no Flutter dependency, fully unit testable.
library;

/// The kind of change between two versions.
enum VersionBumpType {
  /// Left/right are the same version.
  none,

  /// Only build metadata or an unparseable suffix changed.
  build,

  /// A pre-release identifier changed (1.0.0-beta.1 -> 1.0.0-beta.2).
  prerelease,

  /// Patch component increased (1.0.0 -> 1.0.1).
  patch,

  /// Minor component increased (1.0.0 -> 1.1.0).
  minor,

  /// Major component increased (1.0.0 -> 2.0.0). Potentially breaking.
  major,

  /// Versions are not comparable (different schemes).
  unknown,
}

/// An immutable, comparable semantic version.
class SemanticVersion implements Comparable<SemanticVersion> {
  final int major;
  final int minor;
  final int patch;

  /// Dot separated pre-release identifiers, e.g. `['beta', '2']`.
  final List<String> preRelease;

  /// Build metadata; ignored for precedence per semver spec.
  final String? build;

  /// The original string this version was parsed from.
  final String raw;

  const SemanticVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.preRelease = const [],
    this.build,
    this.raw = '',
  });

  static final RegExp _pattern = RegExp(
    r'^[vV]?\s*'
    r'(\d+)'
    r'(?:\.(\d+))?'
    r'(?:\.(\d+))?'
    r'(?:\.(\d+))?'
    r'(?:[-_](?<pre>[0-9A-Za-z][0-9A-Za-z.\-]*))?'
    r'(?:\+(?<build>[0-9A-Za-z][0-9A-Za-z.\-]*))?'
    r'$',
  );

  /// Parses [input], returning `null` when it is not version-like.
  ///
  /// Tolerates leading `v`, missing minor/patch, a fourth numeric component
  /// (folded into build metadata), and `-`/`_` separated pre-release tags.
  static SemanticVersion? tryParse(String? input) {
    if (input == null) return null;
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final match = _pattern.firstMatch(trimmed);
    if (match == null) return null;

    final fourth = match.group(4);
    final rawBuild = match.namedGroup('build');
    final build = fourth != null
        ? (rawBuild == null ? fourth : '$fourth.$rawBuild')
        : rawBuild;

    final pre = match.namedGroup('pre');
    return SemanticVersion(
      major: int.parse(match.group(1)!),
      minor: int.tryParse(match.group(2) ?? '0') ?? 0,
      patch: int.tryParse(match.group(3) ?? '0') ?? 0,
      preRelease: pre == null || pre.isEmpty ? const [] : pre.split('.'),
      build: build,
      raw: trimmed,
    );
  }

  /// Parses [input] or falls back to `0.0.0` carrying the raw text.
  ///
  /// Never throws, so callers rendering catalog data from untrusted
  /// repositories cannot be crashed by malformed metadata.
  static SemanticVersion parseOrZero(String? input) =>
      tryParse(input) ??
      SemanticVersion(major: 0, minor: 0, patch: 0, raw: input?.trim() ?? '');

  bool get isPreRelease => preRelease.isNotEmpty;

  /// `true` when this is a `0.x.y` version, where any minor bump may break.
  bool get isUnstable => major == 0;

  @override
  int compareTo(SemanticVersion other) {
    var result = major.compareTo(other.major);
    if (result != 0) return result;
    result = minor.compareTo(other.minor);
    if (result != 0) return result;
    result = patch.compareTo(other.patch);
    if (result != 0) return result;

    // A version without a pre-release outranks one with it.
    if (preRelease.isEmpty && other.preRelease.isEmpty) return 0;
    if (preRelease.isEmpty) return 1;
    if (other.preRelease.isEmpty) return -1;

    final length = preRelease.length > other.preRelease.length
        ? preRelease.length
        : other.preRelease.length;
    for (var i = 0; i < length; i++) {
      if (i >= preRelease.length) return -1;
      if (i >= other.preRelease.length) return 1;
      result = _comparePreReleaseIdentifier(preRelease[i], other.preRelease[i]);
      if (result != 0) return result;
    }
    return 0;
  }

  static int _comparePreReleaseIdentifier(String a, String b) {
    final numA = int.tryParse(a);
    final numB = int.tryParse(b);
    if (numA != null && numB != null) return numA.compareTo(numB);
    // Numeric identifiers always have lower precedence than alphanumerics.
    if (numA != null) return -1;
    if (numB != null) return 1;
    return a.compareTo(b);
  }

  bool operator >(SemanticVersion other) => compareTo(other) > 0;
  bool operator <(SemanticVersion other) => compareTo(other) < 0;
  bool operator >=(SemanticVersion other) => compareTo(other) >= 0;
  bool operator <=(SemanticVersion other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      other is SemanticVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, preRelease.join('.'));

  @override
  String toString() {
    final buffer = StringBuffer('$major.$minor.$patch');
    if (preRelease.isNotEmpty) buffer.write('-${preRelease.join('.')}');
    if (build != null) buffer.write('+$build');
    return buffer.toString();
  }

  /// Classifies the change from [from] to [to].
  ///
  /// Used by the update intelligence system to explain *why* an update
  /// matters instead of only showing two opaque version strings.
  static VersionBumpType classify(String? from, String? to) {
    final a = tryParse(from);
    final b = tryParse(to);
    if (a == null || b == null) {
      if (from?.trim() == to?.trim()) return VersionBumpType.none;
      return VersionBumpType.unknown;
    }
    if (b.major != a.major) return VersionBumpType.major;
    if (b.minor != a.minor) return VersionBumpType.minor;
    if (b.patch != a.patch) return VersionBumpType.patch;
    if (b.preRelease.join('.') != a.preRelease.join('.')) {
      return VersionBumpType.prerelease;
    }
    if ((b.build ?? '') != (a.build ?? '')) return VersionBumpType.build;
    return VersionBumpType.none;
  }

  /// Whether [candidate] is strictly newer than [current].
  static bool isNewer(String? candidate, String? current) {
    final a = tryParse(candidate);
    final b = tryParse(current);
    if (a == null || b == null) {
      // Unparseable versions (nightly builds, date or hash tags): fall back to
      // lexical ordering of the trimmed strings so such releases still
      // surface as "changed" rather than silently never updating.
      final left = candidate?.trim() ?? '';
      final right = current?.trim() ?? '';
      return left.compareTo(right) > 0;
    }
    return a > b;
  }
}
