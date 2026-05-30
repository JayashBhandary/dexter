import 'dart:convert';
import 'dart:typed_data';

/// Tagged value for a single cell in any backend.
sealed class CellValue {
  const CellValue();

  static CellValue fromDynamic(Object? v) {
    if (v == null) return const NullCell();
    if (v is bool) return BoolCell(v);
    if (v is int) return NumCell(v);
    if (v is double) return NumCell(v);
    if (v is num) return NumCell(v);
    if (v is DateTime) return TimestampCell(v);
    if (v is Uint8List) return BlobCell(v);
    if (v is List<int>) return BlobCell(Uint8List.fromList(v));
    if (v is String) return StringCell(v);
    if (v is Map || v is List) return JsonCell(v);
    return UnknownCell(v);
  }

  /// Convert back to a value suitable for a driver parameter.
  Object? toBindable() => switch (this) {
        NullCell() => null,
        BoolCell(:final value) => value ? 1 : 0,
        NumCell(:final value) => value,
        StringCell(:final value) => value,
        TimestampCell(:final value) => value.toIso8601String(),
        BlobCell(:final value) => value,
        JsonCell(:final value) => jsonEncode(value),
        UnknownCell(:final raw) => raw,
      };

  /// User-facing display string.
  String display() => switch (this) {
        NullCell() => '',
        BoolCell(:final value) => value ? 'true' : 'false',
        NumCell(:final value) => value.toString(),
        StringCell(:final value) => value,
        TimestampCell(:final value) => value.toIso8601String(),
        BlobCell(:final value) => '<blob ${value.lengthInBytes}B>',
        JsonCell(:final value) => jsonEncode(value),
        UnknownCell(:final raw) => raw.toString(),
      };
}

final class NullCell extends CellValue {
  const NullCell();
}

final class BoolCell extends CellValue {
  const BoolCell(this.value);
  final bool value;
}

final class NumCell extends CellValue {
  const NumCell(this.value);
  final num value;
}

final class StringCell extends CellValue {
  const StringCell(this.value);
  final String value;
}

final class TimestampCell extends CellValue {
  const TimestampCell(this.value);
  final DateTime value;
}

final class BlobCell extends CellValue {
  const BlobCell(this.value);
  final Uint8List value;
}

final class JsonCell extends CellValue {
  const JsonCell(this.value);
  final Object value;
}

final class UnknownCell extends CellValue {
  const UnknownCell(this.raw);
  final Object? raw;
}

/// A row is an ordered map of column name → CellValue.
typedef RowData = Map<String, CellValue>;
