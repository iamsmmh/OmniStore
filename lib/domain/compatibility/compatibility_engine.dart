import '../../core/versioning/semantic_version.dart';

enum CompatibilityStatus { compatible, warning, incompatible, unknown }

class CompatibilityReport {
  final String appId;
  final String? appMinOsVersion;
  final String? deviceOsVersion;
  final CompatibilityStatus status;
  final String message;
  final List<CompatibilityIssue> issues;

  const CompatibilityReport({
    required this.appId,
    this.appMinOsVersion,
    this.deviceOsVersion,
    required this.status,
    required this.message,
    this.issues = const [],
  });
}

class CompatibilityIssue {
  final String code;
  final String description;
  final CompatibilityStatus severity;

  const CompatibilityIssue({
    required this.code,
    required this.description,
    required this.severity,
  });
}

class ArchitectureInfo {
  final String arch;
  final String? requiredArch;
  final bool matches;

  const ArchitectureInfo({required this.arch, this.requiredArch, required this.matches});
}

/// Engine that evaluates iOS/Android version and architecture compatibility.
class CompatibilityEngine {
  const CompatibilityEngine();

  CompatibilityReport checkCompatibility({
    required String appId,
    String? appMinOsVersion,
    String? appTargetArch,
    String? deviceOsVersion,
    String? deviceArch,
    bool? requiresJailbreak,
  }) {
    final issues = <CompatibilityIssue>[];

    // OS version check
    if (appMinOsVersion != null && appMinOsVersion.isNotEmpty && deviceOsVersion != null && deviceOsVersion.isNotEmpty) {
      final appMin = SemanticVersion.tryParse(appMinOsVersion);
      final device = SemanticVersion.tryParse(deviceOsVersion);
      if (appMin != null && device != null) {
        if (device < appMin) {
          issues.add(CompatibilityIssue(
            code: 'os_too_old',
            description: 'Requires $appMinOsVersion or later (device is $deviceOsVersion)',
            severity: CompatibilityStatus.incompatible,
          ));
        } else if (_isMajorBehind(device, appMin)) {
          issues.add(const CompatibilityIssue(
            code: 'os_near_limit',
            description: 'Device OS version is close to minimum requirement; update recommended.',
            severity: CompatibilityStatus.warning,
          ));
        }
      } else {
        // Fallback string compare
        if (appMinOsVersion != deviceOsVersion) {
          issues.add(CompatibilityIssue(
            code: 'os_unknown',
            description: 'Could not compare OS versions: $appMinOsVersion vs $deviceOsVersion',
            severity: CompatibilityStatus.unknown,
          ));
        }
      }
    } else if (appMinOsVersion != null && appMinOsVersion.isNotEmpty) {
      issues.add(CompatibilityIssue(
        code: 'os_not_checked',
        description: 'Minimum OS: $appMinOsVersion (device version not available)',
        severity: CompatibilityStatus.unknown,
      ));
    }

    // Architecture check
    if (appTargetArch != null && appTargetArch.isNotEmpty && deviceArch != null && deviceArch.isNotEmpty) {
      final appArch = appTargetArch.toLowerCase();
      final devArch = deviceArch.toLowerCase();
      if (appArch != 'universal' && appArch != devArch && !devArch.contains(appArch) && !appArch.contains(devArch)) {
        issues.add(CompatibilityIssue(
          code: 'arch_mismatch',
          description: 'App targets $appTargetArch, device is $deviceArch. May not run or may require translation.',
          severity: CompatibilityStatus.warning,
        ));
      }
    }

    if (requiresJailbreak == true) {
      issues.add(const CompatibilityIssue(
        code: 'jailbreak_required',
        description: 'This app requires a jailbroken device.',
        severity: CompatibilityStatus.warning,
      ));
    }

    final status = _deriveStatus(issues);
    final message = _deriveMessage(status, issues, appMinOsVersion, deviceOsVersion);

    return CompatibilityReport(
      appId: appId,
      appMinOsVersion: appMinOsVersion,
      deviceOsVersion: deviceOsVersion,
      status: status,
      message: message,
      issues: issues,
    );
  }

  bool _isMajorBehind(SemanticVersion device, SemanticVersion min) {
    // If device major is same as min but minor far behind? Simplified.
    return false;
  }

  CompatibilityStatus _deriveStatus(List<CompatibilityIssue> issues) {
    if (issues.any((i) => i.severity == CompatibilityStatus.incompatible)) return CompatibilityStatus.incompatible;
    if (issues.any((i) => i.severity == CompatibilityStatus.warning)) return CompatibilityStatus.warning;
    if (issues.isEmpty) return CompatibilityStatus.compatible;
    if (issues.any((i) => i.severity == CompatibilityStatus.unknown)) return CompatibilityStatus.unknown;
    return CompatibilityStatus.compatible;
  }

  String _deriveMessage(CompatibilityStatus status, List<CompatibilityIssue> issues, String? min, String? device) {
    switch (status) {
      case CompatibilityStatus.compatible:
        return min != null ? 'Compatible with your device (requires $min+)' : 'Compatible with your device';
      case CompatibilityStatus.warning:
        return issues.first.description;
      case CompatibilityStatus.incompatible:
        return issues.first.description;
      case CompatibilityStatus.unknown:
        return 'Compatibility unknown — check requirements';
    }
  }
}

extension CompatibilityStatusDisplay on CompatibilityStatus {
  String get label => switch (this) {
        CompatibilityStatus.compatible => 'Compatible',
        CompatibilityStatus.warning => 'Check required',
        CompatibilityStatus.incompatible => 'Incompatible',
        CompatibilityStatus.unknown => 'Unknown',
      };
}
