import 'dart:math';
import '../versioning/semantic_version.dart';

/// Utility functions for OmniStore
class AppUtils {
  AppUtils._();

  /// Generate a unique ID
  static String generateId() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    return values.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Compare two version strings using semantic versioning.
  /// Returns: -1 if v1 < v2, 0 if equal, 1 if v1 > v2
  static int compareVersions(String v1, String v2) {
    final a = SemanticVersion.tryParse(v1);
    final b = SemanticVersion.tryParse(v2);
    if (a != null && b != null) {
      return a.compareTo(b);
    }
    // Fallback to lenient numeric comparison for unparseable tags
    return _fallbackCompare(v1, v2);
  }

  static int _fallbackCompare(String v1, String v2) {
    // Strip leading v and build metadata
    String norm(String v) => v.trim().replaceFirst(RegExp(r'^v', caseSensitive: false), '').split('+').first;
    final parts1 = norm(v1).split(RegExp(r'[.\-_]')).map((p) => int.tryParse(p) ?? 0).toList();
    final parts2 = norm(v2).split(RegExp(r'[.\-_]')).map((p) => int.tryParse(p) ?? 0).toList();
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

  /// Sanitize filename for safe filesystem usage
  static String sanitizeFilename(String filename) {
    var sanitized = filename.replaceAll(RegExp(r'[^\w\s.-]'), '_');
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), '_');
    // Prevent directory traversal and hidden files
    sanitized = sanitized.replaceAll('..', '_');
    if (sanitized.startsWith('.')) sanitized = '_$sanitized';
    if (sanitized.isEmpty) return 'file';
    if (sanitized.length > 120) {
      final ext = sanitized.contains('.') ? sanitized.split('.').last : '';
      final base = sanitized.substring(0, 100);
      return ext.isNotEmpty && ext.length < 10 ? '$base.$ext' : base;
    }
    return sanitized;
  }

  /// Get file extension from URL
  static String getExtensionFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    final path = uri.path;
    final lastDot = path.lastIndexOf('.');
    if (lastDot == -1) return '';
    final ext = path.substring(lastDot + 1).toLowerCase();
    // Strip query-like chars that may have been encoded in path
    return ext.split(RegExp(r'[^a-z0-9]')).first;
  }

  /// Sanitize and validate a URL string for safe usage
  static String? sanitizeUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    if (uri.host.isEmpty) return null;
    // Block private/local addresses
    final host = uri.host.toLowerCase();
    if (host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host.startsWith('10.') ||
        host.startsWith('192.168.') ||
        host.startsWith('172.')) {
      return null;
    }
    return uri.toString();
  }
}
