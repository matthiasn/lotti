import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/tasks/state/time_by_category_controller.dart';

class TimeByCategoryChart extends ConsumerWidget {
  const TimeByCategoryChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(timeByCategoryControllerProvider).value;

    return Column(
      children: [
        const Divider(),
        const Text('Time by category:'),
        ...?data?.keys.map((
          key,
        ) {
          final value = data[key];
          return Text('$key: $value');
        }),
        const Divider(),
      ],
    );
  }
}
