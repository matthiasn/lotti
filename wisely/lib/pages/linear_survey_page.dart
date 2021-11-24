// modified from https://github.com/cph-cachet/research.package/blob/master/example/lib/linear_survey_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:research_package/research_package.dart';
import 'package:wisely/surveys/linear_survey_objects.dart';

class LinearSurveyPage extends StatelessWidget {
  const LinearSurveyPage({Key? key}) : super(key: key);

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
        child: RPUITask(
          task: linearSurveyTask,
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
    ]);
  }
}
