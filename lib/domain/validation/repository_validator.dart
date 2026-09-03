import '../../core/logger/app_logger.dart';
import '../../core/security/security_service.dart';
import '../models/repository_entity.dart';
import '../services/repository_provider.dart';

enum ValidationIssueSeverity { info, warning, error }
enum ValidationIssueCategory { url, feed, metadata, content, security }

class ValidationIssue {
  final String code;
  final String message;
  final String? remediation;
  final ValidationIssueSeverity severity;
  final ValidationIssueCategory category;

  const ValidationIssue({
    required this.code,
    required this.message,
    this.remediation,
    required this.severity,
    required this.category,
  });
}

class ValidationReport {
  final String url;
  final RepositoryType? detectedType;
  final bool isValid;
  final int score; // 0-100
  final List<ValidationIssue> issues;
  final Map<String, dynamic>? metadata;
  final int appCount;
  final Duration validationTime;

  const ValidationReport({
    required this.url,
    this.detectedType,
    required this.isValid,
    required this.score,
    required this.issues,
    this.metadata,
    this.appCount = 0,
    required this.validationTime,
  });

  List<ValidationIssue> get errors => issues.where((i) => i.severity == ValidationIssueSeverity.error).toList();
  List<ValidationIssue> get warnings => issues.where((i) => i.severity == ValidationIssueSeverity.warning).toList();

  bool get hasErrors => errors.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
}

/// Comprehensive repository validation engine.
/// Validates URL format, feed structure, metadata completeness,
/// icon availability, download URLs, version info and integrity.
class RepositoryValidator {
  final SecurityService _securityService;
  final RepositoryProviderRegistry _registry;
  final _logger = AppLogger.getLogger('RepositoryValidator');

  RepositoryValidator({
    required SecurityService securityService,
    required RepositoryProviderRegistry registry,
  })  : _securityService = securityService,
        _registry = registry;

