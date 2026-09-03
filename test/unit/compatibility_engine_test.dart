import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/domain/compatibility/compatibility_engine.dart';

void main() {
  group('CompatibilityEngine', () {
    const engine = CompatibilityEngine();

    test('compatible when no constraints', () {
      final report = engine.checkCompatibility(appId: 'test');
      expect(report.status, CompatibilityStatus.compatible);
    });

    test('incompatible when device OS too old', () {
      final report = engine.checkCompatibility(appId: 'test', appMinOsVersion: '17.0', deviceOsVersion: '16.0');
      expect(report.status, CompatibilityStatus.incompatible);
      expect(report.issues.any((i) => i.code == 'os_too_old'), isTrue);
    });

    test('compatible when device OS newer', () {
      final report = engine.checkCompatibility(appId: 'test', appMinOsVersion: '16.0', deviceOsVersion: '17.2');
      expect(report.status, CompatibilityStatus.compatible);
    });

    test('warning for jailbreak required', () {
      final report = engine.checkCompatibility(appId: 'test', requiresJailbreak: true);
      expect(report.status, CompatibilityStatus.warning);
    });

    test('accessible label present', () {
      expect(CompatibilityStatus.compatible.label, isNotEmpty);
      expect(CompatibilityStatus.incompatible.label, isNotEmpty);
    });
  });
}
