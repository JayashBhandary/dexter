import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// Preset accent colors offered in the picker.
const _accents = <(String, int)>[
  ('Indigo', 0xFF3D5AFE),
  ('Blue', 0xFF1E88E5),
  ('Teal', 0xFF00897B),
  ('Green', 0xFF43A047),
  ('Amber', 0xFFFFB300),
  ('Orange', 0xFFFB8C00),
  ('Red', 0xFFE53935),
  ('Pink', 0xFFD81B60),
  ('Purple', 0xFF8E24AA),
  ('Slate', 0xFF546E7A),
];

const _pageSizes = [25, 50, 100, 200, 500];

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(Spacing.lg),
            children: [
              _section(theme, 'Appearance'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Theme'),
                subtitle: const Text('System follows your OS setting'),
                trailing: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto),
                        label: Text('System')),
                    ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode),
                        label: Text('Light')),
                    ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode),
                        label: Text('Dark')),
                  ],
                  selected: {settings.themeMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => notifier.setThemeMode(s.first),
                ),
              ),
              const SizedBox(height: Spacing.md),
              Text('Accent color', style: theme.textTheme.bodyMedium),
              const SizedBox(height: Spacing.sm),
              Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                children: [
                  for (final (name, argb) in _accents)
                    _Swatch(
                      name: name,
                      color: Color(argb),
                      selected: settings.seedColor == argb,
                      onTap: () => notifier.setSeedColor(argb),
                    ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Compact density'),
                subtitle: const Text('Tighter spacing for dense screens'),
                value: settings.compactDensity,
                onChanged: notifier.setCompactDensity,
              ),
              const Divider(height: Spacing.xl),
              _section(theme, 'Data'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Rows per page'),
                subtitle: const Text('Default page size when browsing tables'),
                trailing: DropdownButton<int>(
                  value: _pageSizes.contains(settings.pageSize)
                      ? settings.pageSize
                      : 100,
                  items: [
                    for (final n in _pageSizes)
                      DropdownMenuItem(value: n, child: Text('$n')),
                  ],
                  onChanged: (v) {
                    if (v != null) notifier.setPageSize(v);
                  },
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Confirm before delete'),
                subtitle: const Text('Ask before destructive actions'),
                value: settings.confirmDeletes,
                onChanged: notifier.setConfirmDeletes,
              ),
              const Divider(height: Spacing.xl),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => notifier.reset(),
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text('Reset to defaults'),
                ),
              ),
              const SizedBox(height: Spacing.lg),
              Text(
                'Theme preview uses seed ${_hex(settings.seedColor)} · '
                'matches ${AppTheme.defaultSeed == settings.seed ? 'default' : 'custom'}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(ThemeData theme, String label) => Padding(
        padding: const EdgeInsets.only(bottom: Spacing.sm),
        child: Text(label,
            style: theme.textTheme.titleSmall
                ?.copyWith(color: theme.colorScheme.primary)),
      );

  static String _hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 18)
              : null,
        ),
      ),
    );
  }
}
