import 'package:googleapis/firestore/v1.dart' as fs;
import 'package:googleapis_auth/auth_io.dart' as ga;
import 'package:http/http.dart' as http;

import '../../core/capabilities.dart';
import '../../core/cell_value.dart';
import '../../core/errors.dart';
import '../../core/page.dart';
import '../../core/query_spec.dart';
import '../../domain/connection_record.dart';
import '../../domain/connection_secrets.dart';
import '../data_source.dart';
import 'firestore_value.dart';

class FirestoreDataSource extends DataSource
    with Writable, SchemaReadable {
  FirestoreDataSource({required this.record, required this.secrets});

  final ConnectionRecord record;
  final ConnectionSecrets? secrets;

  http.Client? _client;
  fs.FirestoreApi? _api;
  late String _parent;

  static const _schemaSampleSize = 50;
  static const _idField = '__id';

  @override
  String get id => record.id;
  @override
  String get displayName => record.name;
  @override
  DataSourceKind get kind => DataSourceKind.firestore;
  @override
  Set<Capability> get capabilities => const {
        Capability.write,
        Capability.schemaRead,
      };

  String get _projectId =>
      (record.config['projectId'] as String?) ??
      (throw const ConnectError('Firestore projectId missing'));

  String get _databaseId =>
      (record.config['databaseId'] as String?) ?? '(default)';

  String get _mode => (record.config['mode'] as String?) ?? 'serviceAccount';

  @override
  Future<void> connect() async {
    try {
      _parent = 'projects/$_projectId/databases/$_databaseId/documents';
      if (_mode == 'emulator') {
        final host = (record.config['emulatorHost'] as String?) ?? 'localhost:8080';
        final root = host.startsWith('http') ? host : 'http://$host';
        _client = http.Client();
        _api = fs.FirestoreApi(_client!, rootUrl: '$root/');
      } else {
        final saJson = secrets?.serviceAccountJson;
        if (saJson == null || saJson.isEmpty) {
          throw const ConnectError('Service account JSON missing');
        }
        final creds = ga.ServiceAccountCredentials.fromJson(saJson);
        _client = await ga.clientViaServiceAccount(
          creds,
          [fs.FirestoreApi.datastoreScope],
        );
        _api = fs.FirestoreApi(_client!);
      }
      await ping();
    } catch (e, st) {
      throw ConnectError('Firestore connect failed: $e', cause: e, stack: st);
    }
  }

  @override
  Future<void> disconnect() async {
    _client?.close();
    _client = null;
    _api = null;
  }

  @override
  Future<void> ping() async {
    final api = _api;
    if (api == null) throw const ConnectError('Not connected');
    // Touch the root — listCollectionIds is the cheapest validation.
    await api.projects.databases.documents.listCollectionIds(
      fs.ListCollectionIdsRequest(pageSize: 1),
      _parent,
    );
  }

  @override
  Future<void> dispose() => disconnect();

  fs.FirestoreApi get _open {
    final a = _api;
    if (a == null) throw const ConnectError('Not connected');
    return a;
  }

  @override
  Future<List<ContainerRef>> listContainers() async {
    final res = await _open.projects.databases.documents.listCollectionIds(
      fs.ListCollectionIdsRequest(pageSize: 200),
      _parent,
    );
    final ids = res.collectionIds ?? const <String>[];
    return [
      for (final id in ids)
        ContainerRef(name: id, path: id, subtype: 'collection'),
    ];
  }

  @override
  Future<Page<RowData>> listRows(ContainerRef container, QuerySpec spec) async {
    final collectionId = container.path ?? container.name;
    final res = await _open.projects.databases.documents.list(
      _parent,
      collectionId,
      pageSize: spec.limit,
      pageToken: spec.cursor,
    );
    final docs = res.documents ?? const <fs.Document>[];
    return Page(
      items: [for (final d in docs) _docToRow(d)],
      nextCursor: res.nextPageToken,
    );
  }

  RowData _docToRow(fs.Document d) {
    final out = <String, CellValue>{};
    final id = _idFromName(d.name);
    if (id != null) out[_idField] = StringCell(id);
    final fields = d.fields ?? const <String, fs.Value>{};
    for (final e in fields.entries) {
      out[e.key] = valueToCell(e.value);
    }
    return out;
  }

  String? _idFromName(String? fullName) {
    if (fullName == null) return null;
    final i = fullName.lastIndexOf('/');
    return i < 0 ? fullName : fullName.substring(i + 1);
  }

  @override
  Future<RowData?> getRow(ContainerRef container, RowId id) async {
    final docId = id.fields[_idField]?.display();
    if (docId == null || docId.isEmpty) return null;
    final collectionId = container.path ?? container.name;
    try {
      final d = await _open.projects.databases.documents.get(
        '$_parent/$collectionId/$docId',
      );
      return _docToRow(d);
    } on fs.DetailedApiRequestError catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Map<String, fs.Value> _toFields(Map<String, CellValue> values) => {
        for (final e in values.entries)
          if (e.key != _idField) e.key: cellToValue(e.value),
      };

  @override
  Future<RowId> insertRow(
      ContainerRef container, Map<String, CellValue> values) async {
    final collectionId = container.path ?? container.name;
    final providedId = values[_idField]?.display();
    final doc = fs.Document(fields: _toFields(values));
    try {
      final res = await _open.projects.databases.documents.createDocument(
        doc,
        _parent,
        collectionId,
        documentId: (providedId == null || providedId.isEmpty) ? null : providedId,
      );
      final id = _idFromName(res.name);
      return RowId({if (id != null) _idField: StringCell(id)});
    } on fs.DetailedApiRequestError catch (e, st) {
      throw QueryError(e.message ?? 'Insert failed', cause: e, stack: st);
    }
  }

  @override
  Future<int> updateRow(
      ContainerRef container, RowId id, Map<String, CellValue> values) async {
    final docId = id.fields[_idField]?.display();
    if (docId == null || docId.isEmpty) {
      throw const QueryError('Cannot update: missing __id');
    }
    final collectionId = container.path ?? container.name;
    final fields = _toFields(values);
    try {
      await _open.projects.databases.documents.patch(
        fs.Document(fields: fields),
        '$_parent/$collectionId/$docId',
        updateMask_fieldPaths: fields.keys.toList(),
      );
      return 1;
    } on fs.DetailedApiRequestError catch (e, st) {
      throw QueryError(e.message ?? 'Update failed', cause: e, stack: st);
    }
  }

  @override
  Future<int> deleteRow(ContainerRef container, RowId id) async {
    final docId = id.fields[_idField]?.display();
    if (docId == null || docId.isEmpty) return 0;
    final collectionId = container.path ?? container.name;
    try {
      await _open.projects.databases.documents.delete(
        '$_parent/$collectionId/$docId',
      );
      return 1;
    } on fs.DetailedApiRequestError catch (e, st) {
      throw QueryError(e.message ?? 'Delete failed', cause: e, stack: st);
    }
  }

  @override
  Future<ContainerSchema> getSchema(ContainerRef container) async {
    final collectionId = container.path ?? container.name;
    final res = await _open.projects.databases.documents.list(
      _parent,
      collectionId,
      pageSize: _schemaSampleSize,
    );
    final docs = res.documents ?? const <fs.Document>[];
    final counts = <String, int>{};
    final typeLabels = <String, Set<String>>{};
    for (final d in docs) {
      final fields = d.fields ?? const <String, fs.Value>{};
      for (final e in fields.entries) {
        counts[e.key] = (counts[e.key] ?? 0) + 1;
        typeLabels.putIfAbsent(e.key, () => <String>{}).add(_typeOf(e.value));
      }
    }
    final sample = docs.length;
    final columns = <ColumnSchema>[
      const ColumnSchema(
        name: _idField,
        typeLabel: 'string',
        nullable: false,
        isPrimaryKey: true,
      ),
      for (final entry in counts.entries)
        ColumnSchema(
          name: entry.key,
          typeLabel: typeLabels[entry.key]!.join(' | '),
          nullable: entry.value < sample,
          frequency: sample == 0 ? null : entry.value / sample,
        ),
    ];
    return ContainerSchema(container: container, columns: columns);
  }

  String _typeOf(fs.Value v) {
    if (v.stringValue != null) return 'string';
    if (v.integerValue != null) return 'integer';
    if (v.doubleValue != null) return 'double';
    if (v.booleanValue != null) return 'bool';
    if (v.timestampValue != null) return 'timestamp';
    if (v.bytesValue != null) return 'bytes';
    if (v.referenceValue != null) return 'reference';
    if (v.geoPointValue != null) return 'geopoint';
    if (v.arrayValue != null) return 'array';
    if (v.mapValue != null) return 'map';
    if (v.nullValue != null) return 'null';
    return 'unknown';
  }
}
