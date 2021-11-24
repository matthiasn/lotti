// modified from https://github.com/cph-cachet/research.package/blob/master/example/lib/linear_survey_page.dart
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:research_package/research_package.dart';
import 'package:wisely/surveys/cfq11_survey.dart';
import 'package:wisely/surveys/panas_survey.dart';
import 'package:wisely/widgets/buttons.dart';

class LinearSurveyPage extends StatelessWidget {
  final RPOrderedTask task;
  const LinearSurveyPage(this.task, {Key? key}) : super(key: key);

  String _encode(Object object) =>
      const JsonEncoder.withIndent(' ').convert(object);

  void printWrapped(String text) {
    final pattern = RegExp('.{1,800}'); // 800 is the size of each chunk
    pattern.allMatches(text).forEach((match) => debugPrint(match.group(0)));
  }

  void resultCallback(RPTaskResult result) {
    // Do anything with the result
    debugPrint(_encode(result));
  }

  void cancelCallBack(RPTaskResult result) {
    // Do anything with the result at the moment of the cancellation
    debugPrint("The result so far:\n" + _encode(result));
  }

  @override
  Widget build(BuildContext context) {
    return Flex(direction: Axis.vertical, children: [
      Expanded(
        child: Theme(
          data: ThemeData(
            primaryColor: Colors.lightBlue[800],
            fontFamily: 'Oswald',

            // Define the default `TextTheme`. Use this to specify the default
            // text styling for headlines, titles, bodies of text, and more.
            textTheme: TextTheme(
              headline3: const TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
              ),
              headline5: const TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.w100,
              ),
              headline6: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.w400,
                color: Colors.grey[800],
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 40.0),
            child: RPUITask(
              task: task,
              onSubmit: resultCallback,
              onCancel: (RPTaskResult? result) {
                if (result == null) {
                  debugPrint("No result");
                } else {
                  cancelCallBack(result);
                }
              },
            ),
          ),
        ),
      ),
    ]);
  }
}

class SurveyPage extends StatelessWidget {
  const SurveyPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    void runSurvey(RPOrderedTask task) async {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(16),
          ),
        ),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        builder: (BuildContext context) {
          return LinearSurveyPage(task);
        },
      );
    }

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Button(
              'CFQ 11',
              onPressed: () => runSurvey(cfq11SurveyTask),
              primaryColor: CupertinoColors.systemOrange,
            ),
            Button(
              'PANAS',
              onPressed: () => runSurvey(panasSurveyTask),
              primaryColor: CupertinoColors.systemOrange,
            ),
          ],
        ),
      ),
    );
  }
}
