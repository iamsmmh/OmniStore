import 'package:flutter_test/flutter_test.dart';
import 'package:omnistore/domain/community/community_contracts.dart';

void main() {
  group('capabilities', () {
    test('community features are off by default', () {
      expect(CommunityCapabilities.disabled.anyEnabled, isFalse);
      expect(const CommunityCapabilities().ratings, isFalse);
    });

    test('anyEnabled reflects individual switches', () {
      expect(const CommunityCapabilities(ratings: true).anyEnabled, isTrue);
    });
  });

  group('DisabledCommunityService', () {
    const service = DisabledCommunityService();

    test('returns empty aggregates instead of throwing', () async {
      final rating = await service.ratingFor('app');
      expect(rating.count, 0);
      expect(rating.average, 0);
      expect(await service.reviewsFor('app'), isEmpty);
    });

    test('returns an entry for every requested app', () async {
      final ratings = await service.ratingsFor(['a', 'b']);
      expect(ratings.keys, containsAll(['a', 'b']));
    });

    test('submitting a review is unsupported while disabled', () {
      expect(
        () => service.submitReview(appId: 'a', rating: 5, body: 'Nice'),
        throwsUnsupportedError,
      );
    });

    test('reporting is a silent no-op', () async {
      await service.report(targetId: 'a', reason: 'spam');
    });
  });

  group('RatingSummary confidence', () {
    test('is zero with no votes', () {
      expect(RatingSummary.empty('a').confidenceScore, 0);
    });

    test('ranks many good ratings above few perfect ones', () {
      const few = RatingSummary(appId: 'a', average: 5.0, count: 3);
      const many = RatingSummary(appId: 'b', average: 4.6, count: 500);
      expect(many.confidenceScore, greaterThan(few.confidenceScore));
    });

    test('stays within 0..1', () {
      const summary = RatingSummary(appId: 'a', average: 5.0, count: 10000);
      expect(summary.confidenceScore, inInclusiveRange(0.0, 1.0));
    });
  });

  group('moderation', () {
    const policy = StrictModerationPolicy();

    test('new submissions are pending, never auto-published', () {
      expect(policy.classify('Great app'), ModerationState.pending);
    });

    test('empty submissions are removed', () {
      expect(policy.classify('   '), ModerationState.removed);
    });

    test('only published reviews are displayed', () {
      final pending = Review(
        id: '1',
        appId: 'a',
        authorHandle: 'anon',
        rating: 5,
        body: 'Nice',
        createdAt: DateTime(2026),
      );
      expect(policy.shouldDisplay(pending), isFalse);
      expect(
        policy.shouldDisplay(Review(
          id: '2',
          appId: 'a',
          authorHandle: 'anon',
          rating: 5,
          body: 'Nice',
          createdAt: DateTime(2026),
          moderationState: ModerationState.published,
        )),
        isTrue,
      );
    });
  });
}
