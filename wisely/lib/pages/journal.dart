import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({Key? key}) : super(key: key);

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  //
  // Initialize a "Broadcast" Stream controller of integers
  //
  final StreamController<int> ctrl = StreamController<int>.broadcast();

  @override
  void initState() {
    super.initState();

    //
    // Initialize a single listener which filters out the odd numbers and
    // only prints the even numbers
    //
    final StreamSubscription subscription = ctrl.stream
        .where((value) => (value % 2 == 0))
        .listen((value) => print('$value'));

    //
    // We here add the data that will flow inside the stream
    //
    for (int i = 1; i < 11; i++) {
      ctrl.sink.add(i);
    }

    //
    // We release the StreamController
    //
    ctrl.close();
  }

  void _click() async {}

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            OutlinedButton(
              onPressed: _click,
              child: const Text(
                'Click me',
                style: TextStyle(color: CupertinoColors.systemOrange),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
