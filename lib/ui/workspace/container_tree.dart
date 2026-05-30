import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../connectors/data_source.dart';
import '../../state/active_source_provider.dart';
import '../../state/workspace_provider.dart';
import '../../theme/tokens.dart';

class ContainerTree extends ConsumerWidget {
  const ContainerTree({super.key, required this.connectionId});

  final String connectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final containers = ref.watch(activeContainersProvider);
    return containers.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Text('Error: $e'),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('No containers'));
        }
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final c = list[i];
            return _ContainerTile(connectionId: connectionId, container: c);
          },
        );
      },
    );
  }
}

class _ContainerTile extends ConsumerWidget {
  const _ContainerTile({required this.connectionId, required this.container});
  final String connectionId;
  final ContainerRef container;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBucket = container.subtype == 'bucket';
    return ListTile(
      dense: true,
      leading: Icon(
        isBucket
            ? Icons.folder_outlined
            : container.subtype == 'view'
                ? Icons.visibility_outlined
                : Icons.table_chart_outlined,
        size: 18,
      ),
      title: Text(container.name, overflow: TextOverflow.ellipsis),
      onTap: () => ref
          .read(workspaceProvider.notifier)
          .openBrowseTab(connectionId, container),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_horiz, size: 18),
        onSelected: (v) {
          final notifier = ref.read(workspaceProvider.notifier);
          switch (v) {
            case 'browse':
              notifier.openBrowseTab(connectionId, container);
            case 'schema':
              notifier.openSchemaTab(connectionId, container);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
              value: 'browse',
              child: Text(isBucket ? 'Open' : 'Browse rows')),
          if (!isBucket)
            const PopupMenuItem(value: 'schema', child: Text('View schema')),
        ],
      ),
    );
  }
}
