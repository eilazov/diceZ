import 'package:flutter/services.dart';

/// Small haptic vocabulary for the game's key moments. Each method maps to a
/// built-in [HapticFeedback] call; all are no-ops on devices or platforms
/// (web, most desktops) that don't support vibration.
abstract final class AppHaptics {
  /// The dice tumble.
  static void roll() => HapticFeedback.mediumImpact();

  /// A die is held or released.
  static void hold() => HapticFeedback.selectionClick();

  /// A category is committed.
  static void commit() => HapticFeedback.lightImpact();

  /// The match is over.
  static void gameOver() => HapticFeedback.heavyImpact();
}
