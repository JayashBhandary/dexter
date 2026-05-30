import 'dart:convert';

import 'package:mongo_dart/mongo_dart.dart' as m;

import '../../core/capabilities.dart';
import '../../core/cell_value.dart';
import '../../core/errors.dart';
import '../../core/page.dart';
import '../../core/query_spec.dart';
import '../../domain/connection_record.dart';
import '../../domain/connection_secrets.dart';
import '../data_source.dart';
import 'mongo_query_translator.dart';

class MongoDataSource extends DataSource
    with RawQueryable, Writable, SchemaReadable {
  MongoDataSource({required this.record, required this.secrets});

  final ConnectionRecord record;
  final ConnectionSecrets? secrets;
  m.Db? _db;

  static const _schemaSampleSize = 50;
  static const _idField = '_id';

  @override
  String get id => record.id;
  @override
  String get displayName => record.name;
  @override
  DataSourceKind get kind => DataSourceKind.mongo;
  @override
  Set<Capability> get capabilities => const {
        Capability.rawQuery,
        Capability.write,
        Capability.schemaRead,
      };

  m.Db get _open {
    final d = _db;
    if (d == null) throw const ConnectError('Not connected');
    return d;
  }

  String _buildUri() {
    final host = record.config['host'] as String? ?? 'localhost';
    final port = (record.config['port'] as num?)?.toInt() ?? 27017;
    final database = record.config['database'] as String? ?? 'admin';
    final username = record.config['username'] as String?;
    final tls = (record.config['tls'] as bool?) ?? false;
    final auth = (username == null || username.isEmpty)
        ? ''
        : '${Uri.encodeComponent(username)}'
          '${secrets?.password == null || secrets!.password!.isEmpty ? '' : ':${Uri.encodeComponent(secrets!.password!)}'}'
          '@';
    final query = tls ? '?tls=true' : '';
    return 'mongodb://$auth$host:$port/$database$query';
  }

  @override
  Future<void> connect() async {
    try {
      _db = await m.Db.create(_buildUri());
      await _db!.open();
    } catch (e, st) {
      throw ConnectError('Mongo connect failed: $e', cause: e, stack: st);
    }
  }

  @override
  Future<void> disconnect() async {
    final d = _db;
    _db = null;
    if (d != null) await d.close();
  }

  @override
  Future<void> ping() async {
    await _open.runCommand({'ping': 1});
  }

  @override
  Future<void> dispose() => disconnect();

  @override
  Future<List<ContainerRef>> listContainers() async {
    final names = await _open.getCollectionNames();
    return [
      for (final n in names.whereType<String>())
        ContainerRef(name: n, subtype: 'collection'),
    ];
  }

  Object? _toPlain(Object? v) {
    if (v == null) return null;
    if (v is m.ObjectId) return v.oid;
    if (v is DateTime) return v;
    if (v is Map) {
      return {for (final e in v.entries) e.key.toString(): _toPlain(e.value)};
    }
    if (v is List) return v.map(_toPlain).toList();
    return v;
  }

  RowData _docToRow(Map<String, dynamic> doc) {
    final out = <String, CellValue>{};
    for (final e in doc.entries) {
      out[e.key] = CellValue.fromDynamic(_toPlain(e.value));
    }
    return out;
  }

  @override
  Future<Page<RowData>> listRows(ContainerRef container, QuerySpec spec) async {
    final coll = _open.collection(container.name);
    final filter = querySpecToFilter(spec);
    final sort = querySpecToSort(spec);
    final builder = m.SelectorBuilder();
    if (filter.isNotEmpty) builder.raw(filter);
    if (sort.isNotEmpty) {
      for (final e in sort.entries) {
        builder.sortBy(e.key, descending: (e.value as int) == -1);
      }
    }
    builder.skip(spec.offset).limit(spec.limit);
    final docs = await coll.find(builder).toList();
    final rows = [for (final d in docs) _docToRow(d)];
    final more = rows.length == spec.limit;
    return Page(
      items: rows,
      nextCursor: more ? (spec.offset + spec.limit).toString() : null,
    );
  }

  Object _idValue(CellValue cell) {
    final s = cell.display();
    // Try ObjectId hex first; else use raw string.
    if (s.length == 24 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(s)) {
      try {
        return m.ObjectId.fromHexString(s);
      } catch (_) {}
    }
    return cell.toBindable() ?? s;
  }

  @override
  Future<RowData?> getRow(ContainerRef container, RowId id) async {
    final selector = <String, Object?>{
      for (final e in id.fields.entries)
        e.key: e.key == _idField ? _idValue(e.value) : e.value.toBindable(),
    };
    final coll = _open.collection(container.name);
    final doc = await coll.findOne(m.SelectorBuilder()..raw(selector));
    if (doc == null) return null;
    return _docToRow(doc);
  }

  Map<String, Object?> _docFromValues(Map<String, CellValue> values) {
    return {
      for (final e in values.entries)
        if (e.value is! NullCell)
          e.key: e.key == _idField ? _idValue(e.value) : e.value.toBindable(),
    };
  }

  @override
  Future<RowId> insertRow(
      ContainerRef container, Map<String, CellValue> values) async {
    final coll = _open.collection(container.name);
    final doc = _docFromValues(values);
    // Remove _id if empty so server generates ObjectId.
    if (doc[_idField] == null || (doc[_idField] is String && (doc[_idField] as String).isEmpty)) {
      doc.remove(_idField);
    }
    try {
      final r = await coll.insertOne(doc);
      if (!r.isSuccess) {
        throw QueryError(r.writeError?.errmsg ?? 'Insert failed');
      }
      final id = r.id;
      return RowId({_idField: CellValue.fromDynamic(_toPlain(id))});
    } on m.MongoDartError catch (e, st) {
      throw QueryError(e.message, cause: e, stack: st);
    }
  }

  @override
  Future<int> updateRow(
      ContainerRef container, RowId id, Map<String, CellValue> values) async {
    final coll = _open.collection(container.name);
    final selector = <String, Object?>{
      for (final e in id.fields.entries)
        e.key: e.key == _idField ? _idValue(e.value) : e.value.toBindable(),
    };
    final setDoc = <String, Object?>{
      for (final e in values.entries)
        if (e.key != _idField) e.key: e.value.toBindable(),
    };
    try {
      final r = await coll.updateOne(selector, {r'$set': setDoc});
      if (r.hasWriteErrors) {
        throw QueryError(r.writeError?.errmsg ?? 'Update failed');
      }
      return r.nModified;
    } on m.MongoDartError catch (e, st) {
      throw QueryError(e.message, cause: e, stack: st);
    }
  }

  @override
  Future<int> deleteRow(ContainerRef container, RowId id) async {
    final coll = _open.collection(container.name);
    final selector = <String, Object?>{
      for (final e in id.fields.entries)
        e.key: e.key == _idField ? _idValue(e.value) : e.value.toBindable(),
    };
    try {
      final r = await coll.deleteOne(selector);
      if (r.hasWriteErrors) {
        throw QueryError(r.writeError?.errmsg ?? 'Delete failed');
      }
      return r.nRemoved;
    } on m.MongoDartError catch (e, st) {
      throw QueryError(e.message, cause: e, stack: st);
    }
  }

  @override
  Future<QueryResult> runRawQuery(String text,
      [List<Object?> params = const []]) async {
    final sw = Stopwatch()..start();
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const QueryError('Empty query');
    }
    try {
      // Convention: prefix `collection:<name>:` then JSON filter or pipeline.
      // Example: `collection:users:{"age": {"$gt": 18}}`
      //          `collection:orders:[{"$group": {"_id": "$status", "n": {"$sum": 1}}}]`
      String collName;
      String body;
      final m1 = RegExp(r'^collection:([A-Za-z_][\w.-]*):(.*)$', dotAll: true)
          .firstMatch(trimmed);
      if (m1 != null) {
        collName = m1.group(1)!;
        body = m1.group(2)!.trim();
      } else {
        throw const QueryError(
            'Use: collection:<name>:<json-filter or pipeline>');
      }
      final coll = _open.collection(collName);
      final parsed = jsonDecode(body);
      List<Map<String, dynamic>> docs;
      if (parsed is List) {
        final pipeline = parsed
            .map((e) => Map<String, Object>.from(e as Map))
            .toList();
        docs = await coll.aggregateToStream(pipeline).toList();
      } else if (parsed is Map) {
        final filter = Map<String, dynamic>.from(parsed);
        docs = await coll.find(m.SelectorBuilder()..raw(filter)).toList();
      } else {
        throw const QueryError('Body must be JSON object or array');
      }
      final cols = <String>{};
      for (final d in docs) {
        cols.addAll(d.keys);
      }
      return QueryResult(
        columns: cols.toList(),
        rows: [for (final d in docs) _docToRow(d)],
        elapsed: sw.elapsed,
      );
    } on FormatException catch (e, st) {
      throw QueryError('Invalid JSON: ${e.message}', cause: e, stack: st);
    } on m.MongoDartError catch (e, st) {
      throw QueryError(e.message, cause: e, stack: st);
    }
  }

  @override
  Future<ContainerSchema> getSchema(ContainerRef container) async {
    final coll = _open.collection(container.name);
    final docs = await coll
        .find(m.SelectorBuilder()..limit(_schemaSampleSize))
        .toList();
    final counts = <String, int>{};
    final typeLabels = <String, Set<String>>{};
    for (final d in docs) {
      for (final e in d.entries) {
        counts[e.key] = (counts[e.key] ?? 0) + 1;
        typeLabels.putIfAbsent(e.key, () => <String>{}).add(_typeOf(e.value));
      }
    }
    final sample = docs.length;
    final columns = <ColumnSchema>[
      for (final entry in counts.entries)
        ColumnSchema(
          name: entry.key,
          typeLabel: typeLabels[entry.key]!.join(' | '),
          nullable: entry.value < sample,
          isPrimaryKey: entry.key == _idField,
          frequency: sample == 0 ? null : entry.value / sample,
        ),
    ];
    return ContainerSchema(container: container, columns: columns);
  }

  String _typeOf(Object? v) {
    if (v == null) return 'null';
    if (v is m.ObjectId) return 'objectId';
    if (v is bool) return 'bool';
    if (v is int) return 'int';
    if (v is double) return 'double';
    if (v is num) return 'number';
    if (v is String) return 'string';
    if (v is DateTime) return 'date';
    if (v is List) return 'array';
    if (v is Map) return 'object';
    return v.runtimeType.toString();
  }
}
