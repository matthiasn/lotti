import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/providers/service_providers.dart';

/// Invisible wrapper that triggers a full sync catch-up on app resume.
///
/// This ensures sessions that were backgrounded (without a connectivity
/// transition) still perform a robust catch-up immediately on resume.
class AppLifecycleRescanObserver extends ConsumerStatefulWidget {
  const AppLifecycleRescanObserver({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLifecycleRescanObserver> createState() =>
      _AppLifecycleRescanObserverState();
}

class _AppLifecycleRescanObserverState
    extends ConsumerState<AppLifecycleRescanObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Unawaited; MatrixService handles coalescing and logging.
      ref.read(matrixServiceProvider).forceRescan();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
