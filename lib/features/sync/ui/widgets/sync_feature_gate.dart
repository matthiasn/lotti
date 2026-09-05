import 'package:beamer/beamer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/profiles/state/profile_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

/// Keeps sync-only surfaces out of worlds that cannot render them.
///
/// Two gates, in order:
///
/// 1. **Capability** — guest/demo worlds never construct the Matrix stack
///    (`ProfileCapabilities.guest`), so [child] must not build there at
///    all: it would resolve `matrixServiceProvider`, which is deliberately
///    unoverridden in guest worlds and fails with an `UnimplementedError`.
/// 2. **Config flag** — in real worlds the `enable_matrix` flag decides
///    whether the sync surfaces are shown.
///
/// Either gate failing redirects back to Settings after the first frame,
/// preserving the deep-link bounce behaviour.
class SyncFeatureGate extends ConsumerWidget {
  const SyncFeatureGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(syncFeatureAvailableProvider)) {
      return const _BounceToSettings();
    }
    return StreamBuilder<bool>(
      stream: getIt<JournalDb>().watchConfigFlag(enableMatrixFlag),
      builder: (context, snap) {
        // While loading initial flag value, render nothing (avoid false redirect bounce).
        if (!snap.hasData) {
          return const SizedBox.shrink();
        }

        final enabled = snap.data ?? false;
        if (enabled) return child;

        return const _BounceToSettings();
      },
    );
  }
}

/// Renders nothing and beams back to the Settings root after the first
/// frame — the shared "this surface does not exist here" behaviour of
/// [SyncFeatureGate].
class _BounceToSettings extends StatelessWidget {
  const _BounceToSettings();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      try {
        Beamer.of(context).beamToNamed('/settings');
      } catch (_) {
        // In tests or contexts without Beamer, just render nothing.
      }
    });
    return const SizedBox.shrink();
  }
}
