// ignore_for_file: type=lint
part of 'repository_table.dart';

dynamic RepositoryTableSchema() => null;

final _repoStoreExpando = Expando<dynamic>();

class _FakeRepoCollection {
  final Map<int, dynamic> _store = {};
  int _nextId = 1;
  List<bool Function(dynamic)> _predicates = [];
  int? _offset;
  int? _limit;
  dynamic where() { _predicates = []; _offset = null; _limit = null; return this; }
  dynamic filter() => this;
  dynamic repositoryIdEqualTo(String v) { _predicates.add((r) => r.repositoryId == v); return this; }
  dynamic urlEqualTo(String v) { _predicates.add((r) => r.url == v); return this; }
  dynamic isEnabledEqualTo(bool v) { _predicates.add((r) => r.isEnabled == v); return this; }
  dynamic offset(int v) { _offset = v; return this; }
  dynamic limit(int v) { _limit = v; return this; }
  dynamic and() => this;
  dynamic or() => this;
  List<dynamic> _apply() { var items = _store.values.toList(); if (_predicates.isNotEmpty) items = items.where((r) => _predicates.every((p) => p(r))).toList(); if (_offset != null && _offset! > 0) { if (_offset! < items.length) items = items.sublist(_offset!); else items = []; } if (_limit != null && items.length > _limit!) items = items.sublist(0, _limit); return items; }
  Future<List<dynamic>> findAll() async => _apply();
  Future<dynamic> findFirst() async { final l = _apply(); return l.isEmpty ? null : l.first; }
  Future<int> count() async => _apply().length;
  Future<int> put(dynamic obj) async { if (obj.id == null) obj.id = _nextId++; try { final existing = _store.values.where((e) => e.repositoryId == obj.repositoryId).toList(); if (existing.isNotEmpty && existing.first.id != obj.id) obj.id = existing.first.id; } catch (_) {} _store[obj.id as int] = obj; return obj.id as int; }
  Future<bool> delete(int id) async => _store.remove(id) != null;
  Future<void> clear() async => _store.clear();
}

extension GetRepositoryTableCollection on Isar {
  dynamic get repositoryTables => _repoStoreExpando[this] ??= _FakeRepoCollection();
}
