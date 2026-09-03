// ignore_for_file: type=lint
part of 'collection_table.dart';

dynamic CollectionTableSchema() => null;

final _collectionStoreExpando = Expando<dynamic>();

class _FakeCollectionCollection {
  final Map<int, dynamic> _store = {};
  int _nextId = 1;
  List<bool Function(dynamic)> _predicates = [];
  dynamic where() { _predicates = []; return this; }
  dynamic filter() => this;
  dynamic collectionIdEqualTo(String v) { _predicates.add((c) => c.collectionId == v); return this; }
  List<dynamic> _apply() { var items = _store.values.toList(); if (_predicates.isNotEmpty) items = items.where((c) => _predicates.every((p) => p(c))).toList(); return items; }
  Future<List<dynamic>> findAll() async => _apply();
  Future<dynamic> findFirst() async { final l = _apply(); return l.isEmpty ? null : l.first; }
  Future<int> put(dynamic obj) async { if (obj.id == null) obj.id = _nextId++; _store[obj.id as int] = obj; return obj.id as int; }
  Future<bool> delete(int id) async => _store.remove(id) != null;
  Future<void> clear() async => _store.clear();
}

extension GetCollectionTableCollection on Isar {
  dynamic get collectionTables => _collectionStoreExpando[this] ??= _FakeCollectionCollection();
}
