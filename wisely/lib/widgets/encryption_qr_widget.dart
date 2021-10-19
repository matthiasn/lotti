import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wisely/blocs/encryption/encryption_cubit.dart';

class EncryptionQrWidget extends StatelessWidget {
  const EncryptionQrWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EncryptionCubit, EncryptionState>(
        builder: (context, EncryptionState state) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TextButton(
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16.0,
                    horizontal: 32.0,
                  ),
                  backgroundColor: Colors.white),
              onPressed: () => context.read<EncryptionCubit>().loadSharedKey(),
              child: const Text(
                'Load Shared Key',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Padding(padding: EdgeInsets.all(8.0)),
            TextButton(
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16.0,
                    horizontal: 32.0,
                  ),
                  backgroundColor: Colors.red),
              onPressed: () =>
                  context.read<EncryptionCubit>().generateSharedKey(),
              child: const Text(
                'Generate Shared Key',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Padding(padding: EdgeInsets.all(8.0)),
            state.when(
              (String? sharedKey) => Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.all(
                        Radius.circular(8.0),
                      ),
                    ),
                    child: QrImage(
                      data: sharedKey!,
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                  ),
                  const Padding(padding: EdgeInsets.all(8.0)),
                  Text(
                    sharedKey,
                    style: const TextStyle(
                      fontFamily: 'ShareTechMono',
                    ),
                  ),
                  const Padding(padding: EdgeInsets.all(8.0)),
                  TextButton(
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16.0,
                          horizontal: 32.0,
                        ),
                        backgroundColor: Colors.red),
                    onPressed: () =>
                        context.read<EncryptionCubit>().deleteSharedKey(),
                    child: const Text(
                      'Delete Shared Key',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              loading: () => const Text('loading key'),
              generating: () => const Text('generating key'),
              empty: () => const Text('not initialized'),
            ),
          ],
        ),
      );
    });
  }
}
