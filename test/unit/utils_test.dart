import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/core/utils/app_utils.dart';

void main() {
  group('AppUtils', () {
    group('compareVersions', () {
      test('should return 0 for equal versions', () {
        expect(AppUtils.compareVersions('1.0.0', '1.0.0'), 0);
        expect(AppUtils.compareVersions('2.3.4', '2.3.4'), 0);
      });

      test('should return -1 when v1 < v2', () {
        expect(AppUtils.compareVersions('1.0.0', '1.0.1'), -1);
        expect(AppUtils.compareVersions('1.0.0', '1.1.0'), -1);
        expect(AppUtils.compareVersions('1.0.0', '2.0.0'), -1);
      });

      test('should return 1 when v1 > v2', () {
        expect(AppUtils.compareVersions('1.0.1', '1.0.0'), 1);
        expect(AppUtils.compareVersions('1.1.0', '1.0.0'), 1);
        expect(AppUtils.compareVersions('2.0.0', '1.0.0'), 1);
      });

      test('should handle versions with different lengths', () {
        expect(AppUtils.compareVersions('1.0', '1.0.0'), 0);
        expect(AppUtils.compareVersions('1.0', '1.0.1'), -1);
      });
    });

    group('isNewerVersion', () {
      test('should return true when version1 is newer', () {
        expect(AppUtils.isNewerVersion('1.0.1', '1.0.0'), isTrue);
        expect(AppUtils.isNewerVersion('2.0.0', '1.9.9'), isTrue);
      });

      test('should return false when version1 is not newer', () {
        expect(AppUtils.isNewerVersion('1.0.0', '1.0.1'), isFalse);
        expect(AppUtils.isNewerVersion('1.0.0', '1.0.0'), isFalse);
      });
    });

    group('formatBytes', () {
      test('should format bytes correctly', () {
        expect(AppUtils.formatBytes(0), '0 B');
        expect(AppUtils.formatBytes(500), '500.0 B');
        expect(AppUtils.formatBytes(1024), '1.0 KB');
        expect(AppUtils.formatBytes(1048576), '1.0 MB');
        expect(AppUtils.formatBytes(1073741824), '1.0 GB');
      });

      test('should handle custom decimal places', () {
        expect(AppUtils.formatBytes(1536, 2), '1.50 KB');
      });
    });

    group('truncate', () {
      test('should not truncate short strings', () {
        expect(AppUtils.truncate('hello', 10), 'hello');
      });

      test('should truncate long strings', () {
        expect(AppUtils.truncate('hello world', 5), 'hello...');
      });
    });

    group('getExtensionFromUrl', () {
      test('should extract file extension', () {
        expect(
          AppUtils.getExtensionFromUrl('https://example.com/file.ipa'),
          'ipa',
        );
        expect(
          AppUtils.getExtensionFromUrl('https://example.com/file.apk'),
          'apk',
        );
      });

      test('should handle URLs without extension', () {
        expect(
          AppUtils.getExtensionFromUrl('https://example.com/path'),
          '',
        );
      });

      test('should handle invalid URLs', () {
        expect(AppUtils.getExtensionFromUrl('not-a-url'), '');
      });
    });

    group('generateId', () {
      test('should generate unique IDs', () {
        final id1 = AppUtils.generateId();
        final id2 = AppUtils.generateId();
        expect(id1, isNot(id2));
      });

      test('should generate 32-character hex string', () {
        final id = AppUtils.generateId();
        expect(id.length, 32);
        expect(RegExp(r'^[0-9a-f]+$').hasMatch(id), isTrue);
      });
    });
  });
}
