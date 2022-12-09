import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/habits/habits_cubit.dart';
import 'package:lotti/blocs/habits/habits_state.dart';
import 'package:lotti/themes/theme.dart';

class HabitsPageProgressBar extends StatelessWidget {
  const HabitsPageProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HabitsCubit, HabitsState>(
      builder: (context, HabitsState state) {
        final width = MediaQuery.of(context).size.width - 200;
        const height = 20.0;
        final total = state.habitDefinitions.length;

        if (total == 0) {
          return const SizedBox.shrink();
        }

        final successfulToday = state.successfulToday.length;
        final done = successfulToday / total;
        final percentage = (done * 100).toInt();

        final greenWidth = done * width;
        final redWidth = width - greenWidth - 1;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: 0,
              child: Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Text(
                  '$percentage %',
                  style: chartTitleStyle().copyWith(
                    color: styleConfig().primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(height),
              child: Row(
                children: [
                  Container(
                    width: greenWidth,
                    height: height,
                    color: styleConfig().primaryColor,
                  ),
                  const SizedBox(width: 1),
                  Opacity(
                    opacity: 0.5,
                    child: Container(
                      width: redWidth,
                      height: height,
                      color: styleConfig().alarm,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text(
                '$percentage %',
                style: chartTitleStyle().copyWith(
                  color: styleConfig().primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