  Future<ValidationReport> validate(String url, {RepositoryType? expectedType}) async {
    final stopwatch = Stopwatch()..start();
    final issues = <ValidationIssue>[];

    // 1. URL format validation
    final urlIssues = _validateUrlFormat(url);
    issues.addAll(urlIssues);
    if (urlIssues.any((i) => i.severity == ValidationIssueSeverity.error)) {
      stopwatch.stop();
      return ValidationReport(
        url: url,
        isValid: false,
        score: 0,
        issues: issues,
        validationTime: stopwatch.elapsed,
      );
    }

    // 2. Provider detection
    RepositoryProvider? provider;
    RepositoryType? detectedType;
    if (expectedType != null) {
      provider = _registry.getProvider(expectedType);
      detectedType = expectedType;
    }
    provider ??= _registry.detectProvider(url);
    detectedType ??= provider?.type;

    if (provider == null) {
      issues.add(const ValidationIssue(
        code: 'no_provider',
        message: 'No provider could handle this URL. It will be treated as a generic JSON feed.',
        severity: ValidationIssueSeverity.info,
        category: ValidationIssueCategory.feed,
      ));
      // Allow generic fallback
      provider = _registry.getProvider(RepositoryType.genericFeed);
      detectedType = RepositoryType.genericFeed;
    }

    if (provider == null) {
      stopwatch.stop();
      return ValidationReport(
        url: url,
        detectedType: detectedType,
        isValid: false,
        score: 20,
        issues: issues,
        validationTime: stopwatch.elapsed,
      );
    }

    // 3. Feed structure validation
    RepositoryValidationData data;
    try {
      data = await provider.validate(url).timeout(const Duration(seconds: 30));
    } catch (e) {
      issues.add(ValidationIssue(
        code: 'fetch_failed',
        message: 'Failed to fetch repository: $e',
        remediation: 'Check that the URL is accessible and returns valid JSON.',
        severity: ValidationIssueSeverity.error,
        category: ValidationIssueCategory.feed,
      ));
      stopwatch.stop();
      return ValidationReport(
        url: url,
        detectedType: detectedType,
        isValid: false,
        score: _calculateScore(issues, 0, 0),
        issues: issues,
        validationTime: stopwatch.elapsed,
      );
    }

    if (!data.isValid) {
      issues.add(const ValidationIssue(
        code: 'invalid_feed',
        message: 'Repository feed structure is invalid or empty',
        remediation: 'Verify the URL points to a supported feed format (AltStore, OmniSource, Feather, GitHub/GitLab releases).',
        severity: ValidationIssueSeverity.error,
        category: ValidationIssueCategory.feed,
      ));
      stopwatch.stop();
      return ValidationReport(
        url: url,
        detectedType: detectedType,
        isValid: false,
        score: _calculateScore(issues, 0, 0),
        issues: issues,
        metadata: data.metadata,
        validationTime: stopwatch.elapsed,
      );
    }

    // 4. Metadata completeness
    final metaIssues = _validateMetadataCompleteness(data);
    issues.addAll(metaIssues);

    // 5. Icon availability (not blocking)
    if (data.iconUrl == null || data.iconUrl!.isEmpty) {
      issues.add(const ValidationIssue(
        code: 'missing_icon',
        message: 'Repository does not provide an icon',
        severity: ValidationIssueSeverity.info,
        category: ValidationIssueCategory.metadata,
      ));
    } else if (!_securityService.validateUrl(data.iconUrl!)) {
      issues.add(ValidationIssue(
        code: 'insecure_icon',
        message: 'Repository icon URL is not HTTPS: ${data.iconUrl}',
        severity: ValidationIssueSeverity.warning,
        category: ValidationIssueCategory.security,
      ));
    }

    // 6. App-level checks by sampling fetchApps
    int appCount = data.appCount;
    try {
      final apps = await provider.fetchApps(url).timeout(const Duration(seconds: 30));
      appCount = apps.length;
      final contentIssues = _validateAppContent(apps);
      issues.addAll(contentIssues);
      if (apps.isEmpty) {
        issues.add(const ValidationIssue(
          code: 'no_apps',
          message: 'Repository contains no apps',
          severity: ValidationIssueSeverity.warning,
          category: ValidationIssueCategory.content,
        ));
      }
    } catch (e) {
      issues.add(ValidationIssue(
        code: 'app_fetch_failed',
        message: 'Failed to fetch app list: $e',
        severity: ValidationIssueSeverity.error,
        category: ValidationIssueCategory.feed,
      ));
    }

    stopwatch.stop();
    final hasError = issues.any((i) => i.severity == ValidationIssueSeverity.error);
    final score = _calculateScore(issues, appCount, data.appCount);

    _logger.info('Validation complete for $url: valid=$hasError score=$score issues=${issues.length}');
    return ValidationReport(
      url: url,
      detectedType: detectedType,
      isValid: !hasError,
      score: score,
      issues: issues,
      metadata: data.metadata,
      appCount: appCount,
      validationTime: stopwatch.elapsed,
    );
  }

  List<ValidationIssue> _validateUrlFormat(String url) {
    final issues = <ValidationIssue>[];
    final uri = Uri.tryParse(url);
    if (uri == null) {
      issues.add(const ValidationIssue(
        code: 'malformed_url',
        message: 'URL is malformed and cannot be parsed',
        remediation: 'Provide a valid HTTPS URL.',
        severity: ValidationIssueSeverity.error,
        category: ValidationIssueCategory.url,
      ));
      return issues;
    }
    if (uri.scheme != 'https') {
      issues.add(ValidationIssue(
        code: 'insecure_scheme',
        message: 'URL scheme is ${uri.scheme}, HTTPS is required',
        remediation: 'Ask the maintainer to publish over HTTPS.',
        severity: ValidationIssueSeverity.error,
        category: ValidationIssueCategory.security,
      ));
    }
    if (uri.host.isEmpty) {
      issues.add(const ValidationIssue(
        code: 'missing_host',
        message: 'URL has no host',
        severity: ValidationIssueSeverity.error,
        category: ValidationIssueCategory.url,
      ));
    }
    if (uri.host.length < 3) {
      issues.add(const ValidationIssue(
        code: 'short_host',
        message: 'Host name looks invalid',
        severity: ValidationIssueSeverity.warning,
        category: ValidationIssueCategory.url,
      ));
    }
    return issues;
  }

