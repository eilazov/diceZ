import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// A dim `AppName 1.2.0 (3)` line. Reads the package version once on init and
/// renders nothing until it is available. Meant for the bottom of a screen.
class VersionIndicator extends StatefulWidget {
  const VersionIndicator({super.key});

  @override
  State<VersionIndicator> createState() => _VersionIndicatorState();
}

class _VersionIndicatorState extends State<VersionIndicator> {
  String? _label;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _label = '${info.appName} ${info.version} (${info.buildNumber})';
    });
  }

  @override
  Widget build(BuildContext context) {
    final label = _label;
    if (label == null) return const SizedBox.shrink();

    return Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
