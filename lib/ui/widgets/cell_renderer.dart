import 'package:flutter/material.dart';

import '../../core/cell_value.dart';

class CellRenderer extends StatelessWidget {
  const CellRenderer(this.value, {super.key});
  final CellValue value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (value is NullCell) {
      return Text(
        'NULL',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    if (value is BlobCell || value is JsonCell) {
      return Chip(
        visualDensity: VisualDensity.compact,
        label: Text(value.display(), overflow: TextOverflow.ellipsis),
      );
    }
    return Text(value.display(), overflow: TextOverflow.ellipsis);
  }
}
