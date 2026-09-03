
import '../tables/collection_table.dart';

/// Data Access Object for collection operations
class CollectionDao {
  final dynamic _isar;

  CollectionDao(this._isar);

  /// Get all collections
  Future<List<CollectionTable>> getAll() async {
    return _isar.collectionTables.where().findAll();
  }

  /// Get collection by ID
  Future<CollectionTable?> getById(String collectionId) async {
    return _isar.collectionTables
        .where()
        .filter()
        .collectionIdEqualTo(collectionId)
        .findFirst();
  }

  /// Save collection
  Future<void> save(CollectionTable collection) async {
    await _isar.writeTxn(() async {
      await _isar.collectionTables.put(collection);
    });
  }

  /// Add app to collection
  Future<void> addAppToCollection(
    String collectionId,
    String appId,
  ) async {
    final collection = await getById(collectionId);
    if (collection != null && !collection.appIds.contains(appId)) {
      await _isar.writeTxn(() async {
        collection.appIds.add(appId);
        collection.updatedAt = DateTime.now();
        await _isar.collectionTables.put(collection);
      });
    }
  }

  /// Remove app from collection
  Future<void> removeAppFromCollection(
    String collectionId,
    String appId,
  ) async {
    final collection = await getById(collectionId);
    if (collection != null) {
      await _isar.writeTxn(() async {
        collection.appIds.remove(appId);
        collection.updatedAt = DateTime.now();
        await _isar.collectionTables.put(collection);
      });
    }
  }

  /// Delete collection
  Future<void> delete(String collectionId) async {
    await _isar.writeTxn(() async {
      final collection = await getById(collectionId);
      if (collection != null) {
        await _isar.collectionTables.delete(collection.id!);
      }
    });
  }
}
