import 'dart:convert';

import '../core/capabilities.dart';

class ConnectionRecord {
  ConnectionRecord({
    required this.id,
    required this.name,
    required this.kind,
    required this.config,
    required this.secretsRef,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.color,
    this.tags = const [],
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String name;
  final DataSourceKind kind;
  final Map<String, Object?> config; // non-secret kind-specific config
  final String secretsRef; // index into flutter_secure_storage
  final DateTime createdAt;
  DateTime updatedAt;
  String? color;
  List<String> tags;

  ConnectionRecord copyWith({
    String? name,
    Map<String, Object?>? config,
    String? color,
    List<String>? tags,
  }) =>
      ConnectionRecord(
        id: id,
        name: name ?? this.name,
        kind: kind,
        config: config ?? this.config,
        secretsRef: secretsRef,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        color: color ?? this.color,
        tags: tags ?? this.tags,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'config': config,
        'secretsRef': secretsRef,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'color': color,
        'tags': tags,
      };

  static ConnectionRecord fromJson(Map<String, Object?> j) => ConnectionRecord(
        id: j['id']! as String,
        name: j['name']! as String,
        kind: DataSourceKind.values.byName(j['kind']! as String),
        config: Map<String, Object?>.from(j['config'] as Map),
        secretsRef: j['secretsRef']! as String,
        createdAt: DateTime.parse(j['createdAt']! as String),
        updatedAt: DateTime.parse(j['updatedAt']! as String),
        color: j['color'] as String?,
        tags: List<String>.from((j['tags'] as List?) ?? const []),
      );

  static String encodeList(List<ConnectionRecord> records) =>
      jsonEncode(records.map((r) => r.toJson()).toList());

  static List<ConnectionRecord> decodeList(String raw) {
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => fromJson(Map<String, Object?>.from(e as Map)))
        .toList();
  }
}
