import 'package:flutter/material.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';
import 'package:lotti/theme.dart';

class LinkedDuration extends StatelessWidget {
  final JournalDb db = getIt<JournalDb>();
  final String id;

  LinkedDuration({
    required this.id,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: db.watchLinkedTotalDuration(linkedFrom: id),
        builder: (_, AsyncSnapshot<Duration> snapshot) {
          return Text(
            snapshot.data.toString().split('.').first,
            style: TextStyle(
              fontFamily: 'Oswald',
              color: AppColors.entryTextColor,
              fontWeight: FontWeight.normal,
              fontSize: 14.0,
            ),
          );
        });
  }
}
