import 'package:flutter/widgets.dart';

/// Bottom breathing room for a scrollable that reaches the screen edge:
/// as tall as the device's bottom system bar, or [minimum] when there is none.
///
/// Use `SafeArea` never wraps a scrollable — it shrinks the viewport so items
/// get clipped as they pass the bottom. This adds padding instead.
class BottomPadding extends StatelessWidget {
  const BottomPadding({super.key});

  static double of(BuildContext context, {double minimum = 16}) {
    final double viewPadding = MediaQuery.viewPaddingOf(context).bottom;
    return viewPadding > minimum ? viewPadding : minimum;
  }

  @override
  Widget build(BuildContext context) => SizedBox(height: of(context));
}
