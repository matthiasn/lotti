import 'dart:async';
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
      // Unawaited; attach error logging to avoid unhandled async errors.
      unawaited(
        ref.read(matrixServiceProvider).forceRescan().catchError(
          (Object error, StackTrace stackTrace) {
            try {
              ref.read(loggingServiceProvider).captureException(
                    error,
                    stackTrace: stackTrace,
                    domain: 'AppLifecycleRescanObserver',
                    subDomain: 'didChangeAppLifecycleState',
                  );
            } catch (_) {
              // Best-effort logging only.
            }
          },
        ),
      );
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
