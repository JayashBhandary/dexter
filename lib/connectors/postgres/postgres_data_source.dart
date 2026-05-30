import 'package:postgres/postgres.dart';

import '../../core/capabilities.dart';
import '../../core/cell_value.dart';
import '../../core/errors.dart';
import '../../core/page.dart';
import '../../core/query_spec.dart';
import '../../domain/connection_record.dart';
import '../../domain/connection_secrets.dart';
import '../data_source.dart';
import '../sql_common/sql_query_builder.dart';
import 'postgres_dialect.dart';

class PostgresDataSource extends DataSource
    with RawQueryable, Writable, SchemaReadable, SchemaMutable, Transactional {
  PostgresDataSource({required this.record, required this.secrets});

  final ConnectionRecord record;
  final ConnectionSecrets? secrets;
  Connection? _conn;

  static final _builder = SqlQueryBuilder(
    quote: pgQuoteIdent,
    paramPlaceholder: pgPlaceholder,
  );

  @override
  String get id => record.id;
  @override
  String get displayName => record.name;
  @override
  DataSourceKind get kind => DataSourceKind.postgres;
  @override
  Set<Capability> get capabilities => const {
        Capability.rawQuery,
        Capability.write,
        Capability.schemaRead,
        Capability.schemaMutate,
        Capability.transactions,
      };

  Connection get _c {
    final c = _conn;
    if (c == null) throw const ConnectError('Not connected');
    return c;
  }

  SslMode _sslModeFromString(String? raw) {
    switch (raw) {
      case 'disable':
        return SslMode.disable;
      case 'require':
        return SslMode.require;
      case 'verifyFull':
        return SslMode.verifyFull;
      case null:
      case '':
      default:
        return SslMode.require;
    }
  }

  @override
  Future<void> connect() async {
    final host = record.config['host'] as String? ?? 'localhost';
    final port = (record.config['port'] as num?)?.toInt() ?? 5432;
    final database = record.config['database'] as String? ?? 'postgres';
    final username = record.config['username'] as String? ?? 'postgres';
    final ssl = _sslModeFromString(record.config['sslMode'] as String?);
    try {
      _conn = await Connection.open(
        Endpoint(
          host: host,
          port: port,
          database: database,
          username: username,
          password: secrets?.password,
        ),
        settings: ConnectionSettings(sslMode: ssl),
      );
    } catch (e, st) {
      throw ConnectError('Postgres connect failed: $e', cause: e, stack: st);
    }
  }

  @override
  Future<void> disconnect() async {
    final c = _conn;
    _conn = null;
    if (c != null) await c.close();
  }

  @override
  Future<void> ping() async {
    await _c.execute('SELECT 1');
  }

  @override
  Future<void> dispose() => disconnect();

  @override
  Future<List<ContainerRef>> listContainers() async {
    final r = await _c.execute(
      'SELECT table_schema, table_name, table_type '
      'FROM information_schema.tables '
      "WHERE table_schema NOT IN ('pg_catalog','information_schema') "
      'ORDER BY table_schema, table_name',
    );
    return [
      for (final row in r)
        ContainerRef(
          name: row[1]! as String,
          namespace: row[0]! as String,
          subtype: (row[2]! as String) == 'VIEW' ? 'view' : 'table',
        ),
    ];
  }

  String _qualifiedFor(ContainerRef c) => pgQuoteQualified(c.namespace, c.name);

  @override
  Future<Page<RowData>> listRows(ContainerRef container, QuerySpec spec) async {
    final built = _builder.buildSelect(_qualifiedFor(container), spec);
    final r = await _c.execute(built.sql, parameters: built.params);
    final cols = r.schema.columns.map((c) => c.columnName ?? '?').toList();
    final rows = [
      for (final row in r) _toRowData(cols, row),
    ];
    final more = rows.length == spec.limit;
    return Page(
      items: rows,
      nextCursor: more ? (spec.offset + spec.limit).toString() : null,
    );
  }

  RowData _toRowData(List<String> cols, ResultRow row) {
    final out = <String, CellValue>{};
    for (var i = 0; i < cols.length; i++) {
      out[cols[i]] = CellValue.fromDynamic(row[i]);
    }
    return out;
  }

  @override
  Future<RowData?> getRow(ContainerRef container, RowId id) async {
    final preds = <String>[];
    final params = <Object?>[];
    var i = 1;
    for (final e in id.fields.entries) {
      preds.add('${pgQuoteIdent(e.key)} = ${pgPlaceholder(i++)}');
      params.add(e.value.toBindable());
    }
    final r = await _c.execute(
      'SELECT * FROM ${_qualifiedFor(container)} WHERE ${preds.join(' AND ')} LIMIT 1',
      parameters: params,
    );
    if (r.isEmpty) return null;
    final cols = r.schema.columns.map((c) => c.columnName ?? '?').toList();
    return _toRowData(cols, r.first);
  }

  @override
  Future<QueryResult> runRawQuery(String text,
      [List<Object?> params = const []]) async {
    final sw = Stopwatch()..start();
    try {
      final r = await _c.execute(text, parameters: params.isEmpty ? null : params);
      final cols = r.schema.columns.map((c) => c.columnName ?? '?').toList();
      if (cols.isEmpty) {
        return QueryResult(
          columns: const [],
          rows: const [],
          affectedRows: r.affectedRows,
          elapsed: sw.elapsed,
        );
      }
      return QueryResult(
        columns: cols,
        rows: [for (final row in r) _toRowData(cols, row)],
        affectedRows: r.affectedRows,
        elapsed: sw.elapsed,
      );
    } on ServerException catch (e, st) {
      throw QueryError(e.message, cause: e, stack: st);
    } catch (e, st) {
      throw QueryError(e.toString(), cause: e, stack: st);
    }
  }

  @override
  Future<RowId> insertRow(
      ContainerRef container, Map<String, CellValue> values) async {
    if (values.isEmpty) {
      throw const QueryError('No values supplied for insert');
    }
    final cols = values.keys.map(pgQuoteIdent).join(', ');
    var i = 1;
    final phs = values.values.map((_) => pgPlaceholder(i++)).join(', ');
    final params = values.values.map((v) => v.toBindable()).toList();
    final r = await _c.execute(
      'INSERT INTO ${_qualifiedFor(container)} ($cols) VALUES ($phs) RETURNING *',
      parameters: params,
    );
    if (r.isEmpty) return const RowId({});
    final colsOut = r.schema.columns.map((c) => c.columnName ?? '?').toList();
    final returned = _toRowData(colsOut, r.first);
    return RowId(returned);
  }

  @override
  Future<int> updateRow(
      ContainerRef container, RowId id, Map<String, CellValue> values) async {
    if (values.isEmpty) return 0;
    var i = 1;
    final setExpr =
        values.keys.map((c) => '${pgQuoteIdent(c)} = ${pgPlaceholder(i++)}').join(', ');
    final whereExpr =
        id.fields.keys.map((c) => '${pgQuoteIdent(c)} = ${pgPlaceholder(i++)}').join(' AND ');
    final params = [
      ...values.values.map((v) => v.toBindable()),
      ...id.fields.values.map((v) => v.toBindable()),
    ];
    final r = await _c.execute(
      'UPDATE ${_qualifiedFor(container)} SET $setExpr WHERE $whereExpr',
      parameters: params,
    );
    return r.affectedRows;
  }

  @override
  Future<int> deleteRow(ContainerRef container, RowId id) async {
    var i = 1;
    final whereExpr =
        id.fields.keys.map((c) => '${pgQuoteIdent(c)} = ${pgPlaceholder(i++)}').join(' AND ');
    final params = id.fields.values.map((v) => v.toBindable()).toList();
    final r = await _c.execute(
      'DELETE FROM ${_qualifiedFor(container)} WHERE $whereExpr',
      parameters: params,
    );
    return r.affectedRows;
  }

  @override
  Future<ContainerSchema> getSchema(ContainerRef container) async {
    final ns = container.namespace ?? 'public';
    final cols = await _c.execute(
      'SELECT column_name, data_type, is_nullable, column_default '
      'FROM information_schema.columns '
      r'WHERE table_schema = $1 AND table_name = $2 '
      'ORDER BY ordinal_position',
      parameters: [ns, container.name],
    );
    final pkRes = await _c.execute(
      'SELECT kcu.column_name '
      'FROM information_schema.table_constraints tc '
      'JOIN information_schema.key_column_usage kcu '
      'ON tc.constraint_name = kcu.constraint_name '
      'AND tc.table_schema = kcu.table_schema '
      r"WHERE tc.constraint_type = 'PRIMARY KEY' "
      r'AND tc.table_schema = $1 AND tc.table_name = $2',
      parameters: [ns, container.name],
    );
    final pkSet = {for (final r in pkRes) r[0]! as String};
    final columns = [
      for (final r in cols)
        ColumnSchema(
          name: r[0]! as String,
          typeLabel: r[1]! as String,
          nullable: (r[2]! as String).toUpperCase() == 'YES',
          isPrimaryKey: pkSet.contains(r[0]),
          defaultExpr: r[3] as String?,
        ),
    ];
    return ContainerSchema(container: container, columns: columns);
  }

  @override
  Future<void> createContainer(ContainerSchema schema) async {
    final cols = schema.columns.map((c) {
      final parts = <String>[pgQuoteIdent(c.name), c.typeLabel];
      if (!c.nullable) parts.add('NOT NULL');
      if (c.isPrimaryKey) parts.add('PRIMARY KEY');
      if (c.defaultExpr != null) parts.add('DEFAULT ${c.defaultExpr}');
      return parts.join(' ');
    }).join(', ');
    await _c.execute('CREATE TABLE ${_qualifiedFor(schema.container)} ($cols)');
  }

  @override
  Future<void> dropContainer(ContainerRef container) async {
    await _c.execute('DROP TABLE ${_qualifiedFor(container)}');
  }

  @override
  Future<void> alterColumn(
      ContainerRef container, String columnName, ColumnSchema newDef) async {
    if (columnName != newDef.name) {
      await _c.execute(
        'ALTER TABLE ${_qualifiedFor(container)} '
        'RENAME COLUMN ${pgQuoteIdent(columnName)} TO ${pgQuoteIdent(newDef.name)}',
      );
    }
    await _c.execute(
      'ALTER TABLE ${_qualifiedFor(container)} '
      'ALTER COLUMN ${pgQuoteIdent(newDef.name)} TYPE ${newDef.typeLabel}',
    );
    await _c.execute(
      'ALTER TABLE ${_qualifiedFor(container)} '
      'ALTER COLUMN ${pgQuoteIdent(newDef.name)} '
      '${newDef.nullable ? 'DROP NOT NULL' : 'SET NOT NULL'}',
    );
  }

  // Postgres transactions on the simple connection: BEGIN/COMMIT/ROLLBACK
  // statements are valid; runTx wraps a sub-session but is more invasive.
  @override
  Future<void> beginTx() async => _c.execute('BEGIN');
  @override
  Future<void> commit() async => _c.execute('COMMIT');
  @override
  Future<void> rollback() async => _c.execute('ROLLBACK');
}
