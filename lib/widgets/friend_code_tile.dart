import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// "Your friend code" with a copy button.
class FriendCodeTile extends StatelessWidget {
  const FriendCodeTile({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          'Your friend code',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SelectableText(
              code,
              style: theme.textTheme.headlineSmall?.copyWith(
                letterSpacing: 4,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            IconButton(
              tooltip: 'Copy code',
              icon: const Icon(Icons.copy),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: code));
                messenger.showSnackBar(
                  const SnackBar(content: Text('Friend code copied')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
