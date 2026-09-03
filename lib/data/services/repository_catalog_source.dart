/// [CatalogSource] backed by the local persisted catalog.
///
/// Reads through [AppRepository] rather than touching Isar directly, so the
/// same source works on desktop/web builds that swap the storage engine.
library;

import '../../core/logger/app_logger.dart';
import '../../domain/models/app_entity.dart';
import '../../domain/repositories/app_repository.dart';
import 'discovery_service.dart';

class RepositoryCatalogSource implements CatalogSource {
  final AppRepository _appRepository;

  /// Whether to fetch full app entities (description, tags) while indexing.
  ///
  /// Full detail improves search recall but costs one read per app; on very
  /// large catalogs the caller can index summaries first and enrich later.
  final bool includeFullDetail;

  final _logger = AppLogger.getLogger('RepositoryCatalogSource');

  RepositoryCatalogSource({
    required AppRepository appRepository,
    this.includeFullDetail = true,
  }) : _appRepository = appRepository;

  @override
  Stream<List<CatalogRecord>> streamAll({int chunkSize = 500}) async* {
    var page = 0;
    while (true) {
      final summaries = await _appRepository.getAllApps(
        page: page,
        pageSize: chunkSize,
      );
      if (summaries.isEmpty) return;
      yield await _toRecords(summaries);
      if (summaries.length < chunkSize) return;
      page++;
    }
  }

  @override
  Future<List<CatalogRecord>> changedSince(DateTime? since) async {
    // The catalog exposes recency ordering; anything updated after the last
    // index build is a candidate. Pulling a bounded window keeps delta cost
    // proportional to what actually changed.
    try {
      final recent = await _appRepository.getRecentlyUpdatedApps(limit: 500);
      if (since == null) return _toRecords(recent);
      final changed =
          recent.where((a) => a.releaseDate.isAfter(since)).toList();
      return _toRecords(changed);
    } catch (e, stack) {
      _logger.severe('Failed to compute catalog delta', e, stack);
      return const [];
    }
  }

  Future<List<CatalogRecord>> _toRecords(List<AppSummary> summaries) async {
    final records = <CatalogRecord>[];
    for (final summary in summaries) {
      AppEntity? full;
      if (includeFullDetail) {
        try {
          full = await _appRepository.getAppById(summary.id);
        } catch (_) {
          full = null; // indexing must never fail because of one bad record
        }
      }
      records.add(CatalogRecord(
        id: summary.id,
        name: summary.name,
        developer: summary.developer,
        repositoryId: full?.repositoryId ?? '',
        description: full?.description ?? '',
        categories: summary.categories,
        tags: full?.tags ?? const [],
        aliases: _deriveAliases(summary, full),
        releaseDates: [summary.releaseDate],
      ));
    }
    return records;
  }

  /// Derives searchable aliases users are likely to type: the bundle id's
  /// last segment ("org.videolan.vlc" -> "vlc") and an initialism of the
  /// display name ("Visual Studio Code" -> "vsc").
  static List<String> _deriveAliases(AppSummary summary, AppEntity? full) {
    final aliases = <String>{};
    final bundleId = full?.bundleId ?? summary.bundleId;
    if (bundleId.contains('.')) {
      final last = bundleId.split('.').last;
      if (last.length >= 2) aliases.add(last);
    }
    final words = summary.name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length >= 2) {
      aliases.add(words.map((w) => w[0]).join());
    }
    aliases.remove(summary.name);
    return aliases.toList();
  }
}
