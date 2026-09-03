import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import 'daos/app_dao.dart';
import 'daos/repository_dao.dart';
import 'daos/download_dao.dart';
import 'daos/collection_dao.dart';
import 'tables/app_table.dart';
import 'tables/repository_table.dart';
import 'tables/download_table.dart';
import 'tables/collection_table.dart';

export 'tables/app_table.dart';
export 'tables/repository_table.dart';
export 'tables/download_table.dart';
export 'tables/collection_table.dart';

/// Database provider - initializes and provides Isar instance
final databaseProvider = FutureProvider<Isar>((ref) async {
  final dir = await getApplicationDocumentsDirectory();

  return Isar.open(
    [
      AppTableSchema,
      RepositoryTableSchema,
      DownloadTableSchema,
      CollectionTableSchema,
    ],
    directory: dir.path,
    name: AppConstants.databaseName,
  );
});

/// Database access layer
class DatabaseService {
  final Isar _isar;

  DatabaseService(this._isar);

  late final AppDao appDao = AppDao(_isar);
  late final RepositoryDao repositoryDao = RepositoryDao(_isar);
  late final DownloadDao downloadDao = DownloadDao(_isar);
  late final CollectionDao collectionDao = CollectionDao(_isar);

  Future<void> close() async {
    await _isar.close();
  }

  Future<void> clearAll() async {
    await _isar.writeTxn(() async {
      await _isar.appTables.clear();
      await _isar.repositoryTables.clear();
      await _isar.downloadTables.clear();
      await _isar.collectionTables.clear();
    });
  }
}
