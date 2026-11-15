import 'package:flutter/material.dart';

import '../models/game_mode.dart';

/// Asks which rule set to challenge [friendName] with; null if dismissed.
Future<GameMode?> showChallengeModeDialog(
  BuildContext context,
  String friendName,
) => showDialog<GameMode>(
  context: context,
  builder: (context) => SimpleDialog(
    title: Text('Challenge $friendName'),
    children: [
      for (final m in GameMode.values)
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop(m),
          child: Text('${m.label} (${m.rounds} rounds)'),
        ),
    ],
  ),
);
