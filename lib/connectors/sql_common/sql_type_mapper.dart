import '../../core/cell_value.dart';

/// Coarse type families used by the row form / cell renderer.
enum CellTypeFamily { text, integer, real, bool, timestamp, blob, json, unknown }

CellTypeFamily familyForSqlType(String? typeName) {
  if (typeName == null) {
    return CellTypeFamily.unknown;
  }
  final t = typeName.toUpperCase();
  if (t.contains('INT')) {
    return CellTypeFamily.integer;
  }
  if (t.contains('REAL') ||
      t.contains('FLOA') ||
      t.contains('DOUB') ||
      t.contains('NUMERIC') ||
      t.contains('DECIMAL')) {
    return CellTypeFamily.real;
  }
  if (t.contains('BOOL')) {
    return CellTypeFamily.bool;
  }
  if (t.contains('DATE') || t.contains('TIME')) {
    return CellTypeFamily.timestamp;
  }
  if (t.contains('BLOB') || t.contains('BYTEA')) {
    return CellTypeFamily.blob;
  }
  if (t.contains('JSON')) {
    return CellTypeFamily.json;
  }
  if (t.contains('CHAR') || t.contains('TEXT') || t.contains('CLOB')) {
    return CellTypeFamily.text;
  }
  return CellTypeFamily.unknown;
}

CellValue parseString(String input, CellTypeFamily family) {
  if (input.isEmpty) return const NullCell();
  switch (family) {
    case CellTypeFamily.integer:
      final v = int.tryParse(input);
      return v == null ? StringCell(input) : NumCell(v);
    case CellTypeFamily.real:
      final v = double.tryParse(input);
      return v == null ? StringCell(input) : NumCell(v);
    case CellTypeFamily.bool:
      final l = input.toLowerCase();
      if (l == 'true' || l == '1' || l == 't') return const BoolCell(true);
      if (l == 'false' || l == '0' || l == 'f') return const BoolCell(false);
      return StringCell(input);
    case CellTypeFamily.timestamp:
      final v = DateTime.tryParse(input);
      return v == null ? StringCell(input) : TimestampCell(v);
    default:
      return StringCell(input);
  }
}
