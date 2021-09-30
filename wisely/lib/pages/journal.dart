import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:wisely/blocs/counter_bloc.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({Key? key}) : super(key: key);

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final _bloc = CounterBloc();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            OutlinedButton(
              onPressed: () => _bloc.add(Increment()),
              child: const Text(
                'Increment',
                style: TextStyle(color: CupertinoColors.systemOrange),
              ),
            ),
            OutlinedButton(
              onPressed: () => _bloc.add(Decrement()),
              child: const Text(
                'Decrement',
                style: TextStyle(color: CupertinoColors.systemOrange),
              ),
            ),
            StreamBuilder<int>(
                stream: _bloc.stream,
                initialData: 0,
                builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
                  return Text('You hit me: ${snapshot.data} times');
                }),
          ],
        ),
      ),
    );
  }
}
