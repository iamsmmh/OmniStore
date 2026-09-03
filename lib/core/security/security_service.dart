import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:omnistore/core/logger/app_logger.dart';

class SecurityService {
  final _logger = AppLogger.getLogger('SecurityService');

  /// Validate SHA256 hash of downloaded content
  bool validateSha256(String content, String expectedHash) {
    try {
      final bytes = utf8.encode(content);
      final digest = sha256.convert(bytes);
      final actualHash = digest.toString();
      
      final isValid = actualHash.toLowerCase() == expectedHash.toLowerCase();
      
      if (!isValid) {
        _logger.warning(
          'SHA256 validation failed\n'
          'Expected: $expectedHash\n'
          'Actual: $actualHash',
        );
      }
      
      return isValid;
    } catch (e) {
      _logger.severe('SHA256 validation error', e);
      return false;
    }
  }

  /// Validate SHA256 hash of binary content
  bool validateSha256Bytes(List<int> bytes, String expectedHash) {
    try {
      final digest = sha256.convert(bytes);
      final actualHash = digest.toString();
      
      final isValid = actualHash.toLowerCase() == expectedHash.toLowerCase();
      
      if (!isValid) {
        _logger.warning(
          'SHA256 byte validation failed\n'
          'Expected: $expectedHash\n'
          'Actual: $actualHash',
        );
      }
      
      return isValid;
    } catch (e) {
      _logger.severe('SHA256 byte validation error', e);
      return false;
    }
  }

  /// Validate URL scheme
  bool validateUrl(String url) {
    try {
      final uri = Uri.parse(url);
      
      // Enforce HTTPS
      if (uri.scheme != 'https') {
        _logger.warning('URL validation failed: non-HTTPS scheme ${uri.scheme}');
        return false;
      }
      
      // Validate host
      if (uri.host.isEmpty) {
        _logger.warning('URL validation failed: empty host');
        return false;
      }
      
      return true;
    } catch (e) {
      _logger.severe('URL validation error', e);
      return false;
    }
  }

  /// Validate metadata structure
  bool validateMetadata(Map<String, dynamic> metadata) {
    try {
      // Required fields
      const requiredFields = ['id', 'name', 'version'];
      
      for (final field in requiredFields) {
        if (!metadata.containsKey(field) || metadata[field] == null) {
          _logger.warning('Metadata validation failed: missing $field');
          return false;
        }
      }
      
      // Validate version format
      final version = metadata['version'] as String;
      if (!_isValidVersion(version)) {
        _logger.warning('Metadata validation failed: invalid version $version');
        return false;
      }
      
      return true;
    } catch (e) {
      _logger.severe('Metadata validation error', e);
      return false;
    }
  }

  bool _isValidVersion(String version) {
    final versionPattern = RegExp(r'^\d+\.\d+\.\d+(-[\w.]+)?$');
    return versionPattern.hasMatch(version);
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
}
