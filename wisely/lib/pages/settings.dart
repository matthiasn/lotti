import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wisely/blocs/counter_bloc.dart';
import 'package:wisely/blocs/vector_clock_counter_cubit.dart';
import 'package:wisely/sync/encryption.dart';
import 'package:wisely/sync/encryption_salsa.dart';
import 'package:wisely/widgets/sync/imap_config.dart';
import 'package:wisely/widgets/sync/qr_widget.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CounterBloc, int>(builder: (context, int count) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
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
                      onPressed: () {
                        encryptDecrypt("fooo bar");
                        encryptDecryptSalsa("fooo bar");
                        context.read<VectorClockCubit>().increment();
                        context.read<CounterBloc>().add(Increment());
                      }),
                  Text('$count', style: Theme.of(context).textTheme.headline6)
                ],
              ),
              const EncryptionQrWidget(),
              const EmailConfigForm(),
            ],
          ),
        ),
      );
    });
  }
}
