import 'package:flutter/material.dart';

import '../../connectors/data_source.dart';
import '../../connectors/sql_common/sql_type_mapper.dart';
import '../../core/cell_value.dart';
import '../../theme/tokens.dart';

class RowFormResult {
  const RowFormResult(this.values);
  final Map<String, CellValue> values;
}

class RowForm extends StatefulWidget {
  const RowForm({
    super.key,
    required this.schema,
    this.initial,
    required this.onSubmit,
    this.submitLabel = 'Save',
  });

  final ContainerSchema schema;
  final RowData? initial;
  final ValueChanged<RowFormResult> onSubmit;
  final String submitLabel;

  @override
  State<RowForm> createState() => _RowFormState();
}

class _RowFormState extends State<RowForm> {
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final c in widget.schema.columns)
        c.name: TextEditingController(
          text: widget.initial?[c.name]?.display() ?? '',
        ),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final values = <String, CellValue>{};
    for (final col in widget.schema.columns) {
      final raw = _controllers[col.name]!.text;
      final family = familyForSqlType(col.typeLabel);
      values[col.name] = parseString(raw, family);
    }
    widget.onSubmit(RowFormResult(values));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(Spacing.lg),
            children: [
              for (final col in widget.schema.columns) ...[
                Text(
                  '${col.name}  ',
                  style: theme.textTheme.labelLarge,
                ),
                Text(
                  '${col.typeLabel}${col.isPrimaryKey ? '  PK' : ''}${col.nullable ? '' : '  NOT NULL'}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(height: Spacing.xs),
                TextField(
                  controller: _controllers[col.name],
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: Spacing.md),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: Spacing.sm),
              FilledButton(
                onPressed: _submit,
                child: Text(widget.submitLabel),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
