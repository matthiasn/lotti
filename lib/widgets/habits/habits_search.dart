import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/habits/habits_cubit.dart';
import 'package:lotti/blocs/habits/habits_state.dart';
import 'package:lotti/themes/theme.dart';

class HabitsSearchWidget extends StatelessWidget {
  const HabitsSearchWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();

    return BlocBuilder<HabitsCubit, HabitsState>(
      builder: (context, HabitsState state) {
        final cubit = context.read<HabitsCubit>();

        final styleActive = searchFieldStyle();
        final styleHint = searchFieldHintStyle();
        final style = state.searchString.isEmpty ? styleHint : styleActive;

        return Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: SearchBar(
                controller: controller,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.search,
                    color: style.color,
                  ),
                ),
                trailing: [
                  Visibility(
                    visible: cubit.state.searchString.isNotEmpty,
                    child: GestureDetector(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.close_rounded,
                          color: style.color,
                        ),
                      ),
                      onTap: () {
                        cubit.setSearchString('');
                        controller.clear();
                        FocusScope.of(context).requestFocus(FocusNode());
                      },
                    ),
                  ),
                ],
                onChanged: cubit.setSearchString,
              ),
            ),
          ),
        );
      },
    );
  }
}
