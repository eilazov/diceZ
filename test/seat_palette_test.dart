import 'package:flutter_test/flutter_test.dart';

import 'package:dice_zee/seat_palette.dart';

void main() {
  test('each of the four seats has a distinct colour', () {
    final colors = {for (var s = 0; s < 4; s++) SeatPalette.color(s)};
    expect(colors, hasLength(4));
  });

  test('seat colours wrap past the fourth seat', () {
    expect(SeatPalette.color(4), SeatPalette.color(0));
    expect(SeatPalette.color(5), SeatPalette.color(1));
  });

  test('labels are 1-based', () {
    expect(SeatPalette.label(0), 'Player 1');
    expect(SeatPalette.label(3), 'Player 4');
    expect(SeatPalette.shortLabel(0), 'P1');
    expect(SeatPalette.shortLabel(3), 'P4');
  });
}
