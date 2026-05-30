import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../connectors/data_source.dart';
import '../../state/schema_provider.dart';
import '../../theme/tokens.dart';

class SchemaPane extends ConsumerWidget {
  const SchemaPane({super.key, required this.container});
  final ContainerRef container;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(containerSchemaProvider(container));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (schema) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md, vertical: Spacing.xs),
              child: Row(
                children: [
                  Text('${container.name} · schema',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  Text('${schema.columns.length} columns'),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: schema.columns.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final c = schema.columns[i];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      c.isPrimaryKey ? Icons.key : Icons.view_column_outlined,
                      size: 18,
                    ),
                    title: Text(c.name),
                    subtitle: Text(
                      '${c.typeLabel}${c.nullable ? '' : ' · NOT NULL'}'
                      '${c.defaultExpr != null ? ' · default ${c.defaultExpr}' : ''}',
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
