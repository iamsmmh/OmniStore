import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/core/error/failures.dart';

void main() {
  group('Failure classes', () {
    group('NetworkFailure', () {
      test('noConnection creates correct failure', () {
        final failure = NetworkFailure.noConnection();
        expect(failure.message, 'No internet connection');
        expect(failure.code, 'NO_CONNECTION');
      });

      test('timeout creates correct failure', () {
        final failure = NetworkFailure.timeout();
        expect(failure.message, 'Connection timed out');
        expect(failure.code, 'TIMEOUT');
      });

      test('serverError creates correct failure', () {
        final failure = NetworkFailure.serverError(500);
        expect(failure.message, 'Server error (Status: 500)');
        expect(failure.code, 'SERVER_ERROR_500');
      });
    });

    group('RepositoryFailure', () {
      test('invalidUrl creates correct failure', () {
        final failure = RepositoryFailure.invalidUrl();
        expect(failure.message, 'Invalid repository URL');
        expect(failure.code, 'INVALID_URL');
      });

      test('invalidFormat creates correct failure', () {
        final failure = RepositoryFailure.invalidFormat();
        expect(failure.message, 'Invalid repository format');
        expect(failure.code, 'INVALID_FORMAT');
      });

      test('alreadyExists creates correct failure', () {
        final failure = RepositoryFailure.alreadyExists();
        expect(failure.message, 'Repository already exists');
        expect(failure.code, 'ALREADY_EXISTS');
      });
    });

    group('DownloadFailure', () {
      test('integrityCheck creates correct failure', () {
        final failure = DownloadFailure.integrityCheck();
        expect(failure.message, 'Download integrity check failed');
        expect(failure.code, 'INTEGRITY_CHECK_FAILED');
      });

      test('insufficientStorage creates correct failure', () {
        final failure = DownloadFailure.insufficientStorage();
        expect(failure.message, 'Insufficient storage space');
        expect(failure.code, 'INSUFFICIENT_STORAGE');
      });
    });

    group('SecurityFailure', () {
      test('insecureUrl creates correct failure', () {
        final failure = SecurityFailure.insecureUrl();
        expect(failure.message, 'Insecure URL - HTTPS required');
        expect(failure.code, 'INSECURE_URL');
      });

      test('invalidHash creates correct failure', () {
        final failure = SecurityFailure.invalidHash();
        expect(failure.message, 'Hash validation failed');
        expect(failure.code, 'INVALID_HASH');
      });
    });

    group('Equatable', () {
      test('same failures should be equal', () {
        expect(
          NetworkFailure.noConnection(),
          equals(NetworkFailure.noConnection()),
        );
      });

      test('different failures should not be equal', () {
        expect(
          NetworkFailure.noConnection(),
          isNot(equals(NetworkFailure.timeout())),
        );
      });
    });
  });
}
