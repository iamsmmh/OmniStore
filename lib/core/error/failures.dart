import 'package:equatable/equatable.dart';

/// Base failure class for error handling
abstract class Failure extends Equatable {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const Failure({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  List<Object?> get props => [message, code, originalError];
}

/// Network-related failures
class NetworkFailure extends Failure {
  const NetworkFailure({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory NetworkFailure.noConnection() => const NetworkFailure(
        message: 'No internet connection',
        code: 'NO_CONNECTION',
      );

  factory NetworkFailure.timeout() => const NetworkFailure(
        message: 'Connection timed out',
        code: 'TIMEOUT',
      );

  factory NetworkFailure.serverError(int statusCode) => NetworkFailure(
        message: 'Server error (Status: $statusCode)',
        code: 'SERVER_ERROR_$statusCode',
      );

  factory NetworkFailure.notFound() => const NetworkFailure(
        message: 'Resource not found',
        code: 'NOT_FOUND',
      );
}

/// Repository-related failures
class RepositoryFailure extends Failure {
  const RepositoryFailure({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory RepositoryFailure.invalidUrl() => const RepositoryFailure(
        message: 'Invalid repository URL',
        code: 'INVALID_URL',
      );

  factory RepositoryFailure.invalidFormat() => const RepositoryFailure(
        message: 'Invalid repository format',
        code: 'INVALID_FORMAT',
      );

  factory RepositoryFailure.notAccessible() => const RepositoryFailure(
        message: 'Repository not accessible',
        code: 'NOT_ACCESSIBLE',
      );

  factory RepositoryFailure.alreadyExists() => const RepositoryFailure(
        message: 'Repository already exists',
        code: 'ALREADY_EXISTS',
      );

  factory RepositoryFailure.maxReached() => const RepositoryFailure(
        message: 'Maximum number of repositories reached',
        code: 'MAX_REPOSITORIES',
      );
}

/// Download-related failures
class DownloadFailure extends Failure {
  const DownloadFailure({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory DownloadFailure.fileNotFound() => const DownloadFailure(
        message: 'File not found',
        code: 'FILE_NOT_FOUND',
      );

  factory DownloadFailure.insufficientStorage() => const DownloadFailure(
        message: 'Insufficient storage space',
        code: 'INSUFFICIENT_STORAGE',
      );

  factory DownloadFailure.integrityCheck() => const DownloadFailure(
        message: 'Download integrity check failed',
        code: 'INTEGRITY_CHECK_FAILED',
      );

  factory DownloadFailure.cancelled() => const DownloadFailure(
        message: 'Download cancelled',
        code: 'CANCELLED',
      );

  factory DownloadFailure.alreadyExists() => const DownloadFailure(
        message: 'Download already exists',
        code: 'DUPLICATE_DOWNLOAD',
      );
}

/// Security-related failures
class SecurityFailure extends Failure {
  const SecurityFailure({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory SecurityFailure.insecureUrl() => const SecurityFailure(
        message: 'Insecure URL - HTTPS required',
        code: 'INSECURE_URL',
      );

  factory SecurityFailure.invalidHash() => const SecurityFailure(
        message: 'Hash validation failed',
        code: 'INVALID_HASH',
      );

  factory SecurityFailure.invalidMetadata() => const SecurityFailure(
        message: 'Invalid metadata',
        code: 'INVALID_METADATA',
      );
}

/// Database-related failures
class DatabaseFailure extends Failure {
  const DatabaseFailure({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory DatabaseFailure.notInitialized() => const DatabaseFailure(
        message: 'Database not initialized',
        code: 'NOT_INITIALIZED',
      );

  factory DatabaseFailure.corrupted() => const DatabaseFailure(
        message: 'Database corrupted',
        code: 'CORRUPTED',
      );
}

/// Generic unexpected failures
class UnexpectedFailure extends Failure {
  const UnexpectedFailure({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });
}
