import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../logger/app_logger.dart';
import '../versioning/semantic_version.dart';

class SecurityService {
  final _logger = AppLogger.getLogger('SecurityService');

  /// Validate SHA256 hash of textual metadata content.
  /// Prefer [validateSha256Bytes] for binary downloads.
  bool validateSha256(String content, String expectedHash) {
    return validateSha256Bytes(utf8.encode(content), expectedHash);
  }

  /// Validate SHA256 hash of binary content against expected hex digest.
  bool validateSha256Bytes(List<int> bytes, String expectedHash) {
    try {
      final normalized = expectedHash.trim().toLowerCase();
      if (!_isValidSha256(normalized)) {
        _logger.warning('SHA256 validation failed: malformed expected hash');
        return false;
      }
      final digest = sha256.convert(bytes).toString();
      final isValid = digest.toLowerCase() == normalized;
      if (!isValid) {
        _logger.warning(
          'SHA256 byte validation failed\nExpected: $normalized\nActual: $digest',
        );
      }
      return isValid;
    } catch (e) {
      _logger.severe('SHA256 byte validation error', e);
      return false;
    }
  }

  bool _isValidSha256(String hash) {
    return RegExp(r'^[0-9a-f]{64}$').hasMatch(hash);
  }

  /// Validate URL scheme and host with security checks.
  /// Enforces HTTPS, rejects empty hosts, private IPs, and dangerous schemes.
  bool validateUrl(String url) {
    try {
      final uri = Uri.tryParse(url.trim());
      if (uri == null) {
        _logger.warning('URL validation failed: unparseable url');
        return false;
      }
      if (uri.scheme != 'https') {
        _logger.warning('URL validation failed: non-HTTPS scheme ${uri.scheme}');
        return false;
      }
      if (uri.host.isEmpty) {
        _logger.warning('URL validation failed: empty host');
        return false;
      }
      if (_isPrivateHost(uri.host)) {
        _logger.warning('URL validation failed: private/local host ${uri.host}');
        return false;
      }
      // Block URLs with credentials
      if (uri.userInfo.isNotEmpty) {
        _logger.warning('URL validation failed: URL contains credentials');
        return false;
      }
      return true;
    } catch (e) {
      _logger.severe('URL validation error', e);
      return false;
    }
  }

  /// Lenient URL sanitization that returns null for unsafe URLs.
  String? sanitizeUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    if (uri.scheme != 'https') return null;
    if (uri.host.isEmpty) return null;
    if (_isPrivateHost(uri.host)) return null;
    if (uri.userInfo.isNotEmpty) return null;
    return uri.toString();
  }

  bool _isPrivateHost(String host) {
    final h = host.toLowerCase();
    if (h == 'localhost' || h == '127.0.0.1' || h == '::1' || h == '0.0.0.0') return true;
    if (h.startsWith('10.')) return true;
    if (h.startsWith('192.168.')) return true;
    if (RegExp(r'^172\.(1[6-9]|2\d|3[0-1])\.').hasMatch(h)) return true;
    if (h.endsWith('.local') || h.endsWith('.internal')) return true;
    return false;
  }

  /// Validate metadata structure with completeness checks.
  bool validateMetadata(Map<String, dynamic> metadata) {
    try {
      const requiredFields = ['id', 'name', 'version'];
      for (final field in requiredFields) {
        if (!metadata.containsKey(field) || metadata[field] == null) {
          _logger.warning('Metadata validation failed: missing $field');
          return false;
        }
        final val = metadata[field].toString().trim();
        if (val.isEmpty) {
          _logger.warning('Metadata validation failed: empty $field');
          return false;
        }
      }
      final version = metadata['version'].toString();
      if (!_isValidVersion(version)) {
        _logger.warning('Metadata validation failed: invalid version $version');
        return false;
      }
      // Validate optional URLs if present
      for (final key in ['downloadUrl', 'iconUrl', 'sourceUrl']) {
        final url = metadata[key];
        if (url is String && url.isNotEmpty) {
          if (Uri.tryParse(url) == null) {
            _logger.warning('Metadata validation failed: invalid url in $key');
            return false;
          }
        }
      }
      return true;
    } catch (e) {
      _logger.severe('Metadata validation error', e);
      return false;
    }
  }

  bool _isValidVersion(String version) {
    // Accept semver-like tags: v1.0, 1.0, 1.0.0, 1.0.0-beta, 1.0.0+build, 2024.05.01
    if (version.trim().isEmpty) return false;
    // Strip leading v
    final v = version.trim().replaceFirst(RegExp(r'^v', caseSensitive: false), '');
    // Use semantic version parser as primary validator
    if (SemanticVersion.tryParse(v) != null) return true;
    // Lenient fallback for date-based or 2-part versions
    final lenient = RegExp(r'^\d+(\.\d+){1,3}([\-+][\w.+\-]+)?$');
    if (lenient.hasMatch(v)) return true;
    // Also allow single number? no, need at least major.minor
    return false;
  }

  /// Validate that download URL is HTTPS and not suspicious.
  bool isSafeDownloadUrl(String url) {
    if (!validateUrl(url)) return false;
    final lower = url.toLowerCase();
    // Block html pages masquerading as downloads if extension is html
    if (lower.endsWith('.html') || lower.endsWith('.htm')) return false;
    return true;
  }

  /// Generate SHA256 hash
  String generateSha256(String content) {
    final bytes = utf8.encode(content);
    return sha256.convert(bytes).toString();
  }

  /// Generate SHA256 hash from bytes
  String generateSha256FromBytes(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }

  /// Check for injection patterns in user input.
  bool isSafeInput(String input) {
    if (input.contains('\x00')) return false;
    // Block obvious script injection in metadata fields
    final lower = input.toLowerCase();
    const dangerous = ['<script', 'javascript:', 'onerror=', 'onload='];
    for (final pattern in dangerous) {
      if (lower.contains(pattern)) return false;
    }
    return true;
  }
}
