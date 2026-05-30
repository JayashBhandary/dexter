import 'cell_value.dart';

enum FilterOp { eq, ne, gt, gte, lt, lte, like, inList, contains, isNull, notNull }

class FilterClause {
  const FilterClause(this.field, this.op, [this.value]);
  final String field;
  final FilterOp op;
  final CellValue? value;
}

enum SortDir { asc, desc }

class SortClause {
  const SortClause(this.field, [this.dir = SortDir.asc]);
  final String field;
  final SortDir dir;
}

class QuerySpec {
  const QuerySpec({
    this.where = const [],
    this.orderBy = const [],
    this.limit = 100,
    this.offset = 0,
    this.cursor,
    this.projection,
  });

  final List<FilterClause> where;
  final List<SortClause> orderBy;
  final int limit;
  final int offset;
  final String? cursor;
  final List<String>? projection;

  QuerySpec copyWith({
    List<FilterClause>? where,
    List<SortClause>? orderBy,
    int? limit,
    int? offset,
    String? cursor,
    List<String>? projection,
  }) =>
      QuerySpec(
        where: where ?? this.where,
        orderBy: orderBy ?? this.orderBy,
        limit: limit ?? this.limit,
        offset: offset ?? this.offset,
        cursor: cursor ?? this.cursor,
        projection: projection ?? this.projection,
      );
}
