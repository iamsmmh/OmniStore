// ignore_for_file: type=lint
part of 'download_table.dart';

dynamic DownloadTableSchema() => null;

final _downloadStoreExpando = Expando<dynamic>();

class _FakeDownloadCollection {
  final Map<int, dynamic> _store = {};
  int _nextId = 1;
  List<bool Function(dynamic)> _predicates = [];
  String? _sort;
  int? _offset;
  int? _limit;
  List<List<bool Function(dynamic)>> _orGroups = [];
  bool _orMode = false;
  dynamic where() { _predicates = []; _orGroups = []; _orMode = false; _sort = null; _offset = null; _limit = null; return this; }
  dynamic filter() => this;
  dynamic downloadIdEqualTo(String v) { _predicates.add((d) => d.downloadId == v); return this; }
  dynamic appIdEqualTo(String v) { _predicates.add((d) => d.appId == v); return this; }
  dynamic versionEqualTo(String v) { _predicates.add((d) => d.version == v); return this; }
  dynamic statusEqualTo(String v) { _predicates.add((d) => d.status == v); return this; }
  dynamic and() => this;
  dynamic or() { if (_predicates.isNotEmpty) { _orGroups.add(List.from(_predicates)); _predicates = []; } _orMode = true; return this; }
  dynamic sortByCreatedAtDesc() { _sort = 'createdDesc'; return this; }
  dynamic sortByCreatedAt() { _sort = 'created'; return this; }
  dynamic offset(int v) { _offset = v; return this; }
  dynamic limit(int v) { _limit = v; return this; }
  List<dynamic> _apply() { var items = _store.values.toList(); if (_orGroups.isNotEmpty || _orMode) { final groups = [..._orGroups, if (_predicates.isNotEmpty) List.from(_predicates)]; if (groups.isNotEmpty) items = items.where((d) => groups.any((g) => g.every((p) => p(d)))).toList(); } else if (_predicates.isNotEmpty) { items = items.where((d) => _predicates.every((p) => p(d))).toList(); } if (_sort == 'createdDesc') items.sort((a, b) => (b.createdAt as DateTime).compareTo(a.createdAt as DateTime)); else if (_sort == 'created') items.sort((a, b) => (a.createdAt as DateTime).compareTo(b.createdAt as DateTime)); if (_offset != null && _offset! > 0) { if (_offset! < items.length) items = items.sublist(_offset!); else items = []; } if (_limit != null && items.length > _limit!) items = items.sublist(0, _limit); return items; }
  Future<List<dynamic>> findAll() async => _apply();
  Future<dynamic> findFirst() async { final l = _apply(); return l.isEmpty ? null : l.first; }
  Future<int> count() async => _apply().length;
  Future<int> put(dynamic obj) async { if (obj.id == null) obj.id = _nextId++; try { final existing = _store.values.where((e) => e.downloadId == obj.downloadId).toList(); if (existing.isNotEmpty && existing.first.id != obj.id) obj.id = existing.first.id; } catch (_) {} _store[obj.id as int] = obj; return obj.id as int; }
  Future<bool> delete(int id) async => _store.remove(id) != null;
  Future<int> deleteAll() async { final l = _apply(); for (final d in l) { if (d.id != null) _store.remove(d.id); } return l.length; }
  Future<void> clear() async => _store.clear();
}

extension GetDownloadTableCollection on Isar {
  dynamic get downloadTables => _downloadStoreExpando[this] ??= _FakeDownloadCollection();
}
