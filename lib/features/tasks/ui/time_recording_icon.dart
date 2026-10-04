import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/themes/theme.dart';
import 'package:material_ui/material_ui.dart';

/// Red dot shown only while the task identified by [taskId] is the one
/// currently being time-tracked.
///
/// Listens to `TimeService` and compares the active recording's linked task
/// id against [taskId]; renders a small error-coloured [ColorIcon] (with the
/// given [padding]) when they match and an empty box otherwise.
class TimeRecordingIcon extends ConsumerWidget {
  const TimeRecordingIcon({
    required this.taskId,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final String taskId;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeService = ref.watch(timeServiceProvider);

    return StreamBuilder<String?>(
      initialData: timeService.linkedFrom?.meta.id,
      stream: timeService
          .getStream()
          .map((_) => timeService.linkedFrom?.meta.id)
          .distinct(),
      builder:
          (
            _,
            AsyncSnapshot<String?> snapshot,
          ) {
            if (snapshot.data != taskId) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: padding,
              child: ColorIcon(
                context.colorScheme.error,
                size: 12,
              ),
            );
          },
    );
  }
}
