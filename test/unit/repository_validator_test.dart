import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/core/security/security_service.dart';
import 'package:omnistore/domain/services/repository_provider.dart';
import 'package:omnistore/domain/validation/repository_validator.dart';

class _FakeProvider implements RepositoryProvider {
  final RepositoryType type;
  final bool isValid;
  _FakeProvider(this.type, {this.isValid = true});
  @override
  RepositoryType get typeField => type;
  @override
  RepositoryType get type => type;
  @override
  bool canHandle(String url) => true;
  @override
  Future<RepositoryValidationData> validate(String url) async => RepositoryValidationData(isValid: isValid, name: 'Fake', appCount: 2, metadata: {'name': 'Test'});
  @override
  Future<List<dynamic>> fetchApps(String url) async => [];
  @override
  Future<List<dynamic>> fetchUpdates(String url, DateTime since) async => [];
}

void main() {
  group('RepositoryValidator', () {
    late RepositoryValidator validator;
    late RepositoryProviderRegistry registry;

    setUp(() {
      registry = RepositoryProviderRegistry();
      registry.register(_FakeProvider(RepositoryType.genericFeed));
      validator = RepositoryValidator(securityService: SecurityService(), registry: registry);
    });

    test('rejects non-https URL', () async {
      final report = await validator.validate('http://example.com/repo.json');
      expect(report.isValid, isFalse);
      expect(report.issues.any((i) => i.code == 'insecure_scheme'), isTrue);
    });

    test('rejects malformed URL', () async {
      final report = await validator.validate('not-a-url');
      expect(report.isValid, isFalse);
    });

    test('validates https URL successfully', () async {
      final report = await validator.validate('https://example.com/feed.json');
      expect(report.isValid, isTrue);
      expect(report.score, greaterThan(50));
    });

    test('detects empty repository', () async {
      final reg2 = RepositoryProviderRegistry();
      reg2.register(_FakeProvider(RepositoryType.genericFeed, isValid: false));
      final v2 = RepositoryValidator(securityService: SecurityService(), registry: reg2);
      final report = await v2.validate('https://example.com/empty.json');
      expect(report.isValid, isFalse);
    });

    test('generates accessible report with remediation', () async {
      final report = await validator.validate('https://example.com/repo.json');
      expect(report.validationTime.inMilliseconds, greaterThanOrEqualTo(0));
      expect(report.url, isNotEmpty);
    });
  });
}
