import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_sliding_tutorial/flutter_sliding_tutorial.dart';
import 'package:lotti/theme.dart';

double textBodyWidth(BuildContext context) {
  num screenW = MediaQuery.of(context).size.width;
  return min(screenW - 32 - screenW / 8, 700);
}

class SyncAssistantHeaderWidget extends StatelessWidget {
  const SyncAssistantHeaderWidget({
    Key? key,
    required this.title,
  }) : super(key: key);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SlidingContainer(
        offset: 250,
        child: Padding(
          padding: const EdgeInsets.only(top: 32.0),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: titleStyle.copyWith(fontSize: 40),
          ),
        ),
      ),
    );
  }
}
