import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({Key? key}) : super(key: key);

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  int _counter = 0;
  final StreamController<int> _streamController = StreamController<int>();

  @override
  void dispose() {
    _streamController.close();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  void _click() async {
    _streamController.sink.add(++_counter);
  }

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
            StreamBuilder<int>(
                stream: _streamController.stream,
                initialData: _counter,
                builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
                  return Text('You hit me: ${snapshot.data} times');
                }),
          ],
        ),
      ),
    );
  }
}
