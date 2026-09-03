import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/core/analytics/analytics.dart';

void main() {
  group('opt-in behaviour', () {
    test('records nothing while disabled', () async {
      final sink = LocalAnalytics();
      final service = AnalyticsService(sink: sink, enabled: false);
      await service.track(AnalyticsEvent.appViewed,
          dimensions: {'appId': 'a'});
      expect(sink.counters, isEmpty);
    });

    test('records once explicitly enabled', () async {
      final sink = LocalAnalytics();
      final service = AnalyticsService(sink: sink)..setEnabled(true);
      await service.track(AnalyticsEvent.appViewed,
          dimensions: {'appId': 'a'});
      expect(sink.counters[AnalyticsEvent.appViewed.name], 1);
    });

    test('disabling clears locally aggregated data', () async {
      final sink = LocalAnalytics();
      final service = AnalyticsService(sink: sink, enabled: true);
      await service.track(AnalyticsEvent.appViewed,
          dimensions: {'appId': 'a'});
      service.setEnabled(false);
      expect(sink.counters, isEmpty);
      expect(sink.appPopularity, isEmpty);
    });

    test('the default sink is a no-op', () async {
      final service = AnalyticsService()..setEnabled(true);
      await service.track(AnalyticsEvent.appViewed);
      await service.flush();
    });
  });

  group('PII sanitisation', () {
    late LocalAnalytics sink;
    late AnalyticsService service;

    setUp(() {
      sink = LocalAnalytics();
      service = AnalyticsService(sink: sink, enabled: true);
    });

    test('drops email addresses', () async {
      await service.track(AnalyticsEvent.searchPerformed,
          dimensions: {'term': 'user@example.com'});
      expect(sink.searchTrends, isEmpty);
    });

    test('drops filesystem paths', () async {
      await service.track(AnalyticsEvent.searchPerformed,
          dimensions: {'term': '/home/alice/secret.txt'});
      expect(sink.searchTrends, isEmpty);
    });

    test('drops URLs containing credentials', () async {
      await service.track(AnalyticsEvent.searchPerformed,
          dimensions: {'term': 'https://alice:pw@example.com'});
      expect(sink.searchTrends, isEmpty);
    });

    test('redacts long hex tokens', () async {
      await service.track(AnalyticsEvent.appViewed,
          dimensions: {'appId': 'a' * 40});
      expect(sink.appPopularity.keys.single, '<redacted>');
    });

    test('truncates over-long values', () async {
      await service.track(AnalyticsEvent.appViewed,
          dimensions: {'appId': 'x' * 200});
      expect(sink.appPopularity.keys.single.length, 64);
    });
  });

  group('aggregation', () {
    test('installs weigh more than views for popularity', () async {
      final sink = LocalAnalytics();
      final service = AnalyticsService(sink: sink, enabled: true);
      await service.track(AnalyticsEvent.appViewed,
          dimensions: {'appId': 'viewed'});
      await service.track(AnalyticsEvent.appInstalled,
          dimensions: {'appId': 'installed'});
      expect(sink.appPopularity['installed'], 1.0);
      expect(sink.appPopularity['viewed'], lessThan(1.0));
    });

    test('counts repository popularity', () async {
      final sink = LocalAnalytics();
      final service = AnalyticsService(sink: sink, enabled: true);
      await service.track(AnalyticsEvent.appViewed,
          dimensions: {'repositoryId': 'r1'});
      await service.track(AnalyticsEvent.appViewed,
          dimensions: {'repositoryId': 'r1'});
      expect(sink.repositoryPopularity['r1'], 2);
    });

    test('only retains search terms seen above the threshold', () async {
      final sink = LocalAnalytics(searchTermThreshold: 2);
      final service = AnalyticsService(sink: sink, enabled: true);
      await service.track(AnalyticsEvent.searchPerformed,
          dimensions: {'term': 'rare'});
      expect(sink.searchTrends, isEmpty);
      await service.track(AnalyticsEvent.searchPerformed,
          dimensions: {'term': 'rare'});
      expect(sink.searchTrends.single.key, 'rare');
    });

    test('bounds the number of retained search terms', () async {
      final sink = LocalAnalytics(maxSearchTerms: 5, searchTermThreshold: 1);
      final service = AnalyticsService(sink: sink, enabled: true);
      for (var i = 0; i < 50; i++) {
        await service.track(AnalyticsEvent.searchPerformed,
            dimensions: {'term': 'term$i'});
      }
      expect(sink.searchTrends.length, lessThanOrEqualTo(5));
    });

    test('search trends are ordered by frequency', () async {
      final sink = LocalAnalytics(searchTermThreshold: 1);
      final service = AnalyticsService(sink: sink, enabled: true);
      await service.track(AnalyticsEvent.searchPerformed,
          dimensions: {'term': 'a'});
      for (var i = 0; i < 3; i++) {
        await service.track(AnalyticsEvent.searchPerformed,
            dimensions: {'term': 'b'});
      }
      expect(sink.searchTrends.first.key, 'b');
    });

    test('empty aggregates when nothing is recorded', () {
      expect(LocalAnalytics().appPopularity, isEmpty);
    });
  });
}
