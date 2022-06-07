import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_sliding_tutorial/flutter_sliding_tutorial.dart';
import 'package:lotti/theme.dart';

double textBodyWidth(BuildContext context) {
  num screenW = MediaQuery.of(context).size.width;
  return min(screenW - 64 - screenW / 8, 700);
}

class SyncAssistantHeaderWidget extends StatelessWidget {
  const SyncAssistantHeaderWidget({
    Key? key,
    required this.index,
    required this.pageCount,
  }) : super(key: key);

  final int index;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    String title =
        '${localizations.syncAssistantHeadline} ${index + 1} / $pageCount';

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
