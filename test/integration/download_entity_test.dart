import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/domain/models/download_entity.dart';

void main() {
  group('Download Entity Tests', () {
    test('should create valid download entity', () {
      final download = DownloadEntity(
        id: 'download-123',
        appId: 'app-456',
        appName: 'Test App',
        url: 'https://example.com/download/app.ipa',
        fileName: 'app.ipa',
        savePath: 'downloads',
        totalSize: 1000000,
        downloadedSize: 500000,
        status: DownloadStatus.downloading,
        createdAt: DateTime.now(),
        version: '1.0.0',
      );

      expect(download.id, equals('download-123'));
      expect(download.appName, equals('Test App'));
      expect(download.status, equals(DownloadStatus.downloading));
      expect(download.progressPercentage, equals(50.0));
    });

    test('should calculate progress correctly', () {
      final download = DownloadEntity(
        id: 'progress-test',
        appId: 'app-789',
        appName: 'Progress Test App',
        url: 'https://example.com/download',
        fileName: 'test.ipa',
        savePath: 'downloads',
        totalSize: 100000,
        downloadedSize: 75000,
        status: DownloadStatus.downloading,
        createdAt: DateTime.now(),
      );

      expect(download.progressPercentage, equals(75.0));
    });

    test('should handle zero total size', () {
      final download = DownloadEntity(
        id: 'zero-size',
        appId: 'app-zero',
        appName: 'Zero Size App',
        url: 'https://example.com/download',
        fileName: 'test.ipa',
        savePath: 'downloads',
        totalSize: 0,
        downloadedSize: 0,
        status: DownloadStatus.downloading,
        createdAt: DateTime.now(),
      );

      expect(download.progressPercentage, equals(0.0));
    });

    test('should identify resumable downloads', () {
      final paused = DownloadEntity(
        id: 'paused',
        appId: 'app-paused',
        appName: 'Paused App',
        url: 'https://example.com/download',
        fileName: 'test.ipa',
        savePath: 'downloads',
        totalSize: 100,
        downloadedSize: 50,
        status: DownloadStatus.paused,
        createdAt: DateTime.now(),
      );

      final failed = DownloadEntity(
        id: 'failed',
        appId: 'app-failed',
        appName: 'Failed App',
        url: 'https://example.com/download',
        fileName: 'test.ipa',
        savePath: 'downloads',
        totalSize: 100,
        downloadedSize: 25,
        status: DownloadStatus.failed,
        createdAt: DateTime.now(),
      );

      final downloading = DownloadEntity(
        id: 'downloading',
        appId: 'app-downloading',
        appName: 'Downloading App',
        url: 'https://example.com/download',
        fileName: 'test.ipa',
        savePath: 'downloads',
        totalSize: 100,
        downloadedSize: 50,
        status: DownloadStatus.downloading,
        createdAt: DateTime.now(),
      );

      expect(paused.canResume, isTrue);
      expect(failed.canResume, isTrue);
      expect(downloading.canResume, isFalse);
    });

    test('should identify active downloads', () {
      final downloading = DownloadEntity(
        id: 'active-1',
        appId: 'app-1',
        appName: 'Active App 1',
        url: 'https://example.com/download',
        fileName: 'test1.ipa',
        savePath: 'downloads',
        totalSize: 100,
        downloadedSize: 50,
        status: DownloadStatus.downloading,
        createdAt: DateTime.now(),
      );

      final pending = DownloadEntity(
        id: 'active-2',
        appId: 'app-2',
        appName: 'Active App 2',
        url: 'https://example.com/download',
        fileName: 'test2.ipa',
        savePath: 'downloads',
        totalSize: 100,
        downloadedSize: 0,
        status: DownloadStatus.pending,
        createdAt: DateTime.now(),
      );

      final completed = DownloadEntity(
        id: 'inactive',
        appId: 'app-3',
        appName: 'Inactive App',
        url: 'https://example.com/download',
        fileName: 'test3.ipa',
        savePath: 'downloads',
        totalSize: 100,
        downloadedSize: 100,
        status: DownloadStatus.completed,
        createdAt: DateTime.now(),
      );

      expect(downloading.isActive, isTrue);
      expect(pending.isActive, isTrue);
      expect(completed.isActive, isFalse);
    });

    test('should serialize to JSON correctly', () {
      final download = DownloadEntity(
        id: 'json-test',
        appId: 'app-json',
        appName: 'JSON Test App',
        url: 'https://example.com/download',
        fileName: 'test.ipa',
        savePath: 'downloads',
        totalSize: 500000,
        downloadedSize: 250000,
        status: DownloadStatus.downloading,
        createdAt: DateTime(2024, 1, 15, 10, 30),
        version: '2.0.0',
        sha256: 'abc123',
      );

      final json = download.toJson();

      expect(json['id'], equals('json-test'));
      expect(json['appName'], equals('JSON Test App'));
      expect(json['status'], equals('downloading'));
      expect(json['version'], equals('2.0.0'));
      expect(json['sha256'], equals('abc123'));
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'id': 'from-json',
        'appId': 'app-from-json',
        'appName': 'From JSON App',
        'url': 'https://example.com/download',
        'fileName': 'test.ipa',
        'savePath': 'downloads',
        'totalSize': 1000000,
        'downloadedSize': 0,
        'status': 'pending',
        'createdAt': DateTime(2024, 2, 20).toIso8601String(),
        'version': '1.5.0',
      };

      final download = DownloadEntity.fromJson(json);

      expect(download.id, equals('from-json'));
      expect(download.appName, equals('From JSON App'));
      expect(download.status, equals(DownloadStatus.pending));
      expect(download.version, equals('1.5.0'));
    });

    test('should handle all download statuses', () {
      for (final status in DownloadStatus.values) {
        final download = DownloadEntity(
          id: 'status-${status.name}',
          appId: 'app-status',
          appName: 'Status Test App',
          url: 'https://example.com/download',
          fileName: 'test.ipa',
          savePath: 'downloads',
          totalSize: 100,
          downloadedSize: 50,
          status: status,
          createdAt: DateTime.now(),
        );

        expect(download.status, equals(status));
      }
    });
  });
}
