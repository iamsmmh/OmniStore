/// Community layer contracts — designed now, deliberately not wired in.
///
/// Ratings, reviews and community collections require a backend, moderation
/// and abuse handling. Shipping them prematurely would couple OmniStore to a
/// service it does not yet have. Instead this file defines the seams:
///
///  * every capability is an interface with a no-op/disabled default;
///  * moderation is a first-class parameter, not an afterthought;
///  * the UI consumes [CommunityCapabilities] to decide what to render, so
///    the feature can be enabled per-deployment without code changes.
library;

/// What a given community backend supports. The UI must gate on this.
class CommunityCapabilities {
  final bool ratings;
  final bool reviews;
  final bool comments;
  final bool communityCollections;
  final bool reporting;

  const CommunityCapabilities({
    this.ratings = false,
    this.reviews = false,
    this.comments = false,
    this.communityCollections = false,
    this.reporting = false,
  });

  /// Default: fully disabled. OmniStore ships in this mode today.
  static const CommunityCapabilities disabled = CommunityCapabilities();

  bool get anyEnabled =>
      ratings || reviews || comments || communityCollections;
}

/// Aggregate rating for an app. Aggregates only — individual votes never need
/// to be exposed to the client.
class RatingSummary {
  final String appId;
  final double average;
  final int count;

  /// Counts per star value, index 0 == 1 star.
  final List<int> histogram;

  const RatingSummary({
    required this.appId,
    required this.average,
    required this.count,
    this.histogram = const [0, 0, 0, 0, 0],
  });

  static RatingSummary empty(String appId) =>
      RatingSummary(appId: appId, average: 0, count: 0);

  /// Wilson lower bound: ranks a 5-star/3-vote app below a 4.6/500 app.
  /// Prevents brand-new or brigaded entries dominating community rankings.
  double get confidenceScore {
    if (count == 0) return 0;
    final positive = average / 5.0;
    const z = 1.96;
    final n = count.toDouble();
    final denominator = 1 + z * z / n;
    final centre = positive + z * z / (2 * n);
    final margin = z *
        _sqrt(positive * (1 - positive) / n + z * z / (4 * n * n));
    return ((centre - margin) / denominator).clamp(0.0, 1.0);
  }

  static double _sqrt(double value) => value <= 0 ? 0 : _newtonSqrt(value);

  static double _newtonSqrt(double value) {
    var guess = value;
    for (var i = 0; i < 20; i++) {
      guess = 0.5 * (guess + value / guess);
    }
    return guess;
  }
}

enum ModerationState { pending, published, hidden, removed }

class Review {
  final String id;
  final String appId;

  /// Pseudonymous display handle supplied by the backend. OmniStore never
  /// derives this from device or account data locally.
  final String authorHandle;

  final int rating;
  final String body;
  final DateTime createdAt;
  final ModerationState moderationState;

  /// Version the review refers to — reviews of old versions are down-weighted
  /// rather than deleted.
  final String? appVersion;

  const Review({
    required this.id,
    required this.appId,
    required this.authorHandle,
    required this.rating,
    required this.body,
    required this.createdAt,
    this.moderationState = ModerationState.pending,
    this.appVersion,
  });

  bool get isVisible => moderationState == ModerationState.published;
}

/// Read/write access to community content. Implementations are optional.
abstract class CommunityService {
  CommunityCapabilities get capabilities;

  Future<RatingSummary> ratingFor(String appId);
  Future<Map<String, RatingSummary>> ratingsFor(List<String> appIds);
  Future<List<Review>> reviewsFor(String appId, {int page, int pageSize});

  /// Submissions enter [ModerationState.pending] unless the backend
  /// auto-publishes; callers must render the pending state honestly.
  Future<Review> submitReview({
    required String appId,
    required int rating,
    required String body,
    String? appVersion,
  });

  Future<void> report({
    required String targetId,
    required String reason,
  });
}

/// Default implementation used while the community layer is disabled.
///
/// Returning empty aggregates (rather than throwing) means UI code can be
/// written once and simply renders nothing when the feature is off.
class DisabledCommunityService implements CommunityService {
  const DisabledCommunityService();

  @override
  CommunityCapabilities get capabilities => CommunityCapabilities.disabled;

  @override
  Future<RatingSummary> ratingFor(String appId) async =>
      RatingSummary.empty(appId);

  @override
  Future<Map<String, RatingSummary>> ratingsFor(List<String> appIds) async =>
      {for (final id in appIds) id: RatingSummary.empty(id)};

  @override
  Future<List<Review>> reviewsFor(String appId, {int page = 0, int pageSize = 20}) async =>
      const [];

  @override
  Future<Review> submitReview({
    required String appId,
    required int rating,
    required String body,
    String? appVersion,
  }) async {
    throw UnsupportedError('Community features are not enabled.');
  }

  @override
  Future<void> report({required String targetId, required String reason}) async {}
}

/// Hook point for moderation, so a backend can be added later without
/// redesigning the data flow. Client-side filtering is a UX nicety, never a
/// substitute for server-side moderation.
abstract class ModerationPolicy {
  /// Returns the state a newly submitted item should take.
  ModerationState classify(String body);

  /// Whether an already-stored item should be displayed to this user.
  bool shouldDisplay(Review review);
}

/// Conservative default: nothing auto-publishes, nothing unpublished shows.
class StrictModerationPolicy implements ModerationPolicy {
  const StrictModerationPolicy();

  @override
  ModerationState classify(String body) =>
      body.trim().isEmpty ? ModerationState.removed : ModerationState.pending;

  @override
  bool shouldDisplay(Review review) => review.isVisible;
}
