import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/workspace_provider.dart';
import '../../theme/tokens.dart';

class WorkspaceTabBar extends ConsumerWidget {
  const WorkspaceTabBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ws = ref.watch(workspaceProvider);
    final notifier = ref.read(workspaceProvider.notifier);
    return SizedBox(
      height: 40,
      child: Material(
        color: theme.colorScheme.surfaceContainerLowest,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
          child: Row(
            children: [
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final t in ws.tabs)
                      _Tab(
                        label: t.label(),
                        active: t.id == ws.activeTabId,
                        onTap: () => notifier.activate(t.id),
                        onClose: () => notifier.closeTab(t.id),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Settings',
                iconSize: 18,
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.active,
    required this.onTap,
    required this.onClose,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xs, vertical: 4),
      child: Material(
        color: active
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.sm),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
            child: Row(
              children: [
                Text(label,
                    style: TextStyle(
                      color: active
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                      fontWeight:
                          active ? FontWeight.w600 : FontWeight.w400,
                    )),
                const SizedBox(width: Spacing.xs),
                Tooltip(
                  message: 'Close · Ctrl/⌘+W',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Radii.sm),
                    onTap: onClose,
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.close, size: 14),
                    ),
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
