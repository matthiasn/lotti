import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lotti/features/manual/task/presentation/controllers/task_controller.dart';
import 'package:lotti/features/manual/task/presentation/widgets/task_card.dart';
import 'package:lotti/widgets/manual/manual_icons.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class ManualPage extends ConsumerWidget {
  const ManualPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = TaskManualController(ref);
    // final manualContent = controller.getManualContent();
    final manualNote = controller.manualNote;
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            child: Text(
              manualNote,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              textAlign: TextAlign.left,
            ),
          ),
          const SizedBox(
            height: 30,
          ),
          const ManualIcons(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            icon1: Icons.check_circle_outlined,
            icon2: Ionicons.book_outline,
            manualheader: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outlined,
                ),
                Text(
                  'Tasks',
                ),
              ],
            ),
            iconFunc: TaskCard(),
            iconFunc2: Column(
              children: [
                Icon(
                  Ionicons.bar_chart_outline,
                ),
                Text('Dashboard'),
              ],
            ),
          ),
          const SizedBox(
            height: 30,
          ),
          const ManualIcons(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            icon1: Icons.calendar_month_outlined,
            icon2: Icons.settings_outlined,
            manualheader: Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                ),
                Text('Calendar'),
              ],
            ),
            iconFunc: Text('How to view daily/weekly/monthly behavioral patterns'),
            iconFunc2: Column(
              children: [
                Icon(
                  Icons.settings_outlined,
                ),
                Text('Settings'),
              ],
            ),
          ),
          const SizedBox(
            height: 30,
          ),
          ManualIcons(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            icon1: MdiIcons.checkboxMultipleMarkedOutline,
            icon2: Ionicons.bar_chart_outline,
            manualheader: Row(
              children: [
                Icon(
                  MdiIcons.checkboxMultipleMarkedOutline,
                ),
                const Text('Habits'),
              ],
            ),
            iconFunc: const Center(
              child: Text('Here is where the Habits instruction will be'),
            ),
            iconFunc2: const Column(
              children: [
                Icon(
                  Ionicons.bar_chart_outline,
                ),
                Text('Dashboard'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