  List<ValidationIssue> _validateMetadataCompleteness(RepositoryValidationData data) {
    final issues = <ValidationIssue>[];
    if (data.name.isEmpty) {
      issues.add(const ValidationIssue(
        code: 'missing_name',
        message: 'Repository has no name',
        severity: ValidationIssueSeverity.warning,
        category: ValidationIssueCategory.metadata,
      ));
    }
    if (data.description == null || data.description!.trim().isEmpty) {
      issues.add(const ValidationIssue(
        code: 'missing_description',
        message: 'Repository has no description',
        severity: ValidationIssueSeverity.info,
        category: ValidationIssueCategory.metadata,
      ));
    }
    if (data.appCount == 0) {
      issues.add(const ValidationIssue(
        code: 'empty_repo',
        message: 'Repository metadata reports 0 apps',
        severity: ValidationIssueSeverity.warning,
        category: ValidationIssueCategory.content,
      ));
    }
    return issues;
  }

  List<ValidationIssue> _validateAppContent(List<dynamic> apps) {
    final issues = <ValidationIssue>[];
    if (apps.isEmpty) return issues;
    int missingIcon = 0;
    int missingDownload = 0;
    int httpDownload = 0;
    int invalidVersion = 0;
    int missingChecksum = 0;

    for (final app in apps) {
      final dynamic a = app;
      try {
        final icon = a.iconUrl as String? ?? '';
        final dl = a.downloadUrl as String? ?? '';
        final version = a.version as String? ?? '';
        final sha = a.sha256 as String? ?? '';

        if (icon.isEmpty) missingIcon++;
        if (dl.isEmpty) {
          missingDownload++;
        } else {
          final uri = Uri.tryParse(dl);
          if (uri != null && uri.scheme == 'http') httpDownload++;
        }
        // Validate version via semver parser
        if (version.isEmpty || !_isValidVersion(version)) invalidVersion++;
        if (sha.isEmpty) missingChecksum++;
      } catch (_) {}
    }

    final total = apps.length;
    if (missingIcon / total > 0.3) {
      issues.add(ValidationIssue(
        code: 'many_missing_icons',
        message: '${((missingIcon / total) * 100).round()}% of apps have no icon',
        severity: ValidationIssueSeverity.info,
        category: ValidationIssueCategory.metadata,
      ));
    }
    if (missingDownload > 0) {
      issues.add(ValidationIssue(
        code: 'missing_downloads',
        message: '$missingDownload app(s) have no download URL',
        severity: missingDownload / total > 0.1 ? ValidationIssueSeverity.error : ValidationIssueSeverity.warning,
        category: ValidationIssueCategory.content,
      ));
    }
    if (httpDownload > 0) {
      issues.add(ValidationIssue(
        code: 'insecure_downloads',
        message: '$httpDownload download URL(s) are not HTTPS',
        severity: ValidationIssueSeverity.error,
        category: ValidationIssueCategory.security,
      ));
    }
    if (invalidVersion / total > 0.3) {
      issues.add(ValidationIssue(
        code: 'invalid_versions',
        message: '${((invalidVersion / total) * 100).round()}% of apps have unparseable versions',
        severity: ValidationIssueSeverity.warning,
        category: ValidationIssueCategory.metadata,
      ));
    }
    if (missingChecksum / total > 0.8) {
      issues.add(const ValidationIssue(
        code: 'missing_checksums',
        message: 'Most apps do not publish checksums',
        remediation: 'Integrity cannot be verified for downloads without checksums.',
        severity: ValidationIssueSeverity.warning,
        category: ValidationIssueCategory.security,
      ));
    }
    return issues;
  }

  bool _isValidVersion(String v) {
    if (v.isEmpty) return false;
    final norm = v.replaceFirst(RegExp(r'^v', caseSensitive: false), '');
    // Accept semver or date-based
    if (RegExp(r'^\d+(\.\d+){1,3}').hasMatch(norm)) return true;
    return false;
  }

  int _calculateScore(List<ValidationIssue> issues, int actualCount, int metaCount) {
    var score = 100;
    for (final issue in issues) {
      switch (issue.severity) {
        case ValidationIssueSeverity.error:
          score -= 25;
          break;
        case ValidationIssueSeverity.warning:
          score -= 8;
          break;
        case ValidationIssueSeverity.info:
          score -= 2;
          break;
      }
    }
    if (actualCount == 0 && metaCount == 0) score -= 15;
    return score.clamp(0, 100);
  }
}
