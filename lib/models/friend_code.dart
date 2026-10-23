import 'dart:math';

/// The short, shareable ID a player gives friends so they can be found.
/// Six characters from an alphabet without look-alikes (no 0/O, 1/I).
class FriendCode {
  const FriendCode._();

  static const alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const length = 6;

  static String generate(Random random) => String.fromCharCodes(
    List.generate(
      length,
      (_) => alphabet.codeUnitAt(random.nextInt(alphabet.length)),
    ),
  );

  /// Canonical form of typed [input], or null if it can't be a code.
  static String? normalize(String input) {
    final code = input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    if (code.length != length) return null;
    for (final c in code.split('')) {
      if (!alphabet.contains(c)) return null;
    }
    return code;
  }
}
