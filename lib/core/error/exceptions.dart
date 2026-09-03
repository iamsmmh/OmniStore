/// Custom exceptions for OmniStore

/// Base exception class
class OmniStoreException implements Exception {
  final String message;
  final String? code;

  const OmniStoreException(this.message, {this.code});

  @override
  String toString() => 'OmniStoreException($code): $message';
}

/// Thrown when a network request fails
class NetworkException extends OmniStoreException {
  final int? statusCode;
  final dynamic responseData;

  const NetworkException(
    super.message, {
    this.statusCode,
    this.responseData,
    super.code,
  });

  @override
  String toString() =>
      'NetworkException($code, status: $statusCode): $message';
}

/// Thrown when no internet connection is available
class NoConnectionException extends NetworkException {
  const NoConnectionException()
      : super('No internet connection', code: 'NO_CONNECTION');
}

/// Thrown when a request times out
class TimeoutException extends NetworkException {
  const TimeoutException() : super('Request timed out', code: 'TIMEOUT');
}

/// Thrown when repository validation fails
class RepositoryValidationException extends OmniStoreException {
  final String url;
  final List<String> errors;

  const RepositoryValidationException(
    super.message, {
    required this.url,
    this.errors = const [],
    super.code,
  });
}

/// Thrown when a download fails
class DownloadException extends OmniStoreException {
  final String? filePath;
  final String? url;

  const DownloadException(
    super.message, {
    this.filePath,
    this.url,
    super.code,
  });
}

/// Thrown when SHA256 validation fails
class HashValidationException extends OmniStoreException {
  final String expectedHash;
  final String actualHash;

  const HashValidationException({
    required this.expectedHash,
    required this.actualHash,
  }) : super(
          'SHA256 validation failed. Expected: $expectedHash, Actual: $actualHash',
          code: 'HASH_MISMATCH',
        );
}

/// Thrown when a feature is not supported
class UnsupportedException extends OmniStoreException {
  const UnsupportedException(super.message, {super.code});
}

/// Thrown when a required configuration is missing
class ConfigurationException extends OmniStoreException {
  const ConfigurationException(super.message, {super.code});
}
