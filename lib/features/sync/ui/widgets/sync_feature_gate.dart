import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/consts.dart';

class SyncFeatureGate extends StatelessWidget {
  const SyncFeatureGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: getIt<JournalDb>().watchConfigFlag(enableMatrixFlag),
      builder: (context, snap) {
        // While loading initial flag value, render nothing (avoid false redirect bounce).
        if (!snap.hasData) {
          return const SizedBox.shrink();
        }

        final enabled = snap.data ?? false;
        if (enabled) return child;

        // If disabled, try to navigate back to Settings after first frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          try {
            Beamer.of(context).beamToNamed('/settings');
          } catch (_) {
            // In tests or contexts without Beamer, just render nothing.
          }
        });
        return const SizedBox.shrink();
      },
    );
  }
}
