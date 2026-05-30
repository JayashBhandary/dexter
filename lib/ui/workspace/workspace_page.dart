import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/workspace_tab.dart';
import '../../state/active_source_provider.dart';
import '../../state/workspace_provider.dart';
import '../../theme/tokens.dart';
import '../../connectors/data_source.dart';
import '../widgets/empty_states.dart';
import 'browse_pane.dart';
import 'container_tree.dart';
import 'file_browser_pane.dart';
import 'query_pane.dart';
import 'schema_pane.dart';

class WorkspacePage extends ConsumerWidget {
  const WorkspacePage({super.key, required this.connectionId});
  final String connectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceProvider);
    final tab = workspace.activeTab;
    return Row(
      children: [
        SizedBox(
          width: 260,
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(Spacing.sm),
                  child: Row(
                    children: [
                      Text('Objects',
                          style: Theme.of(context).textTheme.labelLarge),
                      const Spacer(),
                      IconButton(
                        tooltip: 'New query tab',
                        iconSize: 18,
                        icon: const Icon(Icons.terminal),
                        onPressed: () => ref
                            .read(workspaceProvider.notifier)
                            .openQueryTab(connectionId),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(child: ContainerTree(connectionId: connectionId)),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          child: tab == null
              ? const EmptyState(
                  icon: Icons.table_view_outlined,
                  title: 'Pick an object',
                  subtitle: 'Click a table on the left to browse rows.',
                )
              : _PaneFor(tab: tab),
        ),
      ],
    );
  }
}

class _PaneFor extends ConsumerWidget {
  const _PaneFor({required this.tab});
  final WorkspaceTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final src = ref.watch(activeDataSourceProvider);
    return src.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (source) {
        switch (tab.view) {
          case WorkspaceView.browse:
            if (tab.container == null) return const Text('No container');
            // File/object stores get the hierarchical browser; tabular
            // sources keep the row grid.
            if (source is FileBrowsable) {
              return FileBrowserPane(
                key: ValueKey('files-${tab.id}-${tab.container!.name}'),
                container: tab.container!,
              );
            }
            return BrowsePane(
              key: ValueKey('browse-${tab.id}-${tab.container!.name}'),
              container: tab.container!,
            );
          case WorkspaceView.query:
            return QueryPane(tabId: tab.id, initialText: tab.queryText);
          case WorkspaceView.schema:
            if (tab.container == null) return const Text('No container');
            return SchemaPane(container: tab.container!);
        }
      },
    );
  }
}
