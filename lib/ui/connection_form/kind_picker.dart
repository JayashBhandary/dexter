import 'package:flutter/material.dart';

import '../../connectors/registry.dart';
import '../../core/capabilities.dart';
import '../../theme/tokens.dart';

class KindPicker extends StatelessWidget {
  const KindPicker({super.key, required this.selected, required this.onChanged});

  final DataSourceKind selected;
  final ValueChanged<DataSourceKind> onChanged;

  @override
  Widget build(BuildContext context) {
    const kinds = DataSourceKind.values;
    final reg = ConnectorRegistry.instance;
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        for (final k in kinds)
          ChoiceChip(
            label: Text(k.label),
            selected: k == selected,
            onSelected: reg.isSupported(k) ? (_) => onChanged(k) : null,
          ),
      ],
    );
  }
}
