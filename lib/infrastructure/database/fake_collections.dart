// ignore_for_file: type=lint
// Dynamic fake collections to enable compilation without Isar codegen.
// Uses dynamic to avoid circular imports.

class FakeAppCollection {
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
  dynamic appIdEqualTo(String v) { _predicates.add((a) => a.appId == v); return this; }
  dynamic repositoryIdEqualTo(String v) { _predicates.add((a) => a.repositoryId == v); return this; }
  dynamic repositoryIdNotEqualTo(String v) { _predicates.add((a) => a.repositoryId != v); return this; }
  dynamic isFavoriteEqualTo(bool v) { _predicates.add((a) => a.isFavorite == v); return this; }
  dynamic isInstalledEqualTo(bool v) { _predicates.add((a) => a.isInstalled == v); return this; }
  dynamic categoriesContains(String v) { _predicates.add((a) => (a.categories as List).contains(v)); return this; }
  dynamic nameContains(String v, {bool caseSensitive = true}) {
    final q = caseSensitive ? v : v.toLowerCase();
    _predicates.add((a) => caseSensitive ? (a.name as String).contains(q) : (a.name as String).toLowerCase().contains(q));
    return this;
  }
  dynamic developerContains(String v, {bool caseSensitive = true}) {
    final q = caseSensitive ? v : v.toLowerCase();
    _predicates.add((a) => caseSensitive ? (a.developer as String).contains(q) : (a.developer as String).toLowerCase().contains(q));
    return this;
  }
  dynamic descriptionContains(String v, {bool caseSensitive = true}) {
    final q = caseSensitive ? v : v.toLowerCase();
    _predicates.add((a) => caseSensitive ? (a.description as String).contains(q) : (a.description as String).toLowerCase().contains(q));
    return this;
  }
  dynamic and() => this;
  dynamic or() { if (_predicates.isNotEmpty) { _orGroups.add(List.from(_predicates)); _predicates = []; } _orMode = true; return this; }
  dynamic sortByReleaseDateDesc() { _sort = 'releaseDateDesc'; return this; }
  dynamic sortByReleaseDate() { _sort = 'releaseDate'; return this; }
  dynamic offset(int v) { _offset = v; return this; }
  dynamic limit(int v) { _limit = v; return this; }

  List<dynamic> _apply() {
    var items = _store.values.toList();
    if (_orGroups.isNotEmpty || _orMode) {
      final groups = [..._orGroups, if (_predicates.isNotEmpty) List.from(_predicates)];
      if (groups.isNotEmpty) items = items.where((a) => groups.any((g) => g.every((p) => p(a)))).toList();
    } else if (_predicates.isNotEmpty) {
      items = items.where((a) => _predicates.every((p) => p(a))).toList();
    }
    if (_sort == 'releaseDateDesc') items.sort((a, b) => (b.releaseDate as DateTime).compareTo(a.releaseDate as DateTime));
    else if (_sort == 'releaseDate') items.sort((a, b) => (a.releaseDate as DateTime).compareTo(b.releaseDate as DateTime));
    if (_offset != null && _offset! > 0) { if (_offset! < items.length) items = items.sublist(_offset!); else items = []; }
    if (_limit != null && items.length > _limit!) items = items.sublist(0, _limit);
    return items;
  }

  Future<List<dynamic>> findAll() async => _apply();
  Future<dynamic> findFirst() async { final l = _apply(); return l.isEmpty ? null : l.first; }
  Future<int> count() async => _apply().length;
  Future<int> put(dynamic obj) async {
    if (obj.id == null) obj.id = _nextId++;
    // handle unique appId
    try {
      final existing = _store.values.where((e) => e.appId == obj.appId).toList();
      if (existing.isNotEmpty && existing.first.id != obj.id) obj.id = existing.first.id;
    } catch (_) {}
    _store[obj.id as int] = obj;
    return obj.id as int;
  }
  Future<List<int>> putAll(List<dynamic> objs) async { final ids = <int>[]; for (final o in objs) ids.add(await put(o)); return ids; }
  Future<bool> delete(int id) async => _store.remove(id) != null;
  Future<int> deleteAll() async { final l = _apply(); for (final a in l) { if (a.id != null) _store.remove(a.id); } return l.length; }
  Future<void> clear() async => _store.clear();
}

