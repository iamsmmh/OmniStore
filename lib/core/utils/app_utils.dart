import 'dart:math';

/// Utility functions for OmniStore
class AppUtils {
  AppUtils._();

  /// Generate a unique ID
  static String generateId() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    return values.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Compare two version strings
  /// Returns: -1 if v1 < v2, 0 if equal, 1 if v1 > v2
  static int compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final parts2 = v2.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    final maxLength = max(parts1.length, parts2.length);

    for (int i = 0; i < maxLength; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;

      if (p1 < p2) return -1;
      if (p1 > p2) return 1;
    }

    return 0;
  }

  /// Check if version1 is newer than version2
  static bool isNewerVersion(String version1, String version2) {
    return compareVersions(version1, version2) > 0;
  }

  /// Format bytes to human-readable size
  static String formatBytes(int bytes, [int decimals = 1]) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  /// Truncate string with ellipsis
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Sanitize filename
  static String sanitizeFilename(String filename) {
    return filename.replaceAll(RegExp(r'[^\w\s.-]'), '_');
  }

  /// Get file extension from URL
  static String getExtensionFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    final path = uri.path;
    final lastDot = path.lastIndexOf('.');
    if (lastDot == -1) return '';
    return path.substring(lastDot + 1).toLowerCase();
  }
}
