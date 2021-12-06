import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/classes/journal_entities.dart';

class SurveySummaryWidget extends StatelessWidget {
  final SurveyEntry surveyEntry;
  const SurveySummaryWidget(
    this.surveyEntry, {
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: surveyEntry.data.calculatedScores.entries
          .map((mapEntry) => Padding(
                padding: const EdgeInsets.all(4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      '${mapEntry.key}: ',
                      style: const TextStyle(
                        fontWeight: FontWeight.normal,
                        fontFamily: 'Oswald',
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      mapEntry.value.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w300,
                        fontSize: 16,
                        fontFamily: 'Oswald',
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
