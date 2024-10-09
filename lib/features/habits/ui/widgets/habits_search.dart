import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/habits/habits_cubit.dart';
import 'package:lotti/blocs/habits/habits_state.dart';

class HabitsSearchWidget extends StatelessWidget {
  const HabitsSearchWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();

    return BlocBuilder<HabitsCubit, HabitsState>(
      builder: (context, HabitsState state) {
        final cubit = context.read<HabitsCubit>();

        return Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Theme(
                data: Theme.of(context).copyWith(
                  inputDecorationTheme: const InputDecorationTheme(),
                ),
                child: SearchBar(
                  controller: controller,
                  leading: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.search),
                  ),
                  trailing: [
                    Visibility(
                      visible: cubit.state.searchString.isNotEmpty,
                      child: GestureDetector(
                        child: const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(Icons.close_rounded),
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
          ),
        );
      },
    );
  }
}
