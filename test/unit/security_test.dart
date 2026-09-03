import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/core/security/security_service.dart';

void main() {
  group('SecurityService', () {
    late SecurityService securityService;

    setUp(() {
      securityService = SecurityService();
    });

    group('validateUrl', () {
      test('should accept HTTPS URLs', () {
        expect(securityService.validateUrl('https://example.com'), isTrue);
        expect(
          securityService.validateUrl('https://github.com/owner/repo'),
          isTrue,
        );
      });

      test('should reject HTTP URLs', () {
        expect(securityService.validateUrl('http://example.com'), isFalse);
      });

      test('should reject empty URLs', () {
        expect(securityService.validateUrl(''), isFalse);
      });

      test('should reject URLs without host', () {
        expect(securityService.validateUrl('https://'), isFalse);
      });
    });

    group('validateSha256', () {
      test('should validate correct SHA256 hash', () {
        final content = 'Hello, World!';
        final expectedHash =
            'dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f';
        expect(securityService.validateSha256(content, expectedHash), isTrue);
      });

      test('should reject incorrect SHA256 hash', () {
        final content = 'Hello, World!';
        final wrongHash = '00000000000000000000000000000000';
        expect(
          securityService.validateSha256(content, wrongHash),
          isFalse,
        );
      });
    });

    group('validateMetadata', () {
      test('should validate complete metadata', () {
        final metadata = {
          'id': 'com.example.app',
          'name': 'Example App',
          'version': '1.0.0',
        };
        expect(securityService.validateMetadata(metadata), isTrue);
      });

      test('should reject metadata missing required fields', () {
        final metadata = {
          'name': 'Example App',
        };
        expect(securityService.validateMetadata(metadata), isFalse);
      });

      test('should reject invalid version format', () {
        final metadata = {
          'id': 'com.example.app',
          'name': 'Example App',
          'version': 'invalid',
        };
        expect(securityService.validateMetadata(metadata), isFalse);
      });
    });

    group('generateSha256', () {
      test('should generate correct hash', () {
        final hash = securityService.generateSha256('test');
        expect(hash, isNotEmpty);
        expect(hash.length, 64);
      });
    });
  });
}
