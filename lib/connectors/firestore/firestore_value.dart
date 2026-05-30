import 'dart:convert';
import 'dart:typed_data';

import 'package:googleapis/firestore/v1.dart' as fs;

import '../../core/cell_value.dart';

/// Convert Firestore Value → CellValue.
CellValue valueToCell(fs.Value v) {
  if (v.nullValue != null) return const NullCell();
  if (v.booleanValue != null) return BoolCell(v.booleanValue!);
  if (v.integerValue != null) {
    final n = int.tryParse(v.integerValue!) ?? 0;
    return NumCell(n);
  }
  if (v.doubleValue != null) return NumCell(v.doubleValue!);
  if (v.stringValue != null) return StringCell(v.stringValue!);
  if (v.timestampValue != null) {
    final dt = DateTime.tryParse(v.timestampValue!);
    return dt == null ? StringCell(v.timestampValue!) : TimestampCell(dt);
  }
  if (v.bytesValue != null) {
    return BlobCell(Uint8List.fromList(base64Decode(v.bytesValue!)));
  }
  if (v.referenceValue != null) return StringCell(v.referenceValue!);
  if (v.geoPointValue != null) {
    return JsonCell({
      'latitude': v.geoPointValue!.latitude,
      'longitude': v.geoPointValue!.longitude,
    });
  }
  if (v.arrayValue != null) {
    return JsonCell(
        (v.arrayValue!.values ?? const <fs.Value>[]).map(_valueToPlain).toList());
  }
  if (v.mapValue != null) {
    return JsonCell(_mapToPlain(v.mapValue!.fields ?? const {}));
  }
  return const UnknownCell(null);
}

/// Convert CellValue → Firestore Value.
fs.Value cellToValue(CellValue cell) {
  return switch (cell) {
    NullCell() => fs.Value(nullValue: 'NULL_VALUE'),
    BoolCell(:final value) => fs.Value(booleanValue: value),
    NumCell(:final value) => value is int
        ? fs.Value(integerValue: value.toString())
        : fs.Value(doubleValue: value.toDouble()),
    StringCell(:final value) => fs.Value(stringValue: value),
    TimestampCell(:final value) =>
      fs.Value(timestampValue: value.toUtc().toIso8601String()),
    BlobCell(:final value) => fs.Value(bytesValue: base64Encode(value)),
    JsonCell(:final value) => _jsonToValue(value),
    UnknownCell() => fs.Value(nullValue: 'NULL_VALUE'),
  };
}

Object? _valueToPlain(fs.Value v) {
  if (v.nullValue != null) return null;
  if (v.booleanValue != null) return v.booleanValue;
  if (v.integerValue != null) return int.tryParse(v.integerValue!) ?? 0;
  if (v.doubleValue != null) return v.doubleValue;
  if (v.stringValue != null) return v.stringValue;
  if (v.timestampValue != null) return v.timestampValue;
  if (v.bytesValue != null) return v.bytesValue;
  if (v.referenceValue != null) return v.referenceValue;
  if (v.arrayValue != null) {
    return (v.arrayValue!.values ?? const <fs.Value>[])
        .map(_valueToPlain)
        .toList();
  }
  if (v.mapValue != null) {
    return _mapToPlain(v.mapValue!.fields ?? const {});
  }
  return null;
}

Map<String, Object?> _mapToPlain(Map<String, fs.Value> fields) {
  return {for (final e in fields.entries) e.key: _valueToPlain(e.value)};
}

fs.Value _jsonToValue(Object json) {
  if (json is List) {
    return fs.Value(
      arrayValue: fs.ArrayValue(
        values: [for (final e in json) _plainToValue(e)],
      ),
    );
  }
  if (json is Map) {
    return fs.Value(
      mapValue: fs.MapValue(
        fields: {
          for (final e in json.entries) e.key.toString(): _plainToValue(e.value),
        },
      ),
    );
  }
  return _plainToValue(json);
}

fs.Value _plainToValue(Object? v) {
  if (v == null) return fs.Value(nullValue: 'NULL_VALUE');
  if (v is bool) return fs.Value(booleanValue: v);
  if (v is int) return fs.Value(integerValue: v.toString());
  if (v is double) return fs.Value(doubleValue: v);
  if (v is num) return fs.Value(doubleValue: v.toDouble());
  if (v is String) return fs.Value(stringValue: v);
  if (v is List) {
    return fs.Value(
      arrayValue: fs.ArrayValue(values: v.map(_plainToValue).toList()),
    );
  }
  if (v is Map) {
    return fs.Value(
      mapValue: fs.MapValue(fields: {
        for (final e in v.entries) e.key.toString(): _plainToValue(e.value),
      }),
    );
  }
  return fs.Value(stringValue: jsonEncode(v));
}
