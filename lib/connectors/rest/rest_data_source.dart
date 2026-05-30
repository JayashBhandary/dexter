import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/capabilities.dart';
import '../../core/cell_value.dart';
import '../../core/errors.dart';
import '../../core/page.dart';
import '../../core/query_spec.dart';
import '../../domain/connection_record.dart';
import '../../domain/connection_secrets.dart';
import '../data_source.dart';
import 'rest_operation.dart';

class RestDataSource extends DataSource with RawQueryable, EndpointInvocable {
  RestDataSource({required this.record, required this.secrets});

  final ConnectionRecord record;
  final ConnectionSecrets? secrets;
  Dio? _dio;
  List<RestOperation> _ops = const [];

  @override
  String get id => record.id;
  @override
  String get displayName => record.name;
  @override
  DataSourceKind get kind => DataSourceKind.rest;
  @override
  Set<Capability> get capabilities => const {
        Capability.rawQuery,
        Capability.endpointInvoke,
      };

  Dio get _open {
    final d = _dio;
    if (d == null) throw const ConnectError('Not connected');
    return d;
  }

  @override
  Future<void> connect() async {
    final baseUrl = record.config['baseUrl'] as String? ?? '';
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
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: defaultHeaders,
      validateStatus: (_) => true,
    ));
    final rawOps = record.config['operations'] as String?;
    _ops = rawOps == null ? const [] : RestOperation.decodeList(rawOps);
  }

  @override
  Future<void> disconnect() async {
    _dio?.close(force: true);
    _dio = null;
  }

  @override
  Future<void> ping() async {
    // Cheapest signal: HEAD or GET /; if baseUrl unreachable, throws.
    try {
      await _open.head('');
    } catch (_) {
      await _open.get('');
    }
  }

  @override
  Future<void> dispose() => disconnect();

  @override
  Future<List<ContainerRef>> listContainers() async {
    return [
      for (final op in _ops)
        ContainerRef(name: op.name, subtype: op.method, path: op.name),
    ];
  }

  RestOperation? _opByName(String? name) {
    if (name == null) return null;
    for (final o in _ops) {
      if (o.name == name) return o;
    }
    return null;
  }

  @override
  Future<Page<RowData>> listRows(ContainerRef container, QuerySpec spec) async {
    final op = _opByName(container.path ?? container.name);
    if (op == null) {
      throw QueryError('No saved operation named "${container.name}"');
    }
    final res = await _send(op);
    final extracted = _extractRows(res.data, op.rowsPath);
    return Page(items: extracted, nextCursor: null);
  }

  @override
  Future<RowData?> getRow(ContainerRef container, RowId id) async => null;

  Future<Response<dynamic>> _send(RestOperation op,
      {String? overrideBody}) async {
    final body = overrideBody ?? op.body;
    Object? data;
    if (body != null && body.trim().isNotEmpty) {
      try {
        data = jsonDecode(body);
      } catch (_) {
        data = body;
      }
    }
    return _open.request(
      op.path,
      data: data,
      options: Options(method: op.method, headers: op.headers),
    );
  }

  List<RowData> _extractRows(dynamic body, String? rowsPath) {
    dynamic node = body;
    if (rowsPath != null && rowsPath.isNotEmpty && node is Map) {
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
  Future<QueryResult> runRawQuery(String text,
      [List<Object?> params = const []]) async {
    // First line: `METHOD path`. Remaining lines: optional JSON body.
    final sw = Stopwatch()..start();
    final lines = text.trimRight().split('\n');
    if (lines.isEmpty || lines.first.trim().isEmpty) {
      throw const QueryError('Empty request');
    }
    final firstParts = lines.first.trim().split(RegExp(r'\s+'));
    if (firstParts.length < 2) {
      throw const QueryError('Use: METHOD path  e.g. "GET /users"');
    }
    final method = firstParts[0].toUpperCase();
    final path = firstParts.sublist(1).join(' ');
    final body = lines.length > 1 ? lines.sublist(1).join('\n').trim() : null;
    try {
      final res = await _send(
        RestOperation(name: 'adhoc', method: method, path: path, body: body),
      );
      final rows = _extractRows(res.data, null);
      final cols = rows.isEmpty
          ? <String>['value']
          : rows.first.keys.toList();
      return QueryResult(
        columns: cols,
        rows: rows,
        affectedRows: res.statusCode,
        elapsed: sw.elapsed,
      );
    } on DioException catch (e, st) {
      throw QueryError(e.message ?? e.toString(), cause: e, stack: st);
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
    final res = await _send(op);
    final rows = _extractRows(res.data, op.rowsPath);
    return QueryResult(
      columns: rows.isEmpty ? const [] : rows.first.keys.toList(),
      rows: rows,
      affectedRows: res.statusCode,
      elapsed: sw.elapsed,
    );
  }
}
