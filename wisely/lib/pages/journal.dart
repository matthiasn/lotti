import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wisely/blocs/counter_bloc.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({Key? key}) : super(key: key);

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
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
    return BlocBuilder<CounterBloc, int>(builder: (context, count) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    tooltip: 'Decrement',
                    onPressed: () =>
                        context.read<CounterBloc>().add(Decrement()),
                  ),
                  IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'Increment',
                      onPressed: () =>
                          context.read<CounterBloc>().add(Increment())),
                ],
              ),
              Text('$count', style: Theme.of(context).textTheme.headline1),
            ],
          ),
        ),
      );
    });
  }
}
