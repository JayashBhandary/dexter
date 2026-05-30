class Page<T> {
  const Page({
    required this.items,
    this.nextCursor,
    this.totalHint,
  });

  final List<T> items;
  final String? nextCursor;
  final int? totalHint;

  bool get hasMore => nextCursor != null;
}
