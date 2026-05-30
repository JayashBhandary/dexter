import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.error, this.onDismiss});

  final Object error;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md, vertical: Spacing.sm),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 18),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text(
                error.toString(),
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                icon: Icon(Icons.close, color: scheme.onErrorContainer, size: 18),
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}
