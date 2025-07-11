// modified from https://github.com/cph-cachet/research.package/blob/master/example/lib/linear_survey_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:research_package/research_package.dart';

class SurveyWidget extends StatelessWidget {
  const SurveyWidget(this.task, this.resultCallback, {super.key});

  final RPOrderedTask task;
  final void Function(RPTaskResult) resultCallback;

  String _encode(Object object) =>
      const JsonEncoder.withIndent(' ').convert(object);

  void cancelCallBack(RPTaskResult result) {
    // Do anything with the result at the moment of the cancellation
    debugPrint('The result so far:\n${_encode(result)}');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 500),
      padding: const EdgeInsets.only(bottom: 20, left: 10, right: 10),
      child: RPUITask(
        task: task,
        onSubmit: resultCallback,
        onCancel: (RPTaskResult? result) {
          if (result == null) {
            debugPrint('No result');
          } else {
            cancelCallBack(result);
          }
        },
      ),
    );
  }
}
