import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';

class HabitsSearchWidget extends ConsumerWidget {
  const HabitsSearchWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final state = ref.watch(habitsControllerProvider);
    final habitsController = ref.read(habitsControllerProvider.notifier);

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Theme(
            data: Theme.of(context).copyWith(),
            child: SearchBar(
              elevation: WidgetStateProperty.all(5),
              controller: controller,
              leading: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.search),
              ),
              trailing: [
                Visibility(
                  visible: state.searchString.isNotEmpty,
                  child: GestureDetector(
                    child: const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.close_rounded),
                    ),
                    onTap: () {
                      habitsController.setSearchString('');
                      controller.clear();
                      FocusScope.of(context).requestFocus(FocusNode());
                    },
                  ),
                ),
              ],
              onChanged: habitsController.setSearchString,
            ),
          ),
        ),
      ),
    );
  }
}
