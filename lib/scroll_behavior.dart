import 'package:flutter/material.dart';

/// Shows a scrollbar on every scrollable, on every platform (mobile included).
class AlwaysScrollbarBehavior extends MaterialScrollBehavior {
  const AlwaysScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return Scrollbar(controller: details.controller, child: child);
  }
}
