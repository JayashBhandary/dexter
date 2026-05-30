import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/active_source_provider.dart';
import '../../state/workspace_provider.dart';
import '../../theme/tokens.dart';
import '../widgets/empty_states.dart';
import '../workspace/workspace_page.dart';
import 'sidebar_connections.dart';
import 'tab_bar.dart';

class _CloseTabIntent extends Intent {
  const _CloseTabIntent();
}

class _CloseAllTabsIntent extends Intent {
  const _CloseAllTabsIntent();
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final activeId = ref.watch(activeConnectionIdProvider);
    final workspace = ref.read(workspaceProvider.notifier);

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyW, control: true):
            _CloseTabIntent(),
        SingleActivator(LogicalKeyboardKey.keyW, meta: true): _CloseTabIntent(),
        SingleActivator(LogicalKeyboardKey.keyW, control: true, alt: true):
            _CloseAllTabsIntent(),
        SingleActivator(LogicalKeyboardKey.keyW, meta: true, alt: true):
            _CloseAllTabsIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _CloseTabIntent: CallbackAction<_CloseTabIntent>(
            onInvoke: (_) {
              workspace.closeActiveTab();
              return null;
            },
          ),
          _CloseAllTabsIntent: CallbackAction<_CloseAllTabsIntent>(
            onInvoke: (_) {
              workspace.closeAllTabs();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: SidebarWidths.expanded,
                  child: Material(
                    color: scheme.surfaceContainerLow,
                    child: const SidebarConnections(),
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  child: Column(
                    children: [
                      const WorkspaceTabBar(),
                      const Divider(height: 1, thickness: 1),
                      Expanded(
                        child: activeId == null
                            ? const EmptyState(
                                icon: Icons.storage_rounded,
                                title: 'No connection open',
                                subtitle:
                                    'Add or pick a connection from the sidebar.',
                              )
                            : WorkspacePage(connectionId: activeId),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
