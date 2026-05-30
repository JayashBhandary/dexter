import 'dart:convert';

import 'package:graphql/client.dart' hide QueryResult;

import '../../core/capabilities.dart';
import '../../core/cell_value.dart';
import '../../core/errors.dart';
import '../../core/page.dart';
import '../../core/query_spec.dart';
import '../../domain/connection_record.dart';
import '../../domain/connection_secrets.dart';
import '../data_source.dart';

class GraphqlOperation {
  const GraphqlOperation({
    required this.name,
    required this.query,
    this.variables = const {},
    this.rowsPath,
  });

  final String name;
  final String query;
  final Map<String, Object?> variables;
  final String? rowsPath;

  Map<String, Object?> toJson() => {
        'name': name,
        'query': query,
        if (variables.isNotEmpty) 'variables': variables,
        if (rowsPath != null) 'rowsPath': rowsPath,
      };

  static GraphqlOperation fromJson(Map<String, Object?> j) => GraphqlOperation(
        name: j['name']! as String,
        query: j['query']! as String,
        variables:
            Map<String, Object?>.from((j['variables'] as Map?) ?? const {}),
        rowsPath: j['rowsPath'] as String?,
      );

  static List<GraphqlOperation> decodeList(String raw) {
    final v = jsonDecode(raw);
    if (v is! List) return [];
    return v.map((e) => fromJson(Map<String, Object?>.from(e as Map))).toList();
  }
}

class GraphqlDataSource extends DataSource
    with RawQueryable, EndpointInvocable {
  GraphqlDataSource({required this.record, required this.secrets});

  final ConnectionRecord record;
  final ConnectionSecrets? secrets;
  GraphQLClient? _client;
  List<GraphqlOperation> _ops = const [];

  @override
  String get id => record.id;
  @override
  String get displayName => record.name;
  @override
  DataSourceKind get kind => DataSourceKind.graphql;
  @override
  Set<Capability> get capabilities => const {
        Capability.rawQuery,
        Capability.endpointInvoke,
      };

  GraphQLClient get _open {
    final c = _client;
    if (c == null) throw const ConnectError('Not connected');
    return c;
  }

  @override
  Future<void> connect() async {
    final endpoint = record.config['endpoint'] as String? ?? '';
    if (endpoint.isEmpty) {
      throw const ConnectError('GraphQL endpoint required');
    }
    final defaultHeaders =
        Map<String, String>.from((record.config['defaultHeaders'] as Map?) ?? {});
    final authMode = record.config['authMode'] as String? ?? 'none';
    if (authMode == 'bearer' && secrets?.bearerToken != null) {
      defaultHeaders['Authorization'] = 'Bearer ${secrets!.bearerToken}';
    } else if (authMode == 'apiKey' && secrets?.apiKey != null) {
      final header = record.config['apiKeyHeader'] as String? ?? 'X-API-Key';
      defaultHeaders[header] = secrets!.apiKey!;
    } else if (authMode == 'basic' && secrets?.basicAuth != null) {
      defaultHeaders['Authorization'] = 'Basic ${secrets!.basicAuth}';
    }
    final link = HttpLink(endpoint, defaultHeaders: defaultHeaders);
    _client = GraphQLClient(link: link, cache: GraphQLCache());
    final rawOps = record.config['operations'] as String?;
    _ops = rawOps == null ? const [] : GraphqlOperation.decodeList(rawOps);
  }

  @override
  Future<void> disconnect() async {
    _client = null;
  }

  @override
  Future<void> ping() async {
    // Cheapest introspection probe.
    final res = await _open.query(QueryOptions(
      document: gql(r'query __Probe { __typename }'),
    ));
    if (res.hasException) {
      throw ConnectError('Ping failed: ${res.exception}');
    }
  }

  @override
  Future<void> dispose() => disconnect();

  @override
  Future<List<ContainerRef>> listContainers() async {
    return [
      for (final op in _ops)
        ContainerRef(name: op.name, subtype: 'query', path: op.name),
    ];
  }

  GraphqlOperation? _opByName(String? name) {
    if (name == null) return null;
    for (final o in _ops) {
      if (o.name == name) return o;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _runQuery(String query,
      Map<String, Object?> variables) async {
    final res = await _open.query(QueryOptions(
      document: gql(query),
      variables: variables,
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (res.hasException) {
      throw QueryError(res.exception.toString());
    }
    return res.data;
  }

  List<RowData> _extractRows(Object? data, String? rowsPath) {
    Object? node = data;
    if (node is Map && (rowsPath == null || rowsPath.isEmpty)) {
      // Auto-pick the first list-valued field for convenience.
      final firstList = node.values.firstWhere(
        (v) => v is List,
        orElse: () => null,
      );
      node = firstList ?? node;
    } else if (rowsPath != null && rowsPath.isNotEmpty && node is Map) {
      for (final part in rowsPath.split('.')) {
        if (node is Map) {
          node = node[part];
        } else {
          break;
        }
      }
    }
    if (node is List) {
      return [
        for (final item in node)
          if (item is Map)
            {
              for (final e in item.entries)
                e.key.toString(): CellValue.fromDynamic(e.value),
            }
          else
            {'value': CellValue.fromDynamic(item)},
      ];
    }
    if (node is Map) {
      return [
        {
          for (final e in node.entries)
            e.key.toString(): CellValue.fromDynamic(e.value),
        }
      ];
    }
    return [
      {'value': CellValue.fromDynamic(node)},
    ];
  }

  @override
  Future<Page<RowData>> listRows(ContainerRef container, QuerySpec spec) async {
    final op = _opByName(container.path ?? container.name);
    if (op == null) {
      throw QueryError('No saved operation "${container.name}"');
    }
    final data = await _runQuery(op.query, op.variables);
    return Page(items: _extractRows(data, op.rowsPath), nextCursor: null);
  }

  @override
  Future<RowData?> getRow(ContainerRef container, RowId id) async => null;

  @override
  Future<QueryResult> runRawQuery(String text,
      [List<Object?> params = const []]) async {
    final sw = Stopwatch()..start();
    try {
      final data = await _runQuery(text, const {});
      final rows = _extractRows(data, null);
      final cols = rows.isEmpty ? const <String>[] : rows.first.keys.toList();
      return QueryResult(columns: cols, rows: rows, elapsed: sw.elapsed);
    } on QueryError {
      rethrow;
    } catch (e, st) {
      throw QueryError(e.toString(), cause: e, stack: st);
    }
  }

  @override
  Future<QueryResult> invoke(ContainerRef container,
      {Map<String, Object?>? variables}) async {
    final op = _opByName(container.path ?? container.name);
    if (op == null) {
      throw QueryError('No saved operation "${container.name}"');
    }
    final sw = Stopwatch()..start();
    final data = await _runQuery(op.query, variables ?? op.variables);
    final rows = _extractRows(data, op.rowsPath);
    return QueryResult(
      columns: rows.isEmpty ? const [] : rows.first.keys.toList(),
      rows: rows,
      elapsed: sw.elapsed,
    );
  }
}
