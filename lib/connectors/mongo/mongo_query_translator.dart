import '../../core/query_spec.dart';

/// Translate a [QuerySpec] into a Mongo filter document.
Map<String, Object?> querySpecToFilter(QuerySpec spec) {
  if (spec.where.isEmpty) return const {};
  final and = <Map<String, Object?>>[];
  for (final c in spec.where) {
    final v = c.value?.toBindable();
    switch (c.op) {
      case FilterOp.eq:
        and.add({c.field: v});
      case FilterOp.ne:
        and.add({c.field: {r'$ne': v}});
      case FilterOp.gt:
        and.add({c.field: {r'$gt': v}});
      case FilterOp.gte:
        and.add({c.field: {r'$gte': v}});
      case FilterOp.lt:
        and.add({c.field: {r'$lt': v}});
      case FilterOp.lte:
        and.add({c.field: {r'$lte': v}});
      case FilterOp.like:
      case FilterOp.contains:
        final raw = v?.toString() ?? '';
        and.add({c.field: {r'$regex': raw, r'$options': 'i'}});
      case FilterOp.inList:
        final list = v is List ? v : [v];
        and.add({c.field: {r'$in': list}});
      case FilterOp.isNull:
        and.add({c.field: null});
      case FilterOp.notNull:
        and.add({c.field: {r'$ne': null}});
    }
  }
  if (and.length == 1) return and.first;
  return {r'$and': and};
}

Map<String, Object?> querySpecToSort(QuerySpec spec) {
  if (spec.orderBy.isEmpty) return const {};
  return {
    for (final o in spec.orderBy) o.field: o.dir == SortDir.asc ? 1 : -1,
  };
}
