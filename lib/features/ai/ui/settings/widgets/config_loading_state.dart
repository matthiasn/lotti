import 'package:flutter/material.dart';

/// A simple loading state widget for configuration lists
///
/// Displays a centered circular progress indicator.
/// This widget provides consistent loading UI across the AI settings module.
///
/// Example:
/// ```dart
/// const ConfigLoadingState()
/// ```
class ConfigLoadingState extends StatelessWidget {
  const ConfigLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}
