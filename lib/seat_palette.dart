import 'package:flutter/material.dart';

/// Per-seat identity colour and labels. Seats are 0-based internally and shown
/// to players as "Player 1"–"Player 4".
///
/// The colours are saturated enough to read as an identity when used to tint
/// the active score-table column, and dark enough to carry white text on a
/// seat chip. They are deliberately fixed (not derived from the theme) so a
/// seat keeps the same colour in light and dark.
abstract final class SeatPalette {
  const SeatPalette._();

  static const List<Color> _colors = [
    Color(0xFF3F51B5), // indigo
    Color(0xFF00897B), // teal
    Color(0xFFF57C00), // orange
    Color(0xFFD81B60), // pink
  ];

  /// Identity colour for [seat] (0-based; wraps past the end of the palette).
  static Color color(int seat) => _colors[seat % _colors.length];

  /// "Player N" for [seat] (0-based).
  static String label(int seat) => 'Player ${seat + 1}';

  /// Short "PN" form, for tight spots like the score-table header.
  static String shortLabel(int seat) => 'P${seat + 1}';
}