class FakeRepositoryCollection {
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
  List<dynamic> _apply() {
    var items = _store.values.toList();
    if (_predicates.isNotEmpty) items = items.where((r) => _predicates.every((p) => p(r))).toList();
    if (_offset != null && _offset! > 0) { if (_offset! < items.length) items = items.sublist(_offset!); else items = []; }
    if (_limit != null && items.length > _limit!) items = items.sublist(0, _limit);
    return items;
  }
  Future<List<dynamic>> findAll() async => _apply();
  Future<dynamic> findFirst() async { final l = _apply(); return l.isEmpty ? null : l.first; }
  Future<int> count() async => _apply().length;
  Future<int> put(dynamic obj) async { if (obj.id == null) obj.id = _nextId++; try { final existing = _store.values.where((e) => e.repositoryId == obj.repositoryId).toList(); if (existing.isNotEmpty && existing.first.id != obj.id) obj.id = existing.first.id; } catch (_) {} _store[obj.id as int] = obj; return obj.id as int; }
  Future<bool> delete(int id) async => _store.remove(id) != null;
  Future<void> clear() async => _store.clear();
}

class FakeDownloadCollection {
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
  List<dynamic> _apply() {
    var items = _store.values.toList();
    if (_orGroups.isNotEmpty || _orMode) {
      final groups = [..._orGroups, if (_predicates.isNotEmpty) List.from(_predicates)];
      if (groups.isNotEmpty) items = items.where((d) => groups.any((g) => g.every((p) => p(d)))).toList();
    } else if (_predicates.isNotEmpty) {
      items = items.where((d) => _predicates.every((p) => p(d))).toList();
    }
    if (_sort == 'createdDesc') items.sort((a, b) => (b.createdAt as DateTime).compareTo(a.createdAt as DateTime));
    else if (_sort == 'created') items.sort((a, b) => (a.createdAt as DateTime).compareTo(b.createdAt as DateTime));
    if (_offset != null && _offset! > 0) { if (_offset! < items.length) items = items.sublist(_offset!); else items = []; }
    if (_limit != null && items.length > _limit!) items = items.sublist(0, _limit);
    return items;
  }
  Future<List<dynamic>> findAll() async => _apply();
  Future<dynamic> findFirst() async { final l = _apply(); return l.isEmpty ? null : l.first; }
  Future<int> count() async => _apply().length;
  Future<int> put(dynamic obj) async { if (obj.id == null) obj.id = _nextId++; try { final existing = _store.values.where((e) => e.downloadId == obj.downloadId).toList(); if (existing.isNotEmpty && existing.first.id != obj.id) obj.id = existing.first.id; } catch (_) {} _store[obj.id as int] = obj; return obj.id as int; }
  Future<bool> delete(int id) async => _store.remove(id) != null;
  Future<int> deleteAll() async { final l = _apply(); for (final d in l) { if (d.id != null) _store.remove(d.id); } return l.length; }
  Future<void> clear() async => _store.clear();
}

class FakeCollectionCollection {
  final Map<int, dynamic> _store = {};
  int _nextId = 1;
  List<bool Function(dynamic)> _predicates = [];
  dynamic where() { _predicates = []; return this; }
  dynamic filter() => this;
  dynamic collectionIdEqualTo(String v) { _predicates.add((c) => c.collectionId == v); return this; }
  List<dynamic> _apply() {
    var items = _store.values.toList();
    if (_predicates.isNotEmpty) items = items.where((c) => _predicates.every((p) => p(c))).toList();
    return items;
  }
  Future<List<dynamic>> findAll() async => _apply();
  Future<dynamic> findFirst() async { final l = _apply(); return l.isEmpty ? null : l.first; }
  Future<int> put(dynamic obj) async { if (obj.id == null) obj.id = _nextId++; _store[obj.id as int] = obj; return obj.id as int; }
  Future<bool> delete(int id) async => _store.remove(id) != null;
  Future<void> clear() async => _store.clear();
}
