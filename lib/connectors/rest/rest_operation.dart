import 'dart:convert';

class RestOperation {
  const RestOperation({
    required this.name,
    required this.method,
    required this.path,
    this.headers = const {},
    this.body,
    this.rowsPath,
  });

  final String name;
  final String method;
  final String path;
  final Map<String, String> headers;
  final String? body; // JSON text
  final String? rowsPath; // dot-path into response to extract array (e.g. "data.users")

  Map<String, Object?> toJson() => {
        'name': name,
        'method': method,
        'path': path,
        if (headers.isNotEmpty) 'headers': headers,
        if (body != null) 'body': body,
        if (rowsPath != null) 'rowsPath': rowsPath,
      };

  static RestOperation fromJson(Map<String, Object?> j) => RestOperation(
        name: j['name']! as String,
        method: (j['method'] as String?) ?? 'GET',
        path: (j['path'] as String?) ?? '/',
        headers: Map<String, String>.from((j['headers'] as Map?) ?? const {}),
        body: j['body'] as String?,
        rowsPath: j['rowsPath'] as String?,
      );

  static List<RestOperation> decodeList(String raw) {
    final v = jsonDecode(raw);
    if (v is! List) return [];
    return v.map((e) => fromJson(Map<String, Object?>.from(e as Map))).toList();
  }

  static String encodeList(List<RestOperation> ops) =>
      const JsonEncoder.withIndent('  ')
          .convert(ops.map((o) => o.toJson()).toList());
}
